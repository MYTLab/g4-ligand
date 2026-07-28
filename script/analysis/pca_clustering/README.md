# PCA and K-Means Clustering

This directory contains scripts for principal component analysis (PCA) and K-means clustering of molecular dynamics trajectories.

## Workflow

1. Align the trajectory using DNA heavy atoms.
2. Select the atoms used for structural comparison.
3. Calculate the coordinate covariance matrix.
4. Project trajectory frames onto the principal components.
5. Perform K-means clustering in the selected PCA space.
6. Identify representative structures for each cluster.
7. Calculate the population of each cluster.

## Analysis Goals

PCA and clustering are used to compare:

- Conformational space sampled in K⁺ and Na⁺ environments
- Relative populations of major conformational states
- Representative TO–G4 binding structures
- Differences in TO position and DNA contacts
