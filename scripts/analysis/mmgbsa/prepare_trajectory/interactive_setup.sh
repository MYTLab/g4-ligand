#!/bin/bash
# interactive_setup.sh
# 1. 搜尋檔案 -> 2. 選擇檔案 -> 3. 設定輸出目錄 -> 4. 呼叫 Slurm

echo "====== STRIPSPLIT 互動設定介面 ======"

# --- Part A: 搜尋並選擇檔案 ---
echo "請直接貼上你要搜尋的最上層資料夾（可多個，空格分隔）:"
read dir_input
read -a ROOTS <<< "$dir_input"

all_psf=()
all_pdb=()
all_dcd=()
all_coor=()

echo "正在搜尋檔案，請稍候..."
for root in "${ROOTS[@]}"; do
    if [ ! -d "$root" ]; then echo "警告: $root 不是資料夾，跳過。"; continue; fi
    while IFS= read -r fname; do all_psf+=("$fname"); done < <(find "$root" -type f -iname "*.psf")
    while IFS= read -r fname; do all_pdb+=("$fname"); done < <(find "$root" -type f -iname "*.pdb")
    while IFS= read -r fname; do all_dcd+=("$fname"); done < <(find "$root" -type f -iname "*.dcd")
    while IFS= read -r fname; do all_coor+=("$fname"); done < <(find "$root" -type f -iname "*.coor")
done

if [ ${#all_psf[@]} -eq 0 ] || [ ${#all_dcd[@]} -eq 0 ]; then
    echo "[Error] 找不到 PSF 或 DCD 檔案，請確認路徑。"
    exit 1
fi

echo "=== 請選擇 PSF 檔案 ==="
select PSF in "${all_psf[@]}"; do break; done
echo "=== 請選擇 PDB 檔案 ==="
select PDB in "${all_pdb[@]}"; do break; done
echo "=== 請選擇 DCD 格式 (Template) ==="
select DCDPAT in "${all_dcd[@]}"; do break; done
echo "=== 請選擇 COOR 檔案 ==="
select COOR in "${all_coor[@]}"; do break; done

# --- Part B: 自動建立輸出資料夾 (重點功能) ---
echo "------------------------------------------------"
read -p "請輸入「輸出資料夾」名稱 (例如: output_run1): " OUT_DIR_NAME

# 如果使用者沒輸入，給個預設值
if [ -z "$OUT_DIR_NAME" ]; then
    OUT_DIR_NAME="stripsplit_output_$(date +%Y%m%d_%H%M)"
fi

# 建立絕對路徑 (Slurm 在節點運作時需要絕對路徑)
CURRENT_DIR=$(pwd)
FULL_OUT_DIR="${CURRENT_DIR}/${OUT_DIR_NAME}"

if [ ! -d "$FULL_OUT_DIR" ]; then
    echo "正在建立資料夾: $FULL_OUT_DIR"
    mkdir -p "$FULL_OUT_DIR"
else
    echo "資料夾已存在: $FULL_OUT_DIR (將使用此資料夾)"
fi

# --- Part C: 參數設定 ---
read -p "請輸入 Replica 數量 (預設 1): " NREP
NREP=${NREP:-1}

# --- Part D: 提交作業 ---
echo "準備提交 Slurm 作業..."

# 使用 sbatch 提交，並透過 export 傳遞變數給 Slurm 腳本
# 注意：這裡呼叫 submit.slurm
JOB_ID=$(sbatch --parsable \
    --export=ALL,MY_PSF="$PSF",MY_PDB="$PDB",MY_DCD="$DCDPAT",MY_COOR="$COOR",MY_OUTDIR="$FULL_OUT_DIR",MY_NREP="$NREP" \
    submit.slurm)

echo "作業已提交！ Job ID: $JOB_ID"
echo "輸出檔案將位於: $FULL_OUT_DIR"
echo "Log 檔案將位於: $FULL_OUT_DIR/slurm-${JOB_ID}.out"
