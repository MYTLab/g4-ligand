[CmdletBinding()]
param(
    [ValidateSet("Check", "Prepare", "Energy", "Postprocess", "All")]
    [string]$Stage = "All",
    [string]$ConfigPath = (Join-Path $PSScriptRoot "config_windows.json")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Require-File {
    param([string]$Path, [string]$Label)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label does not exist: $Path"
    }
}

function Require-Directory {
    param([string]$Path, [string]$Label)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "$Label does not exist: $Path"
    }
}

function To-TclPath {
    param([string]$Path)
    return ([IO.Path]::GetFullPath($Path)).Replace('\', '/')
}

function Read-Number {
    param([string]$Text)
    return [double]::Parse($Text, [Globalization.CultureInfo]::InvariantCulture)
}

function Format-Number {
    param([double]$Value)
    return $Value.ToString("R", [Globalization.CultureInfo]::InvariantCulture)
}

function Test-Configuration {
    param($Config)

    Require-File $Config.vmd_executable "VMD executable"
    Require-File $Config.namd_executable "NAMD executable"
    Require-Directory $Config.toppar_dir "CHARMM toppar directory"
    Require-File $Config.ligand_parameter "Ligand parameter"
    Require-File $Config.psf "PSF"
    Require-File $Config.pdb "PDB"
    Require-File $Config.coor "COOR"

    if ([int]$Config.cores -lt 1) { throw "cores must be at least 1." }
    if ([int]$Config.stride -lt 1) { throw "stride must be at least 1." }
    if ([string]::IsNullOrWhiteSpace([string]$Config.target_segid)) { throw "target_segid cannot be empty." }
    if ([string]::IsNullOrWhiteSpace([string]$Config.ligand_segid)) { throw "ligand_segid cannot be empty." }

    $seen = @{}
    $replicas = @($Config.replicas)
    if ($replicas.Count -eq 0) { throw "At least one replica is required." }
    foreach ($rep in $replicas) {
        $number = [int]$rep.number
        if ($number -lt 1) { throw "Replica numbers must be greater than zero." }
        if ($seen.ContainsKey($number)) { throw "Duplicate replica number: $number" }
        $seen[$number] = $true
        Require-File $rep.dcd "Replica $number DCD"
    }

    Write-Host "Configuration check passed." -ForegroundColor Green
    Write-Host "Output directory: $($Config.output_dir)"
    Write-Host "Replicas: $($replicas.number -join ', ')"
}

function Invoke-Prepare {
    param($Config)

    $outputDir = [IO.Path]::GetFullPath([string]$Config.output_dir)
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

    $tclScript = Join-Path (Split-Path $PSScriptRoot -Parent) "prepare_trajectory\stripsplit.tcl"
    Require-File $tclScript "stripsplit.tcl"

    $oldCpuCount = $env:VMDFORCECPUCOUNT
    $env:VMDFORCECPUCOUNT = "1"
    try {
        foreach ($rep in @($Config.replicas)) {
            $number = [int]$rep.number
            $log = Join-Path $outputDir "stripsplit-rep$number.log"
            $arguments = @(
                "-dispdev", "text",
                "-e", (To-TclPath $tclScript),
                "-args",
                "--outdir", (To-TclPath $outputDir),
                "--dcdfmt", (To-TclPath ([string]$rep.dcd)),
                "--rep", "$number",
                "--stride", "$([int]$Config.stride)",
                "--nstages", "1",
                "--targseg", [string]$Config.target_segid,
                "--ligseg", [string]$Config.ligand_segid,
                "--psf", (To-TclPath ([string]$Config.psf)),
                "--pdb", (To-TclPath ([string]$Config.pdb)),
                "--coor", (To-TclPath ([string]$Config.coor))
            )
            if (-not (Test-Path -LiteralPath (Join-Path $outputDir "complex.psf"))) {
                $arguments += "--mkpsf"
            }

            Write-Host "`n[VMD] Processing replica $number ..." -ForegroundColor Cyan
            & $Config.vmd_executable @arguments 2>&1 | Tee-Object -FilePath $log
            if ($LASTEXITCODE -ne 0) { throw "VMD failed for replica $number. See: $log" }

            foreach ($system in @("complex", "target", "ligand")) {
                Require-File (Join-Path $outputDir "$system-rep$number-formmgbsa.dcd") "$system replica $number DCD"
            }
        }
    }
    finally {
        $env:VMDFORCECPUCOUNT = $oldCpuCount
    }

    Write-Host "`nTrajectory preparation completed: $outputDir" -ForegroundColor Green
}

function Get-EnergyRows {
    param([string]$LogPath)
    $rows = [Collections.Generic.List[object]]::new()
    foreach ($line in Get-Content -LiteralPath $LogPath) {
        if (-not $line.StartsWith("ENERGY:")) { continue }
        $parts = $line -split '\s+'
        if ($parts.Count -lt 14) { continue }
        try {
            $rows.Add([pscustomobject]@{
                Step = Read-Number $parts[1]
                Total = Read-Number $parts[13]
            })
        }
        catch {
            continue
        }
    }
    return @($rows)
}

function Invoke-Energy {
    param(
        $Config,
        [switch]$SkipNAMD
    )

    $outputDir = [IO.Path]::GetFullPath([string]$Config.output_dir)
    Require-Directory $outputDir "Prepared trajectory output directory"
    $templatePath = Join-Path $PSScriptRoot "gbis_template_windows.namd"
    Require-File $templatePath "Windows NAMD template"
    $template = Get-Content -LiteralPath $templatePath -Raw
    $systems = @("complex", "target", "ligand")

    Push-Location $outputDir
    try {
        foreach ($rep in @($Config.replicas)) {
            $number = [int]$rep.number
            $energyBySystem = @{}

            foreach ($system in $systems) {
                Require-File (Join-Path $outputDir "$system.psf") "$system PSF"
                Require-File (Join-Path $outputDir "$system.pdb") "$system PDB"
                Require-File (Join-Path $outputDir "$system-rep$number-formmgbsa.dcd") "$system replica $number DCD"

                $conf = Join-Path $outputDir "m-$system-rep$number.namd"
                $log = Join-Path $outputDir "m-$system-rep$number.log"
                $energyFile = Join-Path $outputDir "m-$system-rep$number.e"
                $topparPath = To-TclPath ([string]$Config.toppar_dir)
                $ligandPath = To-TclPath ([string]$Config.ligand_parameter)
                $rendered = $template.Replace("%SYS%", $system).Replace("%REP%", "$number").Replace("%TOPPARDIR%", $topparPath).Replace("%LIGAND_PRM%", $ligandPath)
                Set-Content -LiteralPath $conf -Value $rendered -Encoding ascii

                if ($SkipNAMD) {
                    Require-File $log "Existing NAMD log for $system replica $number"
                    Write-Host "`n[Postprocess] Reading $log" -ForegroundColor Cyan
                }
                else {
                    Write-Host "`n[NAMD] replica $number / $system ..." -ForegroundColor Cyan
                    & $Config.namd_executable "+p$([int]$Config.cores)" $conf 2>&1 | Tee-Object -FilePath $log
                    if ($LASTEXITCODE -ne 0) { throw "NAMD failed for $system replica $number. See: $log" }
                }

                $rows = @(Get-EnergyRows $log)
                if ($rows.Count -eq 0) { throw "No ENERGY records were found in $log." }
                $energyBySystem[$system] = $rows

                if ($system -eq "ligand") {
                    $rows | ForEach-Object { "$(Format-Number $_.Step) $(Format-Number $_.Total)" } |
                        Set-Content -LiteralPath $energyFile -Encoding ascii
                }
                else {
                    $rows | ForEach-Object { Format-Number $_.Total } |
                        Set-Content -LiteralPath $energyFile -Encoding ascii
                }
            }

            $counts = $systems | ForEach-Object { @($energyBySystem[$_]).Count }
            $uniqueCounts = @($counts | Select-Object -Unique)
            if ($uniqueCounts.Count -ne 1) {
                throw "ENERGY row counts differ for replica $number (complex/target/ligand): $($counts -join ', ')"
            }

            for ($i = 0; $i -lt $counts[0]; $i++) {
                $steps = $systems | ForEach-Object { $energyBySystem[$_][$i].Step }
                $uniqueSteps = @($steps | Select-Object -Unique)
                if ($uniqueSteps.Count -ne 1) {
                    throw "NAMD steps differ for replica $number at row ${i}: $($steps -join ', ')"
                }
            }

            $result = [Collections.Generic.List[string]]::new()
            $result.Add("# step instantaneous_delta_g running_average_delta_g")
            $sum = 0.0
            $accepted = 0
            for ($i = 0; $i -lt $counts[0]; $i++) {
                $delta = $energyBySystem.complex[$i].Total -
                    $energyBySystem.target[$i].Total -
                    $energyBySystem.ligand[$i].Total
                if ($delta -le [double]$Config.energy_filter_min -or $delta -ge [double]$Config.energy_filter_max) {
                    continue
                }
                $accepted++
                $sum += $delta
                $average = $sum / $accepted
                $step = $energyBySystem.ligand[$i].Step
                $result.Add("$(Format-Number $step) $(Format-Number $delta) $(Format-Number $average)")
            }
            if ($accepted -eq 0) { throw "No frames passed the energy filter for replica $number." }

            $finalPath = Join-Path $outputDir "final_results_rep$number.dat"
            $result | Set-Content -LiteralPath $finalPath -Encoding ascii
            Write-Host "Replica $number completed: $finalPath ($accepted frames)" -ForegroundColor Green
        }
    }
    finally {
        Pop-Location
    }
}

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    throw "Configuration file not found: $ConfigPath`nRun .\setup_windows.ps1 first."
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
Test-Configuration $config

switch ($Stage) {
    "Check"   { break }
    "Prepare" { Invoke-Prepare $config }
    "Energy"  { Invoke-Energy $config }
    "Postprocess" { Invoke-Energy $config -SkipNAMD }
    "All"     { Invoke-Prepare $config; Invoke-Energy $config }
}
