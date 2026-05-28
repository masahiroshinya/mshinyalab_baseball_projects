# 学習ワークフロー：反応時間（RT）を算出しよう

## このフォルダの目的

前回（s4_学習用）で作った分析スクリプトに、**反応時間の算出機能**を追加することが目標です。
あわせて、既存コードに潜む **バグ** を自分で発見・修正する練習も行います。

| ファイル名                                | 種類       | 役割                                                  |
| ----------------------------------------- | ---------- | ----------------------------------------------------- |
| `s5_forstudy_scratch5.m`                | スクリプト | 反応時間の算出内容を1試行で手を動かして確かめる練習帳 |
| `s5_forstudy_m3_analyze_single_trial.m` | 関数       | バグ修正 + 新機能を盛り込んだ関数を自分で書く         |

> **学習の流れ**：まず `scratch5`（スクリプト）でコードを試し、うまく動いたら `s5_forstudy_m3`（関数）にまとめる。最後に本番の `m3_analyze_single_trial.m` に反映する。

---

## 今回追加する機能と修正するバグの全体像

```
m3_analyze_single_trial(Data)  の現状と修正内容

  ✅ すでに動いている部分
      フィルタリング
      バット先端の速度・ピーク速度の計算
      LED 点灯タイミングの検出（tCueMarker, cueCode, cueText）

  🐛 バグ（修正が必要）
      ① cueCode, cueText が Result に保存されていない
      ② errortext という変数名のスペルミス（T が小文字）

  ➕ 新しく追加する機能
      ③ スイング開始タイミングの検出（tSwingOnset）
      ④ 反応時間の算出（RT [ms]）
      ⑤ 描画に縦線を追加（視覚的な確認）
```

---

## 全体の処理の流れ

```
[1] 設定           → 被験者・条件・試行番号を決める
[2] データ読み込み  → x3_DataChecked からデータを取得
[3] フィルター処理  → マーカーデータのノイズを除去（前回の復習）
[4] 速度の計算      → バット先端の合成速度 netVelTop を求める
[5] LED タイミング  → LED が光ったフレームを検出（前回の復習）
[6] バグ修正        → cueCode/cueText を Result に保存する
[7] スイング開始検出 → 速度が閾値を超えた最初のフレームを探す
[8] 反応時間の算出  → RT = (スイング開始 - LED 点灯) / fs × 1000 [ms]
[9] 描画の更新      → グラフにスイング開始の縦線を追加する
```

---

## STEP 1：ファイルの準備とカレントフォルダの設定

### やること

`s5_学習用_反応時間算出/` フォルダにある以下のファイルに、コードを書き足していきます。

- `s5_forstudy_scratch5.m`
- `s5_forstudy_m3_analyze_single_trial.m`

### 作業前の必須設定

MATLABのカレントフォルダを **`Preliminary experiments/2026-05-13/MATLAB/`** に設定すること。

さらに、このフォルダ（`s5_学習用_反応時間算出/`）をパスに追加すること。

```matlab
% コマンドウィンドウで実行する
addpath('s5_学習用_反応時間算出')
```

> `x3_DataChecked/` フォルダへのパスが通るようにするため、カレントフォルダは必ず `MATLAB/` にすること。

### 確認ポイント

- [X] MATLABのカレントフォルダが `MATLAB/` になっていることを確認する
- [X] `s5_forstudy_scratch5.m` がエディターで開けることを確認する

---

## STEP 2：前回のコードを引き継ぐ

前回（s4）で完成させたコードをベースに進めます。
`s5_forstudy_scratch5.m` に、以下のコードをそのまま書いてください。

```matlab
clear
close all
clc

iSubject   = 1 ;
iCondition = 1 ;
iTrial     = 1 ;

ConditionNameArray = {'free', 'simple', 'gonogo'} ;
nCondition = length(ConditionNameArray) ;

dataFilePath = sprintf('x3_DataChecked/Data%02d', iSubject) ;
load(dataFilePath)

Data = DataArray(iTrial, iCondition) ;

Prm = parameters ;

% filter
fs = Data.FrameRate ;
fc = Prm.Fc ;
[b, a] = butter(2, fc/(fs/2)) ;
M = filt_all_fields(b, a, Data.Markers) ;

% velocity of 'top'
top = M.top ;
velTop = diff3p(top, 1/fs) ;
netVelTop = sum(velTop.^2, 2).^0.5 ;

peakVelTop = max(netVelTop) ;
Result.PeakVelTop = peakVelTop ;

% LED timing
led = Data.LEDData(:,2) ;
tCueAnalog = find(abs(led) > 2, 1, 'first') ;
tCueMarker = round(tCueAnalog / Data.AnalogFs * fs) ;

if isempty(tCueAnalog)
    errorCode = Prm.ErrorCode.LEDTimingNotDetected ;
    errortext = Prm.ErrorText.LEDTimingNotDetected ;
else
    if led(tCueAnalog) > 0
        cueCode = 1 ;
        cueText = 'Go' ;
    elseif led(tCueAnalog) < 0
        cueCode = 2 ;
        cueText = 'NoGo' ;
    end
end

% figure
figure(2)
plotTimeRange = [-1, 3] ;

subplot(3,1,[1:2]) ;
n = length(top) ;
tArray = ([1:n] - tCueMarker) / fs ;
plot(tArray, netVelTop)
set(gca, 'xlim', plotTimeRange) ;
xlabel('Time from LED [s]')
ylabel('Bat tip speed [mm/s]')

subplot(3,1,3) ;
nAnalog = length(Data.LEDData) ;
tArrayAnalog = ([1:nAnalog] - tCueAnalog) / Data.AnalogFs ;
plot(tArrayAnalog, Data.LEDData)
set(gca, 'xlim', plotTimeRange) ;
xlabel('Time from LED [s]')
ylabel('LED signal [V]')
```

### 確認ポイント

- [X] 実行してエラーが出ないことを確認する
- [X] Figure 2 が表示され、速度（上）と LED 信号（下）のグラフが見えることを確認する
- [X] `cueText` の値をコマンドウィンドウで確認する（`'Go'` または `'NoGo'`）

---

## STEP 3：バグを発見しよう

コードが動くことを確認したら、**問題点を探します**。

### 課題

コマンドウィンドウで次を実行し、`Result` の中身を確認してください。

```matlab
Result
```

### 問いかけ

- `Result` の中には何が入っていますか？
- `cueCode`（Go か NoGo か）は `Result` に入っていますか？

### 確認ポイント

- [X] `Result` には `PeakVelTop` だけが入っており、`cueCode` や `cueText` がないことを確認する

> **これがバグです。** `cueCode` と `cueText` は計算されているのに、`Result` に格納するコードが抜けています。
> また、LED が検出されなかった場合のコードに `errortext`（小文字の t）というスペルミスがあります（正しくは `errorText`）。

---

## STEP 4：バグを修正する（cueCode と cueText を Result に保存する）

### バグ修正の考え方

`if isempty(tCueAnalog)` の分岐の中を見直します。

**修正前のコード（現状）:**

```matlab
if isempty(tCueAnalog)
    errorCode = Prm.ErrorCode.LEDTimingNotDetected ;
    errortext = Prm.ErrorText.LEDTimingNotDetected ;   % ← スペルミス（T が小文字）
else
    if led(tCueAnalog) > 0
        cueCode = 1 ;
        cueText = 'Go' ;
    elseif led(tCueAnalog) < 0
        cueCode = 2 ;
        cueText = 'NoGo' ;
    end
    % ← ここに cueCode を Result に保存するコードが必要なのに、ない！
end
```

**修正後のコード（以下に書き換える）:**

```matlab
if isempty(tCueAnalog)
    errorCode = Prm.ErrorCode.LEDTimingNotDetected ;
    errorText = Prm.ErrorText.LEDTimingNotDetected ;   % ← 修正① T を大文字に
    Result.CueCode    = NaN ;
    Result.CueText    = '' ;
    Result.TCueMarker = NaN ;
else
    if led(tCueAnalog) > 0
        cueCode = 1 ;
        cueText = 'Go' ;
    elseif led(tCueAnalog) < 0
        cueCode = 2 ;
        cueText = 'NoGo' ;
    end
    % ← 修正② cueCode / cueText を Result に保存する
    Result.CueCode    = cueCode ;
    Result.CueText    = cueText ;
    Result.TCueMarker = tCueMarker ;
end
```

### 各行の説明

| コード                       | 意味                                                                    |
| ---------------------------- | ----------------------------------------------------------------------- |
| `Result.CueCode = cueCode` | Go(1) か NoGo(2) かを Result に格納する                                 |
| `Result.CueText = cueText` | `'Go'` または `'NoGo'` という文字列を格納する                       |
| `Result.TCueMarker = ...`  | LED が光ったフレーム番号を格納する（後で RT 計算に使う）                |
| `Result.CueCode = NaN`     | LED が検出できなかった試行では、数値ではなく「欠損値（NaN）」を代入する |

> **NaN（Not a Number）とは？**
> 「値がない（欠損）」ことを表す特別な数値です。0 と違い、「計算できなかった・データが無効」であることを明示できます。

### 確認ポイント

- [X] コードを修正して再実行し、`Result` に `CueCode`・`CueText`・`TCueMarker` が含まれることを確認する
- [X] `Result.CueText` が `'Go'` または `'NoGo'` になっていることを確認する

---

## STEP 5：スイング開始検出の原理をグラフで理解する

### スイング開始とは？

バットスイングの「開始」を、コンピューターはどうやって判断するのでしょうか？

最もシンプルな方法は **「速度が閾値を超えた瞬間」** をスイング開始とみなす方法です。

```
バット先端速度 netVelTop のイメージ

速度
│                                  ▲ ピーク速度 (peakVelTop)
│                           ●●●●●●
│                       ●●●
│         閾値 ─── ●
│    ────────── ●
│                 ↑
│           ここが「スイング開始フレーム」= tSwingOnset
│     ↑
│  LED 点灯 (tCueMarker)
0──────────────────────────── フレーム
```

### グラフで確認してみよう

コマンドウィンドウで次を実行して、速度の時系列を確認してください。

```matlab
figure(3)
plot(tArray, netVelTop)
set(gca, 'xlim', plotTimeRange)
xlabel('Time from LED [s]')
ylabel('Bat tip speed [mm/s]')
title('バット先端の合成速度')
```

グラフを見て、以下を確認してください。

### 確認ポイント

- [X] 速度が上がり始める（スイングが始まる）のは LED 点灯後（t > 0）であることを確認する
- [X] 速度が最初にゆっくり上がり始め、その後急激に増加することを確認する（「スイング開始」の判断が難しい理由）
- [X] `peakVelTop` の値をコマンドウィンドウで確認する

---

## STEP 6：閾値を設定する

速度が「どの値」を超えたらスイング開始とみなすか、**閾値（threshold）** を決めます。

### 閾値の設定方法

今回は「ピーク速度の 5%」を閾値とします。

```matlab
threshold = 0.05 * peakVelTop ;
```

### 各部分の意味

| コード部分     | 意味                                             |
| -------------- | ------------------------------------------------ |
| `threshold`  | 「閾値」を入れる変数の名前（英語で「しきい値」） |
| `0.05`       | 5% を小数で表した数。5 ÷ 100 = 0.05             |
| `*`          | 掛け算（乗算）の記号                             |
| `peakVelTop` | STEP 5 で求めたバット先端のピーク速度            |

**計算の流れ（具体例）：**

```
peakVelTop が 25000 mm/s だった場合

threshold = 0.05 × 25000
          = 1250 mm/s

→ 速度が 1250 mm/s を超えた瞬間を「スイング開始」とみなす
```

### なぜ「ピーク速度の 5%」なのか？

| 方法                         | 問題点                                                                     |
| ---------------------------- | -------------------------------------------------------------------------- |
| 固定値（例: 100 mm/s）にする | 被験者によってスイング速度が違うので、速い人には低すぎ・遅い人には高すぎる |
| ピーク速度の一定割合にする   | 被験者ごとに自動的にスケールが調整されるので、公平に比較できる             |

> **5% という値の根拠**：バイオメカニクス研究では 5〜10% がよく使われます。今回は 5% でスタートします。

### コードを書こう

`s5_forstudy_scratch5.m` に、以下を追加してください。

```matlab
% スイング開始検出の閾値（ピーク速度の 5%）
threshold = 0.05 * peakVelTop ;

fprintf('peakVelTop = %.1f mm/s\n', peakVelTop) ;
fprintf('threshold  = %.1f mm/s\n', threshold) ;
```

### fprintf とは？

`fprintf` は「コマンドウィンドウに文字と数値を整形して表示する」関数です。

```matlab
fprintf('peakVelTop = %.1f mm/s\n', peakVelTop) ;
```

この1行を分解すると：

| 部分                | 意味                                                                          |
| ------------------- | ----------------------------------------------------------------------------- |
| `fprintf`         | 「書式付き出力（formatted print）」の略。コマンドウィンドウへ表示する         |
| `'peakVelTop = '` | そのまま表示する文字列（シングルクォートで囲む）                              |
| `%.1f`            | 数値の表示形式。`%` が「ここに数値を入れる」印。`.1f` は「小数点以下1桁」 |
| `' mm/s'`         | 単位を文字として表示                                                          |
| `\n`              | 改行（next line）。これがないと次の表示が同じ行に続く                         |
| `, peakVelTop`    | `%.1f` の位置に入れる実際の数値。変数名をカンマのあとに書く                 |

**`%.1f` の読み方：**

```
% . 1 f
│   │ └── float（小数）を表示する
│   └──── 小数点以下の桁数（1桁）
└──────── 「ここに数値を入れる」というマーク
```

**表示形式の例：**

| 書式     | 数値 25947.3 の表示結果 | 説明           |
| -------- | ----------------------- | -------------- |
| `%.1f` | `25947.3`             | 小数点以下1桁  |
| `%.0f` | `25947`               | 小数点以下なし |
| `%d`   | `25947`               | 整数として表示 |
| `%.3f` | `25947.300`           | 小数点以下3桁  |

**`\n` がない場合との比較：**

```matlab
% \n あり（2行になる）
fprintf('peakVelTop = %.1f mm/s\n', peakVelTop) ;
fprintf('threshold  = %.1f mm/s\n', threshold) ;
% → コマンドウィンドウの表示:
%   peakVelTop = 25947.3 mm/s
%   threshold  = 1297.4 mm/s

% \n なし（1行になってしまう）
fprintf('peakVelTop = %.1f mm/s', peakVelTop) ;
fprintf('threshold  = %.1f mm/s', threshold) ;
% → コマンドウィンドウの表示:
%   peakVelTop = 25947.3 mm/sthreshold  = 1297.4 mm/s  ← くっついてしまう
```

### なぜ fprintf を使うのか？

コマンドウィンドウに数値を表示する方法は複数あります。

| 方法                             | 表示例                        | 特徴                         |
| -------------------------------- | ----------------------------- | ---------------------------- |
| `peakVelTop`（セミコロンなし） | `peakVelTop = 2.5947e+04`   | 科学表記で見づらい場合がある |
| `disp(peakVelTop)`             | `2.5947e+04`                | 変数名が表示されない         |
| `fprintf('...')`               | `peakVelTop = 25947.3 mm/s` | 単位や説明も一緒に表示できる |

`fprintf` を使うと、**数値に単位や説明をつけて**、自分でわかりやすい形式で表示できます。

### 確認ポイント

- [X] コードを実行して、コマンドウィンドウに `peakVelTop = ○○○ mm/s` と `threshold = ○○○ mm/s` が表示されることを確認する
- [X] `threshold` の値が `peakVelTop` のおよそ 5% になっていることを確認する
  - 例：`peakVelTop = 25947.3 mm/s` → `threshold = 1297.4 mm/s`（= 25947.3 × 0.05）

---

## STEP 7：find でスイング開始フレームを探す

### 使う関数：find

`find` は、配列の中から「条件を満たす要素の番号（インデックス）」を探す関数です。

```matlab
% 基本的な使い方
find(条件)               % 条件を満たす全インデックスを返す
find(条件, 1, 'first')  % 最初に条件を満たすインデックスだけを返す
```

**具体例（数値で理解しよう）：**

```matlab
v = [2, 5, 8, 3, 9, 1] ;
find(v > 4)             % → [2, 3, 5]   （5, 8, 9 の位置）
find(v > 4, 1, 'first') % → 2           （最初に 4 を超えたのは 2番目の 5）
```

### スイング開始フレームの探し方

**重要なポイント**：スイング開始は「LED 点灯後」にしか起きません。
そのため、LED 点灯フレーム（`tCueMarker`）より前は探す必要がありません。

```matlab
% LED 点灯以降のフレーム番号の範囲を作る
n = length(netVelTop) ;
searchRange = tCueMarker : n ;
```

> **`searchRange` とは？**
> `tCueMarker` フレームから最後のフレームまでの連続した番号のリストです。
> 例：`tCueMarker = 500`、`n = 1000` なら、`searchRange = [500, 501, 502, ..., 1000]`

```matlab
% searchRange の範囲内で、閾値を超える最初のフレームを探す
idxAboveThreshold = find(netVelTop(searchRange) > threshold, 1, 'first') ;
```

> **注意**：`netVelTop(searchRange)` は「`searchRange` の範囲だけ抜き出した配列」です。
> この中での番号（インデックス）は「1から始まる部分的な番号」になっています。
> 元の配列での番号（フレーム番号）に戻すには、次の計算が必要です。

```matlab
% 部分的な番号 → 元のフレーム番号 に変換する
tSwingOnset = searchRange(1) + idxAboveThreshold - 1 ;
```

**なぜ -1 が必要か？（具体例）**

```
searchRange = [500, 501, 502, ..., 1000]

もし netVelTop(searchRange) の中で
  2番目（idxAboveThreshold = 2）が閾値を超えたとする。

2番目 = searchRange(2) = 501

計算式：searchRange(1) + idxAboveThreshold - 1
      = 500            + 2                 - 1
      = 501   ✅ 正しい元のフレーム番号が得られる
```

### コードを書こう

```matlab
n = length(netVelTop) ;
searchRange = tCueMarker : n ;

idxAboveThreshold = find(netVelTop(searchRange) > threshold, 1, 'first') ;

if isempty(idxAboveThreshold)
    % 閾値を超えなかった（NoGo で正解、またはデータ異常）
    tSwingOnset = NaN ;
    fprintf('スイング開始が検出されませんでした\n') ;
else
    tSwingOnset = searchRange(1) + idxAboveThreshold - 1 ;
    fprintf('tSwingOnset = %d フレーム目\n', tSwingOnset) ;
end
```

### 確認ポイント

- [X] `tSwingOnset` の値が表示されることを確認する
- [X] `tSwingOnset > tCueMarker` であることを確認する（スイング開始は LED 点灯後のはず）
- [X] `netVelTop(tSwingOnset)` の値が `threshold` に近いことを確認する

---

## STEP 8：反応時間を算出する

### 反応時間（RT）の定義

```
反応時間 [ms] = スイング開始フレーム − LED 点灯フレーム
                              ÷ サンプリング周波数 fs
                              × 1000（秒→ミリ秒に変換）
```

$$
RT [\text{ms}] = \frac{t_{\text{SwingOnset}} - t_{\text{CueMarker}}}{f_s} \times 1000
$$

### コードを書こう

```matlab
if isnan(tSwingOnset)
    RT = NaN ;
    fprintf('RT は算出できませんでした（スイング未検出）\n') ;
else
    RT = (tSwingOnset - tCueMarker) / fs * 1000 ;
    fprintf('RT = %.1f ms\n', RT) ;
end

Result.SwingOnset = tSwingOnset ;
Result.RT         = RT ;
```

### 各行の説明

| コード                       | 意味                                                              |
| ---------------------------- | ----------------------------------------------------------------- |
| `tSwingOnset - tCueMarker` | スイング開始と LED 点灯の「フレーム数の差」を求める               |
| `/ fs`                     | フレーム数の差 ÷ サンプリング周波数 = 時間差 [秒] に変換         |
| `* 1000`                   | 秒 → ミリ秒に変換（1 秒 = 1000 ミリ秒）                          |
| `isnan(tSwingOnset)`       | `tSwingOnset` が NaN かどうかを判定する（スイング未検出の場合） |
| `Result.SwingOnset = ...`  | スイング開始フレームを Result に格納する                          |
| `Result.RT = RT`           | 反応時間を Result に格納する                                      |

### ヒトの反応時間の目安

| 刺激の種類     | 典型的な反応時間                  |
| -------------- | --------------------------------- |
| 光刺激（視覚） | 150〜300 ms                       |
| 音刺激（聴覚） | 100〜200 ms                       |
| バットスイング | 200〜600 ms（課題の難易度による） |

> 算出された `RT` の値は、この範囲に入っていますか？

### 確認ポイント

- [X] `RT` の値が表示されることを確認する
- [X] RT の値がおおよそ 150〜600 ms 程度であることを確認する（値が極端に小さい・大きい場合はデータや閾値を見直す）
- [X] `Result.RT` と `Result.SwingOnset` が格納されていることを確認する（`Result` と入力して確認）

---

## STEP 9：描画にスイング開始の縦線を追加する

### やること

Figure 2 の速度グラフに、スイング開始タイミング（`tSwingOnset`）を縦線で追記します。

### 使う関数：lineplot

`lineplot` は現在のグラフに縦線または横線を追加する関数です（このプロジェクトの独自関数）。

```matlab
lineplot(x の値, 'v', '線のスタイル')
```

| 引数       | 意味                                                           |
| ---------- | -------------------------------------------------------------- |
| `x の値` | どの x 座標に縦線を引くか（LED からの経過時間 [s] で指定）     |
| `'v'`    | vertical（縦線）。横線は `'h'`                               |
| `'r--'`  | 赤色の破線。`'g-'`（緑実線）、`'k-'`（黒実線）なども使える |

### コードを書こう

Figure 2 の速度グラフ（`subplot(3,1,[1:2])`）を描いたあとに、以下を追加してください。

```matlab
% Figure 2 のグラフを開く（すでに表示されている場合）
figure(2)
subplot(3,1,[1:2])

% スイング開始の縦線（tSwingOnset を LED からの相対時間に変換してから描く）
if ~isnan(tSwingOnset)
    tSwingOnset_sec = (tSwingOnset - tCueMarker) / fs ;
    lineplot(tSwingOnset_sec, 'v', 'r-') ;
end

% タイトルに RT の値を表示する
if ~isnan(RT)
    title(sprintf('RT = %.1f ms   (CueText: %s)', RT, cueText))
else
    title('スイング未検出')
end
```

### 各行の説明

| コード                                       | 意味                                                               |
| -------------------------------------------- | ------------------------------------------------------------------ |
| `tSwingOnset - tCueMarker) / fs`           | スイング開始フレームを「LED からの経過時間 [秒]」に変換する        |
| `lineplot(tSwingOnset_sec, 'v', 'r-')`     | その位置に赤い縦線を引く                                           |
| `~isnan(tSwingOnset)`                      | `~` は「〜ではない」の意味。スイングが検出されている場合だけ実行 |
| `sprintf('RT = %.1f ms ...', RT, cueText)` | 数値と文字列を組み合わせたタイトル文字列を作る                     |

### 確認ポイント

- [X] グラフの速度が最初に上がり始める位置に赤い縦線が引かれることを確認する
- [X] タイトルに `RT = ○○○ ms` と表示されることを確認する
- [X] 縦線の位置が「速度が閾値を超えた瞬間」と一致しているか、グラフを拡大して確認する

---

## STEP 10：scratch5 の完成確認

### 動作確認チェックリスト

- [X] スクリプト全体をはじめから最後まで実行してエラーが出ないことを確認する
- [X] `Result` に以下のフィールドがすべて含まれることを確認する| フィールド名          | 内容                          |
  | --------------------- | ----------------------------- |
  | `Result.PeakVelTop` | バット先端のピーク速度 [mm/s] |
  | `Result.CueCode`    | 1（Go）または 2（NoGo）       |
  | `Result.CueText`    | `'Go'` または `'NoGo'`    |
  | `Result.TCueMarker` | LED 点灯フレーム番号          |
  | `Result.SwingOnset` | スイング開始フレーム番号      |
  | `Result.RT`         | 反応時間 [ms]                 |
- [X] Figure 2 にスイング開始の赤い縦線が表示されることを確認する
- [X] タイトルに RT の値が表示されることを確認する

> 以上が全部 OK なら、`scratch5` は完成です！

---

## STEP 11：関数 `s5_forstudy_m3_analyze_single_trial.m` を書く

### どの部分を関数に入れるか？

`scratch5` の中から「**データを受け取って計算する部分**」だけを関数に入れます。

| 処理                                 | 関数に入れる？ | 理由                                                |
| ------------------------------------ | -------------- | --------------------------------------------------- |
| `clear`, `close all`, `clc`    | ❌ 入れない    | 関数の中で `clear` を使うと呼び出し元が壊れるため |
| `iSubject = 1` などの設定          | ❌ 入れない    | 「どの試行か」は呼び出し側で決める                  |
| `load(...)`, `DataArray(...)`    | ❌ 入れない    | データの読み込みも呼び出し側の仕事                  |
| `Prm = parameters`                 | ✅ 入れる      | 分析パラメータの取得は関数内の処理                  |
| フィルター処理                       | ✅ 入れる      | データの加工は関数の仕事                            |
| バット速度の計算                     | ✅ 入れる      | 分析指標の計算は関数の仕事                          |
| LED タイミングの検出（バグ修正済み） | ✅ 入れる      | 分析指標の計算は関数の仕事                          |
| スイング開始の検出                   | ✅ 入れる      | 分析指標の計算は関数の仕事                          |
| 反応時間の算出                       | ✅ 入れる      | 分析指標の計算は関数の仕事                          |
| `figure(...)` などの描画           | ❌ 入れない    | 描画は呼び出し側で行う（関数は計算に集中）          |

### コードを書こう（`s5_forstudy_m3_analyze_single_trial.m`）

`scratch5` の「入れる」部分を参考に、`s5_forstudy_m3_analyze_single_trial.m` に関数のコードを書いてください。

関数のひな形はすでに書いてあります：

```matlab
function Result = s5_forstudy_m3_analyze_single_trial(Data)
    % ← ここにコードを書いていく
end
```

> **ヒント**：STEP 2〜8 で `scratch5` に書いたコードのうち、描画以外の部分をそのまま貼れば完成です。

### 確認ポイント

- [X] 関数のコードを書いた
- [X] 関数の最初の行が `function Result = s5_forstudy_m3_analyze_single_trial(Data)` になっている
- [X] 関数の最後の行が `end` になっている

---

## STEP 12：関数の動作確認

### コマンドウィンドウで試す

```matlab
% (1) データを読み込む
load('x3_DataChecked/Data01')

% (2) 1試行目・1条件目のデータを取り出す
Data = DataArray(1, 1) ;

% (3) 関数を呼び出す
Result = s5_forstudy_m3_analyze_single_trial(Data)
```

### 確認ポイント

- [X] `Result` 構造体が返ってきているか確認する
- [X] `Result.RT` の値が、`scratch5` で確認した RT と一致しているか確認する
- [X] `Result.CueText` が `'Go'` または `'NoGo'` になっているか確認する

> **一致していれば、関数が正しく動いています！**

---

## STEP 13：本番の m3 に反映する

### やること

`s5_forstudy_m3` で完成したコードを、本番の `m3_analyze_single_trial.m` に反映します。

> **注意**：`m3_analyze_single_trial.m` は全試行の分析で使われる本番ファイルです。
> 変更する前に、現在のコードをよく確認してから、修正・追加してください。

変更箇所の概要：

| 変更の種類 | 内容                                                      |
| ---------- | --------------------------------------------------------- |
| バグ修正   | `errortext` → `errorText`（スペルミス）              |
| バグ修正   | `cueCode`, `cueText`, `TCueMarker` を Result に追加 |
| 機能追加   | スイング開始検出（threshold, searchRange, tSwingOnset）   |
| 機能追加   | 反応時間算出（RT）を Result に追加                        |

### 確認ポイント

- [X] `m3_analyze_single_trial.m` を修正した
- [ ] `x3_analyze_single_trial.m` を実行し、`x4_SingleTrialAnalysisResults/` に結果が保存されることを確認する

---

## 全体の振り返りチェックリスト

- [X] STEP 1：カレントフォルダを設定した
- [X] STEP 2：前回のコードを `scratch5` に書いてエラーなしに動いた
- [X] STEP 3：`Result` に `cueCode` が含まれないバグを発見した
- [X] STEP 4：バグを修正し、`Result` に `CueCode`・`CueText`・`TCueMarker` が入るようにした
- [X] STEP 5：グラフでスイング開始の様子を目で確認した
- [X] STEP 6：ピーク速度の 5% を閾値として設定した
- [X] STEP 7：`find` と `searchRange` を使ってスイング開始フレームを検出した
- [X] STEP 8：反応時間 [ms] を算出し、妥当な値であることを確認した
- [X] STEP 9：グラフにスイング開始の縦線を追加した
- [X] STEP 10：`scratch5` 全体を通して実行してエラーなしに完了した
- [X] STEP 11：`s5_forstudy_m3` に関数のコードを書いた
- [X] STEP 12：関数を呼び出してテストし、`scratch5` と同じ RT が得られることを確認した
- [X] STEP 13：本番の `m3_analyze_single_trial.m` に修正・機能追加を反映した

---

## 困ったときのヒント

### エラーが出たら

1. エラーメッセージを読む（どのファイルの何行目か確認する）
2. エラーが出た行のコードを見直す
3. AIアシスタントにエラーメッセージを貼り付けて質問する

### 変数の中身を確認したいときは

```matlab
% コマンドウィンドウで変数名を打つ（セミコロンなし）
Result
netVelTop(tSwingOnset)   % スイング開始フレームの速度値を確認
threshold                % 閾値の値を確認
```

### searchRange のインデックス変換が分からないときは

```matlab
% 具体的な数値で確かめてみよう
tCueMarker = 500 ;
n = 1000 ;
searchRange = tCueMarker : n ;
searchRange(1)   % → 500  （最初の要素は tCueMarker）
searchRange(2)   % → 501  （2番目の要素は tCueMarker + 1）
```

### コードの意味が分からないときは

```matlab
help find
help isnan
help sprintf
```

---

*作成日: 2026-05-26*
