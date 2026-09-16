# ============================================================
# batch_add_3K_charmmgui.tcl
#
# Input files:
#   551.pdb
#   579.pdb
#   586.pdb
#   589.pdb
#   601.pdb
#   618.pdb
#   631.pdb
#
# Output files:
#   551_K.pdb
#   579_K.pdb
#   ...
#
# Function:
#   1. Select guanine O6 atoms
#   2. Determine G4 stacking/channel axis
#   3. Place 3 K+ ions along the channel
#   4. Write POT ions in CHARMM-GUI-compatible PDB format
#
# ============================================================


# ------------------------------------------------------------
# Files to process
# ------------------------------------------------------------
set files {551 579 586 589 601 618 631}


# ------------------------------------------------------------
# Distance between adjacent K+ ions (Angstrom)
# ------------------------------------------------------------
set spacing 3.4


# ============================================================
# Main loop
# ============================================================

foreach id $files {

    set input_pdb  "${id}.pdb"
    set output_pdb "${id}_K.pdb"

    puts ""
    puts "===================================================="
    puts "Processing : $input_pdb"
    puts "Output     : $output_pdb"
    puts "===================================================="


    # --------------------------------------------------------
    # Check input
    # --------------------------------------------------------
    if {![file exists $input_pdb]} {

        puts "ERROR: $input_pdb not found."
        puts "Skipping..."

        continue
    }


    # --------------------------------------------------------
    # Load PDB
    # --------------------------------------------------------
    mol new $input_pdb type pdb waitfor all


    # --------------------------------------------------------
    # Select guanine O6 atoms
    # --------------------------------------------------------
    set o6 [atomselect top "(resname G DG GUA) and name O6"]

    set n [$o6 num]

    puts "Number of guanine O6 atoms = $n"


    if {$n == 0} {

        puts "ERROR: No guanine O6 atoms found."

        $o6 delete
        mol delete top

        continue
    }


    # --------------------------------------------------------
    # Calculate G4 center
    # --------------------------------------------------------
    set center [measure center $o6]

    lassign $center cx cy cz

    puts ""
    puts "G4 center:"
    puts "  X = $cx"
    puts "  Y = $cy"
    puts "  Z = $cz"


    # O6 coordinates
    set coords [$o6 get {x y z}]


    # --------------------------------------------------------
    # Obtain principal axes
    # --------------------------------------------------------
    set inertia [measure inertia $o6]

    set axes [lindex $inertia 1]

    set axis1 [lindex $axes 0]
    set axis2 [lindex $axes 1]
    set axis3 [lindex $axes 2]


    puts ""
    puts "Principal axes:"
    puts "  Axis1 = $axis1"
    puts "  Axis2 = $axis2"
    puts "  Axis3 = $axis3"


    # --------------------------------------------------------
    # Find G4 stacking/channel axis
    #
    # Test each principal axis by projecting all O6 atoms
    # and calculate projection variance.
    #
    # The axis with the largest spread is taken as the
    # G4 stacking/channel direction.
    # --------------------------------------------------------

    set best_axis ""
    set best_variance -1.0


    foreach axis [list $axis1 $axis2 $axis3] {

        lassign $axis ax ay az

        set projections {}


        foreach xyz $coords {

            lassign $xyz x y z

            set dx [expr {$x - $cx}]
            set dy [expr {$y - $cy}]
            set dz [expr {$z - $cz}]

            set p [expr {
                $dx*$ax +
                $dy*$ay +
                $dz*$az
            }]

            lappend projections $p
        }


        # Calculate mean
        set mean 0.0

        foreach p $projections {

            set mean [expr {$mean + $p}]
        }

        set mean [expr {
            $mean / double([llength $projections])
        }]


        # Calculate variance
        set variance 0.0

        foreach p $projections {

            set d [expr {$p - $mean}]

            set variance [expr {
                $variance + $d*$d
            }]
        }


        puts "Projection variance for $axis = $variance"


        if {$variance > $best_variance} {

            set best_variance $variance
            set best_axis $axis
        }
    }


    # --------------------------------------------------------
    # Normalize channel axis
    # --------------------------------------------------------

    lassign $best_axis ax ay az


    set norm [expr {
        sqrt(
            $ax*$ax +
            $ay*$ay +
            $az*$az
        )
    }]


    set ax [expr {$ax / $norm}]
    set ay [expr {$ay / $norm}]
    set az [expr {$az / $norm}]


    puts ""
    puts "Detected G4 channel axis:"
    puts "  $ax  $ay  $az"


    # --------------------------------------------------------
    # Generate 3 K+ positions
    #
    # K1 = center - spacing * axis
    # K2 = center
    # K3 = center + spacing * axis
    # --------------------------------------------------------

    set k1 [list \
        [expr {$cx - $spacing*$ax}] \
        [expr {$cy - $spacing*$ay}] \
        [expr {$cz - $spacing*$az}] \
    ]


    set k2 [list \
        $cx \
        $cy \
        $cz \
    ]


    set k3 [list \
        [expr {$cx + $spacing*$ax}] \
        [expr {$cy + $spacing*$ay}] \
        [expr {$cz + $spacing*$az}] \
    ]


    set positions [list $k1 $k2 $k3]


    puts ""
    puts "K+ positions:"
    puts "  K1 = $k1"
    puts "  K2 = $k2"
    puts "  K3 = $k3"


    # --------------------------------------------------------
    # Write original structure to temporary PDB
    # --------------------------------------------------------

    set all [atomselect top all]

    set temp_pdb "${id}_temp.pdb"

    $all writepdb $temp_pdb


    # --------------------------------------------------------
    # Open files
    # --------------------------------------------------------

    set fin  [open $temp_pdb r]
    set fout [open $output_pdb w]


    # --------------------------------------------------------
    # Copy original structure
    #
    # Remove END and TER records.
    # We will add our own TER after POT ions.
    # --------------------------------------------------------

    while {[gets $fin line] >= 0} {

        set trimmed [string trim $line]


        if {$trimmed == "END"} {
            continue
        }


        if {[string match "TER*" $trimmed]} {
            continue
        }


        puts $fout $line
    }


    close $fin


    # --------------------------------------------------------
    # Determine next atom serial
    # --------------------------------------------------------

    set atomid [expr {[$all num] + 1}]


    # --------------------------------------------------------
    # POT settings
    #
    # Based on previous CHARMM-GUI ion format:
    #
    # atom name : POT
    # resname   : POT
    # chain ID  : B
    # residue   : 24 / 25 / 26
    # segname   : HETB
    #
    # --------------------------------------------------------

    set resid 24

    set chainID "B"

    set segname "HETB"


    # --------------------------------------------------------
    # Write 3 K+ ions
    #
    # PDB columns:
    #
    #  1-6   ATOM
    #  7-11  atom serial
    # 13-16  atom name = POT
    # 18-20  residue name = POT
    # 22     chain ID = B
    # 23-26  residue number
    # 31-38  X
    # 39-46  Y
    # 47-54  Z
    # 55-60  occupancy
    # 61-66  B-factor
    # 73-76  segname = HETB
    #
    # --------------------------------------------------------

    foreach p $positions {

        lassign $p x y z


        puts $fout [format \
"ATOM  %5d  POT POT %1s%4d    %8.3f%8.3f%8.3f%6.2f%6.2f      %-4s" \
        $atomid \
        $chainID \
        $resid \
        $x \
        $y \
        $z \
        1.00 \
        0.00 \
        $segname]


        incr atomid
        incr resid
    }


    # --------------------------------------------------------
    # Last residue ID
    # --------------------------------------------------------
    set last_resid [expr {$resid - 1}]


    # --------------------------------------------------------
    # Write TER
    #
    # Example:
    #
    # TER     564      POT B  26
    #
    # --------------------------------------------------------

    puts $fout [format \
"TER   %5d      POT %1s%4d" \
    $atomid \
    $chainID \
    $last_resid]


    # --------------------------------------------------------
    # END
    # --------------------------------------------------------

    puts $fout "END"

    close $fout


    # --------------------------------------------------------
    # Cleanup
    # --------------------------------------------------------

    file delete -force $temp_pdb

    $o6 delete
    $all delete

    mol delete top


    puts ""
    puts "Finished: $output_pdb"
}


puts ""
puts "===================================================="
puts "ALL STRUCTURES FINISHED"
puts "===================================================="

