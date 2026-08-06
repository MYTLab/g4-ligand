# MM/GBSA Workflow

本資料夾包含以 VMD、NAMD/GBIS 與 Python 完成 MM/GBSA 分析所需的前處理、能量計算及結果分析程式。

## 1. 整體流程

~~~text
原始 PSF／PDB／COOR／DCD
        │
        ▼
VMD 軌跡前處理
        │
        ├── complex.psf / complex.pdb / complex DCD
        ├── target.psf  / target.pdb  / target DCD
        └── ligand.psf  / ligand.pdb  / ligand DCD
        │
        ▼
NAMD GBIS 單點能量計算
        │
        ├── complex energy
        ├── target energy
        └── ligand energy
        │
        ▼
ΔG = Ecomplex − Etarget − Eligand
        │
        ▼
Python Notebook 分析與繪圖
~~~

## 2. 檔案說明

| 檔案 | 用途 |
|---|---|
| interactive_setup.sh | 互動選擇 PSF、PDB、DCD、COOR，並提交軌跡前處理 |
| submit.slurm | VMD 軌跡前處理的 Slurm 提交腳本 |
| worker_wrapper.sh | 接收 Slurm 參數並呼叫 VMD／Tcl |
| stripsplit.tcl | 對齊軌跡，拆出 complex、target、ligand |
| submit_namd_mmgbsa.slurm | NAMD GBIS 能量計算的 Slurm 提交腳本 |
| worker_mmgbsa.sh | 執行三套能量計算並計算 ΔG |
| gbis_template.namd | NAMD GBIS 設定模板 |
| mmgbsa_handover.ipynb | 讀取結果、統計 analysis region 並繪圖 |

建議將這些檔案放在同一個資料夾：

~~~text
scripts/analysis/mmgbsa/
├── README.md
├── interactive_setup.sh
├── submit.slurm
├── worker_wrapper.sh
├── stripsplit.tcl
├── submit_namd_mmgbsa.slurm
├── worker_mmgbsa.sh
├── gbis_template.namd
└── mmgbsa_handover.ipynb
~~~

目前腳本使用相對路徑互相呼叫，因此執行前請先進入此資料夾：

~~~bash
cd scripts/analysis/mmgbsa
~~~

## 3. 執行環境

需要：

- Slurm：sbatch、squeue、sacct
- VMD 1.9.4 或相容版本
- VMD packages：pbctools、psfgen
- Singularity/Apptainer
- NAMD 2.14 CPU image 或可直接執行的 NAMD
- CHARMM36/CGenFF parameter files
- Python 3、NumPy、Matplotlib

第一次使用可檢查：

~~~bash
which sbatch
which vmd
which singularity
~~~

設定執行權限：

~~~bash
chmod +x interactive_setup.sh
chmod +x worker_wrapper.sh
chmod +x worker_mmgbsa.sh
~~~

## 4. 階段一：準備 complex、target、ligand 軌跡

### 4.1 準備輸入

需要同一套模擬系統的：

- PSF topology
- PDB structure
- COOR reference coordinates
- DCD trajectory

PSF、PDB、COOR 與 DCD 的原子數及原子順序必須一致。

stripsplit.tcl 預設使用：

~~~text
Target segment：DNAA
Ligand segment：HETA
~~~

若系統使用其他 segid，修改 stripsplit.tcl：

~~~tcl
set targ_seg DNAA
set lig_seg HETA
~~~

### 4.2 檢查 VMD 路徑

在 worker_wrapper.sh 中確認：

~~~bash
VMD_EXEC="/ceph/sharedfs/work/MYTLab/vmd-1.9.4a55/bin/vmd"
~~~

若路徑不同，先執行：

~~~bash
which vmd
~~~

再將結果填入 VMD_EXEC。

### 4.3 提交前處理

~~~bash
bash interactive_setup.sh
~~~

依提示完成：

1. 輸入搜尋資料夾。
2. 選擇 PSF。
3. 選擇 PDB。
4. 選擇 DCD。
5. 選擇 COOR。
6. 輸入輸出資料夾名稱。
7. 輸入 replica 數量。

腳本會透過 submit.slurm 提交作業。

### 4.4 目前版本的重要限制

目前 interactive_setup.sh 一次只選一條 DCD，但 worker_wrapper.sh 可以循環多個 replicas。多 replica 邏輯尚未完整連接，輸入 NREP 大於 1 可能把同一條 DCD 重複處理。

在腳本修正前，建議：

~~~text
每次只選擇一條 DCD
Replica 數量輸入 1
每個 replica 分開執行
~~~

例如分別建立：

~~~text
mmgbsa606_rep1/
mmgbsa606_rep2/
mmgbsa606_rep3/
~~~

### 4.5 監看作業

~~~bash
squeue -u "$USER"
sacct -j JOB_ID --format=JobID,State,Elapsed,MaxRSS,ExitCode
~~~

### 4.6 預期輸出

~~~text
complex.psf
complex.pdb
complex-rep1-formmgbsa.dcd

target.psf
target.pdb
target-rep1-formmgbsa.dcd

ligand.psf
ligand.pdb
ligand-rep1-formmgbsa.dcd

stripsplit-rep1.log
slurm-JOBID.out
~~~

確認：

~~~bash
ls -lh OUTPUT_DIRECTORY
du -h OUTPUT_DIRECTORY/*.dcd
~~~

## 5. 階段二：NAMD GBIS 能量計算

### 5.1 修改 Slurm 設定

開啟 submit_namd_mmgbsa.slurm，確認：

~~~bash
SIF_IMAGE="/path/to/namd2.14cpu.sif"
CPU_CORES=4
WORK_DIR="/path/to/mmgbsa_system_rep1"
TOPPAR_DIR="/path/to/toppar"
TEMPLATE_PATH="$(pwd)/gbis_template.namd"
REPLICA=1
~~~

CPU_CORES 應與下列設定一致：

~~~bash
#SBATCH --cpus-per-task=4
~~~

WORK_DIR 與 REPLICA 必須符合實際檔名：

~~~text
WORK_DIR 中存在 complex-rep3-formmgbsa.dcd
→ REPLICA 必須設為 3
~~~

目前原始設定中的 WORK_DIR 指向 rep3，但 REPLICA 為 1，提交前必須修正。

### 5.2 修改 ligand parameter

開啟 gbis_template.namd，確認：

~~~tcl
parameters /path/to/ligand.prm
~~~

目前檔案固定使用 score606 的 tog.prm。若分析其他 ligand 或參數位置，必須更換。

同時確認研究設定：

~~~tcl
solventDielectric 74.69
ionConcentration 0.3
temperature 310
~~~

### 5.3 提交 NAMD

~~~bash
sbatch submit_namd_mmgbsa.slurm
~~~

監看：

~~~bash
squeue -u "$USER"
~~~

### 5.4 預期輸出

~~~text
m-complex-rep1.namd
m-complex-rep1.log
m-complex-rep1.e

m-target-rep1.namd
m-target-rep1.log
m-target-rep1.e

m-ligand-rep1.namd
m-ligand-rep1.log
m-ligand-rep1.e

final_results_rep1.dat
~~~

確認 NAMD 正常完成：

~~~bash
grep -n "End of program" m-*-rep1.log
~~~

確認三套系統都有相同數量的能量：

~~~bash
wc -l m-complex-rep1.e
wc -l m-target-rep1.e
wc -l m-ligand-rep1.e
~~~

三個 .e 檔的行數必須相同。

確認最終結果：

~~~bash
head final_results_rep1.dat
tail final_results_rep1.dat
wc -l final_results_rep1.dat
~~~

## 6. ΔG 輸出定義

MM/GBSA 能量差：

~~~text
ΔG = Ecomplex − Etarget − Eligand
~~~

目前 worker_mmgbsa.sh 產生的 final_results_rep1.dat 為：

~~~text
Column 1：timestep
Column 2：running-average ΔG
~~~

第二欄不是逐 frame ΔG。它適合觀察收斂趨勢，但不適合直接當成獨立逐 frame 數值計算一般 mean／SD。

建議後續修改成：

~~~text
Column 1：timestep
Column 2：instantaneous ΔG
Column 3：running-average ΔG
~~~

修改前，分析 Notebook 應將第二欄解讀為 running average。

## 7. 階段三：Python 分析

開啟 mmgbsa_handover.ipynb，修改：

~~~python
DATA_FILE = Path("/path/to/final_results_rep1.dat")
SYSTEM_NAME = "K_606_rep1"
ION_LABEL = "K+"
DOCKING_SCORE = "6.06"

FRAME_COLUMN_INDEX = 0
ENERGY_COLUMN_INDEX = 1
TIME_PER_FRAME_NS = 0.002
ANALYSIS_START_NS = 50.0
~~~

注意：

- 目前 ENERGY_COLUMN_INDEX = 1 讀到 running-average ΔG。
- 若 worker 改成三欄格式，index 1 可讀 instantaneous ΔG，index 2 可讀 running-average ΔG。
- 若第一欄是 NAMD timestep 而不是 DCD frame index，必須重新確認 TIME_PER_FRAME_NS。

Notebook 輸出：

~~~text
mmgbsa_energy_data.npz
mmgbsa_energy_data.csv
run_summary.txt
figure_mmgbsa_free_energy.png
figure_mmgbsa_free_energy.pdf
~~~

## 8. 完整執行順序

~~~bash
# 1. 進入腳本資料夾
cd scripts/analysis/mmgbsa

# 2. 每次處理一條 DCD
bash interactive_setup.sh

# 3. 監看 VMD 前處理
squeue -u "$USER"

# 4. 檢查 complex／target／ligand 輸出
ls -lh /path/to/mmgbsa_system_rep1

# 5. 修改 submit_namd_mmgbsa.slurm 與 gbis_template.namd

# 6. 提交 NAMD GBIS
sbatch submit_namd_mmgbsa.slurm

# 7. 監看 NAMD
squeue -u "$USER"

# 8. 檢查能量與 final results
wc -l /path/to/mmgbsa_system_rep1/m-*.e
head /path/to/mmgbsa_system_rep1/final_results_rep1.dat

# 9. 開啟 mmgbsa_handover.ipynb
# 10. 設定 DATA_FILE 後由上往下執行
~~~

## 9. 常見錯誤

### 找不到 VMD

確認 worker_wrapper.sh 中的 VMD_EXEC，並執行：

~~~bash
which vmd
~~~

### VMD affinity error

確認 submit.slurm 包含：

~~~bash
export VMDFORCECPUCOUNT=1
~~~

### 找不到 complex／target／ligand DCD

確認：

- 階段一已成功完成。
- WORK_DIR 指向正確資料夾。
- REPLICA 與檔名一致。

### NAMD log 沒有 ENERGY

~~~bash
grep "^ENERGY:" m-complex-rep1.log | head
~~~

確認 NAMD 沒有因 parameter、PSF 或 DCD 錯誤提前停止。

### 三個 energy 檔行數不同

complex、target、ligand 必須讀取相同 frame 數。若行數不同，不應直接使用 paste 計算 ΔG。

### Notebook 的 mean／SD 為 NaN

代表時間軸尚未到 ANALYSIS_START_NS，或 TIME_PER_FRAME_NS 設定不正確。

## 10. Git 管理

建議提交：

- Bash、Slurm、Tcl、NAMD template
- Notebook
- README
- 小型設定範例

不要提交大型軌跡與結果。

建議 .gitignore：

~~~gitignore
results/
output/
*.dcd
*.coor
*.vel
*.xsc
*.log
*.e
*.npz
slurm-*.out
gb_bnm_rep*
~~~

## 11. 最終檢查清單

- [ ] PSF、PDB、COOR、DCD 屬於同一套系統
- [ ] Target 與 ligand segid 正確
- [ ] 每次前處理只使用一條明確 DCD
- [ ] complex、target、ligand DCD frame 數一致
- [ ] CPU_CORES 與 Slurm CPU 數一致
- [ ] WORK_DIR 與 REPLICA 一致
- [ ] Ligand parameter file 正確
- [ ] 三個 NAMD log 正常結束
- [ ] 三個 energy 檔行數一致
- [ ] 已確認 final results 第二欄的物理意義
- [ ] Notebook 的時間換算與欄位索引正確

