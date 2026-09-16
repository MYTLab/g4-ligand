#!/usr/bin/env bash
#SBATCH --job-name=hybrid551
#SBATCH --partition=v100-al9
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=1
#SBATCH --output=slurm-%j.out

set -euo pipefail
# Set this once for your DICOS environment; this is the original supplied image.
SIF_PATH="/ceph/sharedfs/work/MYTLab/namd3.0.1.sif"
# Submit from the system directory: cd 551; sbatch G4_md.sh
RUN_DIR=${SLURM_SUBMIT_DIR:-"$(pwd)"}
cd -- "$RUN_DIR"
if [[ ! -s "$SIF_PATH" ]]; then
    echo "ERROR: NAMD image not found: $SIF_PATH" >&2
    exit 1
fi
bash ../scripts/preflight.sh "$RUN_DIR" --require-reviewed-pbc
for name in nvt.log npt.log md.log G4_TO_nvt.restart.coor G4_TO_npt.restart.coor G4_TO_551.restart.coor; do
    if [[ -e "$name" ]]; then
        echo "ERROR: Existing result $name; use a fresh run directory, not this fresh-start script." >&2
        exit 1
    fi
done
module load singularity/4.1.2
command -v singularity >/dev/null
hostname
echo "Starting a new simulation in $RUN_DIR"
# Bind the complete package so configs, inputs and shared toppar remain visible.
PACKAGE_DIR=$(cd -- .. && pwd)
run_stage() {
    local conf=$1 log=$2 prefix=$3
    echo "Starting $conf"
    singularity run --nv --bind "$PACKAGE_DIR:$PACKAGE_DIR" \
        "$SIF_PATH" namd3 +p1 +devices 0 "$RUN_DIR/$conf" > "$log" 2>&1
    if ! rg -q 'End of program' "$log" 2>/dev/null; then
        if ! grep -q 'End of program' "$log"; then
            echo "ERROR: No normal completion marker in $log. Inspect it before continuing." >&2
            exit 1
        fi
    fi
    for suffix in coor vel xsc; do
        if [[ ! -s "$prefix.restart.$suffix" ]]; then
            echo "ERROR: Missing restart output: $prefix.restart.$suffix" >&2
            exit 1
        fi
    done
    echo "Completed $conf"
}
run_stage G4_TO_nvt.conf nvt.log G4_TO_nvt
run_stage G4_TO_npt.conf npt.log G4_TO_npt
run_stage G4_md.conf md.log G4_TO_551
echo "All simulation stages completed successfully."
