#!/bin/bash
# worker_wrapper.sh
# 接收參數並執行 VMD 的迴圈邏輯

PSF=$1
PDB=$2
DCDPAT=$3
COOR=$4
OUTDIR=$5
NREP=$6
SCRIPT="stripsplit.tcl"

# =================================================================
# 【VMD路徑設定區】
# 1. 嘗試載入模組 (適用於大多數 HPC)
module load vmd 2>/dev/null

# 2. 手動指定執行檔路徑
# 如果計算節點找不到 vmd，請在登入節點打 `which vmd` 查詢完整路徑
# 然後將下方的 "vmd" 改為完整路徑 (例如 "/usr/local/bin/vmd" 或 "/opt/vmd/bin/vmd")
VMD_EXEC="/ceph/sharedfs/work/MYTLab/vmd-1.9.4a55/bin/vmd"
# =================================================================

# 確保輸出資料夾存在 (雙重檢查，因為這是另一個節點)
mkdir -p "$OUTDIR"

# 進入迴圈執行 Replica
for rep in $(seq 1 $NREP); do
    echo "Processing Replica $rep..."
    
    # 判斷是否需要製作 PSF (僅第一次需要，或每個 Rep 都要視邏輯而定)
    # 這裡假設 complex.psf 如果已經存在該資料夾就不重做，節省時間
    MKPSF_FLAG=""
    if [ ! -f "$OUTDIR/complex.psf" ]; then
        MKPSF_FLAG="--mkpsf"
    fi

    # 執行 VMD
    # 使用 $VMD_EXEC 變數來執行
    $VMD_EXEC -dispdev text -e "$SCRIPT" \
        -args \
        --outdir "$OUTDIR" \
        $MKPSF_FLAG \
        --dcdfmt "$DCDPAT" \
        --rep "$rep" \
        --stride 1 \
        --nstages 1 \
        --psf "$PSF" \
        --pdb "$PDB" \
        --coor "$COOR" >> "$OUTDIR/stripsplit-rep${rep}.log"

    echo "Replica $rep done."
done

echo "Worker script finished."