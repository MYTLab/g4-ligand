# 自行補入的已準備初始 PDB

由交接提供者放入全部已選好的 G4–TO 初始 pose，例如 `551_K.pdb`。
來源為 2JSM，pose 來自 AutoDock 4.2；本交接不要求重跑 docking。
中央 K⁺ 已補好的檔案，不要再次執行 `reference/original/add2.tcl`。

請為每個 PDB 補上：系統編號、是否已含中央 K⁺、中央 K⁺ 數量、來源 model。
本交接包尚未包含這批初始 PDB。`551/step3_input.pdb` 是溶劑化後的範例，
不是需要重新上傳 CHARMM-GUI 的未溶劑化 pose。
