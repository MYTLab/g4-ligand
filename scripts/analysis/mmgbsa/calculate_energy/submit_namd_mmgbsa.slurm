#!/bin/bash
#SBATCH --job-name=mmgbsa
#SBATCH --cpus-per-task=4
#SBATCH --partition=edr1-al9_short_serial
#SBATCH --output=slurm-%j.out
#SBATCH --mem=32G  # <--- [新增] 明確申請 32GB 記憶體，避免 OOM

# 1. 載入 Singularity
module load singularity/4.1.2 2>/dev/null || module load singularity

# 2. 設定映像檔與指令
SIF_IMAGE="/ceph/sharedfs/work/MYTLab/sif/namd2.14cpu.sif"

# 檢查映像檔
if [ ! -f "$SIF_IMAGE" ]; then
    echo "Error: 找不到 Singularity 映像檔: $SIF_IMAGE"
    exit 1
fi

NAMD_EXEC="singularity exec $SIF_IMAGE namd2"

# 3. [修正] 明確指定核心數 (不要依賴環境變數)
CPU_CORES=1

# 組合完整的執行指令 (傳給 worker 用)
NAMD_EXEC="singularity exec $SIF_IMAGE namd2"

# 4. 設定路徑
WORK_DIR="/ceph/sharedfs/work/MYTLab/asher/center_ion_project/K/mmgbsa_control_12_23/mmgbsa721_rep3/"
TOPPAR_DIR="/dicos_ui_home/chrysaliso/home/toppar/"
TEMPLATE_PATH="$(pwd)/gbis_template.namd"
REPLICA=1


# ================= 執行區 =================

echo "Job running on $(hostname)"
echo "Using Command: $NAMD_EXEC"
echo "Cores: $CPU_CORES"

if [ ! -d "$TOPPAR_DIR" ]; then
    echo "Error: 找不到 Toppar 目錄: $TOPPAR_DIR"
    exit 1
fi

# 呼叫 Worker (傳入 CPU_CORES)
bash worker_mmgbsa.sh \
    "$WORK_DIR" \
    "$TOPPAR_DIR" \
    "$TEMPLATE_PATH" \
    "$REPLICA" \
    "$CPU_CORES" \
    "$NAMD_EXEC"

echo "Job Done."
