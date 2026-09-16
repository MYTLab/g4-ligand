# 自行補入的 force-field 檔案

請把原本成功使用的完整 toppar 內容直接放在此資料夾，包含 `tog.prm`。
正確位置是 `toppar/par_all36_na.prm`，不要多包一層 `toppar/toppar/`。

本交接包不附 force-field 檔案，也不會自動下載或替換版本。
執行 `bash scripts/preflight.sh 551` 會逐項檢查三份設定引用的參數檔。
有 TO 的 RTF/STR、CGenFF penalty 報告或手動修改記錄，也請保留作為來源紀錄。
缺少參數檔、缺少 angle/dihedral 參數或高 penalty，不能因為路徑檢查通過就視為解決。
