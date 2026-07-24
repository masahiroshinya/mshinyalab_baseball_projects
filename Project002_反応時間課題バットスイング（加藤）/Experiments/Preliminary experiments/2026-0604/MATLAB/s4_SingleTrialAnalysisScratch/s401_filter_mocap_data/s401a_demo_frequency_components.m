% s401a_demo_frequency_components.m
%
% 【学習目標 / Learning Goal】
%   信号の「周波数成分」とは何かを理解する
%   Understand what "frequency components" of a signal mean
%
% 【内容 / Contents】
%   Figure 1: 3種類の成分信号を時間領域・周波数領域で比較する
%             Compare three signal components in time and frequency domains
%     Row 1 : 低周波成分（身体運動）/ Low-freq component (body motion)
%     Row 2 : 50 Hz 正弦波ノイズ（EMG ハムノイズの例）
%             50 Hz sine noise (example of EMG hum noise)
%     Row 3 : ランダムノイズ randn（実際のモーキャプノイズに近い例）
%             Random noise via randn (closer to real motion capture noise)
%
%   Figure 2: 2種類の合成信号を比較し、ノイズのタイプによる違いを確認する
%             Compare two combined signals to see the effect of noise type
%     Row 1 : 運動 + 50 Hz 正弦波ノイズ / Motion + 50 Hz sine noise
%     Row 2 : 運動 + ランダムノイズ / Motion + random noise
%
% 【ポイント / Key Point】
%   実際のモーキャプノイズは、50 Hz 正弦波のように特定の周波数に集中せず、
%   広い周波数帯域にわたるランダムノイズである（白色雑音に近い）。
%   EMG のような電気生理計測ではハムノイズ（50/60 Hz）が現れることがある。
%
%   Real motion capture noise is not concentrated at a single frequency
%   like a 50 Hz sine wave, but is broadband random noise (close to white noise).
%   EMG-type physiological measurements can show hum noise at 50/60 Hz.
%
% 【実行方法 / How to run】
%   MATLABのカレントフォルダを s401_filter_mocap_data/ に設定してから実行
%   Set MATLAB current folder to s401_filter_mocap_data/ before running
% -----------------------------------------------------------------------

clear
close all
clc


% =======================================================================
% パラメータ / Parameters
% =======================================================================

rng(42) ;  % 乱数シードを固定して再現性を確保 / Fix random seed for reproducibility

fs       = 200 ;                        % サンプリング周波数 / Sampling frequency [Hz]
duration = 3 ;                          % 信号の長さ / Signal duration [s]
t = (0 : 1/fs : duration - 1/fs) ;     % 時間軸 / Time axis [s]


% =======================================================================
% 信号の生成 / Generate Signals
% =======================================================================

% --- 低周波成分: バットスイングのような身体運動に対応 ---
% Low-frequency component: represents body movements like bat swings
f_low = 3 ;      % 周波数 / Frequency [Hz]
A_low = 100 ;    % 振幅 / Amplitude [mm]
signal_motion = A_low * sin(2*pi*f_low*t) ;

% --- ノイズ例 A: 50 Hz 正弦波（EMG などのハムノイズに相当）---
% Noise example A: 50 Hz sine wave (equivalent to EMG hum noise)
% 電源周波数に起因するハムノイズは特定の周波数に鋭いピークをもつ
% Hum noise caused by power-line frequency shows a sharp peak at that frequency
f_hum = 50 ;     % 周波数 / Frequency [Hz]
A_hum = 5 ;      % 振幅 / Amplitude [mm]
noise_hum = A_hum * sin(2*pi*f_hum*t) ;

% --- ノイズ例 B: ランダムノイズ（実際のモーキャプノイズに近い）---
% Noise example B: random noise (closer to real motion capture noise)
% 反射マーカーの微小振動や計測系の電気的ノイズは、
% 特定の周波数ではなく広い帯域に分布するランダムノイズとなる
% Marker vibrations and electronic noise are distributed across a broad
% frequency band, not concentrated at a single frequency
noise_std  = 3 ;                        % 標準偏差（ノイズ強度）/ Noise standard deviation [mm]
noise_rand = noise_std * randn(size(t)) ;


% =======================================================================
% FFT によるパワースペクトルの計算 / Compute Power Spectrum via FFT
% =======================================================================

N      = length(t) ;
f_axis = (0 : N-1) * fs / N ;    % 周波数軸 / Frequency axis [Hz]
idx    = 1 : N/2+1 ;             % 片側スペクトルのインデックス / One-sided index
f_plot = f_axis(idx) ;

% 各成分のパワースペクトルを計算し、片側スペクトルに変換する
% Compute power spectrum of each component and extract the one-sided spectrum
% 注意: MATLAB では ps(x)(idx) のような連鎖インデックスは使えないため2行に分割
% Note: MATLAB does not support chained indexing like ps(x)(idx); split into two steps
PS_motion     = 2 * abs(fft(signal_motion))             / N ;  PS_motion     = PS_motion(idx) ;
PS_hum        = 2 * abs(fft(noise_hum))                 / N ;  PS_hum        = PS_hum(idx) ;
PS_rand       = 2 * abs(fft(noise_rand))                / N ;  PS_rand       = PS_rand(idx) ;
PS_combined_A = 2 * abs(fft(signal_motion + noise_hum)) / N ;  PS_combined_A = PS_combined_A(idx) ;
PS_combined_B = 2 * abs(fft(signal_motion + noise_rand))/ N ;  PS_combined_B = PS_combined_B(idx) ;


% =======================================================================
% Figure 1: 3種類の成分の比較 / Compare Three Signal Components
% =======================================================================

tRange = [0, 0.5] ;   % 表示する時間範囲 / Time range to display [s]
fRange = [0, fs/2] ;  % 表示する周波数範囲 / Frequency range [Hz]

figure(1)
set(gcf, 'Name', 'Figure 1: Component Comparison', ...
         'Position', [30 80 1050 700])

% --- Row 1: 身体運動成分 / Body motion component ---
subplot(3, 2, 1)
plot(t, signal_motion, 'b-', 'LineWidth', 1.5)
ylabel('Amplitude [mm]')
title(sprintf('Motion component: %d Hz sine', f_low))
set(gca, 'XLim', tRange) ; grid on

subplot(3, 2, 2)
plot(f_plot, PS_motion, 'b-', 'LineWidth', 1.5)
ylabel('Power [mm]')
title('Power Spectrum')
set(gca, 'XLim', fRange) ; grid on

% --- Row 2: ハムノイズ（50 Hz 正弦波）/ Hum noise (50 Hz sine) ---
subplot(3, 2, 3)
plot(t, noise_hum, 'r-', 'LineWidth', 1.5)
ylabel('Amplitude [mm]')
title(sprintf('Hum noise example: %d Hz sine  (e.g. EMG)', f_hum))
set(gca, 'XLim', tRange) ; grid on

subplot(3, 2, 4)
plot(f_plot, PS_hum, 'r-', 'LineWidth', 1.5)
ylabel('Power [mm]')
% 50 Hz に鋭いピークが1本だけ現れることを示す
% Shows a single sharp peak at 50 Hz
xline(f_hum, 'r--', 'LineWidth', 1, 'Label', sprintf('%d Hz', f_hum))
set(gca, 'XLim', fRange) ; grid on

% --- Row 3: ランダムノイズ (randn) / Random noise ---
subplot(3, 2, 5)
plot(t, noise_rand, 'Color', [0.5 0.5 0.5], 'LineWidth', 1)
ylabel('Amplitude [mm]')
xlabel('Time [s]')
title(sprintf('Random noise: randn  (std = %d mm)', noise_std))
set(gca, 'XLim', tRange) ; grid on

subplot(3, 2, 6)
plot(f_plot, PS_rand, 'Color', [0.5 0.5 0.5], 'LineWidth', 1)
ylabel('Power [mm]')
xlabel('Frequency [Hz]')
% パワーが全周波数帯域に広く分布することを示す（白色雑音）
% Shows power distributed broadly across all frequencies (white noise)
set(gca, 'XLim', fRange) ; grid on


% =======================================================================
% Figure 2: 合成信号のノイズタイプ別比較 / Combined Signal Comparison
% =======================================================================

figure(2)
set(gcf, 'Name', 'Figure 2: Combined Signal Comparison', ...
         'Position', [80 60 1050 550])

% --- Row 1: 運動 + ハムノイズ / Motion + hum noise ---
subplot(2, 2, 1)
plot(t, signal_motion + noise_hum, 'r-', 'LineWidth', 1)
ylabel('Amplitude [mm]')
title(sprintf('Motion + Hum Noise (%d Hz sine)', f_hum))
set(gca, 'XLim', tRange) ; grid on

subplot(2, 2, 2)
plot(f_plot, PS_combined_A, 'r-', 'LineWidth', 1.5)
ylabel('Power [mm]')
title('Power Spectrum')
xline(f_low, 'b:', 'LineWidth', 1, 'Label', sprintf('%d Hz (motion)', f_low))
xline(f_hum, 'r:', 'LineWidth', 1, 'Label', sprintf('%d Hz (hum)', f_hum))
set(gca, 'XLim', fRange) ; grid on

% --- Row 2: 運動 + ランダムノイズ / Motion + random noise ---
subplot(2, 2, 3)
plot(t, signal_motion + noise_rand, 'Color', [0.4 0.4 0.4], 'LineWidth', 1)
ylabel('Amplitude [mm]')
xlabel('Time [s]')
title('Motion + Random Noise  (closer to real mocap noise)')
set(gca, 'XLim', tRange) ; grid on

subplot(2, 2, 4)
plot(f_plot, PS_combined_B, 'Color', [0.4 0.4 0.4], 'LineWidth', 1.5)
ylabel('Power [mm]')
xlabel('Frequency [Hz]')
xline(f_low, 'b:', 'LineWidth', 1.5, 'Label', sprintf('%d Hz (motion)', f_low))
set(gca, 'XLim', fRange) ; grid on


% =======================================================================
% 確認ポイント / Check Points
% =======================================================================

fprintf('\n--- 確認ポイント / Check Points (Figure 1) ---\n')
fprintf('・ハムノイズ（50 Hz 正弦波）はパワースペクトルに鋭いピークが1本現れる\n')
fprintf('  Hum noise (50 Hz sine) shows a single sharp peak in the power spectrum\n')
fprintf('・ランダムノイズ (randn) はパワーが全周波数帯域に広く分布する（白色雑音）\n')
fprintf('  Random noise has power distributed across all frequencies (white noise)\n')
fprintf('\n--- 確認ポイント / Check Points (Figure 2) ---\n')
fprintf('・どちらの合成信号も時間領域では「ノイズが乗っている」ように見える\n')
fprintf('  Both combined signals look "noisy" in the time domain\n')
fprintf('・パワースペクトルで見ると、ノイズのタイプによって分布が大きく異なる\n')
fprintf('  The power spectrum reveals the very different distribution of each noise type\n')
fprintf('・実際のモーキャプノイズはランダムノイズ（右）に近い\n')
fprintf('  Real motion capture noise is closer to random noise (right)\n')
fprintf('  → 次のステップ (s401b) でフィルターをかけて確認しよう\n')
fprintf('     Next: apply a filter in s401b and see the effect\n')
