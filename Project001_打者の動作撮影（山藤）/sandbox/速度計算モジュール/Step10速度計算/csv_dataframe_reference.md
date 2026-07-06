# CSVとDataFrameの基本処理メモ

このメモは、速度計算コードを書くときに参照するためのものです。
CSVに保存されたフレーム番号や3D座標を読み込み、Pythonで扱いやすい形に変換する流れをまとめます。

---

## 1. CSVを読み込む

CSVファイルを読み込むときは、`pandas` を使います。

```python
import pandas as pd

df = pd.read_csv("data.csv")
```

ここで `df` は DataFrame です。
DataFrame は、CSVを表のように扱うための入れ物です。

イメージ：

```text
frame    x      y      z
0        1.2    3.4    5.6
1        1.3    3.5    5.7
2        1.5    3.7    5.9
```

---

## 2. フレーム番号をlistに変換する

CSVの `frame` 列を取り出し、Pythonのlistに変換します。

```python
frames = df["frame"].tolist()
```

`df["frame"]` は DataFrame の中から `frame` 列だけを取り出す処理です。
`.tolist()` は、その列を Python の list に変換する処理です。

結果のイメージ：

```python
[0, 1, 2]
```

Matplotlibでグラフを描くときは、この `frames` を横軸として使えます。

```python
plt.plot(frames, speeds)
```

---

## 3. 1列ずつ取り出してlistにする

3D座標の `x`, `y`, `z` を別々のlistとして扱いたい場合は、次のように書きます。

```python
x_list = df["x"].tolist()
y_list = df["y"].tolist()
z_list = df["z"].tolist()
```

この形は、各列を個別に確認したいときに便利です。

---

## 4. 3D座標をまとめてNumPy配列にする

速度計算では、`x`, `y`, `z` をまとめて1つの3D座標として扱うことが多いです。
その場合は、次のように書きます。

```python
points_3d = df[["x", "y", "z"]].to_numpy()
```

`df[["x", "y", "z"]]` は、複数の列をまとめて取り出す処理です。
`.to_numpy()` は、それを NumPy 配列に変換する処理です。

結果のイメージ：

```python
[
    [1.2, 3.4, 5.6],
    [1.3, 3.5, 5.7],
    [1.5, 3.7, 5.9]
]
```

速度計算では、次のように現在フレームと1フレーム前を取り出せます。

```python
current_point = points_3d[i]
previous_point = points_3d[i - 1]
```

---

## 5. 1行ずつ処理する

DataFrameを1行ずつ見ながら処理したい場合は、`for` 文を使います。

```python
for i in range(len(df)):
    frame = df.loc[i, "frame"]
    x = df.loc[i, "x"]
    y = df.loc[i, "y"]
    z = df.loc[i, "z"]
```

`df.loc[i, "frame"]` は、`i` 行目の `frame` 列の値を取り出す処理です。

ただし、速度計算では「現在フレーム」と「1フレーム前」を比べる必要があるため、次のように `1` から始めることが多いです。

```python
for i in range(1, len(df)):
    current_frame = df.loc[i, "frame"]
    previous_frame = df.loc[i - 1, "frame"]

    current_point = df.loc[i, ["x", "y", "z"]].to_numpy()
    previous_point = df.loc[i - 1, ["x", "y", "z"]].to_numpy()
```

---

## 6. 新しい列をDataFrameに追加する

計算した速度を DataFrame に追加したい場合は、新しい列名を指定します。

```python
df["speed_kmph"] = speeds
```

`speeds` は、各フレームの速度を入れたlistまたはNumPy配列です。

例：

```python
speeds = [float("nan"), 12.4, 15.8, 18.1]
df["speed_kmph"] = speeds
```

最初のフレームは1フレーム前がないため、速度を計算できません。
そのため `NaN` を入れておくと、グラフ上では欠損値として扱えます。

---

## 7. 欠損値をNaNとして扱う

速度が計算できない場所は、`0` ではなく `NaN` にします。

```python
import numpy as np

speeds.append(np.nan)
```

`0` を入れると「速度が本当に0だった」と誤解されるため、欠損値には `NaN` を使います。

Matplotlibでは、`NaN` の場所は線が途切れて表示されます。

```python
plt.plot(frames, speeds, marker="o")
```

---

## 8. DataFrameをCSVとして保存する

速度列を追加した DataFrame を、新しいCSVとして保存します。

```python
df.to_csv("result_with_speed.csv", index=False)
```

`index=False` を付けると、DataFrameの行番号をCSVに保存しません。
通常は `index=False` を付ける方が見やすいです。

---

## 9. 速度計算でよく使う基本セット

速度計算の最初に使う形は、次のセットが基本です。

```python
import pandas as pd
import numpy as np

df = pd.read_csv("data.csv")

frames = df["frame"].tolist()
points_3d = df[["x", "y", "z"]].to_numpy()
```

この形にしておくと、

```python
points_3d[i]
points_3d[i - 1]
```

で、現在フレームと1フレーム前の3D座標を取り出せます。

---

## 10. 速度計算との接続イメージ

```python
import pandas as pd
import numpy as np

df = pd.read_csv("data.csv")

frames = df["frame"].tolist()
points_3d = df[["x", "y", "z"]].to_numpy()

fps = 240
dt = 1 / fps

speeds = [np.nan]

for i in range(1, len(points_3d)):
    current_point = points_3d[i]
    previous_point = points_3d[i - 1]

    movement = current_point - previous_point
    distance = np.linalg.norm(movement)

    speed_mps = distance / dt
    speed_kmph = speed_mps * 3.6

    speeds.append(speed_kmph)

df["speed_kmph"] = speeds
df.to_csv("result_with_speed.csv", index=False)
```

このコードは、三角測量後の3D座標がメートル単位で保存されている場合の例です。
3D座標がミリメートル単位の場合は、速度の単位も変わるため注意が必要です。
