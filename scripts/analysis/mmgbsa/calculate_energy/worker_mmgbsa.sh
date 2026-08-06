#!/bin/bash
# worker_mmgbsa.sh
# 修改版：計算 Running Average (累計平均) 以觀察收斂性

INPUT_DIR=$1
TOPPAR_DIR=$2
TEMPLATE_FILE=$3
REP=$4
# 如果 $5 是空的，預設為 1
N_CORES=${5:-1}
NAMD_CMD=$6

if [ -z "$NAMD_CMD" ]; then
    echo "Error: 未指定 NAMD 執行檔路徑。"
    exit 1
fi

cd "$INPUT_DIR" || exit
echo "進入工作目錄: $(pwd)"
echo "CPU 核心數設定為: $N_CORES"

# 定義要計算的三個系統
SYSTEMS=("complex" "target" "ligand")

echo "=== 開始 NAMD GBIS 計算 (Rep: $REP) ==="

# 1. 執行 NAMD 計算 (這部分不變)
for sys in "${SYSTEMS[@]}"; do
    CONF_FILE="m-${sys}-rep${REP}.namd"
    LOG_FILE="m-${sys}-rep${REP}.log"
    ENERGY_FILE="m-${sys}-rep${REP}.e"
    
    # 檢查是否已經算過，避免重複跑 (可選)
    # if [ -f "$ENERGY_FILE" ]; then
    #     echo "  -> $sys 能量檔已存在，跳過計算..."
    #     continue
    # fi

    echo "  -> Processing $sys..."

    # 替換 Template 變數
    sed -e "s|%SYS%|${sys}|g" \
        -e "s|%REP%|${REP}|g" \
        -e "s|%TOPPARDIR%|${TOPPAR_DIR}|g" \
        "$TEMPLATE_FILE" > "$CONF_FILE"

    echo "執行指令: $NAMD_CMD +p${N_CORES} $CONF_FILE"
    $NAMD_CMD +p${N_CORES} "$CONF_FILE" > "$LOG_FILE"

    # 提取能量
    # Ligand 檔提取: [TimeStep] [TotalEnergy]
    # 其他檔提取: [TotalEnergy]
    if [ "$sys" == "ligand" ]; then
          grep "^ENERGY:" "$LOG_FILE" | awk '{print $2,$14}' > "$ENERGY_FILE"
    else
          grep "^ENERGY:" "$LOG_FILE" | awk '{print $14}' > "$ENERGY_FILE"
    fi
done

# 2. 計算 Delta G (Running Average 版本)
FINAL_OUT="final_results_rep${REP}.dat"
echo "=== 計算 Running Average Delta G 並輸出至 $FINAL_OUT ==="

# paste 結構:
# Col 1: TimeStep (來自 ligand)
# Col 2: Ligand Energy
# Col 3: Target Energy
# Col 4: Complex Energy

paste m-ligand-rep${REP}.e m-target-rep${REP}.e m-complex-rep${REP}.e | \
awk 'BEGIN { 
    ra = 0.0; 
    count = 0; 
} 
{
    # 計算當前幀的 Delta G
    diff = ($4 - $3 - $2);
    
    # [過濾機制] 這裡保留了原本腳本的過濾條件，避免異常值破壞平均
    if (diff > -8000 && diff < 1000) { 
        ra += diff; 
        count++; 
        
        # 輸出: [時間步] [目前的累計平均能量]
        # 注意：這裡輸出的是 ra/count，這就是你要的收斂曲線數據
        print $1, ra/count;
    }
}' > "$FINAL_OUT"

# 顯示前幾行確認結果
echo "--- 輸出檔案前 5 行 (時間 vs 累計平均能量) ---"
head -n 5 "$FINAL_OUT"
echo "..."
tail -n 5 "$FINAL_OUT"
echo "Worker 完成。"
