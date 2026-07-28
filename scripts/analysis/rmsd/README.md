# RMSD Analysis

This directory contains scripts for calculating the RMSD of G-quadruplex DNA during molecular dynamics simulations.

## Method

- Trajectories are aligned using DNA heavy atoms.
- The first trajectory frame is used as the reference structure.
- NAMD timestep: 2 fs.
- DCD output frequency: 1000 steps.
- Each trajectory frame corresponds to 0.002 ns.

## Scripts

- `calculate_rmsd.py`: Calculates RMSD and saves the results as an NPZ file.

## Output
