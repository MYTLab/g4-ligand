# RMSF Analysis Workflow

本流程用於分析 G4 DNA 系統的 RMSF，並產生 RMSF 圖。

---

## Step 1. 計算 RMSF

執行：

```bash
python calculate_rmsf_blank_na_c1.py
```

### 輸入檔案

```text
step3_input.psf

rep1/*.dcd
rep2/*.dcd
rep3/*.dcd
```

### 程式功能

```text
Trajectory
↓
G-tetrad Core Alignment
↓
C1' RMSF Calculation
↓
NPZ Output
```

### 重要設定

修改：

```python
CORE_RESIDUES
```

指定 G-tetrad core。

修改：

```python
system_setup
```

指定 PSF 與 DCD 檔案位置。

修改：

```python
output_file
```

指定輸出檔名。

### 輸出檔案

```text
rmsf_data_na_all_blank_c1.npz
```

---

## Step 2. 繪製 RMSF

執行：

```bash
python plot_rmsf_na_blank_avg_err.py
```

### 輸入檔案

```text
rmsf_data_na_all_blank_c1.npz
```

### 程式功能

```text
Load RMSF Data
↓
Calculate Mean
↓
Calculate Standard Deviation
↓
Plot RMSF Profile
```

### 重要設定

修改：

```python
data_file
```

指定要讀取的 RMSF 檔案。

修改：

```python
target_key
```

指定要繪製的系統。

修改：

```python
core_indices
```

指定 G-tetrad core 區域（灰色背景）。

修改：

```python
y_max
```

控制 Y 軸上限。

---

## RMSF 計算方式

### Alignment

使用：

```text
P
C1'
C4'
```

並以：

```text
G-tetrad Core
```

作為對齊基準。

目的：

```text
移除整體平移與旋轉影響
```

---

### RMSF Calculation

使用：

```text
C1'
```

作為每個 nucleotide 的代表原子。

因此：

```text
1 Residue
↓
1 RMSF Value
```

---

## 單位說明

MDTraj 輸出：

```text
nm
```

繪圖時轉換：

```text
Å
```

換算方式：

```text
1 nm = 10 Å
```

---

## 完整流程

```text
PSF + DCD
↓
calculate_rmsf_blank_na_c1.py
↓
rmsf_data_xxx.npz
↓
plot_rmsf_na_blank_avg_err.py
↓
RMSF Figure
```
