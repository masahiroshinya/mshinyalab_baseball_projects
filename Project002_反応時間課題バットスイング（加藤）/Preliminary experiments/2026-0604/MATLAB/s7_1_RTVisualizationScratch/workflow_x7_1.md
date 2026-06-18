# ワークフロー：条件別 反応時間の可視化（x7_1）

## このファイルの目的

`x7_1_visualize_reaction_time.m` を書き上げるための手順書です。

x7 で作成した `ResultsTable`（マルチ試行テーブル）を読み込み、
条件間の反応時間（RT）を以下の2種類のグラフで可視化します。

| グラフ    | 種類     | 内容                               |
| --------- | -------- | ---------------------------------- |
| figure(1) | 箱ひげ図 | 条件間のRTの分布を比較する         |
| figure(2) | 散布図   | 試行ごとのRTの時系列変化を確認する |

---

## 全体の処理の流れ

```
[STEP 1] データ（x7テーブル）を読み込む
[STEP 2] 条件別にデータを抽出する（NaN・NoGo除外）
[STEP 2.5] 各条件の平均反応時間を計算する
[STEP 3] 箱ひげ図で条件間を比較する（figure 1）
[STEP 4] 各試行の反応時間を散布図で確認する（figure 2）
```

---

## STEP 1：データ（x7テーブル）を読み込む

x7 で保存した `ResultsTable` を `load` で読み込みます。

```matlab
clear
close all
clc

iSubject = 1 ;

filePath = sprintf('x7_MultiTrialAnalysisResultsChecked/MultiTrialResults%02d', iSubject) ;
load(filePath)   % → ResultsTable が読み込まれる
```

### ResultsTable の構造確認

読み込んだら、テーブルの中身を確認しましょう。

```matlab
% コマンドウィンドウで確認する
disp(head(ResultsTable, 5))   % 先頭5行を表示
```

テーブルには以下の列が含まれています：

| 列名             | 内容                                   |
| ---------------- | -------------------------------------- |
| `Condition`    | 条件名（"free" / "simple" / "gonogo"） |
| `Trial`        | 試行番号                               |
| `CueText`      | "Go" または "NoGo"                     |
| `RT_ms`        | 反応時間 [ms]（スイング未検出は NaN）  |
| `PeakOmegaDeg` | 最大角速度 [deg/s]                     |

### 確認ポイント

- [X] `head(ResultsTable, 5)` を実行し、テーブルの中身が表示されることを確認する
- [X] `Condition` 列に "free" / "simple" / "gonogo" が入っていることを確認する

---

## STEP 2：条件別にデータを抽出する

### テーブルの論理インデックスとは？

通常の配列インデックスは数字で指定します（例：`A(3)` → 3番目の要素）。
**論理インデックス**は `true` / `false` のリストで指定します。

```
A = [10, 20, 30, 40, 50]

論理インデックス: [false, false, true, true, false]
                                ↑     ↑
結果: A([false,false,true,true,false]) = [30, 40]
```

テーブルで使うと、**条件を満たす行だけ**を取り出せます。

```matlab
% 例: Condition 列が "simple" の行の RT だけを取り出す
mask = ResultsTable.Condition == "simple" ;
% mask は [nRow × 1] の logical 配列（true/false のリスト）

RT_simple = ResultsTable.RT_ms(mask) ;
```

---

### 今回の抽出ルール

- **free 条件**：Go キュー（+5V）の後に自由なタイミングでスイングする条件。NoGo はなく全試行が Go キューなので、simple と同様に全試行を使う
- **simple 条件**：全試行を使う（NoGo がない）
- **gonogo 条件**：Go 試行のみ（NoGo 試行を除外する）
- **共通**：`RT_ms` が NaN の試行（スイング未検出）は除外する

```matlab
% free 条件（Go cue 後にスイングした試行のみ有効）
mask_free    = ResultsTable.Condition == "free" & ResultsTable.CueText == "Go" ;
RT_free      = ResultsTable.RT_ms(mask_free) ;
Trial_free   = ResultsTable.Trial(mask_free) ;

nanMask_free = ~isnan(RT_free) ;
RT_free      = RT_free(nanMask_free) ;
Trial_free   = Trial_free(nanMask_free) ;

% simple 条件
mask_simple  = ResultsTable.Condition == "simple" ;
RT_simple    = ResultsTable.RT_ms(mask_simple) ;
Trial_simple = ResultsTable.Trial(mask_simple) ;

nanMask_simple = ~isnan(RT_simple) ;
RT_simple      = RT_simple(nanMask_simple) ;
Trial_simple   = Trial_simple(nanMask_simple) ;

% gonogo 条件（Go 試行のみ）
mask_gonogo  = ResultsTable.Condition == "gonogo" & ResultsTable.CueText == "Go" ;
RT_gonogo    = ResultsTable.RT_ms(mask_gonogo) ;
Trial_gonogo = ResultsTable.Trial(mask_gonogo) ;

nanMask_gonogo = ~isnan(RT_gonogo) ;
RT_gonogo      = RT_gonogo(nanMask_gonogo) ;
Trial_gonogo   = Trial_gonogo(nanMask_gonogo) ;
```

### `&` と `==` の意味

| 記号         | 意味                  | 例                                            |
| ------------ | --------------------- | --------------------------------------------- |
| `==`       | 等しいか              | `Condition == "gonogo"` → gonogo 行は true |
| `&`        | 両方 true のとき true | `A & B` → A も B も true の行だけ          |
| `~isnan()` | NaN でないか          | `~isnan(RT)` → 数値が入っている行は true   |

### 確認ポイント

- [X] `length(RT_free)`・`length(RT_simple)`・`length(RT_gonogo)` を実行し、試行数が表示されることを確認する
- [X] `RT_free` の試行数が `RT_simple` と同程度であることを確認する（どちらも全試行が Go）
- [X] `RT_gonogo` に NaN が含まれないことを確認する（`any(isnan(RT_gonogo))` が 0 になる）

---

## STEP 2.5：各条件の平均反応時間を計算する

STEP 3 のタイトルに平均値を表示するため、事前に `mean()` で計算しておきます。

```matlab
mean_free   = mean(RT_free) ;
mean_simple = mean(RT_simple) ;
mean_gonogo = mean(RT_gonogo) ;
```

### `mean()` について

`mean(x)` はベクトル `x` の平均値を返します。
NaN 除外済みのデータに対して使うため、ここでは NaN を気にする必要はありません。

### 確認ポイント

- [ ] `fprintf('free: %.0f ms / simple: %.0f ms / gonogo: %.0f ms\n', mean_free, mean_simple, mean_gonogo)` を実行し、それらしい値が表示されることを確認する

---

## STEP 3：箱ひげ図で条件間を比較する

### `boxplot` の使い方

```matlab
boxplot(データ, グループラベル)
```

複数条件を1つの `boxplot` に描くには、データとラベルを1つの配列にまとめる必要があります。

```
RT_simple = [500; 480; 520; ...]   （simple 条件の RT）
RT_gonogo = [600; 580; 640; ...]   （gonogo 条件の RT）

まとめる:
allRT    = [500; 480; 520; ...; 600; 580; 640; ...]
allLabel = {'simple'; 'simple'; 'simple'; ...; 'gonogo'; 'gonogo'; 'gonogo'; ...}
```

```matlab
figure(1)
clf

% データとラベルを結合する（free → simple → gonogo の順）
allRT    = [RT_free              ; RT_simple              ; RT_gonogo              ] ;
allLabel = [repmat({'free'},   length(RT_free),   1) ; ...
            repmat({'simple'}, length(RT_simple), 1) ; ...
            repmat({'gonogo'}, length(RT_gonogo), 1) ] ;

boxplot(allRT, allLabel, 'GroupOrder', {'free', 'simple', 'gonogo'}) ;

ylabel('反応時間 (ms)') ;
title(sprintf('Subject %02d : 条件別 反応時間\nfree: %.0f ms  /  simple: %.0f ms  /  gonogo: %.0f ms', ...
    iSubject, mean_free, mean_simple, mean_gonogo)) ;
grid on ;
```

### タイトルに平均値を表示する仕組み

| 書き方   | 意味                                                 |
| -------- | ---------------------------------------------------- |
| `\n`   | タイトルを2行に分ける（改行）                        |
| `%.0f` | 小数点なしの浮動小数点数（例：1123.4 → 1123）       |
| `...`  | 行が長いため次の行に続くことを示す（MATLABの行継続） |

表示イメージ：

```
Subject 01 : 条件別 反応時間
free: 1090 ms  /  simple: 1140 ms  /  gonogo: 1080 ms
```

### `repmat` の意味

`repmat(A, m, n)` は行列 A を m 行 n 列に繰り返す関数です。

```matlab
repmat({'simple'}, 3, 1)

% 結果:
%   {'simple'}
%   {'simple'}
%   {'simple'}
```

データ数と同じ行数のラベルリストを一気に作れます。

### `'GroupOrder'` オプション

グラフに表示する条件の並び順を指定します。
指定しないと、MATLABがアルファベット順で自動並び替えをするため、
意図した順番にならないことがあります。

### 確認ポイント

- [X] 上段に箱ひげ図が表示されることを確認する
- [X] simple と gonogo の2つの箱が並んで表示されることを確認する
- [X] Y 軸のラベルが「反応時間 (ms)」になっていることを確認する

---

## STEP 4：各試行の反応時間を散布図で確認する

箱ひげ図は分布の要約ですが、各試行の値は見えません。
散布図を追加することで、外れ値の確認や試行順の傾向（練習効果など）を確認できます。

### `scatter` の使い方

```matlab
scatter(X, Y)             % X と Y を散布図で描く
scatter(X, Y, sz, 'c')   % sz: マーカーサイズ、'c': 色（'b'=青, 'r'=赤など）
```

### 2条件を1つのグラフに重ね描きする

```matlab
figure(2)
clf

hold on   % ← これ以降の plot/scatter を同じ軸に重ね描きする

scatter(Trial_free,   RT_free,   40, 'g', 'filled', 'DisplayName', 'free') ;
scatter(Trial_simple, RT_simple, 40, 'b', 'filled', 'DisplayName', 'simple') ;
scatter(Trial_gonogo, RT_gonogo, 40, 'r', 'filled', 'DisplayName', 'gonogo') ;

hold off  % ← 重ね描きを終了する

xlabel('試行番号') ;
ylabel('反応時間 (ms)') ;
legend('Location', 'best') ;
grid on ;
```

### `hold on` / `hold off` の仕組み

```
hold on がない場合:
  scatter(Trial_simple, ...)  → グラフが描かれる
  scatter(Trial_gonogo, ...)  → 前のグラフが消えて、新しいグラフに置き換わる

hold on がある場合:
  scatter(Trial_simple, ...)  → グラフが描かれる
  scatter(Trial_gonogo, ...)  → 前のグラフに上書き（重ね描き）される
  hold off                   → 重ね描きモードを終了する
```

### `'DisplayName'` と `legend`

`'DisplayName', '名前'` を scatter や plot に付けると、
`legend` を呼んだときにその名前が凡例として表示されます。

```matlab
scatter(..., 'DisplayName', 'simple')   % 凡例の名前を指定
legend('Location', 'best')              % 自動で邪魔にならない位置に凡例を表示
```

### 確認ポイント

- [X] 下段に散布図が表示されることを確認する
- [X] 青（simple）と赤（gonogo）の2種類の点が表示されることを確認する
- [X] 凡例が表示されることを確認する
- [X] 試行が進むにつれてRTに変化の傾向があるか（練習効果など）を目視確認する

---

## 完成コードの全体像

```matlab
% x7_1_visualize_reaction_time.m

clear
close all
clc

% -----------------------------------------------------------------------
% STEP 1: データ読み込み
% -----------------------------------------------------------------------
iSubject = 1 ;
filePath = sprintf('x7_MultiTrialAnalysisResultsChecked/MultiTrialResults%02d', iSubject) ;
load(filePath)

% -----------------------------------------------------------------------
% STEP 2: 条件別データ抽出（NaN・NoGo除外）
% -----------------------------------------------------------------------
mask_free    = ResultsTable.Condition == "free" & ResultsTable.CueText == "Go" ;
RT_free      = ResultsTable.RT_ms(mask_free) ;
Trial_free   = ResultsTable.Trial(mask_free) ;

mask_simple  = ResultsTable.Condition == "simple" ;
RT_simple    = ResultsTable.RT_ms(mask_simple) ;
Trial_simple = ResultsTable.Trial(mask_simple) ;

mask_gonogo  = ResultsTable.Condition == "gonogo" & ResultsTable.CueText == "Go" ;
RT_gonogo    = ResultsTable.RT_ms(mask_gonogo) ;
Trial_gonogo = ResultsTable.Trial(mask_gonogo) ;

nanMask_free    = ~isnan(RT_free) ;
RT_free         = RT_free(nanMask_free) ;
Trial_free      = Trial_free(nanMask_free) ;

nanMask_simple  = ~isnan(RT_simple) ;
RT_simple       = RT_simple(nanMask_simple) ;
Trial_simple    = Trial_simple(nanMask_simple) ;

nanMask_gonogo  = ~isnan(RT_gonogo) ;
RT_gonogo       = RT_gonogo(nanMask_gonogo) ;
Trial_gonogo    = Trial_gonogo(nanMask_gonogo) ;

% -----------------------------------------------------------------------
% STEP 2.5: 各条件の平均反応時間を計算
% -----------------------------------------------------------------------
mean_free   = mean(RT_free) ;
mean_simple = mean(RT_simple) ;
mean_gonogo = mean(RT_gonogo) ;

% -----------------------------------------------------------------------
% STEP 3: 箱ひげ図（figure 1）
% -----------------------------------------------------------------------
figure(1)
clf

allRT    = [RT_free              ; RT_simple              ; RT_gonogo              ] ;
allLabel = [repmat({'free'},   length(RT_free),   1) ; ...
            repmat({'simple'}, length(RT_simple), 1) ; ...
            repmat({'gonogo'}, length(RT_gonogo), 1) ] ;

boxplot(allRT, allLabel, 'GroupOrder', {'free', 'simple', 'gonogo'}) ;

ylabel('反応時間 (ms)') ;
title(sprintf('Subject %02d : 条件別 反応時間\nfree: %.0f ms  /  simple: %.0f ms  /  gonogo: %.0f ms', ...
    iSubject, mean_free, mean_simple, mean_gonogo)) ;
grid on ;

% -----------------------------------------------------------------------
% STEP 4: 各試行の散布図（figure 2）
% -----------------------------------------------------------------------
figure(2)
clf

hold on
scatter(Trial_free,   RT_free,   40, 'g', 'filled', 'DisplayName', 'free') ;
scatter(Trial_simple, RT_simple, 40, 'b', 'filled', 'DisplayName', 'simple') ;
scatter(Trial_gonogo, RT_gonogo, 40, 'r', 'filled', 'DisplayName', 'gonogo') ;
hold off

xlabel('試行番号') ;
ylabel('反応時間 (ms)') ;
title(sprintf('Subject %02d : 試行別 反応時間', iSubject)) ;
legend('Location', 'best') ;
grid on ;
```

---

## 全体の振り返りチェックリスト

- [X] STEP 1: `load` でテーブルが読み込めた。`head(ResultsTable, 5)` で中身を確認した
- [X] STEP 2: 条件別に RT を抽出できた。`isnan` チェックで NaN が除外されていることを確認した
- [X] STEP 2.5: `mean_free`・`mean_simple`・`mean_gonogo` がそれらしい値になっていることを確認した
- [X] STEP 3: 箱ひげ図が上段に表示された。タイトルに3条件の平均 RT が表示されている
- [X] STEP 4: 散布図が下段に表示された。凡例も表示されている

---

*作成日: 2026-06-15*
