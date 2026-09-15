# MM/GBSA Windows Terminal 使用說明

這個版本可在 Windows Terminal 的 PowerShell 中執行，不需要 Slurm、Bash、
Singularity 或 Linux 指令。科學計算仍由 VMD 與 NAMD 完成，因此必須先安裝
Windows 版 VMD 和 NAMD；Windows Terminal 本身不能取代它們。

## 1. 需要準備的軟體與資料

- Windows 10/11 與 PowerShell 5.1 或 7
- VMD（需含 `pbctools` 與 `psfgen`）
- NAMD 2.14 或 3.x 的 Windows CPU 版
- CHARMM36/CGenFF `toppar` 資料夾
- TO 的參數檔，例如 `tog.prm`
- 同一套系統的 PSF、PDB、COOR 與每個 replica 的 DCD

預設 segment ID：G4 是 `DNAA`，TO 是 `HETA`。若你的 PSF 不同，請在設定時
填入實際值。

## 2. 第一次設定

解壓縮後，在 `mmgbsa` 資料夾空白處按住 Shift 並按右鍵，選擇
「在終端機中開啟」，再輸入：

```powershell
cd .\windows
Set-ExecutionPolicy -Scope Process Bypass
.\setup_windows.ps1
```

依提示貼上 VMD、NAMD、toppar、`tog.prm`、PSF、PDB、COOR 和 DCD 路徑。
每條 DCD 都要指定真正的 replica 編號。設定會存入：

```text
windows/config_windows.json
```

這個檔案包含本機路徑，通常不應提交至公開 GitHub。

## 3. 先檢查，不開始計算

```powershell
.\run_mmgbsa.ps1 -Stage Check
```

看到「設定檢查通過」後，再開始正式流程。

## 4. 執行方式

一次完成 VMD 前處理和 NAMD 能量計算：

```powershell
.\run_mmgbsa.ps1 -Stage All
```

也可以分開執行：

```powershell
.\run_mmgbsa.ps1 -Stage Prepare
.\run_mmgbsa.ps1 -Stage Energy
```

If all three NAMD logs already exist and only the final Delta G file is missing,
run postprocessing without repeating NAMD:

```powershell
.\run_mmgbsa.ps1 -Stage Postprocess
```

若設定檔不在預設位置：

```powershell
.\run_mmgbsa.ps1 -Stage All -ConfigPath "D:\project\my_config.json"
```

## 5. 主要輸出

每個 replica 會得到：

```text
complex-rep1-formmgbsa.dcd
target-rep1-formmgbsa.dcd
ligand-rep1-formmgbsa.dcd

m-complex-rep1.log
m-target-rep1.log
m-ligand-rep1.log

final_results_rep1.dat
```

`final_results_rep1.dat` 是三欄格式：

| 欄位 | 內容 |
|---|---|
| 1 | NAMD step / DCD frame counter |
| 2 | 該 frame 的 instantaneous ΔG |
| 3 | 截至該 frame 的 running-average ΔG |

其中：

```text
ΔG = Ecomplex − Etarget − Eligand
```

這比舊版只輸出 running average 更適合後續計算 mean 與 SD。Notebook 預設讀取
第二欄，也就是 instantaneous ΔG；若要畫 running average，將
`ENERGY_COLUMN_INDEX` 改成 `2`。

## 6. Notebook

回到 `mmgbsa` 資料夾啟動 JupyterLab：

```powershell
cd ..
jupyter lab
```

開啟 `mmgbsa_handover.ipynb`。Windows 腳本的預設結果路徑已設定為：

```python
Path("./mmgbsa_output/final_results_rep1.dat")
```

如果 setup 時選了其他輸出資料夾，只要修改 notebook 的 `DATA_FILE`。

## 7. 與舊版相比已修正的地方

- 移除 Slurm、Singularity 與伺服器絕對路徑。
- PowerShell 直接呼叫 Windows 版 VMD 與 NAMD。
- 每個 replica 明確對應一條 DCD，不再重複處理同一條 DCD。
- NAMD template 的 toppar 與 ligand parameter 改由設定檔帶入。
- 計算前檢查輸入路徑；三套 ENERGY 行數不同時停止，不會硬湊結果。
- 最終檔同時保留 instantaneous 與 running-average ΔG。
- `stripsplit.tcl` 不會在未指定 `--mkpsf` 時意外重建 PSF。

## 8. 常見問題

### PowerShell 阻擋腳本

只針對目前 Terminal 視窗暫時允許：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

關閉視窗後此設定會失效，不會永久更改系統政策。

### 找不到 VMD 或 NAMD

重新執行 `setup_windows.ps1`，填入實際 `.exe` 完整路徑。不要填捷徑 `.lnk`。

### VMD 顯示找不到 `pbctools` 或 `psfgen`

表示目前 VMD 安裝不完整或套件搜尋路徑有問題。先在 VMD Tk Console 測試：

```tcl
package require pbctools
package require psfgen
```

### NAMD log 沒有 ENERGY

先查看 `m-*-repN.log` 前段的錯誤。常見原因是 toppar 缺檔、`tog.prm` 路徑
錯誤、PSF 中的 atom type 沒有參數，或 NAMD 版本與輸入不相容。

### 記憶體不足

DCD 前處理可能一次載入整條軌跡。先提高 `stride`（例如 10）做小規模測試，
確認流程正確後再改回正式分析值。

## 9. 建議先做的小測試

先使用較短 DCD 或在 `config_windows.json` 將 `stride` 暫時設為 `10`，完成一個
replica 的 `Prepare` 和 `Energy`。確認三個 log 均有 ENERGY、輸出 frame 數一致，
再執行完整資料。
