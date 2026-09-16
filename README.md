# K⁺–Hybrid G4 + TO 模擬交接：DICOS／551 範例

整理日期：2026-09-16。範圍只包含建模與 MD，不包含分析。

## 1. 先看這一頁

本交接以 551 為完整操作範例。G4 的結構來源為 2JSM；G4–TO 初始 pose 已用
AutoDock 4.2 準備，全部初始 PDB 由提供者另外放入 `pdb/`。
接手者不需要重新 docking，也不必對已補好中央 K⁺ 的 PDB 再補離子。

有兩種起點：

| 目的 | 從哪裡開始 |
|---|---|
| 重建一個系統的溶劑與離子環境 | `pdb/` 中未溶劑化、已選 pose 的 PDB → CHARMM-GUI |
| 操作現有 551 範例 | 已提供的 `551/step3_input.psf/pdb` → 核對設定 → DICOS |

**狀態：交接草稿已完成本機靜態檢查，尚未在 DICOS 實際運行驗證。**
提供者仍需補 `toppar/`、全部初始 pose PDB、PBC 核對記錄及成功 log。

水盒截圖是 82 Å，NVT 設定的週期盒是 102 Å。本包不擅自改動此設定，
但提交腳本會在 PBC 核對尚未完成時停止，不能直接將本包標為「已驗證可跑」。

## 2. 檔案位置

- `551/`：一個模擬工作資料夾，含三份操作版設定、提交腳本、PSF、PDB、位置限制檔。
- `toppar/`：提供者自行放入原本使用的 force-field 檔案與 `tog.prm`。
- `pdb/`：提供者自行放入所有已準備的初始 pose；不是溶劑化後的 PDB。
- `scripts/preflight.sh`：只檢查輸入，不執行 MD。
- `reference/original/`：原始設定及 `add2.tcl`，保留供比對，不作為正式提交入口。
- `reference/screenshots/`：三張 CHARMM-GUI 選项截圖。
- `VALIDATION.md`：本地檢查與尚未驗證的項目。

操作版三份 `.conf` 的輸入位置依自身目錄決定，共用上一層 `toppar/`，
不再使用提供者的 `/dicos_ui_home/...` 路徑。restart 與 log 輸出寫在工作資料夾。

## 3. 範例系統與設定

| 項目 | 551 範例／來源 |
|---|---|
| G4 | K⁺ hybrid G4，結構來源 2JSM；來源 model 尚待提供者記錄 |
| TO pose | AutoDock 4.2 準備；採用提供者提供的 PDB |
| DNA segment | `DNAA`，GUI chain A，residue 1–23 |
| TO segment | `HETA`，GUI chain T，resname `TOG` |
| 中央離子 | 提供者確認 3 顆 K⁺ 已補放並保留；仍需目視驗證位置 |
| 溶劑化盒子 | GUI 截圖為 rectangular，82 × 82 × 82 Å |
| 初始 NVT PBC | 原設定 102 × 102 × 102 Å，origin=(0,0,0)；待核對 |
| 鹽 | GUI KCl 0.15 M，勾選中和、Monte-Carlo 放置 |
| GUI force field 選項 | CHARMM36m；DNA 實際引用 `par_all36_na.prm`，TO 引用 CGenFF／`tog.prm` |
| 水模型 | PDB 有 TIP 水；完整模型定義仍需隨實際 toppar 核對，不能只憑 residue 名稱證明 |
| 溫度 | 303.15 K |
| NAMD | 提交腳本沿用提供者的 `namd3.0.1.sif`；實際版本需由 log 確認 |
| 計算資源 | 原提交選项：v100-al9、1 GPU、1 CPU；可用性由當下 DICOS 環境確認 |

GUI 的 70 顆 K⁺／48 顆 Cl⁻ 顯示為溶劑離子估算；目前範例 PDB 也有 70 顆 POT／48 顆 CLA。
這些數字不能單獨辨認哪三顆位於通道，交接不以離子總數作為通道離子位置的證明。

## 4. 使用已提供的 PDB 建立系統

### 4.1 選擇初始結構

1. 從 `pdb/` 取用對應系統的未溶劑化 G4–TO PDB，例如 `551_K.pdb`。
2. 在 VMD 檢查 G4、TO 及中央 3 顆 K⁺；確認不是溶劑化後的 `step3_input.pdb`。
3. 已含中央離子的 PDB 不要再次執行 `add2.tcl`。

`add2.tcl` 僅放在來源附錄：它處理 551、579、586、589、601、618、631，
以 guanine O6 的中心及主軸推定通道，於中心與前後 3.4 Å 放置 3 顆 POT。
此幾何判定是啟發式，不能保證每一構形的方向正確；若未來真的重新補放，
必須檢查通道方向、原有離子與近距離碰撞。

### 4.2 CHARMM-GUI

以下為提供者的建模選项，不是自動化瀏覽器流程：

1. 上傳未溶劑化 PDB。
2. PDB Reader 保留 DNA、TO 與已放好的中央 K⁺；截圖中的 DNAA/HETA 清單
   不足以證明中央離子保留，須檢查該次輸出。
3. 保存自動產生的 TO topology、parameter 及 penalty 資訊。
4. Waterbox：Specify Waterbox Size → Rectangular → X/Y/Z 各 82 Å。
5. Include Ions → Monte-Carlo → KCl → concentration 0.15 M → neutralizing。
6. Force Field Options：CHARMM36m；未勾 WYF、HMR、multi-site Ca²⁺。
7. 選 NAMD，equilibration NVT、dynamics NPT，temperature 303.15 K。
8. 下載整套結果，保留原始建模輸出，以便核對 PBC 與參數。

GUI 是互動步骤，網站介面可能變動。以本包圖片紀錄設定意圖，不聲稱目前介面已線上驗證。

### 4.3 把建模結果放到模擬資料夾

每一套系統必須把同次建立的下列檔案配對使用：

```text
step3_input.psf
step3_input.pdb
prot_posres.ref
```

`prot_posres.ref` 是提供者使用的限制檔：NAMD 從 B-factor 欄讀取限制係數。
不要用另一系統的限制檔替代；如果重新建模導致原子順序變更，必須重新建立或核對限制檔。

本包不提供限制檔重建方法，因此新建系統不能只靠同名檔案就假設完成。
551 的三個配套檔已附入，其他系統需另行準備。

## 5. 執行前必做

### 5.1 放入 toppar

把原本成功使用的完整參數內容放入本包的 `toppar/`，包含 `tog.prm`。
例如 `toppar/par_all36_na.prm`；不要形成 `toppar/toppar/`。
來源版本、TO 手動修訂與 penalty 記錄也要保留，不任意換成新的參數版本。

### 5.2 核對 PBC

82 Å 水盒與 102 Å 週期盒必須對照建模結果與後續處理記錄。
如果有擴盒、重新溶劑化或其他步骤，記錄其來源；不能只因名稱不同就當成互不相關。
如果改動 `.conf` 的盒子，保留修改原因與前後數值，不能直接把 102 改成 82 便宣布已驗證。

完成對照後，編輯 `551/PBC_REVIEW.txt`：

```text
STATUS=CONFIRMED
EVIDENCE=填入實際核對依據、資料檔或成功 log，以及採用的盒子與 origin
```

只在真正核對完成後改 STATUS；未確認前維持 PENDING。

### 5.3 路徑檢查

在 DICOS 登入節點、交接包根目錄執行：

```bash
bash scripts/preflight.sh 551
```

它檢查主要輸入、參數檔是否非空，以及 PSF/PDB/限制檔的原子數。
通過只表示檔案檢查通過，不代表原子順序、TO 參數品質、中央離子位置或盒子已正確。
登入節點只做檢查與提交，不在登入節點直接跑正式 MD。

## 6. DICOS 提交正式模擬

先開啟 `551/G4_md.sh`，確認提供者的映像檔位置仍可用：

```bash
SIF_PATH="/ceph/sharedfs/work/MYTLab/namd3.0.1.sif"
```

Slurm partition、GPU 類型、時間／account 等要求依當下 DICOS 規範確認。
本包沿用使用者的分區與資源，不聲稱已核對當下可用節點。

必須在工作資料夾提交，讓相對 restart 路徑與輸出位置一致：

```bash
cd 551
sbatch G4_md.sh
```

不需要先 chmod；Slurm 可讀腳本。若檔案在 Windows 被改成 CRLF，先在副本用
`dos2unix G4_md.sh ../scripts/preflight.sh` 正規化換行（需工具已安裝）。

提交腳本按順序執行：

| 階段 | 起點 | 執行量 | 限制／系综 | 成功後產生 |
|---|---|---|---|---|
| 最小化 | `step3_input.pdb` | 10,000 steps | NVT 設定内執行，位置限制開啟 | 接著開始 NVT |
| NVT | 最小化後 | 50,000 × 2 fs = 100 ps | 固定盒子；位置限制開啟 | `G4_TO_nvt.restart.*` |
| NPT | NVT restart coor/vel/xsc | 1,000,000 × 2 fs = 2 ns | 壓力控制開啟；位置限制開啟 | `G4_TO_npt.restart.*` |
| Production | NPT restart coor/vel/xsc | 50,000,000 × 2 fs = 100 ns | NPT；位置限制關閉 | `G4_TO_551.dcd` 與 restart |

保留原設定：303.15 K、rigidBonds all、PME、cutoff 12 Å、switch 10 Å、pairlist 14 Å、
NVT 每 1,000 steps 重新指派速度、GPUresident on。
NPT 壓力 target 1.01325 bar。每 1,000 steps 輸出一次，即每 2 ps，不是原註解的 1 ps。
每階段的 `firsttimestep` 沿用 0；這三段不是以連續 timestep 编號保存。

腳本使用原提供者的 `singularity run ... namd3` 呼叫形式，並 bind 整份交接包。
映像檔的 runscript 是否接受此形式，仍需 DICOS 實跑驗證。

## 7. 如何判斷是否完成

提交後记录 job ID，查詢排程：

```bash
squeue -u "$USER"
sacct -j JOB_ID --format=JobID,State,ExitCode,Elapsed,MaxRSS
```

把 JOB_ID 換成實際數字。PENDING 代表尚未執行，可能因 Priority／Resources 等原因；
不要因為等待就重複提交多份工作。

在 `551/` 看目前階段的 log：

```bash
tail -n 40 nvt.log
tail -n 40 npt.log
tail -n 40 md.log
```

尚未開始的階段可能沒有 log，屬正常。
腳本只會在前一個命令成功、log 含 `End of program`、restart coor/vel/xsc 均存在後繼續。
若你使用的映像正常结束標記不同，先核對实际成功 log，再調整檢查，不要直接移除。

正式完成須同時確認 Slurm 為 COMPLETED／ExitCode 0、三階段正常结束、正式 MD 到達預定步數，
且 `.dcd` 與 restart 存在。檔案存在本身不是完成證明。

## 8. 重跑、接續與其他系統

`G4_md.sh` 是 **全新起跑** 的腳本，不是自動續跑腳本。
若已有 log 或主要 restart，它會停止以避免覆蓋。不要删除結果來繞過檢查。
重跑請用新的工作資料夾；中斷續跑需要另行設定實際 restart、timestep 與剩餘步數，
本包尚未附已驗證的續跑入口。

其他系統可以參照 551 的資料夾结构，但要換成自己的 PSF/PDB/限制檔，
核對 PBC、TO 參數與輸出名稱；不能只替換 551 初始 pose 就沿用 551 的溶劑化 PSF。
多 replica 的隨機種子與獨立初始化方式尚待提供者補充，本包只交接一個範例。

## 9. 常見錯誤

| 情況 | 先處理什麼 |
|---|---|
| 找不到 toppar／tog.prm | 檢查參數是否放在根目錄 `toppar/`，檔名是否一致 |
| UNABLE TO FIND ANGLE PARAMETERS 等 | 參數内容不完整；交由提供者核對 TO 參數，不隨意補值 |
| 找不到 NVT／NPT restart | 前一階段未完成，或沒有從工作資料夾提交 |
| 容器看不到輸入 | 確認 package bind 路徑與映像檔入口 |
| Existing result | 使用新工作資料夾，或制定續跑方案；不要覆蓋原結果 |
| PBC review pending | 核對建模週期盒與座標，完成記錄後才提交 |
| 最後只有 All finished 字樣 | 本包已改为错误时停止；仍須看 Slurm、log 與预定步数 |

## 10. 提供者完成交接前清單

- [ ] 放入全部未溶劑化初始 PDB，標明 model 與中央離子狀態。
- [ ] 放入完整 toppar、tog.prm 與 TO 參數來源／修訂資訊。
- [ ] 補上水模型与 PBC（82／102 Å）的核對依據。
- [ ] 說明 `prot_posres.ref` 的建立方法，供未来新建系統使用。
- [ ] 在 DICOS 用操作版跑完一個範例，保存 job ID、實際版本、成功 log。
- [ ] 確认从登入節點提交到计算节点的路徑均可用。
- [ ] 若擴充多 replica／中斷續跑，再補獨立種子与续跑说明。

完成以上項目並更新 VALIDATION.md 後，才把交接包標為「已驗證可運行」。
