# stripsplit.tcl (c) 2019,2020 cameron f abrams
# Modified for ASHER: Added dynamic output directory handling

package require pbctools
package require psfgen

# -----------------------------------------------------------------------------
# 預設參數設定
# -----------------------------------------------------------------------------
set targ_seg DNAA
set lig_seg HETA
set rep -1
set stride 1
set MKPSF 1
set nstages 1
set PSF step3_input.psf
set PDB step3_input.pdb
set COOR G4_TO_center_606.coor
set dcdfmt G4_TO_center_606.dcd
set output_dir "."  ;# 預設為當前目錄

# -----------------------------------------------------------------------------
# 解析命令列參數 (包含新增的 --outdir)
# -----------------------------------------------------------------------------
for { set i 0 } { $i < [llength $argv] } { incr i } {
    if { [lindex $argv $i] == "--dcdfmt" }  { incr i; set dcdfmt [lindex $argv $i] }
    if { [lindex $argv $i] == "--rep" }     { incr i; set rep [lindex $argv $i] }
    if { [lindex $argv $i] == "--stride" }  { incr i; set stride [lindex $argv $i] }
    if { [lindex $argv $i] == "--ligseg" }  { incr i; set lig_seg [lindex $argv $i] }
    if { [lindex $argv $i] == "--targseg" } { incr i; set targ_seg [lindex $argv $i] }
    if { [lindex $argv $i] == "--mkpsf" }   { set MKPSF 1 }
    if { [lindex $argv $i] == "--nstages" } { incr i; set nstages [lindex $argv $i] }
    if { [lindex $argv $i] == "--psf" }     { incr i; set PSF [lindex $argv $i] }
    if { [lindex $argv $i] == "--pdb" }     { incr i; set PDB [lindex $argv $i] }
    if { [lindex $argv $i] == "--coor" }    { incr i; set COOR [lindex $argv $i] }
    # 新增：接收輸出資料夾路徑
    if { [lindex $argv $i] == "--outdir" }  { incr i; set output_dir [lindex $argv $i] }
}

# 檢查必要輸入
if { ! [file exists $PSF] } { puts "Error: $PSF not found."; exit }
if { ! [file exists $PDB] } { puts "Error: $PDB not found."; exit }
if { "$rep" == "-1" } { puts "Must specify replica number with --rep #"; exit }

# -----------------------------------------------------------------------------
# 自動建立輸出資料夾 (Tcl 端雙重保險)
# -----------------------------------------------------------------------------
if { ![file exists $output_dir] } {
    puts "Creating output directory: $output_dir"
    file mkdir $output_dir
}

# -----------------------------------------------------------------------------
# 設定輸出檔案路徑 (全部基於 output_dir)
# -----------------------------------------------------------------------------
set COMPLEX_PSF [file join $output_dir "complex.psf"]
set TARGET_PSF  [file join $output_dir "target.psf"]
set LIGAND_PSF  [file join $output_dir "ligand.psf"]

set COMPLEX_PDB [file join $output_dir "complex.pdb"]
set TARGET_PDB  [file join $output_dir "target.pdb"]
set LIGAND_PDB  [file join $output_dir "ligand.pdb"]

set COMPLEX_DCD [file join $output_dir "complex-rep${rep}-formmgbsa.dcd"]
set TARGET_DCD  [file join $output_dir "target-rep${rep}-formmgbsa.dcd"]
set LIGAND_DCD  [file join $output_dir "ligand-rep${rep}-formmgbsa.dcd"]

puts "Output configuration set to: $output_dir"

# -----------------------------------------------------------------------------
# 產生 PSF 邏輯
# -----------------------------------------------------------------------------
if { "$MKPSF" == "1" } {
    readpsf $PSF
    proc lremove {listVariable value} {
        upvar 1 $listVariable var
        set idx [lsearch -exact $var $value]
        if {$idx >= 0} { set var [lreplace $var $idx $idx] }
    }
    
    mol load psf $PSF pdb $PDB
    set segids [lsort -unique [[atomselect top all] get segid]]
    mol delete top

    lremove segids $lig_seg
    foreach t $targ_seg { lremove segids $t }
    
    foreach s $segids { delatom $s }
    
    writepsf $COMPLEX_PSF
    delatom $lig_seg
    writepsf $TARGET_PSF
    resetpsf
    
    readpsf $COMPLEX_PSF
    foreach t $targ_seg { delatom $t }
    writepsf $LIGAND_PSF
    resetpsf
}

# -----------------------------------------------------------------------------
# 產生 PDB 邏輯 (Align to reference)
# -----------------------------------------------------------------------------
mol new $PSF
mol addfile $COOR
set reference_id [molinfo top get id]
set aln_ref [atomselect $reference_id "segid $targ_seg"]
$aln_ref moveby [vecscale -1 [measure center $aln_ref]]

[atomselect top "segid $targ_seg"]           writepdb $TARGET_PDB
[atomselect top "segid $lig_seg"]            writepdb $LIGAND_PDB
[atomselect top "segid $targ_seg $lig_seg"]  writepdb $COMPLEX_PDB

mol new $PSF
set working_id [molinfo top get id]

# -----------------------------------------------------------------------------
# 處理 DCD
# -----------------------------------------------------------------------------
for { set st 1 } { $st <= $nstages } { incr st } {
   set dcd [format $dcdfmt]
   if { [file exists $dcd] } {
      animate read dcd $dcd skip $stride waitfor all
   } else {
      puts "Error: $dcd not found."
      exit
   }
}

pbc set {82.0 82.0 82.0 90 90 90 } -now
pbc unwrap -all -sel "segid $targ_seg $lig_seg"
set aln_work [atomselect $working_id "segid $targ_seg"]
set aln_do   [atomselect $working_id "segid $targ_seg $lig_seg"]

for { set i 0 } { $i < [molinfo top get numframes] } { incr i } {
    $aln_work frame $i
    $aln_do frame $i
    $aln_do move [measure fit $aln_work $aln_ref]
}

# -----------------------------------------------------------------------------
# 寫出最終 DCD
# -----------------------------------------------------------------------------
animate write dcd $COMPLEX_DCD waitfor all sel $aln_do   $working_id
set res_targ [atomselect $working_id "segid $targ_seg"]
animate write dcd $TARGET_DCD  waitfor all sel $res_targ $working_id
set res_lig [atomselect $working_id "segid $lig_seg"]
animate write dcd $LIGAND_DCD  waitfor all sel $res_lig  $working_id

# 清理
animate delete beg 0 end [expr [molinfo $working_id get numframes]-1] $working_id
exit
