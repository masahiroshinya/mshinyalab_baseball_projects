# 学習ワークフロー：1試行分析スクリプトを自分で書こう

## このフォルダの目的

`s4_SingleTrialAnalysisScratch` フォルダで学んだことを活かして、以下の **2つのファイル** を自分の手で書けるようになることが目標です。

| ファイル名                          | 種類       | 役割                                                                        |
| ----------------------------------- | ---------- | --------------------------------------------------------------------------- |
| `scratch4_analyze_single_trial.m` | スクリプト | 1試行分の分析内容を、手を動かして確かめるための下書き（スクラッチ）ファイル |
| `m3_analyze_single_trial.m`       | 関数       | 完成したら、全試行に繰り返し使いまわせる「部品（関数）」として整える        |

> **学習の流れ**：まず `scratch4`（スクリプト）を書いて分析の内容を確認し、うまく動いたら `m3`（関数）にまとめる。

---

## 学習済みの内容と今回の接続

`s4_SingleTrialAnalysisScratch/s401` で学んだことは、今回そのまま使います。

| 学習済みの内容                                 | 今回どこで使うか                    |
| ---------------------------------------------- | ----------------------------------- |
| バターワースローパスフィルターの仕組み         | `scratch4` のフィルター処理パート |
| `butter()` と `filt_all_fields()` の使い方 | `scratch4` のコード（Step 4）     |

---

## 全体の処理の流れ（まず読んで頭に入れよう）

`scratch4_analyze_single_trial.m` がやることは、大きく分けて以下の5つです。

```
[1] 設定   → 何番の被験者・条件・試行を分析するかを決める
[2] データ読み込み → x3_DataChecked フォルダからデータを取得する
[3] フィルター処理 → マーカーデータのノイズを除去する（s401 で学んだ）
[4] 指標の計算 → バット先端の最大速度・LEDタイミングを求める
[5] 描画    → 結果をグラフで確認する
```

---

## STEP 1：自分のファイルを準備する

### やること

`s4_学習用_SingleTrialAnalysisScratch` フォルダの中にある以下の **学習用ファイル** に、自分でコードを書いていきます。

- `s4_forstudy_scratch4_analyze_single_trial.m`
- `s4_forstudy_m3_analyze_single_trial.m`

> これらは、あなたが自由に書いて・消して・実験するための練習帳です。
> 本番のファイル（`scratch4_analyze_single_trial.m` など）は別フォルダにあるので、壊す心配はありません。

### 作業前の確認

- [X] MATLABのカレントフォルダを `Preliminary experiments/2026-05-13/MATLAB/` に設定する
  （`x3_DataChecked/` フォルダへのパスが通るようにするため）

---

## STEP 2：`scratch4` を書く ― [1] 初期設定

### 書くコード

`s4_forstudy_scratch4_analyze_single_trial.m` の先頭に、以下を書いてください。

```matlab
clear
close all
clc

iSubject   = 1 ;
iCondition = 1 ;
iTrial     = 1 ;

ConditionNameArray = {'free', 'simple', 'gonogo'} ;
nCondition = length(ConditionNameArray) ;
```

### 各行の説明

| コード                       | 意味                                                                                             |
| ---------------------------- | ------------------------------------------------------------------------------------------------ |
| `clear`                    | ワークスペース（変数置き場）を空にする。前回の実行結果が残っていると混乱するため、必ず先頭に書く |
| `close all`                | 開いているグラフウィンドウをすべて閉じる                                                         |
| `clc`                      | コマンドウィンドウの表示を消す                                                                   |
| `iSubject = 1`             | 「1番目の被験者のデータを使う」という意味。`i` は index（番号）の略                            |
| `iCondition = 1`           | 「1番目の条件（free）を使う」                                                                    |
| `iTrial = 1`               | 「1試行目を使う」                                                                                |
| `ConditionNameArray = ...` | 条件名を文字列として並べたリスト（cell配列）                                                     |
| `nCondition = length(...)` | 条件の数を自動で数える（= 3）                                                                    |

### 確認ポイント

- [X] コードを書いて実行し、エラーが出ないことを確認する
- [X] `whos` コマンドを実行して、`iSubject`, `iCondition`, `iTrial` が正しく作成されているか確認する

---

## STEP 3：`scratch4` を書く ― [2] データの読み込み

### 書くコード

STEP 2 の続きに追加してください。

```matlab
dataFilePath = sprintf('x3_DataChecked/Data%02d', iSubject) ;
load(dataFilePath)

Data = DataArray(iTrial, iCondition) ;

Prm = parameters ;
```

### 各行の説明

| コード                            | 意味                                                                                                            |
| --------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `sprintf('...', iSubject)`      | 文字列を作る関数。`%02d` の部分に `iSubject`（= 1）が入り、`'x3_DataChecked/Data01'` という文字列ができる |
| `load(dataFilePath)`            | そのパスの `.mat` ファイルを読み込む。読み込むと `DataArray` という変数がワークスペースに現れる             |
| `DataArray(iTrial, iCondition)` | 2次元の配列から「1試行目・1条件目」のデータを取り出す                                                           |
| `Prm = parameters`              | `parameters.m` という関数を呼んで、分析パラメータ（カットオフ周波数など）を取得する                           |

### 確認ポイント

- [X] 実行後、コマンドウィンドウで `whos` を実行し、`DataArray` と `Data` が現れているか確認する
- [X] `Data` をクリックして中身を見てみよう（`Markers`, `FrameRate`, `LEDData` などのフィールドがある）
- [X] `Prm.Fc` の値が `30` になっていることを確認する（カットオフ周波数 30 Hz）

---

## STEP 4：`scratch4` を書く ― [3] フィルター処理

> s401 で学んだ内容がここで登場します！

### 書くコード

```matlab
% filter
fs = Data.FrameRate ;
fc = Prm.Fc ;
[b,a] = butter(2, fc/(fs/2)) ;
M = filt_all_fields(b,a,Data.Markers) ;
```

### 各行の説明

| コード                                | 意味                                                                                                           |
| ------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `fs = Data.FrameRate`               | サンプリング周波数（1秒間のフレーム数）をデータから取得する                                                    |
| `fc = Prm.Fc`                       | カットオフ周波数（= 30 Hz）。`parameters.m` で設定した値                                                     |
| `butter(2, fc/(fs/2))`              | 2次のバターワースフィルターの係数 `b`, `a` を設計する。`fc/(fs/2)` は「ナイキスト周波数で正規化した fc」 |
| `filt_all_fields(b,a,Data.Markers)` | `Markers` 構造体の全マーカーに一括でフィルターをかける（独自関数）。結果は `M` に入る                      |

### 確認ポイント

- [X] `M` を確認し、`M.top`（バット先端マーカー）などのフィールドがあることを確認する
- [X] `size(M.top)` を実行して、`n × 3` の行列になっていることを確認する（n = フレーム数、3 = xyz）

---

## STEP 5：`scratch4` を書く ― [4-a] バット速度の計算

### 書くコード

```matlab
% velocity of 'top'
top = M.top ;
velTop = diff3p(top, 1/fs) ;
netVelTop = sum(velTop.^2,2).^0.5 ;

peakVelTop = max(netVelTop) ;

Result.PeakVelTop = peakVelTop ;
```

### 各行の説明

| コード                      | 意味                                                                                |
| --------------------------- | ----------------------------------------------------------------------------------- |
| `top = M.top`             | バット先端マーカーの xyz 座標（`n×3` の行列）を取り出す                          |
| `diff3p(top, 1/fs)`       | 3点中心差分法（diff 3-point）で速度を計算する関数。`1/fs` はサンプリング間隔 [秒] |
| `velTop.^2`               | 速度の各成分（Vx, Vy, Vz）を2乗する。`.^2` は「各要素を2乗」の意味                |
| `sum(...,2)`              | 各行方向（=各フレーム）で合計する。`Vx² + Vy² + Vz²` になる                    |
| `.^0.5`                   | 平方根をとる。合成速度 = √(Vx² + Vy² + Vz²)                                     |
| `max(netVelTop)`          | 全フレームの合成速度の最大値（ピーク速度）を求める                                  |
| `Result.PeakVelTop = ...` | 構造体 `Result` にピーク速度を格納する                                            |

### 補足：`diff3p` とは？

速度は「位置の変化 ÷ 時間の変化」で求められます。
3点中心差分法（3-point central difference）は、直前・直後のフレームを使って計算することで、精度を高めた数値微分の方法です。

```
速度[i] ≈ (位置[i+1] - 位置[i-1]) / (2 × Δt)
```

### 確認ポイント

- [X] `netVelTop` を `plot(netVelTop)` で描画し、速度の時系列が確認できるか見てみよう
- [X] `peakVelTop` の値を確認する（単位は mm/s）
- [X] `Result` 構造体に `PeakVelTop` フィールドができているか確認する

---

## STEP 6：`scratch4` を書く ― [4-b] LED タイミングの検出

### 書くコード

```matlab
% LED timing
led = Data.LEDData(:,2) ;
tCueAnalog = find(abs(led) > 2, 1, 'first') ;
tCueMarker = round(tCueAnalog / Data.AnalogFs * fs) ;

if isempty(tCueAnalog)
    errorCode = Prm.ErrorCode.LEDTimingNotDetected ;
    errorText  = Prm.ErrorText.LEDTimingNotDetected ;
else
    if led(tCueAnalog) > 0
        cueCode = 1 ;
        cueText = 'Go' ;
    elseif led(tCueAnalog) < 0
        cueCode = 2 ;
        cueText = 'NoGo' ;
    end
end
```

### 各行の説明

| コード                              | 意味                                                                                                      |
| ----------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `Data.LEDData(:,2)`               | アナログデータの2列目（LED の信号チャンネル）を取り出す                                                   |
| `find(abs(led) > 2, 1, 'first')`  | `abs(led) > 2`（絶対値が2を超える）が最初に真になるインデックスを探す。これが「LED が光ったタイミング」 |
| `tCueAnalog / Data.AnalogFs * fs` | アナログサンプルのインデックスを、マーカーのフレームインデックスに変換する                                |
| `round(...)`                      | 小数点以下を四捨五入して、整数のフレーム番号にする                                                        |
| `isempty(tCueAnalog)`             | `find` が何も見つからなかった（LED が点灯しなかった）場合のエラー処理                                   |
| `led(tCueAnalog) > 0`             | 正の値 → Go 刺激、負の値 → NoGo 刺激 と判定する                                                         |

### 確認ポイント

- [X] `tCueAnalog`、`tCueMarker` の値を確認する（何フレーム目か）
- [X] `cueText` が `'Go'` または `'NoGo'` になっているか確認する
- [X] `plot(led)` で LED 信号を描画し、`tCueAnalog` の位置に電圧の変化が見えるか確認する

---

## STEP 7：`scratch4` を書く ― [5] 描画

### 書くコード

```matlab
% figure
figure(2)
plotTimeRange = [-1, 3] ;

subplot(3,1,[1:2]) ;
n = length(top) ;
tArray = ([1:n] - tCueMarker) / fs ;
plot(tArray, netVelTop)
set(gca, 'xlim', plotTimeRange) ;

subplot(3,1,3) ;
nAnalog = length(Data.LEDData) ;
tArrayAnalog = ([1:nAnalog] - tCueAnalog) / Data.AnalogFs ;
plot(tArrayAnalog, Data.LEDData)
set(gca, 'xlim', plotTimeRange) ;

% stick picture
figure(1)
plot3(M.top(:,1), M.top(:,2), M.top(:,3), 'k-') ; hold on
set(gca, 'xlim', [-1000,2000], 'ylim', [-1000,1000], 'zlim', [0,3000])
grid on

iFrame = 1 ;
h1 = draw_stick_picture(M, {'top', 'bottom'}, iFrame, 'xyz', '-o') ;
```

### 各グラフの説明

**Figure 2（速度と LED 信号）**

| subplot | 内容                                                                     |
| ------- | ------------------------------------------------------------------------ |
| 上2段   | バット先端の合成速度の時系列。横軸はキュー（LED 点灯）からの経過時間 [s] |
| 下1段   | LED 信号の時系列。電圧が変化した位置がキュータイミング                   |

| コード                        | 意味                                               |
| ----------------------------- | -------------------------------------------------- |
| `subplot(3,1,[1:2])`        | 3行1列のグラフの「1〜2行目」を使う                 |
| `([1:n] - tCueMarker) / fs` | フレーム番号をキューからの相対時間 [s] に変換する  |
| `set(gca, 'xlim', ...)`     | x 軸の表示範囲を設定する。`gca` = 現在のグラフ軸 |

**Figure 1（スティックピクチャー）**

| コード                      | 意味                                                     |
| --------------------------- | -------------------------------------------------------- |
| `plot3(...)`              | 3D グラフにバット先端の軌跡を描く                        |
| `draw_stick_picture(...)` | 指定したフレームのスティックピクチャーを描く（独自関数） |

### 確認ポイント

- [X] Figure 2 を見て、速度が盛り上がる部分が「キュー後（t > 0）」にあるか確認する
- [X] Figure 2 の下段で、t = 0 付近に LED 信号の変化が見えるか確認する
- [X] Figure 1 で、バット先端の軌跡がきれいに描かれているか確認する

---

## STEP 8：`scratch4` の完成確認

### 動作確認のチェックリスト

- [X] スクリプト全体をはじめから最後まで実行してエラーが出ないことを確認する
- [X] `Result.PeakVelTop` の値が存在することを確認する
- [X] Figure 1・Figure 2 が正しく表示されることを確認する
- [X] `cueText` が `'Go'` または `'NoGo'` になっていることを確認する

> 以上が全部 OK なら、`scratch4` は完成です！
> 本番の `scratch4_analyze_single_trial.m` と見比べて、内容が一致しているか確認してみましょう。

---

## STEP 9：`m3` を書く ― 関数とは何か？

### スクリプトと関数の違い

|                  | スクリプト（`.m`）                | 関数（`.m`）                                              |
| ---------------- | ----------------------------------- | ----------------------------------------------------------- |
| 実行方法         | ファイル名をコマンドに打つだけ      | `Result = m3_analyze_single_trial(Data)` のように呼び出す |
| データのやり取り | ワークスペースを通じて行う          | 引数（入力）と戻り値（出力）で行う                          |
| 使いまわし       | 1試行ごとに手で書き換える必要がある | データを変えて何度でも呼び出せる                            |

### `m3` の入力と出力

```matlab
function Result = m3_analyze_single_trial(Data)
%   入力:  Data   → 1試行分のデータ構造体
%   出力:  Result → 分析結果をまとめた構造体
end
```

---

## STEP 10：`m3` を書く ― `scratch4` から必要な部分を抽出する

### どの部分を `m3` に入れるか？

`scratch4` の中から「**データを受け取って計算する部分**」だけを `m3` に入れます。
「どの試行か」を決める部分や、描画の部分は関数に入れません。

| 処理                                              | `m3` に入れる？     | 理由                                                            |
| ------------------------------------------------- | --------------------- | --------------------------------------------------------------- |
| `clear`, `close all`, `clc`                 | ❌ 入れない           | 関数の中で `clear` を使うと呼び出し元の変数が消えてしまうため |
| `iSubject = 1` などの設定                       | ❌ 入れない           | 「どの試行か」は関数の外（呼び出し側）で決める                  |
| `load(...)`, `DataArray(...)`                 | ❌ 入れない           | データの読み込みも呼び出し側の仕事                              |
| `Prm = parameters`                              | ✅ 入れる             | 分析パラメータの取得は関数内の処理                              |
| フィルター処理（`butter`, `filt_all_fields`） | ✅ 入れる             | データの加工は関数の仕事                                        |
| バット速度の計算                                  | ✅ 入れる             | 分析指標の計算は関数の仕事                                      |
| LED タイミングの検出                              | ✅ 入れる             | 分析指標の計算は関数の仕事                                      |
| `figure(...)` など描画                          | ❌ 入れない（今回は） | 描画は呼び出し側で行う（関数は計算に集中する）                  |
| `Result.PeakVelTop = ...`                       | ✅ 入れる             | 結果の格納は関数の仕事                                          |

### 書くコード（`s4_forstudy_m3_analyze_single_trial.m`）

```matlab
function Result = m3_analyze_single_trial(Data)

Prm = parameters ;

% filter
fs = Data.FrameRate ;
fc = Prm.Fc ;
[b,a] = butter(2, fc/(fs/2)) ;
M = filt_all_fields(b,a,Data.Markers) ;

% velocity of 'top'
top = M.top ;
velTop = diff3p(top, 1/fs) ;
netVelTop = sum(velTop.^2,2).^0.5 ;

peakVelTop = max(netVelTop) ;

Result.PeakVelTop = peakVelTop ;

% LED timing
led = Data.LEDData(:,2) ;
tCueAnalog = find(abs(led) > 2, 1, 'first') ;
tCueMarker = round(tCueAnalog / Data.AnalogFs * fs) ;

if isempty(tCueAnalog)
    errorCode = Prm.ErrorCode.LEDTimingNotDetected ;
    errorText  = Prm.ErrorText.LEDTimingNotDetected ;
else
    if led(tCueAnalog) > 0
        cueCode = 1 ;
        cueText = 'Go' ;
    elseif led(tCueAnalog) < 0
        cueCode = 2 ;
        cueText = 'NoGo' ;
    end
end

end
```

---

## STEP 11：`m3` の動作確認

### コマンドウィンドウで試す

```matlab
% (1) データを読み込む
load('x3_DataChecked/Data01')

% (2) 1試行目・1条件目のデータを取り出す
Data = DataArray(1, 1) ;

% (3) 関数を呼び出す
Result = m3_analyze_single_trial(Data)
```

### 確認ポイント

- [X] `Result` 構造体が返ってきているか確認する
- [X] `Result.PeakVelTop` の値が、`scratch4` で確認した `peakVelTop` と一致しているか確認する

> **一致していれば、関数が正しく動いています！**

---

## 全体の振り返りチェックリスト

- [X] STEP 1：ファイルを準備した
- [X] STEP 2：初期設定のコードを書いた
- [X] STEP 3：データ読み込みのコードを書いて、`DataArray` が読み込めることを確認した
- [X] STEP 4：フィルター処理のコードを書いた（s401 の復習）
- [X] STEP 5：バット速度の計算コードを書いて、ピーク速度が得られることを確認した
- [X] STEP 6：LED タイミングの検出コードを書いて、`cueText` が得られることを確認した
- [X] STEP 7：描画コードを書いて、グラフが表示されることを確認した
- [X] STEP 8：`scratch4` 全体を通して実行してエラーなしに完了した
- [X] STEP 9：スクリプトと関数の違いを理解した
- [X] STEP 10：`m3` のコードを書いた
- [X] STEP 11：`m3` を呼び出してテストし、`scratch4` と同じ結果が得られることを確認した

---

## 困ったときのヒント

### エラーが出たら

1. エラーメッセージを読む（英語でも、どのファイルの何行目でエラーが出たかが分かる）
2. エラーが出た行を確認する
3. AIアシスタントにエラーメッセージを貼り付けて質問する

### 変数の中身を確認したいときは

```matlab
% コマンドウィンドウで変数名を打つ（セミコロンなし）
Data
M.top
Result
```

### コードの意味が分からないときは

```matlab
% help コマンドで関数の説明を読む
help butter
help find
help sprintf
```

---

*作成日: 2026-05-26*
