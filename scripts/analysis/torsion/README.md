# Thiazole Orange Torsion Analysis

This directory contains scripts for calculating the torsional dynamics of Thiazole Orange (TO) in molecular dynamics simulations.

## Torsion Definitions

Two dihedral angles are used to describe the relative orientation of the aromatic groups of TO:

- φ1: S–C4–C6–C2
- φ2: C2–C6–C4–N1

TO atoms are selected using the residue name `TOG`.

## Method

- φ1 and φ2 are calculated using MDAnalysis.
- Trajectory frames are sampled at a user-defined stride.
- The default stride is 10 frames.
- Each original DCD frame represents 0.002 ns.
- With a stride of 10, one analyzed frame represents 0.02 ns.
- Periodic-boundary information is included in the dihedral calculation when available.
- Torsion angles from individual replicas are stored separately.
- Angles are not averaged directly across replicas because torsional angles are periodic quantities.

## Probability-Density Analysis

For distribution analysis:

- Individual angles are folded into the range from −90° to 90°.
- The default number of histogram bins is 36.
- A probability-density distribution is calculated separately for each replica.
- Mean probability density and sample standard deviation are then calculated across independent replicas.

This workflow avoids errors caused by directly averaging periodic angles near the angular boundaries.

## Systems

The analysis can be applied to:

- Free TO in solution
- TO bound to G4 DNA in a K⁺ environment
- TO bound to G4 DNA in a Na⁺ environment
- Parallel or antiparallel G4 structures

The ion environment and system type are specified through the input manifest and plotting options.

