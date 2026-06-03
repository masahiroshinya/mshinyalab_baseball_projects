# 学習ワークフロー：全バットマーカーを追跡して単一試行解析の精度を上げよう

## このフォルダの目的

現在の単一試行解析では、主にバット先端マーカー `top` を使ってバット速度を計算し、必要に応じて `bottom` を参照しています。
しかし、実際のバット運動は1点だけではなく、複数のバットマーカーの位置関係・欠損・速度変化を合わせて確認することで、より安定して評価できます。

このステップでは、`Data.Markers` に含まれるバット関連マーカーを確認し、各マーカーの座標・速度・ピーク速度・欠損状況を追跡できるようにします。
最終的には、単一試行解析 `m3_analyze_single_trial.m` に反映できる形で、**top / bottom 以外のバットマーカーも分析対象に加えるための考え方と実装手順を学ぶ**ことが目標です。

### 作成する予定のファイル

* `step3_forstudy_visualize_all_bat_markers.m`：全バットマーカーを確認する学習用スクリプト
* 将来的に反映する候補：`m3_analyze_single_trial.m`

---

## 全体の処理の流れ

全バットマーカー追跡で行う処理は以下の通りです。

```
[1] 初期設定              → 分析対象の被験者・条件・試行を指定する
[2] データ読み込み        → DataArray から単一試行の Data を取り出す
[3] マーカー名の確認      → Data.Markers に含まれる全フィールド名を確認する
[4] バットマーカーの選択  → top / bottom 以外のバット関連マーカーを抽出する
[5] 座標のフィルタリング  → 全マーカーの3次元座標に同じフィルターを適用する
[6] 速度計算              → 各マーカーの合成速度を計算する
[7] 欠損・ピーク値確認    → NaN の有無、ピーク速度、速度波形を比較する
[8] 解析結果への保存方針  → Result に保存するフィールド名と構造を決める
```

---

## STEP 1：初期設定を書く

### 書くコード

`step3_forstudy_visualize_all_bat_markers.m` を新規作成し、先頭に以下を書きます。

```matlab
clear
close all
clc

% 分析対象の設定
iSubject   = 1 ;
iCondition = 1 ; % 1: free, 2: simple, 3: gonogo
iTrial     = 1 ;

ConditionNameArray = {'free', 'simple', 'gonogo'} ;
```

### 解説

| コード                 | 意味                                       |
| ---------------------- | ------------------------------------------ |
| `iSubject`           | 被験者番号を指定する                       |
| `iCondition`         | 条件番号を指定する                         |
| `iTrial`             | 確認する試行番号を指定する                 |
| `ConditionNameArray` | 条件番号と条件名を対応させるためのセル配列 |

- [X] STEP 1 のコードを作成し、実行してエラーが出ないことを確認する。

---

## STEP 2：単一試行データを読み込む

### 書くコード

STEP 1 に続けて、以下を追記します。

```matlab
% 元データ (DataArray) の読み込み
dataFilePath = sprintf('x3_DataChecked/Data%02d', iSubject) ;
load(dataFilePath) % DataArray が読み込まれる

% 指定された試行・条件のデータを抽出
Data = DataArray(iTrial, iCondition) ;

% 解析パラメータの読み込み
Prm = parameters ;
```

### 解説

| コード                                           | 意味                                       |
| ------------------------------------------------ | ------------------------------------------ |
| `sprintf('x3_DataChecked/Data%02d', iSubject)` | 被験者番号に対応したデータファイル名を作る |
| `load(dataFilePath)`                           | `DataArray` をワークスペースに読み込む   |
| `DataArray(iTrial, iCondition)`                | 指定した1試行分のデータだけを取り出す      |
| `Prm = parameters`                             | フィルター条件などの共通設定を読み込む     |

- ぴ[X] STEP 2 のコードを追記し、ワークスペースに `Data` が作成されることを確認する。

---

## STEP 3：Data.Markers に含まれるマーカー名を確認する

### 書くコード

```matlab
% Data.Markers に含まれる全マーカー名を確認
markerNameArray = fieldnames(Data.Markers) ;
disp(markerNameArray)
```

### 解説

| コード                       | 意味                                                          |
| ---------------------------- | ------------------------------------------------------------- |
| `fieldnames(Data.Markers)` | `Data.Markers` の中にあるマーカー名をセル配列として取得する |
| `disp(markerNameArray)`    | コマンドウィンドウにマーカー名を表示する                      |

ここで、バットに貼付したマーカーがどの名前で保存されているかを確認します。
`top` と `bottom` 以外のバットマーカー名は、実データの `Data.Markers` のフィールド名に合わせて決めます。

- [X] コマンドウィンドウにマーカー名一覧が表示されることを確認する。
- [X] バット関連マーカーとして使うフィールド名をメモする。

---

## STEP 4：分析対象のバットマーカー名を指定する

### 書くコード

実際に表示されたマーカー名に合わせて、以下の `batMarkerNameArray` を修正します。

```matlab
% 仮の例：実際の fieldnames(Data.Markers) に合わせて修正する
batMarkerNameArray = {'top', 'bottom'} ;

% 例：もし bat1, bat2, bat3 などが存在する場合
% batMarkerNameArray = {'top', 'bottom', 'bat1', 'bat2', 'bat3'} ;

nBatMarker = length(batMarkerNameArray) ;
```

### 解説

| コード                 | 意味                                           |
| ---------------------- | ---------------------------------------------- |
| `batMarkerNameArray` | 分析対象にするバットマーカー名を並べたセル配列 |
| `nBatMarker`         | 分析対象マーカーの数                           |

この段階では、まだ正しいマーカー名が確定していない可能性があります。
まず `fieldnames(Data.Markers)` の結果を見て、実データに存在する名前だけを入れることが重要です。

- [X] `batMarkerNameArray` に実在するマーカー名だけを入れる。
- [X] `top` と `bottom` 以外に追加すべきバットマーカー名を確認する。

---

## STEP 5：全マーカーにフィルターをかける

### 書くコード

```matlab
% フィルター処理
fs = Data.FrameRate ;
fc = Prm.Fc ;
[b, a] = butter(2, fc/(fs/2)) ;
M = filt_all_fields(b, a, Data.Markers) ;
```

### 解説

| コード                   | 意味                                                      |
| ------------------------ | --------------------------------------------------------- |
| `fs = Data.FrameRate`  | マーカー座標のサンプリング周波数                          |
| `fc = Prm.Fc`          | ローパスフィルターのカットオフ周波数                      |
| `butter(2, fc/(fs/2))` | 2次バターワースフィルターの係数を作る                     |
| `filt_all_fields`      | `Data.Markers` 内の全マーカーに同じフィルターを適用する |

複数マーカーを比較する場合は、全マーカーに同じフィルター条件を使うことで、速度やピーク値を公平に比較できます。

- [X] フィルター後のマーカー構造体 `M` が作成されることを確認する。

---

## STEP 6：各バットマーカーの合成速度を計算する

### 書くコード

```matlab
% 各バットマーカーの合成速度を計算
BatMarkerVelocity = struct ;
BatMarkerPeakVelocity = struct ;

for iMarker = 1:nBatMarker
    markerName = batMarkerNameArray{iMarker} ;

    markerPosition = M.(markerName) ;
    markerVelocity = diff3p(markerPosition, 1/fs) ;
    markerNetVelocity = sum(markerVelocity.^2, 2).^0.5 ;

    BatMarkerVelocity.(markerName) = markerNetVelocity ;
    BatMarkerPeakVelocity.(markerName) = max(markerNetVelocity) ;
end
```

### 解説

| コード                                 | 意味                                       |
| -------------------------------------- | ------------------------------------------ |
| `M.(markerName)`                     | 文字列で指定したマーカーの座標を取り出す   |
| `diff3p(markerPosition, 1/fs)`       | 3次元座標を時間微分して速度成分を求める    |
| `sum(markerVelocity.^2, 2).^0.5`     | X/Y/Z速度成分から合成速度を計算する        |
| `BatMarkerVelocity.(markerName)`     | マーカーごとの速度波形を構造体に保存する   |
| `BatMarkerPeakVelocity.(markerName)` | マーカーごとのピーク速度を構造体に保存する |

`M.top` のように固定名で書くのではなく、`M.(markerName)` と書くことで、マーカー名のリストに沿って同じ処理を繰り返せます。
これが、`top` と `bottom` 以外のマーカーを分析対象に広げるときの基本形です。

- [X] `BatMarkerVelocity` に各マーカーの速度波形が保存されることを確認する。
- [X] `BatMarkerPeakVelocity` に各マーカーのピーク速度が保存されることを確認する。

---

## STEP 7：各マーカーの欠損状況を確認する

### 書くコード

```matlab
% 欠損フレーム数を確認
BatMarkerMissingFrameCount = struct ;

for iMarker = 1:nBatMarker
    markerName = batMarkerNameArray{iMarker} ;
    markerPosition = Data.Markers.(markerName) ;

    missingFrame = any(isnan(markerPosition), 2) ;
    BatMarkerMissingFrameCount.(markerName) = sum(missingFrame) ;
end

disp(BatMarkerMissingFrameCount)
```

### 解説

| コード                    | 意味                                                |
| ------------------------- | --------------------------------------------------- |
| `isnan(markerPosition)` | 座標データが欠損している場所を調べる                |
| `any(..., 2)`           | X/Y/Z のどれか1つでも欠損しているフレームを検出する |
| `sum(missingFrame)`     | 欠損フレーム数を数える                              |

単一試行解析の精度を上げるには、速度が高いかどうかだけでなく、マーカーが途中で消えていないかも重要です。
欠損が多いマーカーを基準にすると、スイング開始検出やピーク速度の推定が不安定になります。

- [X] 各バットマーカーの欠損フレーム数を確認する。
- [X] 欠損が多いマーカーを解析の主指標に使わない方針を検討する。

---

## STEP 8：速度波形を重ねて可視化する

### 書くコード

```matlab
figure(1)
clf
hold on

nFrame = length(BatMarkerVelocity.(batMarkerNameArray{1})) ;
tArray = [1:nFrame] / fs ;

for iMarker = 1:nBatMarker
    markerName = batMarkerNameArray{iMarker} ;
    plot(tArray, BatMarkerVelocity.(markerName), 'LineWidth', 1.2)
end

xlabel('Time (s)')
ylabel('Velocity (mm/s)')
legend(batMarkerNameArray, 'Interpreter', 'none')
grid on
```

### 解説

複数マーカーの速度波形を同じグラフに重ねると、以下を確認できます。

| 観点               | 確認すること                                               |
| ------------------ | ---------------------------------------------------------- |
| ピークのタイミング | どのマーカーが同じタイミングで速くなっているか             |
| ピークの大きさ     | `top` だけが極端に大きい、または小さい値になっていないか |
| ノイズ             | 特定マーカーだけ細かく振動していないか                     |
| 欠損の影響         | 欠損補間やフィルター後に不自然な波形が出ていないか         |

- [X] 全バットマーカーの速度波形が1つの図に重ねて表示されることを確認する。
- [X] `top` 以外のマーカーでもスイングらしい速度上昇が見えるか確認する。

---

## STEP 9：LED点灯を0秒にした時間軸で確認する

### 書くコード

解析結果との対応を見やすくするため、LED点灯を0秒とする時間軸でも描画します。

```matlab
led = Data.LEDData(:, 2) ;
tCueAnalog = find(abs(led) > 2, 1, 'first') ;
tCueMarker = round(tCueAnalog / Data.AnalogFs * fs) ;

if isempty(tCueAnalog)
    tArrayCue = [1:nFrame] / fs ;
else
    tArrayCue = ([1:nFrame] - tCueMarker) / fs ;
end

figure(2)
clf
hold on

for iMarker = 1:nBatMarker
    markerName = batMarkerNameArray{iMarker} ;
    plot(tArrayCue, BatMarkerVelocity.(markerName), 'LineWidth', 1.2)
end

xlabel('Time from LED onset (s)')
ylabel('Velocity (mm/s)')
legend(batMarkerNameArray, 'Interpreter', 'none')
set(gca, 'xlim', [-1, 3])
grid on
```

### 解説

既存の反応時間解析では、LED点灯時刻 `tCueMarker` を基準にしてスイング開始を評価します。
全バットマーカー追跡でも同じ基準を使うことで、`top` 以外のマーカーがLED後にどのように動き出しているかを比較できます。

- [X] LED点灯を0秒とした速度波形が表示されることを確認する。
- [X] LED後の速度立ち上がりが複数マーカーで同じ傾向を示すか確認する。

---

## STEP 10：解析結果に保存する項目を決める

### 保存候補

全バットマーカーを単一試行解析に組み込む場合、`Result` に保存する候補は以下です。

| フィールド名の候補                    | 内容                                    |
| ------------------------------------- | --------------------------------------- |
| `Result.BatMarkerNameArray`         | 解析対象にしたバットマーカー名          |
| `Result.BatMarkerPeakVelocity`      | 各マーカーのピーク速度                  |
| `Result.BatMarkerMissingFrameCount` | 各マーカーの欠損フレーム数              |
| `Result.PeakVelTop`                 | 既存互換のため残す `top` のピーク速度 |
| `Result.PeakVelBottom`              | `bottom` のピーク速度                 |

### 方針

最初から `m3_analyze_single_trial.m` を大きく変更するのではなく、まず学習用スクリプトで以下を確認します。

1. 実データに存在するバットマーカー名
2. 各マーカーの欠損フレーム数
3. 各マーカーの速度波形
4. `top` と他マーカーのピーク速度の関係
5. スイング開始検出に使う主マーカーを `top` のままにするか、複数マーカーから決めるか

- [X] `Result` に保存すべきフィールドを決める。
- [X] 既存の `PeakVelTop` を残すかどうかを確認する。
- [X] 複数試行集計で扱いやすい保存形式を検討する。

---

## 完了後の動作確認チェックリスト

* [X] `fieldnames(Data.Markers)` で、実データに含まれる全マーカー名を確認した。
* [X] `top` と `bottom` 以外のバット関連マーカー名を特定した。
* [X] 全バットマーカーに同じフィルター処理を適用した。
* [X] 各バットマーカーの合成速度を計算した。
* [X] 各バットマーカーのピーク速度を確認した。
* [X] 各バットマーカーの欠損フレーム数を確認した。
* [X] 速度波形を重ねて表示し、不自然なマーカーがないか確認した。
* [X] LED点灯を0秒とした時間軸で、各マーカーの速度立ち上がりを確認した。
* [X] `m3_analyze_single_trial.m` に反映する保存項目とフィールド名の方針を決めた。

---

## 次に検討すること

全バットマーカーを追跡できるようになったら、次は以下を検討します。

* スイング開始検出は `top` の速度だけでよいか
* 複数マーカーの平均速度や代表点を使うべきか
* 欠損がある場合に、その試行を除外するか、補間して使うか
* `PeakVelTop` 以外に、どの速度指標を条件間比較に使うか
* バットの姿勢や角速度に近い指標を作れるか
