% s401c_filter_forceplate.m
%
% 【学習目標 / Learning Goal】
%   フォースプレートデータ（床反力 GRF・圧力中心 CoP）に
%   バターワースフィルターを適用し、モーキャプデータとの違いを理解する
%
%   Apply a Butterworth filter to force plate data (GRF and CoP),
%   and understand the key differences from motion capture data filtering.
%
% 【主要な学習ポイント / Key Learning Points】
%   1. フォースプレートはサンプリング周波数が高い (fs_fp = 1000 Hz vs mocap 200 Hz)
%      Force plates have a higher sampling frequency than mocap
%   2. フィルターの設計・適用コードは s401_filter_mocap_data.m と同じ構造
%      The filter design code has the same structure as s401_filter_mocap_data.m
%   3. 逆ダイナミクス計算を行うとき fc はモーキャプと同じ値に揃える必要がある
%      For inverse dynamics: use the SAME fc as mocap data (avoids artifact)
%   4. Section 6 で「fc が不一致のとき何が起きるか」を実際に確認できる（発展）
%      Section 6 shows what happens when fc is mismatched (advanced)
%
% 【実行前に実行すること / Prerequisite】
%   save_sample_data_fp.m を先に実行して SampleData_FP.mat を作成すること
%   Run save_sample_data_fp.m first to create SampleData_FP.mat
%
% 【実行方法 / How to run】
%   MATLABのカレントフォルダを s401_filter_mocap_data/ に設定してから実行
%   Set MATLAB current folder to s401_filter_mocap_data/ before running
% -----------------------------------------------------------------------

clear
close all
clc


% =======================================================================
% ユーティリティ関数のパスを追加 / Add path to utility functions
% filt_all_fields.m は2階層上の MATLAB/ フォルダにある
% filt_all_fields.m is located in the MATLAB/ folder, two levels up
% =======================================================================
addpath('../../')


% =======================================================================
% Section 1: データ読み込みとサンプリング周波数の確認
%            Load Data and Confirm Sampling Frequency
% =======================================================================

% SampleData_FP.mat から Force 構造体を読み込む
% Load Force structures from SampleData_FP.mat
%   読み込まれる変数 / Loaded variables:
%     Force1, Force1_true : 後足（右足）データ / Back foot (right)
%     Force2, Force2_true : 前足（左足）データ / Front foot (left)
%     fs_fp               : サンプリング周波数 / Sampling frequency [Hz]
%     t                   : 時間軸 [s]
load('SampleData_FP.mat') ;

nSamples = length(t) ;

fprintf('===== Section 1: サンプリング周波数の確認 =====\n') ;
fprintf('  フォースプレート    fs_fp   : %d Hz\n', fs_fp) ;
fprintf('  モーキャプ（参考）  fs_mocap: %d Hz\n', 200) ;
fprintf('  → フォースプレートはモーキャプの %d 倍のサンプリング密度\n\n', fs_fp / 200) ;

% ---- ここで考えてみよう / Think about this ----
% Q: サンプリング周波数が高いと、何が「より細かく」記録されるのか？
%    What does a higher sampling frequency record more finely?
% A: 時間分解能（1秒間に記録するデータ点の数）が増える。
%    力の急激な変化（インパクトの瞬間など）も見逃さずに記録できる。
%    Time resolution increases; rapid force changes (e.g. at impact) are captured.


% =======================================================================
% Section 2: フィルターパラメータの設定 / Set Filter Parameters
% =======================================================================

% --- カットオフ周波数 / Cutoff frequency ---
% 【重要】逆ダイナミクス計算（関節トルク算出）を行う場合、
%         フォースプレートの fc をモーキャプの fc と必ず揃えること！
% [IMPORTANT] For inverse dynamics (joint torque calculation),
%             always use the SAME fc as the mocap filter!
fc_fp = 30 ;   % カットオフ周波数 [Hz]  ← モーキャプと同じ値

% --- フィルター次数 / Filter order ---
% モーキャプと同じ order = 2 を使用
% filtfilt で順・逆方向に2回かけるため実質 4 次相当の減衰特性になる
% filtfilt applies the filter twice (forward + backward), giving effective 4th-order roll-off
order = 2 ;

fprintf('===== Section 2: フィルターパラメータ =====\n') ;
fprintf('  カットオフ周波数  fc_fp : %d Hz  ← モーキャプと同じ値に揃えている\n', fc_fp) ;
fprintf('  フィルター次数    order : %d\n', order) ;
fprintf('  （filtfilt で実質 %d 次相当の特性）\n\n', order * 2) ;


% =======================================================================
% Section 3: バターワースフィルターの設計と適用
%            Design and Apply Butterworth Filter
% =======================================================================

% --- 正規化カットオフ周波数 Wn の計算 / Compute normalized cutoff frequency Wn ---
% ナイキスト周波数（= fs/2）で正規化する
% Normalized by the Nyquist frequency (= fs/2)
Wn = fc_fp / (fs_fp / 2) ;
[b_fp, a_fp] = butter(order, Wn, 'low') ;

fprintf('===== Section 3: フィルター設計 =====\n') ;
fprintf('  Wn（正規化カットオフ）    : %.4f\n',   Wn) ;
fprintf('  モーキャプのとき          : %.4f  (fc=30, fs=200  → 30/100)\n', 30/100) ;
fprintf('  フォースプレートのとき    : %.4f  (fc=30, fs=1000 → 30/500)\n', 30/500) ;
fprintf('\n  → Wn の数値は違うが、fc [Hz] が意味する「遮断する周波数」は同じ！\n') ;
fprintf('    butter() は Wn が同じなら fs によらず同じ「形」のフィルターを作る。\n') ;
fprintf('    fs が変わっても fc [Hz] を揃えれば、同じ帯域を遮断できる。\n\n') ;

% --- フィルターの適用 / Apply filter ---
% filt_all_fields() は構造体の全フィールドに filtfilt() を一括適用する
% filt_all_fields() applies filtfilt() to every field of the structure
Force1_filt = filt_all_fields(b_fp, a_fp, Force1) ;
Force2_filt = filt_all_fields(b_fp, a_fp, Force2) ;

fprintf('  フィルタリング完了 / Filtering complete\n') ;
fprintf('  Force1_filt, Force2_filt を生成しました\n\n') ;


% =======================================================================
% Section 4: 床反力（GRF）の可視化
%            Visualize Ground Reaction Forces (GRF)
% =======================================================================

% Force1（後足）と Force2（前足）の Fz, Fx, Fy を左右に並べてプロット
% Plot Fz, Fx, Fy for Force1 (back) and Force2 (front) side by side

figure(1)
set(gcf, 'Name', 'Figure 1: GRF — Raw vs Filtered', ...
         'Position', [30 60 1100 750])

fields_GRF  = {'Fz',      'Fx',              'Fy'} ;
ylabels_GRF = {'Fz [N]',  'Fx [N]',          'Fy [N]'} ;
ytitles_GRF = {'Fz (Vertical GRF / 鉛直床反力)', ...
               'Fx (Medial-Lateral / 左右方向)', ...
               'Fy (Anterior-Posterior / 前後方向)'} ;

for iField = 1 : 3
    fn = fields_GRF{iField} ;

    % --- 左列: Force1（後足）/ Left column: Force1 (back foot) ---
    subplot(3, 2, (iField - 1) * 2 + 1)
    plot(t, Force1.(fn),      'Color', [0.75 0.75 0.75], 'LineWidth', 0.8) ; hold on
    plot(t, Force1_true.(fn), 'b--',                     'LineWidth', 1.0) ;
    plot(t, Force1_filt.(fn), 'k-',                      'LineWidth', 1.5) ;
    ylabel(ylabels_GRF{iField})
    if iField == 1
        title('Force1  (Back foot / 後足)')
        legend('Raw (with noise)', 'True (noiseless)', 'Filtered', ...
               'Location', 'best')
    end
    if iField == 3 ;  xlabel('Time [s]') ; end
    grid on

    % --- 右列: Force2（前足）/ Right column: Force2 (front foot) ---
    subplot(3, 2, (iField - 1) * 2 + 2)
    plot(t, Force2.(fn),      'Color', [0.75 0.75 0.75], 'LineWidth', 0.8) ; hold on
    plot(t, Force2_true.(fn), 'b--',                     'LineWidth', 1.0) ;
    plot(t, Force2_filt.(fn), 'k-',                      'LineWidth', 1.5) ;
    if iField == 1
        title('Force2  (Front foot / 前足)')
    end
    if iField == 3 ;  xlabel('Time [s]') ; end
    grid on
end

sgtitle(sprintf('GRF Filtering   (fc = %d Hz,  fs\\_fp = %d Hz)', fc_fp, fs_fp), ...
        'FontSize', 13, 'FontWeight', 'bold')

% ---- 確認ポイント / Check Points ----
fprintf('===== Section 4: GRF グラフの確認ポイント =====\n') ;
fprintf('  ・Force2.Fz（前足・鉛直）はスイング開始後に増加し、インパクト付近でピークとなる\n') ;
fprintf('    Front foot Fz increases during swing and peaks near impact\n') ;
fprintf('  ・フィルター後（黒線）は真値（青破線）のほぼ中心を通っていることを確認せよ\n') ;
fprintf('    The filtered signal (black) should trace the center of the true signal (dashed blue)\n') ;
fprintf('  ・グラフを拡大してノイズ除去の効果を確認しよう（Step 3 と同様）\n') ;
fprintf('    Zoom in to verify noise removal, just like in Step 3\n\n') ;


% =======================================================================
% Section 5: 圧力中心（CoP）の可視化
%            Visualize Center of Pressure (CoP)
% =======================================================================

figure(2)
set(gcf, 'Name', 'Figure 2: CoP — Raw vs Filtered', ...
         'Position', [80 50 1100 520])

FP_raw  = {Force1,      Force2} ;
FP_true = {Force1_true, Force2_true} ;
FP_filt = {Force1_filt, Force2_filt} ;
foot_labels = {'Force1  (Back foot / 後足)', 'Force2  (Front foot / 前足)'} ;

for iFoot = 1 : 2

    % --- CoPx の時系列 / CoPx time series ---
    subplot(2, 2, (iFoot - 1) * 2 + 1)
    plot(t, FP_raw{iFoot}.CoPx,  'Color', [0.75 0.75 0.75], 'LineWidth', 0.8) ; hold on
    plot(t, FP_true{iFoot}.CoPx, 'b--', 'LineWidth', 1.0) ;
    plot(t, FP_filt{iFoot}.CoPx, 'k-',  'LineWidth', 1.5) ;
    title([foot_labels{iFoot}, '  —  CoPx'])
    ylabel('CoPx [mm]') ;  xlabel('Time [s]')
    if iFoot == 1
        legend('Raw', 'True', 'Filtered', 'Location', 'best')
    end
    grid on

    % --- CoPy の時系列 / CoPy time series ---
    subplot(2, 2, (iFoot - 1) * 2 + 2)
    plot(t, FP_raw{iFoot}.CoPy,  'Color', [0.75 0.75 0.75], 'LineWidth', 0.8) ; hold on
    plot(t, FP_true{iFoot}.CoPy, 'b--', 'LineWidth', 1.0) ;
    plot(t, FP_filt{iFoot}.CoPy, 'k-',  'LineWidth', 1.5) ;
    title([foot_labels{iFoot}, '  —  CoPy'])
    ylabel('CoPy [mm]') ;  xlabel('Time [s]')
    grid on

end

sgtitle(sprintf('CoP Filtering   (fc = %d Hz,  fs\\_fp = %d Hz)', fc_fp, fs_fp), ...
        'FontSize', 13, 'FontWeight', 'bold')

% ---- 確認ポイント / Check Points ----
fprintf('===== Section 5: CoP グラフの確認ポイント =====\n') ;
fprintf('  ・Force1（後足）の CoPx はスイング中に踵方向（＋）へ移動する\n') ;
fprintf('    Force1 CoPx shifts toward heel (+) during swing\n') ;
fprintf('  ・CoP のランダムノイズは力のノイズ（5N）より小さい（2mm）\n') ;
fprintf('    CoP noise (2mm) is smaller than force noise (5N) — why? (hint: derived value)\n') ;
fprintf('  ・フィルター後の CoP の滑らかさを確認しよう\n\n') ;


% =======================================================================
% Section 6: 【発展】カットオフ周波数の不一致問題
%            [Advanced] The Cutoff Frequency Mismatch Problem
%
% 【背景 / Background】
%   将来、関節トルク（逆ダイナミクス）を計算するとき、
%   キネマティクス（位置データ）× キネティクス（力データ）を掛け合わせる。
%   このとき、両者の fc が異なると、インパクトなど力の急変点で
%   「偽の関節トルク（アーティファクト）」が発生することが知られている。
%
%   When computing joint torques (inverse dynamics), kinematics (position)
%   is multiplied with kinetics (force). If their fc values differ,
%   spurious joint torques (artifacts) appear at rapid force transitions.
%
% 【この Section でやること / What to do here】
%   fc_fp を 30 Hz（正しい値）と 100 Hz（あえて間違えた値）で比較する。
%   フォースプレートに高周波ノイズが残ることを確認する。
%   Compare fc_fp = 30 Hz (correct) vs 100 Hz (wrong) to see residual noise.
% =======================================================================

fc_wrong  = 100 ;   % あえて高い fc を設定（本来はモーキャプと同じ 30 Hz にすべき）
Wn_wrong  = min(fc_wrong / (fs_fp / 2), 0.99) ;
[b_wrong, a_wrong] = butter(order, Wn_wrong, 'low') ;
Force1_wrong = filt_all_fields(b_wrong, a_wrong, Force1) ;

figure(3)
set(gcf, 'Name', 'Figure 3: [Advanced] Cutoff Frequency Mismatch — Force1.Fz', ...
         'Position', [130 40 1050 440])

plot(t, Force1.Fz,       'Color', [0.75 0.75 0.75], 'LineWidth', 0.8) ; hold on
plot(t, Force1_true.Fz,  'b--',                     'LineWidth', 1.2) ;
plot(t, Force1_filt.Fz,  'k-',                      'LineWidth', 2.0) ;
plot(t, Force1_wrong.Fz, 'r-',                      'LineWidth', 1.5) ;

xlabel('Time [s]')
ylabel('Fz [N]')
title('Force1.Fz  —  Cutoff Frequency Mismatch Comparison')
legend('Raw (with noise)', ...
       'True (noiseless)', ...
       sprintf('Filtered  fc = %d Hz  ← correct (matches mocap)', fc_fp), ...
       sprintf('Filtered  fc = %d Hz  ← wrong (too high, noise remains)', fc_wrong), ...
       'Location', 'best')
grid on

% ---- 発展トピックのまとめ / Summary of Advanced Topic ----
fprintf('===== Section 6: 発展トピック / Advanced Topic =====\n') ;
fprintf('  fc_fp = %d Hz（高すぎる値）でフィルターした場合（赤線）:\n', fc_wrong) ;
fprintf('  → ノイズが十分に除去されず、高周波成分が残る\n') ;
fprintf('  → もしこのデータで逆ダイナミクスを計算すると、\n') ;
fprintf('    インパクトなど力の急変点で偽の関節トルクが発生するリスクがある\n') ;
fprintf('  → 解決策: fc_fp = fc_mocap = %d Hz に統一すること\n\n', fc_fp) ;


% =======================================================================
% 完了メッセージ / Completion Message
% =======================================================================

fprintf('===== すべての処理が完了しました / All sections complete =====\n') ;
fprintf('  Figure 1: GRF（床反力）のフィルタリング前後の比較\n') ;
fprintf('            GRF comparison: Raw vs Filtered\n') ;
fprintf('  Figure 2: CoP（圧力中心）のフィルタリング前後の比較\n') ;
fprintf('            CoP comparison: Raw vs Filtered\n') ;
fprintf('  Figure 3: カットオフ周波数の不一致が与える影響（発展）\n') ;
fprintf('            Effect of cutoff frequency mismatch [Advanced]\n') ;
fprintf('\n確認ポイント / What to verify:\n') ;
fprintf('  1. Figure 1 を拡大して、フィルター後（黒）が真値（青破線）の\n') ;
fprintf('     中心を時間軸方向にズレなく通ること（ゼロ位相の証拠）を確認する\n') ;
fprintf('  2. Figure 1 の Force2.Fz（前足・鉛直）のピークの大きさを確認する\n') ;
fprintf('     （スイング中は体重 800N を大きく超えていることが分かる）\n') ;
fprintf('  3. Figure 3 で赤線と黒線を比較し、fc の違いによるノイズ残存を確認する\n') ;
