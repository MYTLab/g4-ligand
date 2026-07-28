# Center-of-Mass Distance Analysis

This directory contains scripts for calculating the center-of-mass (COM) distance between Thiazole Orange (TO) and G-quadruplex DNA during molecular dynamics simulations.

## Method

- The G-quadruplex is selected using the nucleic-acid selection.
- Thiazole Orange is selected using the residue name `TOG`.
- Trajectories are aligned using DNA heavy atoms before distance calculation.
- The COM distance is calculated for every trajectory frame.
- Each trajectory frame corresponds to 0.002 ns.
