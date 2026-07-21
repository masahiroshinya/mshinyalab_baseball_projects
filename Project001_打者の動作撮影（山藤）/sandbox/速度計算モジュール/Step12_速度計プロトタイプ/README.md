# Step12 速度計プロトタイプ

Step09 で出力した3次元座標CSVから、関節点やバット位置の速度を計算する。
まずは「先行研究で出てくる速度指標を、自分のデータから作る」ことを目標にする。

このスクリプトは Python の標準ライブラリだけで動く。
`numpy` や `pandas` が入っていない環境でも実行できる。

## 入力CSV

最低限、次の列が必要。

```text
frame_number
<point>_X
<point>_Y
<point>_Z
```

例:

```text
frame_number,left_wrist_X,left_wrist_Y,left_wrist_Z,bat_X,bat_Y,bat_Z
```

Step09 の出力では、次のような点を想定している。

```text
nose
left_eye
right_eye
left_ear
right_ear
left_shoulder
right_shoulder
left_elbow
right_elbow
left_wrist
right_wrist
left_hip
right_hip
left_knee
right_knee
left_ankle
right_ankle
bat
```

## 実行例

全ての点の速度を計算する。

```powershell
python velocity_meter.py --input sample_tracking_3d.csv --fps 240 --output sample_with_speed.csv
```

バット先端位置を仮推定して、バット先端速度も出す。

```powershell
python velocity_meter.py --input sample_tracking_3d.csv --fps 240 --output sample_with_speed.csv --make-bat-tip
```

ノイズが強い場合、移動平均で少し滑らかにする。
元の座標列は書き換えず、速度計算の内部だけで滑らかにする。

```powershell
python velocity_meter.py --input sample_tracking_3d.csv --fps 240 --output sample_with_speed.csv --make-bat-tip --smooth-window 5
```

## 出力される列

点の名前が `bat` の場合、次の列が追加される。

```text
bat_distance_m
bat_speed_mps
bat_speed_kmph
```

`--make-bat-tip` を付けた場合は、次の列も追加される。

```text
bat_tip_X
bat_tip_Y
bat_tip_Z
bat_tip_distance_m
bat_tip_speed_mps
bat_tip_speed_kmph
```

## 単位

入力座標がメートルなら、`--unit-scale-to-m 1.0` のままでよい。

入力座標がセンチメートルなら、メートルに直すために次のようにする。

```powershell
python velocity_meter.py --input input.csv --fps 240 --output output.csv --unit-scale-to-m 0.01
```

入力座標がミリメートルなら、次のようにする。

```powershell
python velocity_meter.py --input input.csv --fps 240 --output output.csv --unit-scale-to-m 0.001
```

## 研究で見るべき値

最初は次の速度を優先して見る。

| 指標 | 列 | 意味 |
|---|---|---|
| バット位置速度 | `bat_speed_kmph` | 検出されたバット点の速度 |
| バット先端速度 | `bat_tip_speed_kmph` | グリップとバット点から仮推定した先端速度 |
| 左手首速度 | `left_wrist_speed_kmph` | 手の動き |
| 右手首速度 | `right_wrist_speed_kmph` | 手の動き |
| 肩速度 | `left_shoulder_speed_kmph`, `right_shoulder_speed_kmph` | 体幹上部の移動 |

## 注意

- 速度は座標のノイズに敏感。
- 1フレームだけ点が飛ぶと速度が急に大きくなる。
- 先行研究の「バットヘッド速度」に近づけるには、実際のバット先端点をより正確に推定する必要がある。
- `--make-bat-tip` の先端推定は、今の段階ではプレ試行用の近似。
