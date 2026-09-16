#!/bin/bash

#SBATCH --job-name=hybrid551
#SBATCH --partition=v100-al9
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=1

module load singularity/4.1.2

SIF_PATH="/ceph/sharedfs/work/MYTLab/namd3.0.1.sif"
BASE_DIR="/ceph/sharedfs/work/MYTLab/asher/to_hybrid_0910_md/"

echo `hostname`
echo $SLURM_JOB_GPUS

echo "Step 1: Running NVT equilibration..."
singularity run --nv --bind /ceph:/ceph ${SIF_PATH} namd3 +p1 +devices 0 ${BASE_DIR}/G4_TO_nvt.conf > ${BASE_DIR}/nvt.log && \
echo "Step 1 (NVT) completed successfully." && \
echo "" && \

echo "Step 2: Running NPT equilibration..." && \
singularity run --nv --bind /ceph:/ceph ${SIF_PATH} namd3 +p1 +devices 0 ${BASE_DIR}/G4_TO_npt.conf > ${BASE_DIR}/npt.log && \
echo "Step 2 (NPT) completed successfully." && \
echo "" && \

echo "Step 3: Running Production MD..." && \
singularity run --nv --bind /ceph:/ceph ${SIF_PATH} namd3 +p1 +devices 0 ${BASE_DIR}/G4_md.conf > ${BASE_DIR}/md.log && \
echo "Step 3 (MD) completed successfully."


echo "All simulation steps finished."


