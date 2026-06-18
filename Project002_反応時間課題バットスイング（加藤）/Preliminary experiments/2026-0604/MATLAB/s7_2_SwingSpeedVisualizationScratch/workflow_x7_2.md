# ワークフロー：条件別 スイングスピードの可視化（x7_2）

## このファイルの目的

`x7_2_visualize_swing_speed.m` を書き上げるための手順書です。

x7 で作成した `ResultsTable`（マルチ試行テーブル）を読み込み、
条件間のスイングスピード（最大角速度: PeakOmegaDeg）を以下の2種類のグラフで可視化します。

| グラフ    | 種類     | 内容                                             |
| --------- | -------- | ------------------------------------------------ |
| figure(1) | 箱ひげ図 | 条件間のスイングスピードの分布を比較する         |
| figure(2) | 散布図   | 試行ごとのスイングスピードの時系列変化を確認する |

x7_1 との主な違いは以下の1点だけです。

| 項目       | x7_1（反応時間） | x7_2（スイングスピード） |
| ---------- | ---------------- | ------------------------ |
| 対象列     | `RT_ms`        | `PeakOmegaDeg`         |
| 単位       | ms               | deg/s                    |
| 変数名の例 | `RT_free` など | `Omega_free` など      |

---

## 全体の処理の流れ

```
[STEP 1] データ（x7テーブル）を読み込む
[STEP 2] 条件別にデータを抽出する（NaN・NoGo除外）
[STEP 2.5] 各条件の平均スイングスピードを計算する
[STEP 3] 箱ひげ図で条件間を比較する（figure 1）
[STEP 4] 各試行のスイングスピードを散布図で確認する（figure 2）
```

---

## STEP 1：データ（x7テーブル）を読み込む

x7_1 と完全に同じです。同じ `ResultsTable` を使います。

```matlab
clear
close all
clc

iSubject = 1 ;

filePath = sprintf('x7_MultiTrialAnalysisResultsChecked/MultiTrialResults%02d', iSubject) ;
load(filePath)   % → ResultsTable が読み込まれる
```

### ResultsTable の構造確認

```matlab
disp(head(ResultsTable, 5))   % 先頭5行を表示
```

今回使う列は `PeakOmegaDeg` です：

| 列名             | 内容                                            |
| ---------------- | ----------------------------------------------- |
| `Condition`    | 条件名（"free" / "simple" / "gonogo"）          |
| `Trial`        | 試行番号                                        |
| `CueText`      | "Go" または "NoGo"                              |
| `RT_ms`        | 反応時間 [ms]（今回は使わない）                 |
| `PeakOmegaDeg` | 最大角速度 [deg/s] ←**今回はこれを使う** |

### 確認ポイント

- [X] `head(ResultsTable, 5)` を実行し、テーブルの中身が表示されることを確認する
- [X] `PeakOmegaDeg` 列に数値が入っていることを確認する（0 や NaN でないこと）

---

## STEP 2：条件別にデータを抽出する

x7_1 と同じ考え方ですが、取り出す列を `RT_ms` → `PeakOmegaDeg` に変えます。
変数名も `RT_〇〇` → `Omega_〇〇` に変えると、コードが読みやすくなります。

### 抽出ルール（x7_1 と同じ）

- **free 条件**：Go キュー後の試行のみ（`CueText == "Go"`）
- **simple 条件**：全試行を使う（NoGo がない）
- **gonogo 条件**：Go 試行のみ（NoGo 試行を除外）
- **共通**：`PeakOmegaDeg` が NaN の試行は除外する

```matlab
% free 条件
mask_free     = ResultsTable.Condition == "free" & ResultsTable.CueText == "Go" ;
Omega_free    = ResultsTable.PeakOmegaDeg(mask_free) ;
Trial_free    = ResultsTable.Trial(mask_free) ;

nanMask_free  = ~isnan(Omega_free) ;
Omega_free    = Omega_free(nanMask_free) ;
Trial_free    = Trial_free(nanMask_free) ;

% simple 条件
mask_simple   = ResultsTable.Condition == "simple" ;
Omega_simple  = ResultsTable.PeakOmegaDeg(mask_simple) ;
Trial_simple  = ResultsTable.Trial(mask_simple) ;

nanMask_simple = ~isnan(Omega_simple) ;
Omega_simple   = Omega_simple(nanMask_simple) ;
Trial_simple   = Trial_simple(nanMask_simple) ;

% gonogo 条件（Go 試行のみ）
mask_gonogo   = ResultsTable.Condition == "gonogo" & ResultsTable.CueText == "Go" ;
Omega_gonogo  = ResultsTable.PeakOmegaDeg(mask_gonogo) ;
Trial_gonogo  = ResultsTable.Trial(mask_gonogo) ;

nanMask_gonogo = ~isnan(Omega_gonogo) ;
Omega_gonogo   = Omega_gonogo(nanMask_gonogo) ;
Trial_gonogo   = Trial_gonogo(nanMask_gonogo) ;
```

### x7_1 との対応表

x7_1 のコードと見比べながら書くと、違いが分かりやすいです。

| x7_1 のコード             | x7_2 で変わる部分             |
| ------------------------- | ----------------------------- |
| `ResultsTable.RT_ms`    | `ResultsTable.PeakOmegaDeg` |
| `RT_free`               | `Omega_free`                |
| `RT_simple`             | `Omega_simple`              |
| `RT_gonogo`             | `Omega_gonogo`              |
| `nanMask_free` ... など | 変数名も `nanMask_` で統一  |

### 確認ポイント

- [ ] `length(Omega_free)`・`length(Omega_simple)`・`length(Omega_gonogo)` を実行し、試行数が表示されることを確認する
- [ ] `Omega_free` などに NaN が含まれないことを確認する（`any(isnan(Omega_free))` が 0 になる）

---

## STEP 2.5：各条件の平均スイングスピードを計算する

タイトルに平均±SD を表示するため、事前に計算しておきます。

```matlab
mean_free   = mean(Omega_free) ;
mean_simple = mean(Omega_simple) ;
mean_gonogo = mean(Omega_gonogo) ;

std_free    = std(Omega_free) ;
std_simple  = std(Omega_simple) ;
std_gonogo  = std(Omega_gonogo) ;
```

### 確認ポイント

- [ ] `fprintf('free: %.0f / simple: %.0f / gonogo: %.0f deg/s\n', mean_free, mean_simple, mean_gonogo)` を実行し、それらしい値が表示されることを確認する
- [ ] 3条件の平均値の大小関係が直感と合っているか目視する（例：gonogo が最も速い？）

---

## STEP 3：箱ひげ図で条件間を比較する（figure 1）

x7_1 と同じ構造です。変数名と単位表示を変えるだけです。

```matlab
figure(1)
clf

allOmega = [Omega_free ; Omega_simple ; Omega_gonogo] ;
allLabel = [repmat({'free'},   length(Omega_free),   1) ; ...
            repmat({'simple'}, length(Omega_simple), 1) ; ...
            repmat({'gonogo'}, length(Omega_gonogo), 1) ] ;

boxplot(allOmega, allLabel, 'GroupOrder', {'free', 'simple', 'gonogo'}) ;

ylabel('最大角速度 (deg/s)') ;
title(sprintf('Subject %02d : 条件別 スイングスピード\nfree: %.0f±%.0f  /  simple: %.0f±%.0f  /  gonogo: %.0f±%.0f  deg/s', ...
    iSubject, mean_free, std_free, mean_simple, std_simple, mean_gonogo, std_gonogo)) ;
grid on ;
```

### タイトルの表示イメージ

```
Subject 01 : 条件別 スイングスピード
free: 800±50  /  simple: 820±45  /  gonogo: 850±60  deg/s
```

### 確認ポイント

- [ ] 箱ひげ図が3条件分表示されることを確認する
- [ ] Y 軸のラベルが「最大角速度 (deg/s)」になっていることを確認する
- [ ] タイトルに平均±SD が表示されていることを確認する

---

## STEP 4：各試行のスイングスピードを散布図で確認する（figure 2）

x7_1 と同じ構造です。色の割り当ては x7_1 と合わせると分かりやすくなります。

```matlab
figure(2)
clf

hold on
scatter(Trial_free,   Omega_free,   40, 'g', 'filled', 'DisplayName', 'free') ;
scatter(Trial_simple, Omega_simple, 40, 'b', 'filled', 'DisplayName', 'simple') ;
scatter(Trial_gonogo, Omega_gonogo, 40, 'r', 'filled', 'DisplayName', 'gonogo') ;
hold off

xlabel('試行番号') ;
ylabel('最大角速度 (deg/s)') ;
title(sprintf('Subject %02d : 試行別 スイングスピード', iSubject)) ;
legend('Location', 'best') ;
grid on ;
```

### 確認ポイント

- [ ] 散布図が3条件のドット（緑・青・赤）で表示されることを確認する
- [ ] 凡例が表示されることを確認する
- [ ] 試行が進むにつれてスイングスピードに変化の傾向があるか目視する

---

## 完成コードの全体像

```matlab
% x7_2_visualize_swing_speed.m

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
mask_free     = ResultsTable.Condition == "free" & ResultsTable.CueText == "Go" ;
Omega_free    = ResultsTable.PeakOmegaDeg(mask_free) ;
Trial_free    = ResultsTable.Trial(mask_free) ;

mask_simple   = ResultsTable.Condition == "simple" ;
Omega_simple  = ResultsTable.PeakOmegaDeg(mask_simple) ;
Trial_simple  = ResultsTable.Trial(mask_simple) ;

mask_gonogo   = ResultsTable.Condition == "gonogo" & ResultsTable.CueText == "Go" ;
Omega_gonogo  = ResultsTable.PeakOmegaDeg(mask_gonogo) ;
Trial_gonogo  = ResultsTable.Trial(mask_gonogo) ;

nanMask_free   = ~isnan(Omega_free) ;
Omega_free     = Omega_free(nanMask_free) ;
Trial_free     = Trial_free(nanMask_free) ;

nanMask_simple = ~isnan(Omega_simple) ;
Omega_simple   = Omega_simple(nanMask_simple) ;
Trial_simple   = Trial_simple(nanMask_simple) ;

nanMask_gonogo = ~isnan(Omega_gonogo) ;
Omega_gonogo   = Omega_gonogo(nanMask_gonogo) ;
Trial_gonogo   = Trial_gonogo(nanMask_gonogo) ;

% -----------------------------------------------------------------------
% STEP 2.5: 各条件の平均・SD を計算
% -----------------------------------------------------------------------
mean_free   = mean(Omega_free) ;
mean_simple = mean(Omega_simple) ;
mean_gonogo = mean(Omega_gonogo) ;

std_free    = std(Omega_free) ;
std_simple  = std(Omega_simple) ;
std_gonogo  = std(Omega_gonogo) ;

% -----------------------------------------------------------------------
% STEP 3: 箱ひげ図（figure 1）
% -----------------------------------------------------------------------
figure(1)
clf

allOmega = [Omega_free ; Omega_simple ; Omega_gonogo] ;
allLabel = [repmat({'free'},   length(Omega_free),   1) ; ...
            repmat({'simple'}, length(Omega_simple), 1) ; ...
            repmat({'gonogo'}, length(Omega_gonogo), 1) ] ;

boxplot(allOmega, allLabel, 'GroupOrder', {'free', 'simple', 'gonogo'}) ;

ylabel('最大角速度 (deg/s)') ;
title(sprintf('Subject %02d : 条件別 スイングスピード\nfree: %.0f±%.0f  /  simple: %.0f±%.0f  /  gonogo: %.0f±%.0f  deg/s', ...
    iSubject, mean_free, std_free, mean_simple, std_simple, mean_gonogo, std_gonogo)) ;
grid on ;

% -----------------------------------------------------------------------
% STEP 4: 各試行の散布図（figure 2）
% -----------------------------------------------------------------------
figure(2)
clf

hold on
scatter(Trial_free,   Omega_free,   40, 'g', 'filled', 'DisplayName', 'free') ;
scatter(Trial_simple, Omega_simple, 40, 'b', 'filled', 'DisplayName', 'simple') ;
scatter(Trial_gonogo, Omega_gonogo, 40, 'r', 'filled', 'DisplayName', 'gonogo') ;
hold off

xlabel('試行番号') ;
ylabel('最大角速度 (deg/s)') ;
title(sprintf('Subject %02d : 試行別 スイングスピード', iSubject)) ;
legend('Location', 'best') ;
grid on ;
```

---

## 全体の振り返りチェックリスト

- [ ] STEP 1: `load` でテーブルが読み込めた。`head(ResultsTable, 5)` で `PeakOmegaDeg` 列を確認した
- [ ] STEP 2: 条件別に `Omega_〇〇` を抽出できた。NaN が除外されていることを確認した
- [ ] STEP 2.5: `mean_free`・`mean_simple`・`mean_gonogo` がそれらしい値になっていることを確認した
- [ ] STEP 3: 箱ひげ図が3条件分表示された。タイトルに平均±SD が表示されている
- [ ] STEP 4: 散布図が3条件のドットで表示された。凡例も表示されている

---

*作成日: 2026-06-15*
