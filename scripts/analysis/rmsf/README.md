# RMSF Analysis

This directory contains scripts for calculating residue-level root-mean-square fluctuation (RMSF) of G-quadruplex DNA across independent molecular dynamics replicas.

## Method

- RMSF is calculated using the C1′ atom of each nucleotide.
- One C1′ atom is used to represent each DNA residue.
- Trajectories are aligned before RMSF calculation to remove overall translation and rotation.
- Alignment is performed using the following nucleic-acid backbone atoms:
  - P
  - C1′
  - C4′
- The first frame of replica 1 is used as the common alignment reference for all replicas of the same system.
- RMSF is calculated separately for each replica.
- Results are converted from nanometers to angstroms.
- Mean RMSF and sample standard deviation are calculated across independent replicas during plotting.

## Residue Ordering

For visualization, residues can be reordered according to nucleotide type:

1. Guanine residues
2. Adenine residues
3. Thymine residues
4. Other residues, if present

This ordering is used to distinguish the G-tetrad core from loop and flanking residues.
