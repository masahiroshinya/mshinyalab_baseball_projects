% save_sample_data_fp.m
% 学習用フォースプレートサンプルデータ（合成データ）を生成・保存するスクリプト
% Generate and save synthetic force plate sample data for learning
%
% 【生成するデータ / Generated data】
%   Force1    : 後足（右足）フォースプレートデータ（ノイズあり）/ Back foot (right) with noise
%   Force2    : 前足（左足）フォースプレートデータ（ノイズあり）/ Front foot (left) with noise
%   Force1_true, Force2_true : ノイズなし真値（答え合わせ用）/ Noiseless true values (reference)
%   fs_fp     : フォースプレートのサンプリング周波数 [Hz] / Force plate sampling frequency
%   t         : 時間軸 [s, 列ベクトル] / Time axis (column vector)
%
%   各構造体のフィールド（いずれも列ベクトル [nSamples x 1]）
%   Fields of each structure (all column vectors [nSamples x 1]):
%     .Fz    鉛直方向の床反力 [N]   / Vertical ground reaction force [N]
%     .Fx    左右方向の床反力 [N]   / Medial-lateral GRF [N]
%     .Fy    前後方向の床反力 [N]   / Anterior-posterior GRF [N]
%     .CoPx  圧力中心の X 座標 [mm] / Center of pressure X [mm]
%     .CoPy  圧力中心の Y 座標 [mm] / Center of pressure Y [mm]
%
% 【想定場面 / Simulated scenario】
%   右打者のバットスイング（試行時間 3 秒）
%   A right-handed batter's bat swing (3-second trial)
%   t = 0.0 s : 構え（静止） / Quiet stance
%   t = 0.5 s : スイング開始（体重移動開始）/ Swing initiation (weight transfer begins)
%   t = 1.3 s : 床反力ピーク付近（インパクト直前）/ Peak GRF (just before contact)
%   t = 1.5 s : バット−ボール接触 / Bat-ball contact
%   t = 3.0 s : フォロースルー終了 / End of follow-through
%
% 【ノイズの構成 / Noise composition】
%   ・広帯域ランダムノイズ（白色雑音）: 力センサーの電気的ノイズを模擬
%     Broadband random noise: simulates electrical noise of force sensors
%   ・50 Hz 正弦波ノイズ（商用電源ハムノイズ）
%     50 Hz sine hum noise: simulates power-line interference
%
% 【実行方法 / How to run】
%   MATLABのカレントフォルダを s401_filter_mocap_data/ に設定してから実行すること
%   Set MATLAB current folder to s401_filter_mocap_data/ before running
% ---------------------------------------------------------------

clear
clc
rng(42)   % 乱数シードを固定して再現性を確保 / Fix random seed for reproducibility


% =======================================================================
% パラメータ / Parameters
% =======================================================================

fs_fp    = 1000 ;                               % フォースプレートのサンプリング周波数 [Hz]
duration = 3.0 ;                                % 試行の長さ [s]
t = (0 : 1/fs_fp : duration - 1/fs_fp)' ;      % 時間軸 [nSamples x 1]  ← 列ベクトル
nSamples = length(t) ;

% --- 体重 / Body weight ---
bodyWeight = 800 ;   % 体重由来の重力 [N] (≈ 80 kg × 9.8 m/s²)

% --- ノイズパラメータ / Noise parameters ---
noiseStd_F   =  5 ;   % 力の広帯域ランダムノイズ 標準偏差 [N]
noiseAmp_hum = 10 ;   % 商用電源ノイズ (50 Hz 正弦波) の振幅 [N]
noiseStd_CoP =  2 ;   % CoP のランダムノイズ 標準偏差 [mm]


% =======================================================================
% 体重移動プロファイルの生成 / Weight Transfer Profile
% =======================================================================

% --- シグモイド関数: w = 0（静止）→ 1（全荷重移動完了）---
% Sigmoid: w transitions from 0 (quiet stance) to 1 (full weight transfer)
%   center = 1.0 s : インパクト付近で中間点を通過 / midpoint near impact
%   slope  = 4     : 急峻すぎず緩やかすぎない傾き / moderate slope
w = 1 ./ (1 + exp(-4 * (t - 1.0))) ;
w(t < 0.3) = 0 ;   % スイング開始前の静止期間 / Pre-swing quiet phase

% --- 動的荷重係数: スイング中は GRF が体重を超える ---
% Dynamic loading factor: GRF exceeds body weight during the swing
% ガウス関数のピークを t=1.3 s（インパクト直前）に設定
% Gaussian peak placed at t=1.3 s (just before contact)
dynamicLoad = 1 + 0.35 * exp(-((t - 1.3).^2) / (2 * 0.3^2)) ;


% =======================================================================
% 真のシグナル（ノイズなし）の生成 / Generate True (Noiseless) Signals
% =======================================================================

% --- Force1（後足・右足）/ Back foot (right) ---

% Fz: 体重移動に伴い体重の 50% → 10% へ減少
%     Fz decreases from 50% to 10% of body weight as weight shifts forward
Force1_true.Fz = bodyWeight .* dynamicLoad .* (0.50 - 0.40 * w) ;

% Fx: スイング中に内側（左方向）へ力を入れる / Pushes medially during swing
%     sin 関数で開始・終了をなだらかに / Smooth rise and fall using sine
Force1_true.Fx =  60 * sin(pi * max(0, t - 0.4) / 2.2) .* (t >= 0.4 & t < 2.6) ;

% Fy: 後方への踏ん張り / Braces posteriorly
Force1_true.Fy =  30 * sin(pi * max(0, t - 0.5) / 2.0) .* (t >= 0.5 & t < 2.5) ;

% CoPx: 体重移動に伴い踵方向（＋）へシフト / Shifts toward heel (+direction)
Force1_true.CoPx = -10 + 60 * w ;

% CoPy: スイング中にわずかに横方向へシフト / Slight lateral shift during swing
Force1_true.CoPy =  10 * sin(pi * w) ;


% --- Force2（前足・左足）/ Front foot (left) ---

% Fz: 体重移動に伴い体重の 50% から増加し、インパクト付近でピーク
%     Increases from 50% BW; peaks near impact due to dynamic loading
Force2_true.Fz = bodyWeight .* dynamicLoad .* (0.50 + 0.40 * w) ;

% Fx: 外側（右方向）への制動力 / Braces laterally (opposite to Force1.Fx)
Force2_true.Fx = -80 * sin(pi * max(0, t - 0.4) / 2.2) .* (t >= 0.4 & t < 2.6) ;

% Fy: 前方への力 / Pushes anteriorly
Force2_true.Fy =  40 * sin(pi * max(0, t - 0.5) / 2.0) .* (t >= 0.5 & t < 2.5) ;

% CoPx: つま先（＋）から徐々に踵方向へシフト / From toe (+) shifting toward heel
Force2_true.CoPx =  20 - 30 * w ;

% CoPy: Force1 と逆方向のわずかな横方向シフト / Slight lateral shift (opposite)
Force2_true.CoPy = -10 * sin(pi * w) ;


% =======================================================================
% ノイズの追加 / Add Noise to Create Realistic Force Plate Signals
% =======================================================================

% --- ランダムノイズ（広帯域・白色雑音）/ Broadband random (white) noise ---
randNoise_F1 = noiseStd_F * randn(nSamples, 1) ;
randNoise_F2 = noiseStd_F * randn(nSamples, 1) ;

% --- 商用電源ノイズ（50 Hz 正弦波）/ Power-line hum noise (50 Hz sine) ---
% フォースプレートのアンプに商用電源（50 Hz）が混入することを模擬
% Simulates 50 Hz power-line interference entering the force plate amplifier
humNoise = noiseAmp_hum * sin(2*pi*50*t) ;

% --- ノイズを加えた構造体を生成 / Build noisy Force structures ---
fieldNames = fieldnames(Force1_true) ;
for k = 1 : length(fieldNames)
    fn = fieldNames{k} ;
    if length(fn) >= 3 && strcmp(fn(1:3), 'CoP')
        % CoP は力センサーの出力値から算出されるため、電気ノイズよりもランダムノイズが主体
        % CoP is derived from force outputs, so mainly random noise (less hum noise)
        Force1.(fn) = Force1_true.(fn) + noiseStd_CoP * randn(nSamples, 1) ;
        Force2.(fn) = Force2_true.(fn) + noiseStd_CoP * randn(nSamples, 1) ;
    else
        % 力データ（Fz, Fx, Fy）: 白色雑音 + ハムノイズが重畳
        % Force data: broadband white noise + 50 Hz hum noise
        Force1.(fn) = Force1_true.(fn) + randNoise_F1 + humNoise ;
        Force2.(fn) = Force2_true.(fn) + randNoise_F2 + humNoise ;
    end
end


% =======================================================================
% 保存 / Save
% =======================================================================

saveFilePath = 'SampleData_FP' ;
save(saveFilePath, 'Force1', 'Force1_true', 'Force2', 'Force2_true', 'fs_fp', 't') ;

fprintf('SampleData_FP.mat を保存しました / Saved SampleData_FP.mat\n') ;
fprintf('  サンプリング周波数 / fs_fp    : %d Hz\n',  fs_fp) ;
fprintf('  参考: モーキャプ   / fs_mocap : %d Hz\n',  200) ;
fprintf('  試行の長さ / Duration          : %.1f s (%d samples)\n', duration, nSamples) ;
fprintf('  フィールド / Fields            : %s\n', strjoin(fieldNames, ', ')) ;
fprintf('\nノイズパラメータ / Noise parameters:\n') ;
fprintf('  力のランダムノイズ 標準偏差      : %d N\n',  noiseStd_F) ;
fprintf('  50 Hz ハムノイズ（商用電源）振幅 : %d N\n',  noiseAmp_hum) ;
fprintf('  CoP のランダムノイズ 標準偏差    : %d mm\n', noiseStd_CoP) ;
fprintf('\n次のステップ: s401c_filter_forceplate.m を実行してください\n') ;
