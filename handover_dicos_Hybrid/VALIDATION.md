# 驗證狀態

檢查日期：2026-09-16。

| 檢查 | 結果 |
|---|---|
| `bash -n`：操作版提交與 preflight 腳本 | 通過 |
| `reference/original/` 與上傳原始腳本逐位元比對 | 相同，原件未更動 |
| PSF / PDB / prot_posres.ref 原子數 | 均為 51,767 |
| 缺少 toppar 時的 preflight | 如預期回報缺檔並非零退出；不啟動模擬 |
| PBC 尚未核對時的提交前檢查 | 如預期阻擋提交內的模擬啟動 |
| 操作版 `.conf` 與原件差異 | 只改 BASEDIR、TOPPAR 路徑，以及 2 ps 的輸出註解 |
| Tcl / NAMD 設定語法實際執行 | 未驗證；本機沒有 tclsh、NAMD 或指定映像 |
| DICOS / Slurm / GPU / container bind | 未驗證，未提交任何外部工作 |
| 參數內容、原子順序、中央離子幾何、水模型與 PBC | 尚需提供者核對；路徑／原子數檢查不能替代 |

因此目前是「交接說明與操作入口草稿」，不是「已在 DICOS 完成重現的套件」。
提供者補齊檔案並使用操作版成功跑完後，請在此填入：

```text
驗證人：
日期：
系統／資料來源：
PBC 與水模型核對依據：
實際 NAMD 版本：
映像檔／版本或 hash：
Slurm 分區與 job ID：
各階段正常完成 log 路徑：
最終 timestep：
新接手者能否依 README 從頭操作：
```
