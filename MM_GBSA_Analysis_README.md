# MM/GBSA Analysis Workflow

本流程用於整理 MM/GBSA 結果，計算三次 replica 的平均值與標準差，並產生後續繪圖使用的資料。

---

## Workflow

```text
final_results_rep1.dat
(from each replica)
            ↓
 process_mmgbsa_data.py
            ↓
 mmgbsa_analysis_data.npz
            ↓
     plot_mmgbsa.py
            ↓
     MM/GBSA Figure
```

---

## Step 1. Process MM/GBSA Data

執行：

```bash
python process_mmgbsa_data.py
```

### 需要修改

```python
BASE_PATH
```

MM/GBSA資料夾位置

```python
SYSTEMS
```

設定分析系統

例如：

```python
{
    "folder": "mmgbsa606",
    "label": "Docking score=6.06",
    "color": "royalblue"
}
```

### Replica設定

```python
REP_SUFFIXES = [
    "_rep1",
    "_rep2",
    "_rep3"
]
```

### 輸入檔案

```python
DATA_FILENAME
```

預設：

```python
final_results_rep1.dat
```

### 輸出

```text
mmgbsa_analysis_data.npz
```

---

## 資料夾格式

```text
mmgbsa606_rep1/
└── final_results_rep1.dat

mmgbsa606_rep2/
└── final_results_rep1.dat

mmgbsa606_rep3/
└── final_results_rep1.dat
```

程式會自動：

```text
讀取所有 Replica
↓
對齊長度
↓
計算 Mean
↓
計算 Std
↓
輸出 NPZ
```

---

## Step 2. Plot MM/GBSA

執行：

```bash
python plot_mmgbsa.py
```

輸入：

```text
mmgbsa_analysis_data.npz
```

輸出：

```text
MM/GBSA Mean ± Std Figure
```

---

## 注意事項

1.

所有 replica 檔案格式必須一致。

2.

能量值預設讀取：

```text
第二欄 (Column 2)
```

3.

若 replica 長度不同：

```text
rep1 = 5000
rep2 = 4800
rep3 = 5000
```

程式會自動取最短長度：

```text
4800 frames
```

進行統計。

4.

若模擬時間換算不同：

修改

```python
FRAMES_PER_NS
```

例如：

```python
FRAMES_PER_NS = 500.0
```

代表：

```text
500 frames = 1 ns
```

---

## 常見錯誤

### File not found

確認：

```python
BASE_PATH
DATA_FILENAME
```

是否正確。

### No valid data

確認：

```text
final_results_rep1.dat
```

是否存在且包含數值資料。

### 圖畫不出來

確認：

```text
mmgbsa_analysis_data.npz
```

是否成功產生。