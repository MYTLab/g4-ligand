#!/bin/bash
#SBATCH --job-name=stripsplit
#SBATCH --cpus-per-task=1
#SBATCH --partition=edr1-al9_short_serial
#SBATCH --output=slurm-%j.out
#SBATCH --mem=32G  # <--- [新增] 明確申請 32GB 記憶體，避免 OOM

# 載入 VMD module (請依貴單位環境修改)
module load singularity/4.1.2

# 確認變數是否傳入
if [ -z "$MY_PSF" ]; then
    echo "Error: 這是被動腳本，請執行 interactive_setup.sh 來提交作業。"
    exit 1
fi

echo "Running on host: $(hostname)"
echo "Target Output Directory: $MY_OUTDIR"

# --- [新增] 解決 VMD affinity 錯誤與多執行緒干擾 ---
# 強制 VMD 認為只有 1 顆 CPU 可用，避免它嘗試綁定不屬於你的核心
export VMDFORCECPUCOUNT=1
# ------------------------------------------------

# 執行實際的 Bash Worker，傳入所有變數
bash worker_wrapper.sh "$MY_PSF" "$MY_PDB" "$MY_DCD" "$MY_COOR" "$MY_OUTDIR" "$MY_NREP"

# 將 Slurm log 移動到目標資料夾，保持整潔
mv "slurm-${SLURM_JOB_ID}.out" "$MY_OUTDIR/" 2>/dev/null