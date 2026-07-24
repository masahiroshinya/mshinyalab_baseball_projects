# 学習ワークフロー：全バットマーカーの軌跡（スイング軌道）を可視化しよう

## このフォルダの目的

これまでの学習では、バット先端（`top`）の**速度の時系列**を確認してきました。
このステップでは、全バットマーカー（`top` / `first` / `second` / `third` / `bottom`）の**3次元位置の軌跡**を可視化し、バットのスイング軌道をグラフで確認できるようにすることが目標です。

あわせて、「LED点灯前後の一定時間に絞ったフレーム範囲の設定」と「ピーク速度フレームの特定」という新しい技術を習得します。

### 作成するファイル

| ファイル名                          | 種類       | 役割                                               |
| ----------------------------------- | ---------- | -------------------------------------------------- |
| `step4_forstudy_bat_trajectory.m` | スクリプト | 全バットマーカーの軌跡（スイング軌道）を可視化する |

---

## 今回習得する新しい概念

```
学習用_4（復習）で使ったこと
  ✅ データ読み込み・フィルター処理
  ✅ 各バットマーカーの速度計算
  ✅ LED点灯タイミングの検出

今回 新しく学ぶこと
  ➕ フレーム範囲の絞り込み（LED前後の時間窓）
  ➕ [~, idx] = max() でピーク速度フレームを特定する
  ➕ plot3() で3次元軌跡を描く
  ➕ draw_stick_picture() で3D・2Dのスティック図を追加する
  ➕ XY平面（真上から見た図）での可視化
```

---

## 全体の処理の流れ（まず読んで頭に入れよう）

```
[1] 初期設定              → 被験者・条件・試行番号、バットマーカー名リストを設定する
[2] データ読み込み         → x3_DataChecked からデータを読み込む
[3] フィルター処理         → マーカー座標にフィルターをかける（復習）
[4] 速度計算              → 各バットマーカーの合成速度を計算する（復習）
[5] LED タイミング検出     → LED が光ったフレームを検出する（復習）
[6] フレーム範囲の絞り込み → LED 前後の時間窓に対応するフレーム番号の範囲を作る（新規）
[7] ピーク速度フレームの特定 → top マーカーの速度が最大になるフレームを見つける（新規）
[8] 図1：3D 軌跡の描画    → 全バットマーカーの3D軌跡を描き、ピーク時のスティック図を重ねる
[9] 図2：XY 平面の描画    → 真上から見た2D軌跡を描き、ピーク時のバット姿勢を重ねる
```

---

## STEP 1：ファイルの準備と初期設定

### やること

このフォルダ内に `step4_forstudy_bat_trajectory.m` を新規作成し、先頭に以下を書きます。

### 書くコード

```matlab
clear
close all
clc

% 分析対象の設定
iSubject   = 1 ;
iCondition = 1 ; % 1: free, 2: simple, 3: gonogo
iTrial     = 1 ;

ConditionNameArray = {'free', 'simple', 'gonogo'} ;

batMarkerNameArray = {'top', 'first', 'second', 'third', 'bottom'} ;
nBatMarker = length(batMarkerNameArray) ;
```

### 解説

| コード                 | 意味                                              |
| ---------------------- | ------------------------------------------------- |
| `batMarkerNameArray` | バットに貼付した5つのマーカーの名前を並べたリスト |
| `nBatMarker`         | マーカーの総数を自動で数える（= 5）               |

### 作業前の必須設定

MATLABのカレントフォルダを **`Preliminary experiments/2026-05-13/MATLAB/`** に設定すること。

```
（理由：x3_DataChecked/ フォルダへのパスが通るようにするため）
```

### 確認ポイント

- [X] `step4_forstudy_bat_trajectory.m` を作成した
- [X] MATLABのカレントフォルダが `MATLAB/` になっていることを確認する
- [X] コードを実行してエラーが出ないことを確認する

---

## STEP 2：データ読み込みとフィルター処理（復習）

### 書くコード

STEP 1 の続きに追加してください。

```matlab
% データ読み込み
dataFilePath = sprintf('x3_DataChecked/Data%02d', iSubject) ;
load(dataFilePath)

Data = DataArray(iTrial, iCondition) ;
Prm = parameters ;

% フィルター処理
fs = Data.FrameRate ;
fc = Prm.Fc ;
[b, a] = butter(2, fc/(fs/2)) ;
M = filt_all_fields(b, a, Data.Markers) ;
```

### 解説

ここまでは 学習用_4（`step3_forstudy_visualize_all_bat_markers.m`）と全く同じコードです。
詳しい解説は 学習用_4 の workflow.md（STEP 2〜5）を参照してください。

### 確認ポイント

- [X] 実行後、ワークスペースに `DataArray`・`Data`・`M` が現れることを確認する
- [X] `size(M.top)` を実行して `n × 3` の行列になっていることを確認する（n = フレーム数）

---

## STEP 3：各バットマーカーの合成速度を計算する（復習）

### 書くコード

```matlab
% 各バットマーカーの合成速度を計算
BatMarkerVelocity = struct ;

for iMarker = 1:nBatMarker
    markerName = batMarkerNameArray{iMarker} ;
    pos = M.(markerName) ;
    vel = diff3p(pos, 1/fs) ;
    netVel = sum(vel.^2, 2).^0.5 ;
    BatMarkerVelocity.(markerName) = netVel ;
end
```

### 解説

学習用_4（STEP 6）で学んだ内容と同じです。
`for` ループを使って各マーカーの合成速度を一括計算し、`BatMarkerVelocity` 構造体に保存します。

### 確認ポイント

- [X] 実行後、`BatMarkerVelocity.top` などにデータが格納されることを確認する
- [X] `plot(BatMarkerVelocity.top)` を実行して速度の時系列が描かれることを確認する

---

## STEP 4：LED 点灯タイミングの検出（復習）

### 書くコード

```matlab
% LED 点灯タイミングの検出
led = Data.LEDData(:, 2) ;
tCueAnalog = find(abs(led) > 2, 1, 'first') ;
tCueMarker = round(tCueAnalog / Data.AnalogFs * fs) ;

fprintf('LED 点灯フレーム: %d\n', tCueMarker) ;
```

### 解説

学習用_4（STEP 9）で学んだ内容と同じです。
LED 信号の電圧が 2V を超えた最初のフレームを「点灯タイミング」として検出します。

### 確認ポイント

- [X] `tCueMarker` の値が表示されることを確認する
- [X] `plot(led)` で LED 信号を描画し、電圧が変化している箇所を目視で確認する

---

## STEP 5：フレーム範囲の絞り込み（新しい概念）

バット軌跡を可視化するとき、試行全体（数千フレーム）を表示するとスイング以外の動きが混ざり、軌跡が見づらくなります。
「LED点灯の前後一定時間」だけに絞ることで、スイング軌道だけをきれいに取り出せます。

### 書くコード

```matlab
% フレーム範囲の設定（LED 前1秒〜後3秒）
nFrame = size(M.top, 1) ;
frameStart = max(1, tCueMarker + round(-1 * fs)) ;
frameEnd   = min(nFrame, tCueMarker + round(3 * fs)) ;
frameRange = frameStart : frameEnd ;

fprintf('フレーム範囲: %d 〜 %d（計 %d フレーム）\n', frameStart, frameEnd, length(frameRange)) ;
```

### 各行の解説

| コード                                 | 意味                                                                                      |
| -------------------------------------- | ----------------------------------------------------------------------------------------- |
| `nFrame = size(M.top, 1)`            | マーカーデータの総フレーム数を取得する（`size` の第2引数 `1` は「行数」を返す）       |
| `round(-1 * fs)`                     | −1秒分のフレーム数を整数に丸める。`fs = 250` なら `round(-250)` = −250              |
| `tCueMarker + round(-1 * fs)`        | 「LED点灯フレームから1秒前」のフレーム番号を計算する                                      |
| `max(1, ...)`                        | フレーム番号が1より小さくならないようにする安全処理（データの端より外に出ないようにする） |
| `min(nFrame, ...)`                   | フレーム番号が総フレーム数を超えないようにする安全処理                                    |
| `frameRange = frameStart : frameEnd` | 絞り込んだフレームの番号リスト（例：`[350, 351, 352, ..., 1100]`）                      |

**イメージ図：**

```
全フレーム（例）:  1 ─────── 350 ───── 600 ──── 1100 ─── 2000
                             ↑           ↑           ↑
                          LED前1秒    LED点灯      LED後3秒
                             │           │           │
                  frameStart ├───────────────────────┤ frameEnd
                             └────── frameRange ──────┘
```

### 確認ポイント

- [X] `frameStart`・`frameEnd`・`length(frameRange)` の値が表示されることを確認する
- [X] `length(frameRange)` が `4 × fs`（4秒分のフレーム数）に近い値になっていることを確認する
  - 例：`fs = 250` なら `250 × 4 = 1000` フレーム程度

---

## STEP 6：top マーカーのピーク速度フレームを特定する（新しい概念）

スイング軌跡の可視化では、「バットが最も速く動いていた瞬間」のバット姿勢（スティック図）を重ねて表示します。
そのため、**絞り込んだ範囲内**で `top` マーカーの速度が最大になるフレームを見つけます。

### 書くコード

```matlab
% top マーカーのピーク速度フレームを特定（frameRange 内で）
[~, idxPeak] = max(BatMarkerVelocity.top(frameRange)) ;
tPeak = frameRange(idxPeak) ;

fprintf('ピーク速度フレーム: %d\n', tPeak) ;
fprintf('ピーク速度: %.1f mm/s\n', BatMarkerVelocity.top(tPeak)) ;
```

### `[~, idxPeak] = max(...)` の解説

`max()` 関数は、2つの出力を返すことができます。

```matlab
[最大値, そのインデックス] = max(配列)
```

**具体例：**

```matlab
v = [10, 50, 30, 80, 20] ;
[maxVal, idxMax] = max(v) ;
% maxVal = 80   （最大値）
% idxMax = 4    （4番目が最大）
```

**今回のコードの意味：**

| コード部分                                 | 意味                                                                             |
| ------------------------------------------ | -------------------------------------------------------------------------------- |
| `max(BatMarkerVelocity.top(frameRange))` | `frameRange` の範囲内での top マーカー速度の最大値とそのインデックスを求める   |
| `~`（チルダ）                            | 最大値そのものは今回は不要なので、チルダで「捨てる」。インデックスだけを使う     |
| `idxPeak`                                | `frameRange` の中での「何番目か」（1始まり）                                   |
| `tPeak = frameRange(idxPeak)`            | `frameRange` の `idxPeak` 番目の要素 → 元のデータでのフレーム番号に変換する |

**`idxPeak` と `tPeak` の違い（重要！）：**

```
frameRange = [350, 351, 352, ..., 1100]  （例）

idxPeak = 251   → frameRange の「251番目」が最大（frameRange の中での位置）

tPeak = frameRange(251)
       = frameRange(1) + 250
       = 350 + 250
       = 600  → 元データの「600フレーム目」が最大（スティック図を描くときはこちらが必要）
```

### 確認ポイント

- [X] `tPeak`（ピーク速度フレーム）の値が表示されることを確認する
- [X] `tPeak > tCueMarker` であることを確認する（ピーク速度は LED 点灯後のはず）
- [X] `BatMarkerVelocity.top(tPeak)` の値が他のフレームの速度より大きいことを確認する

---

## STEP 7：図1 ― 全バットマーカーの3D軌跡を描く（新しい概念）

### 書くコード

```matlab
figure(1)
clf
hold on

for iMarker = 1:nBatMarker
    markerName = batMarkerNameArray{iMarker} ;
    pos = M.(markerName) ;
    plot3(pos(frameRange, 1), pos(frameRange, 2), pos(frameRange, 3), 'LineWidth', 1.2)
end

xlabel('X (mm)')
ylabel('Y (mm)')
zlabel('Z (mm)')
legend(batMarkerNameArray, 'Interpreter', 'none')
grid on
title('全バットマーカー3D軌跡（LED前後）')
```

### `plot3` の解説

これまで使っていた `plot(x, y)` は2次元グラフでしたが、`plot3(x, y, z)` を使うと3次元グラフが描けます。

| コード                 | 意味                                                |
| ---------------------- | --------------------------------------------------- |
| `plot3(x, y, z)`     | 3次元の折れ線グラフを描く                           |
| `pos(frameRange, 1)` | `frameRange` の範囲内の x 座標（1列目）を取り出す |
| `pos(frameRange, 2)` | y 座標（2列目）                                     |
| `pos(frameRange, 3)` | z 座標（3列目）                                     |
| `zlabel('Z (mm)')`   | z 軸のラベルを設定する（3Dグラフ専用）              |

**`pos(frameRange, 1)` のイメージ：**

```
pos は nFrame × 3 の行列：
        x     y     z
行1  [ 100,  200, 1000 ]
行2  [ 102,  205, 1005 ]
...
行n  [ 300,  180,  900 ]

pos(frameRange, 1) → frameRange の行の、x 座標（1列目）だけを取り出す
```

### 確認ポイント

- [X] 実行して Figure 1 に3次元グラフが表示されることを確認する
- [X] 5本の軌跡（各マーカー1本）が描かれていることを確認する
- [X] グラフをマウスでドラッグして視点を変えられることを確認する（MATLABの3Dグラフは回転できる）
- [X] バットの軌跡がスイングらしい弧を描いているか目視で確認する

---

## STEP 8：図1 ― ピーク時のスティック図を追加する

STEP 7 で描いた3D軌跡に、**ピーク速度時のバット姿勢（スティック図）** を重ね書きします。

### 書くコード

STEP 7 の描画コード（`title(...)` 行）の直前に追加します。

```matlab
% ピーク時のバット姿勢（スティック図）を3Dで追加
draw_stick_picture(M, batMarkerNameArray, tPeak, 'xyz', '-ok') ;
```

### `draw_stick_picture` の引数の解説

| 引数             | 今回の値               | 意味                                                                     |
| ---------------- | ---------------------- | ------------------------------------------------------------------------ |
| `Markers`      | `M`                  | フィルター済みのマーカー座標データ                                       |
| `MarkerNames`  | `batMarkerNameArray` | 描くマーカー名のリスト（top → first → second → third → bottom の順） |
| `frameNumber`  | `tPeak`              | 描くフレーム番号（ピーク速度フレーム）                                   |
| `coordination` | `'xyz'`              | 3次元で描く（`'xy'` にすると2次元になる）                              |
| `varargin`     | `'-ok'`              | 線のスタイル：黒（`k`）の実線（`-`）に丸マーカー（`o`）            |

**`'-ok'` の線スタイルの読み方：**

```
'-ok'  =  '-'（実線）  +  'o'（丸印）  +  'k'（黒色）

他の例：
'--r'   → 赤の破線
'-ob'   → 青の実線 + 丸印
'-^g'   → 緑の実線 + 三角印
```

### 確認ポイント

- [X] Figure 1 にスティック図（黒い線と丸）が重ねて表示されることを確認する
- [X] スティック図が5本の軌跡の終盤付近に表示されているか（ピーク速度はスイングの中盤〜後半）を確認する
- [X] スティック図が「バットらしい直線形状」になっているかを確認する

---

## STEP 8（追加）：全マーカーペアを繋いだスティック図を3Dで描く

### このステップの目的

`draw_stick_picture` は隣接マーカーだけを繋ぎます。
このステップでは **全ての組み合わせ**（top-first、top-second、top-third、…、third-bottom）を直線で繋ぐスティック図を描きます。

5点の全ペア数は **C(5,2) = 10 本**になります。

```
top ─── first ─── second ─── third ─── bottom  （隣接のみ：4本）

top ─── first
top ─── second
top ─── third
top ─── bottom
first ─── second
first ─── third
first ─── bottom
second ─── third
second ─── bottom
third ─── bottom                                （全ペア：10本）
```

### 書くコード

STEP 8 の `draw_stick_picture(...)` の直後に追加します。

```matlab
% tPeak フレームの全マーカー位置を取得
batPos = zeros(nBatMarker, 3) ;
for i = 1:nBatMarker
    batPos(i, :) = M.(batMarkerNameArray{i})(tPeak, :) ;
end

% 全ペアの組み合わせで直線を繋ぐ
for i = 1:nBatMarker
    for j = i+1 : nBatMarker
        plot3([batPos(i,1), batPos(j,1)], ...
              [batPos(i,2), batPos(j,2)], ...
              [batPos(i,3), batPos(j,3)], '-k', 'LineWidth', 1.5)
    end
end
```

### 解説

**ネストしたループで「全ペア」を作る仕組み：**

`j = i+1` から始めることで、同じペアを2回描くことを防いでいます。

```
i=1 (top)    : j = 2,3,4,5 → top-first, top-second, top-third, top-bottom  （4本）
i=2 (first)  : j = 3,4,5   → first-second, first-third, first-bottom       （3本）
i=3 (second) : j = 4,5     → second-third, second-bottom                   （2本）
i=4 (third)  : j = 5       → third-bottom                                  （1本）
                                                               合計 10本
```

**`plot3` に2点を渡す書き方：**

```matlab
plot3([x1, x2], [y1, y2], [z1, z2])
```

x・y・z それぞれに「始点と終点の2つの値」を渡すと、その2点を結ぶ直線が描かれます。

| コード                         | 意味                                          |
| ------------------------------ | --------------------------------------------- |
| `batPos(i, 1)`               | i 番目のマーカーの x 座標                     |
| `[batPos(i,1), batPos(j,1)]` | i 番目と j 番目の x 座標を2要素配列にまとめる |
| `'LineWidth', 1.5`           | 線の太さ                                      |

---

### 確認ポイント

- [X] Figure 1 に10本の線でバット形状が表示されることを確認する
- [X] グラフを回転させて3D空間に傾いていることを確認する
- [X] `i=1, j=2` のときに top-first の線が引かれていることを `batPos(1,:)` と `batPos(2,:)` の値で確認する

---

## STEP 9：図2 ― XY 平面（真上から見た軌跡）を描く（新しい概念）

3D グラフは視点を変えられますが、「真上から見た図（XY平面）」を固定した2D グラフとして別途作成すると、スイング軌道の形がより分かりやすくなります。

### 書くコード

```matlab
figure(2)
clf
hold on

for iMarker = 1:nBatMarker
    markerName = batMarkerNameArray{iMarker} ;
    pos = M.(markerName) ;
    plot(pos(frameRange, 1), pos(frameRange, 2), 'LineWidth', 1.2)
end

% ピーク時のバット姿勢（スティック図）をXY平面で追加
draw_stick_picture(M, batMarkerNameArray, tPeak, 'xy', '-ok') ;

xlabel('X (mm)')
ylabel('Y (mm)')
legend([batMarkerNameArray, {'peak posture'}], 'Interpreter', 'none')
grid on
axis equal
title('バット軌跡（真上から：XY 平面）')
```

### 解説

| コード                                           | 意味                                                                    |
| ------------------------------------------------ | ----------------------------------------------------------------------- |
| `plot(pos(frameRange, 1), pos(frameRange, 2))` | x 座標と y 座標だけを使って2次元グラフを描く（z は無視する）            |
| `draw_stick_picture(M, ..., 'xy', '-ok')`      | XY 平面（真上から見た図）でスティック図を描く                           |
| `axis equal`                                   | x 軸と y 軸のスケールを統一する。これをしないとバット姿勢が歪んで見える |

**`axis equal` の効果：**

```
なし（デフォルト）：x と y のスケールが自動調整される
  → 100mm × 100mm の正方形が長方形に見えてしまう

あり（axis equal）：x と y が同じ比率になる
  → 100mm × 100mm の正方形が正方形に見える
  → バット長さや軌道の形が正しく表現される
```

### 確認ポイント

- [X] Figure 2 に5本の2D軌跡が描かれることを確認する
- [X] Figure 2 に黒のスティック図（ピーク時バット姿勢）が重ねて表示されることを確認する
- [X] `axis equal` により、バットが実際の形状比率で表示されているか確認する
- [X] Figure 1（3D）と Figure 2（XY平面）を見比べて、軌道の形の対応が読み取れるか確認する

---

## STEP 10：完成確認

### 動作確認のチェックリスト

- [X] スクリプト全体をはじめから最後まで実行してエラーが出ないことを確認する
- [X] Figure 1（3D）に5本のマーカー軌跡 ＋ スティック図が表示されることを確認する
- [X] Figure 2（XY平面）に5本のマーカー軌跡 ＋ スティック図が表示されることを確認する
- [X] コマンドウィンドウに以下が表示されることを確認する
  - `LED 点灯フレーム: ○○○`
  - `フレーム範囲: ○○○ 〜 ○○○（計 ○○○ フレーム）`
  - `ピーク速度フレーム: ○○○`
  - `ピーク速度: ○○○.○ mm/s`
- [X] `iCondition = 2`（simple）や `iCondition = 3`（gonogo）に変えて実行しても動作することを確認する
- [X] `iTrial` を別の番号に変えて実行しても動作することを確認する

> 以上が全部 OK なら、スクリプトは完成です！

---

## 困ったときのヒント

### エラーが出たら

1. エラーメッセージを読む（どのファイルの何行目か確認する）
2. エラーが出た行のコードを見直す
3. AI アシスタントにエラーメッセージを貼り付けて質問する

### 変数の中身を確認したいときは

```matlab
frameRange      % フレーム番号リスト
tPeak           % ピーク速度フレーム番号
M.top(tPeak, :) % ピーク時の top マーカーの xyz 座標
BatMarkerVelocity.top(tPeak)   % ピーク速度の値
```

### グラフが見づらいときは

```matlab
% 3D グラフの視点を数値で指定する（ az = 水平角, el = 仰角）
figure(1)
view(0, 90)   % 真上から見た図（Figure 2 と同じ視点）
view(0, 0)    % 真横から見た図
view(45, 30)  % 斜め上から見た図（デフォルトに近い）
```

### コードの意味が分からないときは

```matlab
help plot3
help max
help axis
```

---

## 全体の振り返りチェックリスト

- [X] STEP 1：ファイルを作成し、初期設定のコードを書いた
- [X] STEP 2：データ読み込みとフィルター処理のコードを書いた
- [X] STEP 3：全バットマーカーの速度計算のコードを書いた
- [X] STEP 4：LED 点灯タイミング検出のコードを書いた
- [X] STEP 5：フレーム範囲の絞り込みコードを書き、範囲が正しく設定されることを確認した
- [X] STEP 6：`[~, idxPeak] = max()` でピーク速度フレームを特定し、`tPeak` を取得した
- [X] STEP 7：`plot3` で Figure 1 に5本の3D軌跡を描いた
- [X] STEP 8：`draw_stick_picture` でピーク時のスティック図を Figure 1 に追加した
- [X] STEP 8（追加）：全マーカーの全ペア（10本）を3D直線で繋ぎ、Figure 1 に重ねて表示した
- [X] STEP 9：`plot` で Figure 2 に5本のXY平面軌跡を描き、スティック図も追加した
- [X] STEP 10：全体を通して実行し、エラーなしで2つのグラフが表示された

---

*作成日: 2026-06-03*
