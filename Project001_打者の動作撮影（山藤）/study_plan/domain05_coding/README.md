# 05_coding — Python / コーディング品質 / 3D可視化実装

## 目的

このドメインでは、プログラミング初心者の状態から、最終的に以下を自力で書けるようになることを目指す。

- Python の基本文法を読める・書ける
- CSV の時系列データを `pandas` で扱える
- 3D座標データを関数で整理できる
- `matplotlib` で静的な3D骨格を描ける
- `plotly.graph_objects` の `go.Scatter3d` / `go.Frame` / `go.Figure` を使って、3D骨格アニメーションを作れる
- ノートブックのセルを、あとから読んでも意味が分かる形に分割できる
- エラーが出たときに、どこで・なぜ失敗したかを追える

最終到達点は、Step09 の `batting_3d_tracking.csv` から、打者の3Dスティックフィギュアとバットをアニメーション表示するセルを、自分で組み立てられる状態。

---

## 学習全体マップ

| 段階 | テーマ | 到達目標 |
| --- | --- | --- |
| 0 | ノートブックの使い方 | セルを実行し、変数の中身を確認できる |
| 1 | Python基礎 | 変数、型、条件分岐、ループ、関数を書ける |
| 2 | データ構造 | list / dict / tuple / None / NaN を使い分けられる |
| 3 | pandas基礎 | CSVを読み、列・行・欠損値を扱える |
| 4 | NumPy基礎 | 座標や配列を数値として扱える |
| 5 | 関数分割 | 1つの大きな処理を小さな関数に分けられる |
| 6 | 2D/3Dプロット基礎 | 点・線・軸・スケールを描ける |
| 7 | 骨格データの扱い | 17関節を点と線の集合として扱える |
| 8 | Plotly基礎 | `go.Figure` と `go.Scatter3d` を理解する |
| 9 | Plotlyアニメーション | `go.Frame` で時系列を動かせる |
| 10 | 実装品質 | 読みやすく、再実行しやすく、壊れにくいセルにする |

---

## Phase 0：ノートブックと実行環境に慣れる

### 学ぶこと

- Google Colab / Jupyter Notebook のセル実行
- 上から順番に実行する意味
- 変数は実行後にメモリへ残ること
- `print()` で途中結果を見る方法
- エラー文の読み方
- ライブラリのインポート

### 書けるようにするコード

```python
print("hello")

x = 10
y = 20
print(x + y)

import pandas as pd
import numpy as np
```

### 練習

- 新しいセルを作り、`print()` で自分の名前と今日の日付を表示する
- `x = 3`, `y = 5` を作り、足し算・引き算・掛け算・割り算を表示する
- エラーをわざと出し、エラー文の最後の1行を読む

### チェック

- セルを実行できる
- 変数の値を `print()` で確認できる
- エラーが出たセルを特定できる

---

## Phase 1：Python基礎

### 学ぶこと

- 変数
- 数値、文字列、真偽値
- `if`
- `for`
- `range`
- `len`
- 関数
- コメント

### 書けるようにするコード

```python
score = 85

if score >= 80:
    print("OK")
else:
    print("RETRY")
```

```python
for i in range(5):
    print(i)
```

```python
def add(a, b):
    return a + b

result = add(3, 5)
print(result)
```

### 3D可視化とのつながり

3D骨格の描画では、17個の関節を `for` で順番に処理する。  
また、1フレーム分の処理を `make_plotly_traces(row)` のような関数に分ける。

### 練習

- 0から16までの数字を表示する
- `def double(x):` を作り、入力値を2倍して返す
- `score` が70以上なら `"pass"`、それ以外なら `"fail"` を表示する

### チェック

- `for` で同じ処理を繰り返せる
- `if` で条件によって処理を変えられる
- `def` で関数を書ける

---

## Phase 2：データ構造

### 学ぶこと

- `list`
- `tuple`
- `dict`
- `None`
- `np.nan`
- リスト内包表記
- `append`
- インデックス

### 書けるようにするコード

```python
keypoints = ["nose", "left_eye", "right_eye"]
print(keypoints[0])
```

```python
point = (1.2, 0.5, -0.3)
x, y, z = point
print(x, y, z)
```

```python
row = {
    "nose_X": 0.1,
    "nose_Y": 1.2,
    "nose_Z": 0.3,
}
print(row["nose_X"])
```

### 3D可視化とのつながり

1つの関節は `(x, y, z)` の `tuple` として扱う。  
17個の関節は `list` として扱う。  
欠損している関節は `None` として扱う。

```python
pts = [
    (0.1, 1.0, 0.2),
    None,
    (0.3, 1.1, 0.2),
]
```

### 練習

- 3つの点 `(x, y, z)` をリストに入れる
- `None` が入っている点は表示しない
- 関節名と座標を `dict` で管理する

### チェック

- `list` と `dict` の違いを説明できる
- `None` を使って「存在しない点」を表せる
- `pts[i]` の形で i 番目の点を取り出せる

---

## Phase 3：pandasでCSVを読む

### 学ぶこと

- `pd.read_csv`
- `DataFrame`
- 列の取り出し
- 行の取り出し
- `iloc`
- `iterrows`
- `pd.to_numeric`
- 欠損値 `NaN`
- `dropna`

### 書けるようにするコード

```python
import pandas as pd

df = pd.read_csv("batting_3d_tracking.csv")
print(df.head())
print(df.columns)
```

```python
first_row = df.iloc[0]
print(first_row["frame_number"])
print(first_row["nose_X"])
```

```python
for i, row in df.iterrows():
    print(i, row["frame_number"])
```

### 3D可視化とのつながり

`batting_3d_tracking.csv` は、1行が1フレームを表す。  
各行には `nose_X`, `nose_Y`, `nose_Z` のように、関節名と座標軸が組み合わさった列が入っている。

### 練習

- CSVの列名一覧を表示する
- 最初の5フレームの `frame_number` を表示する
- `nose_X`, `nose_Y`, `nose_Z` を取り出して表示する
- `nose_X` が欠損している行を除外する

### チェック

- `df.iloc[0]` で1行を取り出せる
- `row["nose_X"]` で値を取り出せる
- 欠損値を含む行を除外できる

---

## Phase 4：NumPyと座標計算

### 学ぶこと

- `np.array`
- `np.mean`
- `np.isnan`
- `np.linalg.norm`
- ベクトル
- 座標変換

### 書けるようにするコード

```python
import numpy as np

p1 = np.array([0.0, 0.0, 0.0])
p2 = np.array([1.0, 0.0, 0.0])

distance = np.linalg.norm(p2 - p1)
print(distance)
```

### 3D可視化とのつながり

Step09 のCSV座標は、見やすくするために `(X, Z, -Y)` に変換して表示している。

```python
plot_x = csv_x
plot_y = csv_z
plot_z = -csv_y
```

これは、Matplotlib / Plotly 上で「人が立っている向き」に見えやすくするため。

### 練習

- 2点間距離を計算する
- 左肩と右肩の距離を計算する
- `(x, y, z)` を `(x, z, -y)` に変換する関数を作る

### チェック

- `np.linalg.norm()` で距離を計算できる
- `np.isnan()` で欠損を判定できる
- 座標変換の目的を説明できる

---

## Phase 5：関数に分ける

### 学ぶこと

- 関数の入力
- 関数の返り値
- 1関数1役割
- 関数名の付け方
- 同じ処理を再利用する考え方

### 書けるようにするコード

```python
def transform_point(x, y, z):
    return (x, z, -y)
```

```python
def get_keypoint(row, name):
    x = row[f"{name}_X"]
    y = row[f"{name}_Y"]
    z = row[f"{name}_Z"]
    return transform_point(x, y, z)
```

### 3D可視化とのつながり

Plotlyのセルでは、処理を以下のように分ける。

- `get_plotly_points(row)`：1行から17関節を取り出す
- `get_plotly_bat(row)`：1行からバット中心を取り出す
- `make_plotly_traces(row)`：1フレーム分の描画データを作る

### 練習

- `transform_point(x, y, z)` を書く
- `get_point(row, kp_name)` を書く
- 欠損値があるときは `None` を返すようにする

### チェック

- 長い処理を小さな関数に分けられる
- 関数名から役割が分かる
- 同じ座標変換を複数箇所に書かず、関数で使い回せる

---

## Phase 6：matplotlibで点と線を描く

### 学ぶこと

- `plt.figure`
- `ax.scatter`
- `ax.plot`
- 3D軸
- 軸範囲の固定
- `set_box_aspect`

### 書けるようにするコード

```python
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D

fig = plt.figure()
ax = fig.add_subplot(111, projection="3d")

ax.scatter([0], [0], [0])
ax.plot([0, 1], [0, 0], [0, 0])

plt.show()
```

### 3D可視化とのつながり

まずはアニメーションではなく、1フレームだけ3D骨格を描けるようにする。  
動くものを書く前に、止まった1枚を正しく描く。

### 練習

- 3D空間に1点を描く
- 2点を線でつなぐ
- 17個の点を描く
- `SKELETON = [(5,6), (5,7), ...]` を使って骨格線を描く

### チェック

- 3D軸に点と線を描ける
- 軸範囲を固定できる
- 骨格がフレームによって拡大縮小して見えないようにできる

---

## Phase 7：骨格データを点と線として扱う

### 学ぶこと

- COCO 17 keypoints
- 関節名リスト
- 骨格接続リスト
- 点が欠損したときの処理
- 手首からバット中心へ線を引く考え方

### 重要なデータ

```python
KEYPOINT_NAMES = [
    "nose", "left_eye", "right_eye", "left_ear", "right_ear",
    "left_shoulder", "right_shoulder",
    "left_elbow", "right_elbow",
    "left_wrist", "right_wrist",
    "left_hip", "right_hip",
    "left_knee", "right_knee",
    "left_ankle", "right_ankle",
]
```

```python
SKELETON = [
    (0,1),(0,2),(1,3),(2,4),(5,6),
    (5,7),(7,9),(6,8),(8,10),
    (5,11),(6,12),(11,12),
    (11,13),(13,15),(12,14),(14,16),
]
```

### 3D可視化とのつながり

骨格は「点の集合」ではなく、「点を線でつないだ構造」として見る。  
`SKELETON` は、どの点とどの点を線でつなぐかを表す設計図。

### 練習

- `KEYPOINT_NAMES[9]` が何を表すか確認する
- `SKELETON` の各ペアを `for i, j in SKELETON:` で表示する
- 欠損点がある場合、その線は描かない処理を書く
- 左手首・右手首からバット中心へ線を引く処理を書く

### チェック

- 17関節の名前と番号の対応をだいたい理解している
- `(i, j)` が「i番目とj番目を線で結ぶ」という意味だと説明できる
- 欠損点があるときにエラーを出さずスキップできる

---

## Phase 8：Plotly基礎

### 学ぶこと

- `plotly.graph_objects`
- `go.Figure`
- `go.Scatter`
- `go.Scatter3d`
- `fig.update_layout`
- `fig.show`
- Plotlyはブラウザ上でインタラクティブに動くこと

### 書けるようにするコード

```python
import plotly.graph_objects as go

fig = go.Figure()

fig.add_trace(go.Scatter3d(
    x=[0, 1],
    y=[0, 0],
    z=[0, 0],
    mode="lines+markers"
))

fig.show()
```

### 3D可視化とのつながり

Matplotlibは「画像として描く」感覚。  
Plotlyは「ブラウザ上の操作できる図を作る」感覚。

`go.Scatter3d` は、3D空間に点・線・点と線を描くための部品。

### 練習

- 3D空間に1本の線を描く
- 3D空間に3点を描く
- `mode="markers"` と `mode="lines"` の違いを確認する
- `line=dict(color="red", width=5)` を変えて見た目を変える

### チェック

- `go.Figure()` が図全体だと分かる
- `go.Scatter3d()` が図の中の1つの描画要素だと分かる
- `fig.show()` で表示できる

---

## Phase 9：Plotlyで1フレーム分の骨格を描く

### 学ぶこと

- 1フレーム分の `row` から描画データを作る
- 骨格線用の `x`, `y`, `z` リストを作る
- Plotlyの線を途中で切るために `None` を入れる
- 複数の `Scatter3d` を組み合わせる

### 書けるようにするコード

```python
line_x = [0, 1, None, 1, 2]
line_y = [0, 0, None, 0, 1]
line_z = [0, 0, None, 0, 0]
```

Plotlyでは、`None` を入れると線がそこで切れる。  
骨格の複数の線分を1つの `Scatter3d` にまとめるときに使う。

```python
go.Scatter3d(
    x=line_x,
    y=line_y,
    z=line_z,
    mode="lines"
)
```

### 練習

- 1フレームだけ読み込んで17関節を表示する
- 骨格線だけ表示する
- 関節点だけ表示する
- 骨格線と関節点を別々の `Scatter3d` として表示する
- バット中心を黄色で表示する

### チェック

- Plotlyで1フレーム分の3D骨格を描ける
- `None` で線を分割する理由を説明できる
- 線・点・バットを別々の trace として作れる

---

## Phase 10：`go.Frame` でアニメーションを作る

### 学ぶこと

- `go.Frame` の意味
- `frames` はアニメーションの各コマであること
- `data` に「そのコマで表示するtrace」を入れること
- `name` でフレームを指定できること
- `updatemenus` で再生ボタンを作ること
- `sliders` でフレーム移動を作ること

### 基本形

```python
fig = go.Figure(
    data=first_frame_data,
    frames=[
        go.Frame(data=frame0_data, name="0"),
        go.Frame(data=frame1_data, name="1"),
        go.Frame(data=frame2_data, name="2"),
    ]
)
```

`go.Frame` は「この時刻では、このデータを表示する」というスナップショット。

### Step09での考え方

```python
frames = []

for i, row in df_plotly.iterrows():
    frames.append(go.Frame(
        data=make_plotly_traces(row),
        name=str(i)
    ))
```

この処理では、CSVの各行を1つのアニメーションフレームに変換している。

### 練習

- 2点だけが横に動く簡単なアニメーションを作る
- 1本の線が回転するアニメーションを作る
- 3フレームだけの骨格アニメーションを作る
- 10フレームに増やす
- 全フレームに増やす
- 重い場合に `PLOTLY_FRAME_STEP = 2` として間引く

### チェック

- `go.Frame(data=..., name=...)` の意味を説明できる
- `frames` がリストであることを理解している
- 再生ボタンを押すと `frames` が順番に表示されると説明できる
- スライダーで任意のフレームへ移動できる

---

## Phase 11：再生ボタンとスライダー

### 学ぶこと

- `fig.update_layout`
- `updatemenus`
- `method="animate"`
- `args`
- `frame.duration`
- `transition.duration`
- `sliders`
- `steps`

### 書けるようにするコード

```python
fig.update_layout(
    updatemenus=[dict(
        type="buttons",
        buttons=[
            dict(
                label="Play",
                method="animate",
                args=[None, dict(frame=dict(duration=60, redraw=True))]
            )
        ]
    )]
)
```

### 3D可視化とのつながり

`go.Frame` だけでは、フレームのリストを持っているだけ。  
再生ボタンやスライダーを `layout` に追加して、ユーザーが操作できるようにする。

### 練習

- Playボタンだけ作る
- Pauseボタンを追加する
- スライダーを追加する
- スライダーのラベルを `frame_number` にする
- 再生速度を変える

### チェック

- `updatemenus` がボタン設定だと分かる
- `sliders` がフレーム移動UIだと分かる
- `duration` を変えると再生速度が変わることを確認できる

---

## Phase 12：実データでPlotly 3D骨格アニメーションを書く

### 最終課題

`batting_3d_tracking.csv` を読み込み、以下を満たすPlotlyアニメーションを作る。

- 17関節を赤い点で描く
- 骨格線を青い線で描く
- バット中心を黄色で描く
- 両手首からバット中心へ線を引く
- 座標変換 `(X, Z, -Y)` を行う
- 軸範囲を固定する
- `aspectmode="cube"` にする
- Play / Pause ボタンを付ける
- スライダーを付ける
- 重い場合にフレームを間引けるようにする

### 最小構成

必要な関数は以下。

```python
def get_plotly_points(row):
    ...

def get_plotly_bat(row):
    ...

def make_plotly_traces(row):
    ...
```

必要なPlotly要素は以下。

```python
go.Scatter3d()
go.Frame()
go.Figure()
fig.update_layout()
fig.show()
```

### チェック

- 先頭フレームが表示される
- Playで動く
- マウスで回転できる
- 拡大縮小できる
- 骨格が極端に伸び縮みしない
- バットがあるフレームで黄色表示される
- 欠損値があっても止まらない

---

## Phase 13：コード品質

### 学ぶこと

- セルを長くしすぎない
- 設定値をセル上部にまとめる
- 関数名を分かりやすくする
- 同じ処理を繰り返し書かない
- エラーが出たときに確認しやすい `print` を入れる
- 入力ファイルの存在確認
- 空データへの対処

### 良いセル構成

1. import
2. 設定値
3. データ読み込み
4. 前処理
5. 関数定義
6. Figure作成
7. 表示

### 練習

- 1つの巨大セルを、役割ごとに3つのセルへ分ける
- `PLOTLY_FRAME_STEP` などの設定値を上にまとめる
- `print(f"有効フレーム数: {len(df_plotly)}")` を入れる
- CSVが空だった場合にエラーを分かりやすく出す

### チェック

- あとから読んでも処理の順番が分かる
- 設定変更する場所が分かりやすい
- エラーが出たときに原因を探しやすい

---

## Phase 14：デバッグ力

### よくあるエラー

| エラー | 原因 | 確認すること |
| --- | --- | --- |
| `KeyError: 'nose_X'` | CSVに列がない | `df.columns` を見る |
| `IndexError` | 空のDataFrameを `iloc[0]` した | `len(df)` を見る |
| `NameError` | 変数や関数を定義する前に使った | セルの実行順を確認する |
| `ValueError` | 数値変換や配列形状が合わない | `print(type(x), x)` で確認する |
| 図が重い | フレーム数が多すぎる | `PLOTLY_FRAME_STEP` を増やす |
| 骨格が寝て見える | 座標軸の対応が違う | `(X, Z, -Y)` 変換を確認する |

### デバッグの基本手順

1. エラー文の最後の1行を見る
2. エラーが出た行を見る
3. その行で使っている変数を `print` する
4. `type()` と `len()` を見る
5. 入力データの中身を小さく表示する
6. 1フレームだけで試す
7. 3フレームだけで試す
8. 全フレームに広げる

### チェック

- エラー文をそのまま怖がらずに読める
- `print(df.head())` で入力確認できる
- いきなり全データで試さず、小さいデータで試せる

---

## Phase 15：このプロジェクトでの実践タスク

### Task A：CSV理解

- `batting_3d_tracking.csv` を読み込む
- `df.columns` を表示する
- `frame_number` と `nose_X` の先頭10行を表示する
- 有効フレーム数を数える

### Task B：1関節の3D表示

- `nose` だけを3D点として表示する
- フレームごとの `nose` の軌跡を線で表示する

### Task C：1フレーム骨格表示

- 1フレームだけ17関節を表示する
- `SKELETON` を使って線でつなぐ
- 欠損点がある線はスキップする

### Task D：Matplotlib確認

- Matplotlibで1フレームを描く
- Matplotlibでスライダー表示する
- 軸範囲を固定する

### Task E：Plotly静止表示

- Plotlyで1フレームを描く
- マウスで回転する
- `aspectmode="cube"` を設定する

### Task F：Plotlyアニメーション

- 3フレームだけ `go.Frame` を作る
- 10フレームに増やす
- 全フレームに増やす
- Play / Pause / Slider を追加する

### Task G：Step09セルへの統合

- `セル9-6` としてノートブック末尾へ追加する
- `PLOTLY_FRAME_STEP` を設定可能にする
- バット表示あり・なしの両方で動くようにする

---

## 推奨学習時間

初心者から始める場合の目安。

| Phase | 目安時間 |
| --- | --- |
| Phase 0-2 | 6-10 時間 |
| Phase 3-5 | 8-12 時間 |
| Phase 6-7 | 6-10 時間 |
| Phase 8-11 | 8-15 時間 |
| Phase 12-15 | 8-15 時間 |

合計目安：36-62 時間

一気に進めるより、1日1-2時間ずつ進める。  
各Phaseで「読んで分かった」ではなく、「小さいコードを自分で書けた」を完了条件にする。

---

## 最終到達チェックリスト

- [ ] Pythonの `for` / `if` / `def` を使える
- [ ] `list` / `dict` / `tuple` / `None` を使い分けられる
- [ ] `pandas` でCSVを読み、行と列を取り出せる
- [ ] 欠損値を判定してスキップできる
- [ ] 3D座標を `(X, Z, -Y)` に変換できる
- [ ] 17関節のリストを作れる
- [ ] `SKELETON` を使って骨格線を作れる
- [ ] `matplotlib` で1フレームの3D骨格を描ける
- [ ] `go.Scatter3d` で点と線を描ける
- [ ] `go.Frame` でアニメーションの1コマを作れる
- [ ] `go.Figure(data=..., frames=...)` の構造を説明できる
- [ ] Play / Pause / Slider を追加できる
- [ ] 表示が重いときにフレームを間引ける
- [ ] エラー時に `print`, `type`, `len`, `df.head`, `df.columns` で原因を探せる

---

## このドメインのゴール

最終的には、以下を見たときに「意味が分かる」だけでなく、「自分で似たものを書ける」状態を目指す。

```python
frames = []
for i, row in df_plotly.iterrows():
    frames.append(go.Frame(
        data=make_plotly_traces(row),
        name=str(i)
    ))

fig = go.Figure(
    data=make_plotly_traces(df_plotly.iloc[0]),
    frames=frames
)

fig.show()
```

このコードが分かるということは、Pythonの基礎、pandas、関数分割、3D座標、Plotlyの描画部品、アニメーション構造がつながって理解できているということ。
