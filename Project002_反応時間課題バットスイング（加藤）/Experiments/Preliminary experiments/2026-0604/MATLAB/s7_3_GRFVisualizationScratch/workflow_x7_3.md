# ワークフロー：条件別 床反力（GRF）の可視化（x7_3）

## このファイルの目的

`x7_3_visualize_grf.m` を書き上げるための手順書です。

DataArray に保存されている `Force1`・`Force2`（フォースプレートデータ）を読み込み、
条件間の床反力（GRF）を以下の3種類のグラフで可視化します。

| グラフ    | 種類     | 内容                                                                    |
| --------- | -------- | ----------------------------------------------------------------------- |
| figure(1) | 箱ひげ図 | 条件間のピーク Fz（BW 正規化）の分布を比較する（Force1・Force2 を並列） |
| figure(2) | 散布図   | 試行ごとのピーク Fz の時系列変化を確認する                              |
| figure(3) | 時系列   | 1試行の Fz1・Fz2 波形を LED 基準でプロットする                          |

---

## 前提知識：なぜこのスクリプトは x7_1/x7_2 と設計が違うのか

x7_1・x7_2 は `x7_MultiTrialAnalysisResultsChecked/` の `ResultsTable` を読むだけでした。

**床反力（GRF）の場合は ResultsTable に入っていません。**
GRF はフォースプレートのデータ（`Force1`・`Force2`）で、
`x2_Data/DataXX.mat` の中の `DataArray` に入っています。
そのため x7_3 では **DataArray を直接読み込んで**、GRF 指標を自分で計算します。

### DataArray の中身（復習）

```
DataArray(iTrial, iCondition)
  .Markers          --- マーカー座標（構造体）
  .LEDData          --- LED 信号（Analog チャンネル 1〜2）[samples × 2]
  .AnalogFs         --- アナログデータのサンプリング周波数 [Hz]
  .FrameRate        --- マーカーデータのサンプリング周波数 [Hz]
  .Force1           --- フォースプレート1の力 [samples × 3]（列：Fx, Fy, Fz）
  .Force2           --- フォースプレート2の力 [samples × 3]（列：Fx, Fy, Fz）
  .Moment1          --- フォースプレート1のモーメント [samples × 3]
  .Moment2          --- フォースプレート2のモーメント [samples × 3]
  .ErrorCode / .ErrorText  --- エラー情報
```

`Force1(:, 3)` で **プレート1の垂直分力 Fz1（単位：N）** が取り出せます。
符号の意味：**Fz > 0 → 床が人を押し上げる力（上向き）** です。

### 体重正規化（BW 単位）とは

被験者の体重は人によって異なるため、力の生の値 [N] のまま比較すると
体重の差が分析結果に混入してしまいます。
**体重 [N] で割って BW（Body Weight）単位に変換**することで、
体重に依存しない比較ができます。

```
Fz_BW = Fz_raw [N] ÷ 体重 [N]

静止時：Fz1_BW + Fz2_BW ≈ 1.0 BW（合計が体重とつり合う）
```

体重の推定方法：

- LED 点灯前の静止期（試行開始〜LED 点灯直前）の Fz1 + Fz2 の平均 = 体重

---

## 全体の処理の流れ

```
[STEP 0] DataArray に Force1/Force2 が含まれているか確認する
[STEP 1] データを読み込む（DataArray + SingleTrialResultArray）
[STEP 2] 1試行の GRF を手で計算して感触をつかむ
[STEP 3] 全試行のピーク Fz を計算してまとめる
[STEP 4] 箱ひげ図で条件間を比較する（figure 1）
[STEP 5] 各試行のピーク Fz を散布図で確認する（figure 2）
[STEP 6] 1試行の GRF 時系列をプロットする（figure 3）
```

---

## STEP 0：DataArray に Force1/Force2 が含まれているか確認する

x7_3 を書く前に、まず **DataArray の中に GRF データが存在するか**を確認します。

### 確認コード（MATLAB のコマンドウィンドウで実行）

```matlab
iSubject = 2 ;
load(sprintf('x2_Data/Data%02d', iSubject))   % → DataArray が読み込まれる

% DataArray(1,1) の1試行目（free条件、Trial 1）のフィールドを確認
disp(fieldnames(DataArray(1,1)))
```

**Force1 が表示されれば OK** です。
次のように確認もしてください：

```matlab
size(DataArray(1,1).Force1)   % → [サンプル数 × 3] になるはず
```

### 確認ポイント

- [ ] `fieldnames` の出力に `'Force1'` と `'Force2'` が含まれていることを確認する
- [ ] `size(DataArray(1,1).Force1)` が `[N × 3]`（列数が3）になっていることを確認する

> **もし Force1 が含まれていない場合**：
> この場合は設計を変更する必要があります。
> その場合はすぐに教えてください。

---

## STEP 1：データを読み込む

今回は**2つのファイルを読み込みます**。

| ファイル                                     | 内容                                          | 目的                 |
| -------------------------------------------- | --------------------------------------------- | -------------------- |
| `x2_Data/DataXX.mat`                       | `DataArray`（Force1/Force2 含む）           | GRF データの取得     |
| `x5_SingleTrialAnalysisResultsChecked/...` | `SingleTrialResultArray`（TCueMarker 含む） | LED タイミングの取得 |

### コードを書こう

```matlab
clear
close all
clc

iSubject = 2 ;

% DataArray を読み込む（Force1/Force2 が含まれている）
load(sprintf('x2_Data/Data%02d', iSubject))

% SingleTrialResultArray を読み込む（TCueMarker を使うため）
load(sprintf('x5_SingleTrialAnalysisResultsChecked/SingleTrialAnalysisResults%02d', iSubject))

ConditionNameArray = {'free', 'simple', 'gonogo'} ;
nCondition = length(ConditionNameArray) ;
nTrial     = size(DataArray, 1) ;
```

### なぜ SingleTrialResultArray が必要か

GRF のピーク値を計算するとき、
「**LED 点灯後から2秒間の窓の中で最大値をとる**」という計算をします。
この「LED 点灯サンプル番号」は `SingleTrialResultArray` の `TCueMarker` から計算します。

```
TCueMarker（マーカーフレーム番号）
    ↓  × AnalogFs / FrameRate
tCueAnalog（アナログサンプル番号）
    ↓  〜 tCueAnalog + 2s 分のサンプル数
スイング窓の範囲
```

### 確認ポイント

- [X] `nTrial` が20になっていることを確認する（1条件20試行）
- [X] d `fieldnames(DataArray(1,1))` を実行して `Force1` が含まれていることを再確認する

---

## STEP 2：1試行の GRF を手で計算して感触をつかむ

全試行をループで処理する前に、まず **1試行だけ**で計算を試して、
結果が正しいかどうかを確認します。

### コードを書こう（STEP 1 の続きに追加）

```matlab
% ---- 1試行だけ取り出して確認する ----
iTrial     = 1 ;
iCondition = 1 ;   % 1 = free

Data   = DataArray(iTrial, iCondition) ;
Result = SingleTrialResultArray(iTrial, iCondition) ;

% ---- GRF データを取り出す ----
Fz1 = Data.Force1(:, 3) ;   % 垂直分力（プレート1）[N]
Fz2 = Data.Force2(:, 3) ;   % 垂直分力（プレート2）[N]

% ---- LED タイミングをアナログサンプル番号に変換する ----
% TCueMarker はマーカーフレーム番号 → アナログサンプル番号に換算する
tCueAnalog = round(Result.TCueMarker / Data.FrameRate * Data.AnalogFs) ;
fprintf('tCueAnalog = %d サンプル目（= %.3f 秒）\n', tCueAnalog, tCueAnalog/Data.AnalogFs) ;

% ---- 静止期（LED 点灯前）から体重を推定する ----
staticEnd   = tCueAnalog - 1 ;
bw = mean(Fz1(1:staticEnd)) + mean(Fz2(1:staticEnd)) ;
fprintf('推定体重：%.1f N（約 %.1f kg）\n', bw, bw/9.81) ;

% ---- BW 正規化 ----
Fz1_BW = Fz1 / bw ;
Fz2_BW = Fz2 / bw ;

% ---- スイング窓でピーク Fz を求める ----
% 窓：LED 点灯 〜 LED + 2秒後
swingEnd  = min(tCueAnalog + round(2 * Data.AnalogFs), length(Fz1)) ;
swingRange = tCueAnalog : swingEnd ;

peakFz1 = max(Fz1_BW(swingRange)) ;
peakFz2 = max(Fz2_BW(swingRange)) ;
fprintf('ピーク Fz1 = %.3f BW\n', peakFz1) ;
fprintf('ピーク Fz2 = %.3f BW\n', peakFz2) ;
```

### 確認ポイント

- [X] `tCueAnalog` が検出されていることを確認する（0 や NaN でないこと）
- [X] 推定体重がそれらしい値（例：55〜80 kg 程度）になっていることを確認する
- [X] `peakFz1`・`peakFz2` が正の値であることを確認する
  - 静止時の Fz は 0.4〜0.6 BW 程度（2枚で合計 1.0 BW）
  - スイング中のピーク値は 1.0〜2.0 BW 程度になることもある

### `round(Result.TCueMarker / Data.FrameRate * Data.AnalogFs)` の意味

| ステップ    | 計算                       | 例（FrameRate=200, AnalogFs=1000 の場合） |
| ----------- | -------------------------- | ----------------------------------------- |
| TCueMarker  | マーカーフレーム番号       | 300 フレーム目                            |
| / FrameRate | 秒に変換                   | 300 / 200 = 1.5 秒                        |
| × AnalogFs | アナログサンプル番号に変換 | 1.5 × 1000 = 1500 サンプル目             |
| round()     | 整数に丸める               | 1500                                      |

---

## STEP 3：全試行のピーク Fz を計算してまとめる

STEP 2 と同じ処理を、全条件・全試行に対してループで実行します。
結果は `[nTrial × nCondition]` の行列に格納します。

### 行列（2次元配列）とは

```
PeakFz2 の構造（nTrial=20, nCondition=3 の場合）:

        free    simple  gonogo
Trial 1: 1.23    1.15    1.41
Trial 2: 1.18    1.09    1.38
  ...
Trial 20: 1.21   1.22    1.35

   列1=free  列2=simple  列3=gonogo
   行1〜20 = 各試行のピーク値
```

`PeakFz2(:, 1)` で free 条件の全試行（20個）が取り出せます。

### コードを書こう（STEP 1 の続きに追加）

```matlab
% ---- ピーク Fz を格納する行列を初期化する ----
PeakFz1 = nan(nTrial, nCondition) ;   % [20 × 3]（NaN で初期化）
PeakFz2 = nan(nTrial, nCondition) ;

for iCondition = 1:nCondition
    for iTrial = 1:nTrial

        Data   = DataArray(iTrial, iCondition) ;
        Result = SingleTrialResultArray(iTrial, iCondition) ;

        % Force1 がない試行はスキップ
        if ~isfield(Data, 'Force1') || isempty(Data.Force1)
            continue
        end

        % GRF データを取り出す
        Fz1 = Data.Force1(:, 3) ;
        Fz2 = Data.Force2(:, 3) ;

        % LED タイミング（アナログサンプル番号）
        if isnan(Result.TCueMarker)
            continue
        end
        tCueAnalog = round(Result.TCueMarker / Data.FrameRate * Data.AnalogFs) ;
        if tCueAnalog < 2
            continue
        end

        % 体重推定（LED 前の静止期）
        bw = mean(Fz1(1 : tCueAnalog-1)) + mean(Fz2(1 : tCueAnalog-1)) ;
        if bw <= 0
            continue
        end

        % スイング窓でピーク Fz を求める
        swingEnd  = min(tCueAnalog + round(2 * Data.AnalogFs), length(Fz1)) ;
        swingRange = tCueAnalog : swingEnd ;

        PeakFz1(iTrial, iCondition) = max(Fz1(swingRange)) / bw ;
        PeakFz2(iTrial, iCondition) = max(Fz2(swingRange)) / bw ;

    end
end

fprintf('ピーク Fz の計算完了\n') ;
```

### `continue` とは

ループの中で `continue` に到達すると、**その試行の残りのコードをスキップして次の試行へ進みます**。
エラーが起きそうな試行（Force1 がない、タイミングが NaN など）を安全に飛ばすために使います。

```
for iTrial = 1:20
    if （問題あり）
        continue    ← ここ以降をスキップして iTrial+1 へ
    end
    （通常の計算）
end
```

### 確認ポイント

- [ ] ループが完了してエラーが出ないことを確認する
- [ ] `sum(isnan(PeakFz2))` を実行し、NaN の数が少ないことを確認する
  - NaN が多い場合は `continue` で多くの試行がスキップされている → 原因を確認する

---

## STEP 4：箱ひげ図で条件間を比較する（figure 1）

### やること

プレート1（Force1）とプレート2（Force2）それぞれのピーク Fz を、
条件別に箱ひげ図で比較します。
2つのフォースプレートを `subplot` で左右に並べます。

### コードを書こう（STEP 3 の続きに追加）

```matlab
% ---- 箱ひげ図の準備 ----
% NaN を除外した条件別データ
Fz1_free   = PeakFz1(~isnan(PeakFz1(:,1)), 1) ;
Fz1_simple = PeakFz1(~isnan(PeakFz1(:,2)), 2) ;
Fz1_gonogo = PeakFz1(~isnan(PeakFz1(:,3)), 3) ;

Fz2_free   = PeakFz2(~isnan(PeakFz2(:,1)), 1) ;
Fz2_simple = PeakFz2(~isnan(PeakFz2(:,2)), 2) ;
Fz2_gonogo = PeakFz2(~isnan(PeakFz2(:,3)), 3) ;

mean_Fz1_free   = mean(Fz1_free) ;   mean_Fz2_free   = mean(Fz2_free) ;
mean_Fz1_simple = mean(Fz1_simple) ; mean_Fz2_simple = mean(Fz2_simple) ;
mean_Fz1_gonogo = mean(Fz1_gonogo) ; mean_Fz2_gonogo = mean(Fz2_gonogo) ;

% ---- プロット ----
figure(1)
clf

% ---- subplot(行, 列, 番号) ----
% subplot(1, 2, 1) → 1行2列の配置の左側
subplot(1, 2, 1)

allFz1  = [Fz1_free   ; Fz1_simple   ; Fz1_gonogo  ] ;
label1  = [repmat({'free'},   length(Fz1_free),   1) ; ...
           repmat({'simple'}, length(Fz1_simple), 1) ; ...
           repmat({'gonogo'}, length(Fz1_gonogo), 1) ] ;
boxplot(allFz1, label1, 'GroupOrder', {'free', 'simple', 'gonogo'}) ;
ylabel('Peak Fz [BW]') ;
title(sprintf('プレート1（後ろ足）\nfree: %.2f / simple: %.2f / gonogo: %.2f', ...
    mean_Fz1_free, mean_Fz1_simple, mean_Fz1_gonogo)) ;
grid on

% subplot(1, 2, 2) → 1行2列の配置の右側
subplot(1, 2, 2)

allFz2  = [Fz2_free   ; Fz2_simple   ; Fz2_gonogo  ] ;
label2  = [repmat({'free'},   length(Fz2_free),   1) ; ...
           repmat({'simple'}, length(Fz2_simple), 1) ; ...
           repmat({'gonogo'}, length(Fz2_gonogo), 1) ] ;
boxplot(allFz2, label2, 'GroupOrder', {'free', 'simple', 'gonogo'}) ;
ylabel('Peak Fz [BW]') ;
title(sprintf('プレート2（前の足）\nfree: %.2f / simple: %.2f / gonogo: %.2f', ...
    mean_Fz2_free, mean_Fz2_simple, mean_Fz2_gonogo)) ;
grid on

sgtitle(sprintf('Subject %02d：条件別ピーク垂直分力', iSubject)) ;
```

### `subplot(1, 2, 番号)` の意味

`subplot(行数, 列数, 番号)` は、1つの figure に複数のグラフを並べるために使います。

```
subplot(1, 2, 1)    subplot(1, 2, 2)
┌─────────────┐   ┌─────────────┐
│   左のグラフ  │   │   右のグラフ  │
└─────────────┘   └─────────────┘
    プレート1            プレート2
```

`sgtitle(...)` は figure 全体のタイトルを設定する関数です（subplot の上に表示されます）。

### 確認ポイント

- [X] figure(1) に2つの箱ひげ図が左右に並んでいることを確認する
- [X] Y 軸の単位が BW になっていることを確認する
- [X] プレート1とプレート2で波形の大きさが異なることを確認する
  - どちらが「軸足（後ろ足）」でどちらが「踏み込み足（前の足）」かを考えてみよう

---

## STEP 5：各試行のピーク Fz を散布図で確認する（figure 2）

x7_1・x7_2 と同様に、**試行番号 vs ピーク Fz** の散布図を描きます。
プレート2（踏み込み足）のデータを表示します。

### コードを書こう（STEP 4 の続きに追加）

```matlab
figure(2)
clf

hold on

Trial_free   = find(~isnan(PeakFz2(:,1))) ;
Trial_simple = find(~isnan(PeakFz2(:,2))) ;
Trial_gonogo = find(~isnan(PeakFz2(:,3))) ;

scatter(Trial_free,   Fz2_free,   40, 'g', 'filled', 'DisplayName', 'free') ;
scatter(Trial_simple, Fz2_simple, 40, 'b', 'filled', 'DisplayName', 'simple') ;
scatter(Trial_gonogo, Fz2_gonogo, 40, 'r', 'filled', 'DisplayName', 'gonogo') ;

hold off

xlabel('試行番号') ;
ylabel('Peak Fz [BW]（プレート2）') ;
title(sprintf('Subject %02d：試行別ピーク垂直分力（踏み込み足）', iSubject)) ;
legend('Location', 'best') ;
grid on
```

### 確認ポイント

- [ ] figure(2) に3条件の散布図が重なって表示されることを確認する
- [ ] 試行が進むにつれて傾向に変化があるかを目視確認する

---

## STEP 6：1試行の GRF 時系列をプロットする（figure 3）

1試行の Fz1・Fz2 の時系列を LED 基準でプロットします。
（学習用_8 STEP 6 と同じ形式）

表示する試行を変数で設定できるようにします。

### コードを書こう（STEP 5 の続きに追加）

```matlab
% ---- 表示する試行を選ぶ ----
iCondition_show = 1 ;   % 1=free, 2=simple, 3=gonogo
iTrial_show     = 1 ;   % 試行番号

Data   = DataArray(iTrial_show, iCondition_show) ;
Result = SingleTrialResultArray(iTrial_show, iCondition_show) ;

Fz1 = Data.Force1(:, 3) ;
Fz2 = Data.Force2(:, 3) ;

fsAnalog   = Data.AnalogFs ;
nAnalog    = length(Fz1) ;
tCueAnalog = round(Result.TCueMarker / Data.FrameRate * fsAnalog) ;

% 体重推定と正規化
bw     = mean(Fz1(1:tCueAnalog-1)) + mean(Fz2(1:tCueAnalog-1)) ;
Fz1_BW = Fz1 / bw ;
Fz2_BW = Fz2 / bw ;

% LED 基準の時間軸
tFromLED    = ([1:nAnalog] - tCueAnalog) / fsAnalog ;
plotTimeRange = [-1, 3] ;

% スイング開始時刻（マーカーフレーム → アナログ秒）
if ~isnan(Result.SwingOnset)
    tSwingFromLED = (Result.SwingOnset - Result.TCueMarker) / Data.FrameRate ;
end

% ---- プロット ----
figure(3)
clf

plot(tFromLED, Fz1_BW, 'b-', 'LineWidth', 1.2, 'DisplayName', 'プレート1（後ろ足）') ;
hold on
plot(tFromLED, Fz2_BW, 'r-', 'LineWidth', 1.2, 'DisplayName', 'プレート2（前の足）') ;

% LED 点灯ライン
xline(0, 'k--', 'LineWidth', 1.2) ;

% スイング開始ライン
if ~isnan(Result.SwingOnset)
    xline(tSwingFromLED, 'm-', 'LineWidth', 1.2) ;
end

hold off

set(gca, 'XLim', plotTimeRange) ;
set(gca, 'YLim', [-0.1, 1.6]) ;
xlabel('LED からの時間 [s]') ;
ylabel('Fz [BW]') ;
title(sprintf('Subject %02d  %s  Trial %d  [%s]  RT = %.0f ms', ...
    iSubject, ConditionNameArray{iCondition_show}, iTrial_show, ...
    Result.CueText, Result.RT)) ;
legend('Location', 'northwest') ;
grid on
```

### グラフの読み方

```
Fz [BW]

1.0│ ─────────────────── 1.0 BW（体重）

   │プレート1（青）：後ろ足
   │●●●●●●●●●●│             ●●●●●●●
   │               │         ●●
   │               │     ●●●
   │                                    プレート2（赤）：前の足
   │                         ●●●●●●●●
   │         ●●●●●●
   │ ●●●●●●
   │──────────────────────────────── 時間
           ↑LED（黒破線）   ↑スイング開始（マゼンタ線）
```

LED 点灯後に体重が前足（プレート2）に移動する様子を観察してください。
マゼンタの縦線（スイング開始）とGRFの変化のタイミングを比べてみましょう。

### 確認ポイント

- [X] figure(3) に2本の曲線（青・赤）が表示されることを確認する
- [X] `iCondition_show` と `iTrial_show` の値を変えて複数の試行を確認してみる
- [X] LED 点灯後にどちらかの Fz が変化し始めるかを観察する
- [X] スイング開始（マゼンタ線）より GRF の変化が先か後かを観察する

---

## 完成コードの全体像

```matlab
% x7_3_visualize_grf.m

clear
close all
clc

iSubject = 2 ;

% -----------------------------------------------------------------------
% STEP 1: データ読み込み
% -----------------------------------------------------------------------
load(sprintf('x2_Data/Data%02d', iSubject))
load(sprintf('x5_SingleTrialAnalysisResultsChecked/SingleTrialAnalysisResults%02d', iSubject))

ConditionNameArray = {'free', 'simple', 'gonogo'} ;
nCondition = length(ConditionNameArray) ;
nTrial     = size(DataArray, 1) ;

% -----------------------------------------------------------------------
% STEP 3: 全試行のピーク Fz を計算する
% -----------------------------------------------------------------------
PeakFz1 = nan(nTrial, nCondition) ;
PeakFz2 = nan(nTrial, nCondition) ;

for iCondition = 1:nCondition
    for iTrial = 1:nTrial

        Data   = DataArray(iTrial, iCondition) ;
        Result = SingleTrialResultArray(iTrial, iCondition) ;

        if ~isfield(Data, 'Force1') || isempty(Data.Force1)
            continue
        end

        Fz1 = Data.Force1(:, 3) ;
        Fz2 = Data.Force2(:, 3) ;

        if isnan(Result.TCueMarker)
            continue
        end
        tCueAnalog = round(Result.TCueMarker / Data.FrameRate * Data.AnalogFs) ;
        if tCueAnalog < 2
            continue
        end

        bw = mean(Fz1(1 : tCueAnalog-1)) + mean(Fz2(1 : tCueAnalog-1)) ;
        if bw <= 0
            continue
        end

        swingEnd   = min(tCueAnalog + round(2 * Data.AnalogFs), length(Fz1)) ;
        swingRange = tCueAnalog : swingEnd ;

        PeakFz1(iTrial, iCondition) = max(Fz1(swingRange)) / bw ;
        PeakFz2(iTrial, iCondition) = max(Fz2(swingRange)) / bw ;

    end
end

% -----------------------------------------------------------------------
% STEP 4: NaN 除外・平均計算
% -----------------------------------------------------------------------
Fz1_free   = PeakFz1(~isnan(PeakFz1(:,1)), 1) ;
Fz1_simple = PeakFz1(~isnan(PeakFz1(:,2)), 2) ;
Fz1_gonogo = PeakFz1(~isnan(PeakFz1(:,3)), 3) ;

Fz2_free   = PeakFz2(~isnan(PeakFz2(:,1)), 1) ;
Fz2_simple = PeakFz2(~isnan(PeakFz2(:,2)), 2) ;
Fz2_gonogo = PeakFz2(~isnan(PeakFz2(:,3)), 3) ;

mean_Fz1_free   = mean(Fz1_free) ;   mean_Fz2_free   = mean(Fz2_free) ;
mean_Fz1_simple = mean(Fz1_simple) ; mean_Fz2_simple = mean(Fz2_simple) ;
mean_Fz1_gonogo = mean(Fz1_gonogo) ; mean_Fz2_gonogo = mean(Fz2_gonogo) ;

% -----------------------------------------------------------------------
% figure(1): 箱ひげ図（条件別 ピーク Fz）
% -----------------------------------------------------------------------
figure(1)
clf

subplot(1, 2, 1)
allFz1 = [Fz1_free   ; Fz1_simple   ; Fz1_gonogo  ] ;
label1 = [repmat({'free'},   length(Fz1_free),   1) ; ...
          repmat({'simple'}, length(Fz1_simple), 1) ; ...
          repmat({'gonogo'}, length(Fz1_gonogo), 1) ] ;
boxplot(allFz1, label1, 'GroupOrder', {'free', 'simple', 'gonogo'}) ;
ylabel('Peak Fz [BW]') ;
title(sprintf('プレート1（後ろ足）\nfree: %.2f / simple: %.2f / gonogo: %.2f', ...
    mean_Fz1_free, mean_Fz1_simple, mean_Fz1_gonogo)) ;
grid on

subplot(1, 2, 2)
allFz2 = [Fz2_free   ; Fz2_simple   ; Fz2_gonogo  ] ;
label2 = [repmat({'free'},   length(Fz2_free),   1) ; ...
          repmat({'simple'}, length(Fz2_simple), 1) ; ...
          repmat({'gonogo'}, length(Fz2_gonogo), 1) ] ;
boxplot(allFz2, label2, 'GroupOrder', {'free', 'simple', 'gonogo'}) ;
ylabel('Peak Fz [BW]') ;
title(sprintf('プレート2（前の足）\nfree: %.2f / simple: %.2f / gonogo: %.2f', ...
    mean_Fz2_free, mean_Fz2_simple, mean_Fz2_gonogo)) ;
grid on

sgtitle(sprintf('Subject %02d：条件別ピーク垂直分力', iSubject)) ;

% -----------------------------------------------------------------------
% figure(2): 散布図（試行別 ピーク Fz）
% -----------------------------------------------------------------------
figure(2)
clf

hold on

Trial_free   = find(~isnan(PeakFz2(:,1))) ;
Trial_simple = find(~isnan(PeakFz2(:,2))) ;
Trial_gonogo = find(~isnan(PeakFz2(:,3))) ;

scatter(Trial_free,   Fz2_free,   40, 'g', 'filled', 'DisplayName', 'free') ;
scatter(Trial_simple, Fz2_simple, 40, 'b', 'filled', 'DisplayName', 'simple') ;
scatter(Trial_gonogo, Fz2_gonogo, 40, 'r', 'filled', 'DisplayName', 'gonogo') ;

hold off

xlabel('試行番号') ;
ylabel('Peak Fz [BW]（プレート2）') ;
title(sprintf('Subject %02d：試行別ピーク垂直分力（踏み込み足）', iSubject)) ;
legend('Location', 'best') ;
grid on

% -----------------------------------------------------------------------
% figure(3): GRF 時系列（選択試行）
% -----------------------------------------------------------------------
iCondition_show = 1 ;   % 1=free, 2=simple, 3=gonogo
iTrial_show     = 1 ;

Data   = DataArray(iTrial_show, iCondition_show) ;
Result = SingleTrialResultArray(iTrial_show, iCondition_show) ;

Fz1 = Data.Force1(:, 3) ;
Fz2 = Data.Force2(:, 3) ;

fsAnalog   = Data.AnalogFs ;
nAnalog    = length(Fz1) ;
tCueAnalog = round(Result.TCueMarker / Data.FrameRate * fsAnalog) ;

bw     = mean(Fz1(1:tCueAnalog-1)) + mean(Fz2(1:tCueAnalog-1)) ;
Fz1_BW = Fz1 / bw ;
Fz2_BW = Fz2 / bw ;

tFromLED    = ([1:nAnalog] - tCueAnalog) / fsAnalog ;
plotTimeRange = [-1, 3] ;

figure(3)
clf

plot(tFromLED, Fz1_BW, 'b-', 'LineWidth', 1.2, 'DisplayName', 'プレート1（後ろ足）') ;
hold on
plot(tFromLED, Fz2_BW, 'r-', 'LineWidth', 1.2, 'DisplayName', 'プレート2（前の足）') ;
xline(0, 'k--', 'LineWidth', 1.2) ;
if ~isnan(Result.SwingOnset)
    tSwingFromLED = (Result.SwingOnset - Result.TCueMarker) / Data.FrameRate ;
    xline(tSwingFromLED, 'm-', 'LineWidth', 1.2) ;
end
hold off

set(gca, 'XLim', plotTimeRange) ;
set(gca, 'YLim', [-0.1, 1.6]) ;
xlabel('LED からの時間 [s]') ;
ylabel('Fz [BW]') ;
title(sprintf('Subject %02d  %s  Trial %d  [%s]  RT = %.0f ms', ...
    iSubject, ConditionNameArray{iCondition_show}, iTrial_show, ...
    Result.CueText, Result.RT)) ;
legend('Location', 'northwest') ;
grid on
```

---

## 全体の振り返りチェックリスト

- [ ] STEP 0：`fieldnames(DataArray(1,1))` で `Force1` が含まれていることを確認した
- [ ] STEP 1：2つのファイル（DataArray・SingleTrialResultArray）を読み込んだ
- [ ] STEP 2：1試行の体重推定・BW 正規化・ピーク Fz 計算が動作することを確認した
- [ ] STEP 3：ループで全試行を処理し、PeakFz1・PeakFz2 行列が完成した
- [ ] STEP 4：figure(1) に2つの箱ひげ図が表示された
- [ ] STEP 5：figure(2) に散布図が表示された
- [ ] STEP 6：figure(3) に GRF 時系列が表示された。`iCondition_show`・`iTrial_show` を変えて複数試行を確認した

---

## 今後の拡張方針（メモ・未実装）

### 背景

近年発表された文献の一つで、バットスピードとの関連が **鉛直方向（Fz）だけでなく**、
**後方GRF（Backward GRF）** および **合成GRF（Resultant GRF）** にも見られる、という結果が報告されている。
現状の `x7_3_visualize_grf.m` は Fz（鉛直分力）のみを解析項目にしているため、
今後これらの指標も解析項目として追加したい。

> 文献の書誌情報・具体的な指標定義（後方GRFの符号の取り方、合成GRFの合成方法など）は未記録。
> 次回この文献を参照する際に、`Previous Research/` 配下に文献ノートを追加し、本メモに反映すること。

### 追加したい解析項目（方針）

| 指標               | 想定される定義（要文献確認）                                                                 | 使用するデータ                      |
| ------------------ | ---------------------------------------------------------------------------------------------- | ------------------------------------ |
| 後方GRF（Backward） | Fy（前後方向分力）のうち、後方（後ろ足が地面を後方に蹴る方向）成分のピーク値                     | `Force1(:,2)` / `Force2(:,2)`（要符号確認） |
| 合成GRF（Resultant） | 3軸合成 `sqrt(Fx.^2 + Fy.^2 + Fz.^2)`、または水平（Fx, Fy）+ 垂直（Fz）の合成など、文献の定義に合わせる | `Force1` / `Force2` の全3列          |

### 実装方針（案）

- 現状の Fz 分析（STEP 2〜STEP 6 のパターン：体重正規化 → スイング窓でのピーク抽出 → 条件別比較）と**同じ構造**を、Fy（後方成分）・合成GRFにもそのまま適用できる見込み。
- `Data.Force1` / `Data.Force2` にはすでに Fx, Fy, Fz の全列が含まれているため、データ取り込み側の変更は不要。
- 対応が必要な追加検討事項：
  - 「後方」がどちらの符号（正/負）に対応するかを、[技術説明.md](../分析学習/学習用_8_床反力分析/技術説明.md) の座標系定義（「ヒトが+x方向に移動する力を+Fxとする」）と対応づけて確認する
  - 合成GRFを「フォースプレートごと（Force1, Force2）」で計算するか、「前後2枚の合力」として計算するかを決める
  - 正規化（BW単位）・ピーク抽出窓（スイング窓）は Fz と同じロジックを流用できるか確認する

### ステータス

**方針メモのみ。実装は未着手。** 文献の詳細確認と指標定義の確定後、STEP 2〜6 と同様の形で `x7_3_visualize_grf.m` に追加する。

---

*作成日: 2026-06-18*
*追記: 2026-07-02（後方GRF・合成GRFを解析項目に追加する方針をメモ。実装は未着手）*
