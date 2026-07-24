% s401_filter_mocap_data.m
%
% モーションキャプチャデータにバターワースローパスフィルターを適用する
% Apply a Butterworth low-pass filter to motion capture data
%
% 【実行方法 / How to run】
%   MATLABのカレントフォルダを s401_filter_mocap_data/ に設定してから実行すること
%   Set the MATLAB current folder to s401_filter_mocap_data/ before running
%
% 【入力 / Input】
%   SampleData.mat: Markers 構造体 / Markers structure
%     Markers.top    [nFrames x 3]  バット先端のXYZ座標 / Bat top marker XYZ
%     Markers.bottom [nFrames x 3]  バット末端のXYZ座標 / Bat bottom marker XYZ
%
% 【出力 / Output】
%   Markers_filt: フィルター適用後の Markers 構造体
%                 Markers structure after filtering
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
% データ読み込み / Load Data
% =======================================================================

% SampleData.mat から Markers 構造体を読み込む
% Load the Markers structure from SampleData.mat
load('SampleData.mat')


% =======================================================================
% フィルターパラメータの設定 / Set Filter Parameters
% =======================================================================

% サンプリング周波数 [Hz]
% Sampling frequency [Hz]
% Qualisys の計測設定値に合わせること（Data.FrameRate で確認できる）
% Should match the Qualisys capture setting (check via Data.FrameRate)
fs = 200 ;

% カットオフ周波数 [Hz]
% Cutoff frequency [Hz]
% これ以上の高周波成分が除去される。生体力学では 10–30 Hz が一般的
% Frequencies above this value are attenuated. 10–30 Hz is typical in biomechanics
fc = 30 ;

% バターワースフィルターの次数 / Butterworth filter order
% 次数が高いほど急峻な減衰特性になるが、リンギング（波打ち）が生じやすくなる
% Higher order gives steeper roll-off but increases the risk of ringing artifacts
order = 2 ;


% =======================================================================
% バターワースフィルターの設計 / Design Butterworth Filter
% =======================================================================

% butter() は正規化カットオフ周波数を引数にとる（ナイキスト周波数 = fs/2 で正規化）
% butter() takes a normalized cutoff frequency (normalized by Nyquist = fs/2)
Wn = fc / (fs / 2) ;
[b, a] = butter(order, Wn, 'low') ;


% =======================================================================
% フィルターの適用 / Apply Filter
% =======================================================================

% filt_all_fields() は Markers 構造体の全フィールドに filtfilt() を一括適用する
% filt_all_fields() applies filtfilt() to every field of the Markers structure
%
% filtfilt() は順方向・逆方向の2回フィルタリングを行い、位相遅れをゼロにする
% filtfilt() filters forward and backward to achieve zero phase delay
Markers_filt = filt_all_fields(b, a, Markers) ;


% =======================================================================
% 結果の表示 / Display Results
% =======================================================================

fprintf('フィルタリング完了 / Filtering complete\n') ;
fprintf('  サンプリング周波数 / fs : %d Hz\n', fs) ;
fprintf('  カットオフ周波数   / fc : %d Hz\n', fc) ;
fprintf('  フィルター次数  / order : %d\n', order) ;


% =======================================================================
% 可視化 / Visualization
% =======================================================================

% 時間軸の作成 / Create time axis
nFrames = size(Markers.top, 1) ;
tArray  = (1:nFrames) / fs ;  % [s]

% --- Figure 1: Markers.top のXYZ成分 / XYZ components of Markers.top ---
figure(1)

subplot(3, 1, 1)  % X 成分 / X-component
plot(tArray, Markers.top(:, 1),      'Color', [0.75 0.75 0.75], 'LineWidth', 1) ; hold on
plot(tArray, Markers_filt.top(:, 1), 'k-',   'LineWidth', 1.5) ;
ylabel('x [mm]')
legend('Raw', 'Filtered', 'Location', 'best')
title('Markers.top — フィルタリング前後の比較 / Raw vs Filtered')
grid on

subplot(3, 1, 2)  % Y 成分 / Y-component
plot(tArray, Markers.top(:, 2),      'Color', [0.75 0.75 0.75], 'LineWidth', 1) ; hold on
plot(tArray, Markers_filt.top(:, 2), 'k-',   'LineWidth', 1.5) ;
ylabel('y [mm]')
grid on

subplot(3, 1, 3)  % Z 成分 / Z-component
plot(tArray, Markers.top(:, 3),      'Color', [0.75 0.75 0.75], 'LineWidth', 1) ; hold on
plot(tArray, Markers_filt.top(:, 3), 'k-',   'LineWidth', 1.5) ;
ylabel('z [mm]')
xlabel('Time [s]')
grid on
