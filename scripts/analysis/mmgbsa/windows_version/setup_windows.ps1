[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "config_windows.json")
)

$ErrorActionPreference = "Stop"

function Read-Value {
    param([string]$Prompt, [string]$Default = "")
    $suffix = if ($Default) { " [$Default]" } else { "" }
    $value = Read-Host "$Prompt$suffix"
    if ([string]::IsNullOrWhiteSpace($value)) { return $Default }
    return $value.Trim('"')
}

function Find-Executable {
    param([string[]]$Names)
    foreach ($name in $Names) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    return ""
}

Write-Host "=== MM/GBSA Windows Setup ===" -ForegroundColor Cyan
Write-Host "Paste full paths from File Explorer. Outer quotes are removed automatically."

$vmdDefault = Find-Executable @("vmd.exe", "vmd")
$namdDefault = Find-Executable @("namd3.exe", "namd2.exe", "namd3", "namd2")

$vmd = Read-Value "VMD executable" $vmdDefault
$namd = Read-Value "NAMD executable" $namdDefault
$toppar = Read-Value "CHARMM toppar directory"
$ligandPrm = Read-Value "TO parameter file (for example, tog.prm)"
$psf = Read-Value "Input PSF"
$pdb = Read-Value "Input PDB"
$coor = Read-Value "Input COOR"
$projectRoot = Split-Path $PSScriptRoot -Parent
$output = Read-Value "Output directory" (Join-Path $projectRoot "mmgbsa_output")
$targetSegid = Read-Value "G4 target segid" "DNAA"
$ligandSegid = Read-Value "TO ligand segid" "HETA"
$coresText = Read-Value "NAMD CPU core count" "4"
$cores = [int]$coresText

$replicas = @()
do {
    $repNumber = [int](Read-Value "Replica number" ([string]($replicas.Count + 1)))
    $dcd = Read-Value "DCD for replica $repNumber"
    $replicas += [ordered]@{ number = $repNumber; dcd = $dcd }
    $more = Read-Value "Add another replica? (y/N)" "N"
} while ($more -match '^[Yy]')

$config = [ordered]@{
    vmd_executable = $vmd
    namd_executable = $namd
    toppar_dir = $toppar
    ligand_parameter = $ligandPrm
    psf = $psf
    pdb = $pdb
    coor = $coor
    output_dir = $output
    target_segid = $targetSegid
    ligand_segid = $ligandSegid
    stride = 1
    cores = $cores
    energy_filter_min = -8000.0
    energy_filter_max = 1000.0
    replicas = $replicas
}

$parent = Split-Path -Parent $ConfigPath
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
$config | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ConfigPath -Encoding utf8

Write-Host "Configuration saved: $ConfigPath" -ForegroundColor Green
Write-Host "Next steps:"
Write-Host "  .\run_mmgbsa.ps1 -Stage Check"
Write-Host "  .\run_mmgbsa.ps1 -Stage All"
