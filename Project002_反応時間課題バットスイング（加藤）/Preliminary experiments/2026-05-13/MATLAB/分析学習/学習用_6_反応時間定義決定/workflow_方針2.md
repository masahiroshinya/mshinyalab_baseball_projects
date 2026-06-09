# 実装ワークフロー：方針2（剛体トラッキング専用版）

**作成日**: 2026-06-09
**適用実験**: 予備実験・および個別マーカーなしで剛体のみ計測した場合

---

## 方針2 の定義

| 要素 | 定義 |
|------|------|
| **使用データ** | バット剛体の**原点**（Qualisys で設定したグリップ端付近の基準点）の位置座標 |
| **速度方向** | **3D合成速度** |
| **閾値** | 被験者ごとの**全試行平均ピーク速度**の **10%** |
| **刺激開始点** | LED電圧が 2V を超えた最初のアナログサンプル |

> **重要な前提**：Qualisys Track Engineering で、バット剛体の原点をグリップ端付近に設定済みであることを確認してください。原点の位置は実験設計の段階で確認が必要です。

---

## 全体の処理の流れ

```
[STEP 0] データ構造を確認する（剛体原点のフィールド名を確認）
[STEP 1] 全試行の剛体原点 3D ピーク速度を収集する
[STEP 2] 全試行平均ピーク速度から閾値を設定する（10%）
[STEP 3] 1試行でスイング開始フレームを検出する（確認用）
[STEP 4] グラフで視覚的に確認する
[STEP 5] 全試行で RT を算出する
```

---

## STEP 0：データ構造を確認する（最初に必ず実施）

方針2では個別マーカーではなく**剛体原点の位置座標**を使います。
まず、Qualisys でバット剛体に付けた名前（ラベル）を確認してください。

```matlab
clear ; close all ; clc

iSubject = 1 ;
dataFilePath = sprintf('x3_DataChecked/Data%02d', iSubject) ;
load(dataFilePath)

Data = DataArray(1, 2) ;

% Markers のフィールド名をすべて表示する
disp('=== Data.Markers のフィールド名 ===')
disp(fieldnames(Data.Markers))
```

### 確認ポイント

- [ ] `fieldnames(Data.Markers)` を実行し、表示された名前を確認する
- [ ] バット剛体の原点に対応するフィールド名を特定する（例: `bat`、`Bat`、`bat_rb` など）
- [ ] 以下の `<剛体原点のフィールド名>` に、確認したフィールド名を記入する：`________`

> フィールド名が分からない場合は、AIアシスタントに確認してもらいましょう。

---

## STEP 1：全試行の剛体原点 3D ピーク速度を収集する

```matlab
% STEP 0 で確認したフィールド名を設定する（ここだけ書き換えればOK）
% 例: rbFieldName = 'Bat' ;
rbFieldName = '<剛体原点のフィールド名>' ;  % ← 書き換える

Prm        = parameters ;
iCondition = 2 ;
nTrial     = size(DataArray, 1) ;

peakVelRB_array = NaN(nTrial, 1) ;

for iTrial = 1:nTrial
    Data_i = DataArray(iTrial, iCondition) ;
    fs_i   = Data_i.FrameRate ;
    [b, a] = butter(2, Prm.Fc/(fs_i/2)) ;
    M_i    = filt_all_fields(b, a, Data_i.Markers) ;

    rb_i       = M_i.(rbFieldName) ;        % 剛体原点の位置座標 [n×3]
    velRB_i    = diff3p(rb_i, 1/fs_i) ;
    netVelRB_i = sum(velRB_i.^2, 2).^0.5 ; % 3D合成速度

    peakVelRB_array(iTrial) = max(netVelRB_i) ;
end

meanPeakVelRB = mean(peakVelRB_array, 'omitnan') ;
fprintf('全試行平均ピーク速度（剛体原点 3D）: %.1f mm/s\n', meanPeakVelRB) ;
```

### `M_i.(rbFieldName)` について

`M_i.bat` のように書く代わりに、変数に入れたフィールド名で `M_i.(rbFieldName)` とアクセスできます。
こうすることで、フィールド名が変わっても冒頭の1行だけ書き換えれば動きます。

### 3D合成速度の計算式

```
netVel = sqrt(vx^2 + vy^2 + vz^2)
```

MATLABでは `sum(velRB.^2, 2).^0.5` で表現します：
- `.^2`：各列を2乗する
- `sum(..., 2)`：行方向に合計する（各フレームで x²＋y²＋z² を計算）
- `.^0.5`：平方根をとる

### 確認ポイント

- [ ] ループが実行されエラーが出ないことを確認する
- [ ] `meanPeakVelRB` がコマンドウィンドウに表示されることを確認する
- [ ] 値が数千〜数万 mm/s 程度であることを確認する

---

## STEP 2：閾値を設定する（平均ピーク速度の 10%）

```matlab
threshold_2 = 0.10 * meanPeakVelRB ;
fprintf('方針2 の閾値: %.1f mm/s（平均ピーク速度の 10%%）\n', threshold_2) ;
```

### 確認ポイント

- [ ] `threshold_2` が `meanPeakVelRB` のおよそ 10% になっていることを確認する

---

## STEP 3：1試行でスイング開始フレームを検出する（確認用）

```matlab
iTrial = 1 ;
Data   = DataArray(iTrial, iCondition) ;
fs     = Data.FrameRate ;
[b, a] = butter(2, Prm.Fc/(fs/2)) ;
M      = filt_all_fields(b, a, Data.Markers) ;

% 剛体原点の 3D 合成速度
rb       = M.(rbFieldName) ;
velRB    = diff3p(rb, 1/fs) ;
netVelRB = sum(velRB.^2, 2).^0.5 ;

% LED タイミング
led        = Data.LEDData(:,2) ;
tCueAnalog = find(abs(led) > 2, 1, 'first') ;
tCueMarker = round(tCueAnalog / Data.AnalogFs * fs) ;

% スイング開始検出（LED 点灯後）
searchRange = tCueMarker : length(netVelRB) ;
idx2 = find(netVelRB(searchRange) > threshold_2, 1, 'first') ;

if isempty(idx2)
    tOnset2 = NaN ;
    RT2     = NaN ;
    fprintf('方針2：スイング開始が検出されませんでした\n') ;
else
    tOnset2 = searchRange(1) + idx2 - 1 ;
    RT2     = (tOnset2 - tCueMarker) / fs * 1000 ;
    fprintf('方針2：tSwingOnset = %d フレーム、RT = %.1f ms\n', tOnset2, RT2) ;
end
```

### 方針1 との比較

| | 方針1（X軸1次元速度） | 方針2（3D合成速度） |
|---|---|---|
| 速度の計算 | `abs(velBottom(:, 1))` | `sum(velRB.^2, 2).^0.5` |
| 感度 | X方向の動きのみ検出 | 全方向の動きを合算して検出 |
| ノイズの影響 | 方向が限定されるため安定しやすい | 全方向のノイズも含まれる |
| 適用条件 | `bottom` マーカーあり | 剛体トラッキングのみ |

### 確認ポイント

- [ ] `RT2` が表示されることを確認する
- [ ] RT2 がおおよそ 150〜600 ms であることを確認する
- [ ] `tOnset2 > tCueMarker` であることを確認する

---

## STEP 4：グラフで視覚的に確認する

```matlab
figure(12) ; clf
n      = length(netVelRB) ;
tArray = ([1:n] - tCueMarker) / fs ;

plot(tArray, netVelRB, 'b-') ; hold on
yline(threshold_2, 'k--') ;

if ~isnan(tOnset2)
    lineplot((tOnset2 - tCueMarker)/fs, 'v', 'r-')
end

set(gca, 'xlim', [-0.5, 2.0])
xlabel('Time from LED [s]')
ylabel('Rigid body origin speed [mm/s]')
title(sprintf('方針2（剛体3D速度）：RT = %.1f ms', RT2))
legend('剛体原点3D速度', '閾値(10%)', 'スイング開始', 'Location', 'northwest')
```

### 確認ポイント

- [ ] 剛体原点の 3D 速度波形が表示されることを確認する
- [ ] 黒い破線（閾値）と赤い縦線（スイング開始）が正しい位置に表示されることを確認する
- [ ] 縦線がスイング開始よりも前の時刻に来ていないかを確認する

---

## STEP 5：全試行で RT を算出する

```matlab
RT2_array = NaN(nTrial, 1) ;

for iTrial = 1:nTrial
    Data_i = DataArray(iTrial, iCondition) ;
    fs_i   = Data_i.FrameRate ;
    [b, a] = butter(2, Prm.Fc/(fs_i/2)) ;
    M_i    = filt_all_fields(b, a, Data_i.Markers) ;

    rb_i       = M_i.(rbFieldName) ;
    velRB_i    = diff3p(rb_i, 1/fs_i) ;
    netVelRB_i = sum(velRB_i.^2, 2).^0.5 ;

    led_i        = Data_i.LEDData(:,2) ;
    tCueAnalog_i = find(abs(led_i) > 2, 1, 'first') ;
    tCueMarker_i = round(tCueAnalog_i / Data_i.AnalogFs * fs_i) ;

    searchRange_i = tCueMarker_i : length(netVelRB_i) ;
    idx_i = find(netVelRB_i(searchRange_i) > threshold_2, 1, 'first') ;

    if ~isempty(idx_i)
        tOnset_i         = searchRange_i(1) + idx_i - 1 ;
        RT2_array(iTrial) = (tOnset_i - tCueMarker_i) / fs_i * 1000 ;
    end
end

fprintf('=== 方針2 の全試行 RT ===\n') ;
for iTrial = 1:nTrial
    fprintf('試行 %2d: RT = %.1f ms\n', iTrial, RT2_array(iTrial)) ;
end
fprintf('平均 RT（方針2）= %.1f ms\n', mean(RT2_array, 'omitnan')) ;
```

### 確認ポイント

- [ ] 全試行の RT が表示されることを確認する
- [ ] NaN がある試行はグラフで個別確認する
- [ ] 平均 RT が 150〜600 ms 程度であることを確認する

---

## 全体の振り返りチェックリスト

- [ ] STEP 0：`fieldnames(Data.Markers)` で剛体原点のフィールド名を確認し、`rbFieldName` に設定した
- [ ] STEP 1：全試行の剛体原点 3D ピーク速度の平均を算出した
- [ ] STEP 2：閾値（平均ピーク速度の 10%）を設定した
- [ ] STEP 3：1試行でスイング開始フレームと RT を検出した
- [ ] STEP 4：グラフで縦線の位置を目視確認した
- [ ] STEP 5：全試行で RT を算出し、平均値を確認した

---

*作成日: 2026-06-09*
