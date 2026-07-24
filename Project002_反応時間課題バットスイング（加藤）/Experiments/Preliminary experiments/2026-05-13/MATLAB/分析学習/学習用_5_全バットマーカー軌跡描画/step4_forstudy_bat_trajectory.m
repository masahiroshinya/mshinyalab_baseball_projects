% step4_forstudy_bat_trajectory.m
% 全バットマーカーの軌跡（スイング軌道）を可視化する学習用スクリプト
%
% 使い方：
%   1. workflow.md を読んで処理の流れを理解する
%   2. STEP 1 から順番にコードを追記していく
%   3. 各 STEP ごとに実行して確認する
%
% カレントフォルダ：Preliminary experiments/2026-05-13/MATLAB/ に設定すること

% ↓ ここから下にコードを追記してください
clear
close all
clc

% 分析対象の設定
iSubject   = 1 ;
iCondition = 1 ; % 1: free, 2: simple, 3: gonogo
iTrial     = 1 ;

ConditionNameArray = {'free', 'simple', 'gonogo'} ;

batMarkerNameArray = {'top', 'first', 'second', 'third', 'bottom'} ;
nBatMarker = length(batMarkerNameArray) ;

% データ読み込み
dataFilePath = sprintf('x3_DataChecked/Data%02d', iSubject) ;
load(dataFilePath)

Data = DataArray(iTrial, iCondition) ;
Prm = parameters ;

% フィルター処理
fs = Data.FrameRate ;
fc = Prm.Fc ;
[b, a] = butter(2, fc/(fs/2)) ;
M = filt_all_fields(b, a, Data.Markers) ;

% 各バットマーカーの合成速度を計算
BatMarkerVelocity = struct ;

for iMarker = 1:nBatMarker
    markerName = batMarkerNameArray{iMarker} ;
    pos = M.(markerName) ;
    vel = diff3p(pos, 1/fs) ;
    netVel = sum(vel.^2, 2).^0.5 ;
    BatMarkerVelocity.(markerName) = netVel ;
end

% LED 点灯タイミングの検出
led = Data.LEDData(:, 2) ;
tCueAnalog = find(abs(led) > 2, 1, 'first') ;
tCueMarker = round(tCueAnalog / Data.AnalogFs * fs) ;

fprintf('LED 点灯フレーム: %d\n', tCueMarker) ;

% フレーム範囲の設定（暫定：LED点灯前1秒〜点灯後3秒）
nFrame = size(M.top, 1);
frameStart = max(1, tCueMarker + round(-1 * fs));
frameEnd = min(nFrame, tCueMarker + round(3 * fs));
frameRange = frameStart : frameEnd;

fprintf('フレーム範囲: %d ~ %d (計 %dフレーム)\n', frameStart, frameEnd, length(frameRange));

% topマーカーのピーク速度フレームを特定（frameRange 内で）
[~, idxPeak]  = max(BatMarkerVelocity.top(frameRange));
tPeak = frameRange(idxPeak);

fprintf('ピーク速度フレーム: %d\n', tPeak);
fprintf('ピーク速度: %.1f mm/s\n', BatMarkerVelocity.top(tPeak));

% 全バットマーカーの3D軌跡を描く
figure(1)
clf
hold on

for iMarker = 1:nBatMarker
    markerName = batMarkerNameArray{iMarker};
    pos = M.(markerName);
    plot3(pos(frameRange, 1), pos(frameRange, 2), pos(frameRange, 3), 'LineWidth', 1.2)
end

xlabel('X(mm)')
ylabel('Y(mm)')
zlabel('Z(mm)')
legend(batMarkerNameArray, 'Interpreter','none')
grid on

% ピーク時のバット姿勢（スティック図）を3Dで追加
draw_stick_picture(M, batMarkerNameArray, tPeak, 'xyz', '-ok');

% tPeak 全マーカーフレーム位置を取得
batPos = zeros(nBatMarker, 3) ;
for i = 1:nBatMarker
    batPos(i, :) = M.(batMarkerNameArray{i})(tPeak, :) ;
end

% 全ペアの組み合わせで直線を繋ぐ
for i = 1:nBatMarker
    for j = i+1 : nBatMarker
        plot3([batPos(i,1), batPos(j,1)], ...
        [batPos(i,2), batPos(j,2)], ...
        [batPos(i,3), batPos(j,3)], '-k', 'LineWidth', 0.5)
    end
end

title('全バットマーカー3D軌跡（LED前後）')
view(3)

% XY平面（真上から見た軌跡）を描く
figure(2)
clf
hold on

for iMarker = 1:nBatMarker
    markerName = batMarkerNameArray{iMarker};
    pos = M.(markerName);
    plot(pos(frameRange, 1), pos(frameRange, 2), 'LineWidth', 1.2)
end

% ピーク時のバット姿勢（スティック図）をXY平面で追加
draw_stick_picture(M, batMarkerNameArray, tPeak, 'xy', '-ok');

% tPeak 全マーカーフレーム位置を取得
batPos = zeros(nBatMarker, 3) ;
for i = 1:nBatMarker
    batPos(i, :) = M.(batMarkerNameArray{i})(tPeak, :) ;
end

% 全ペアの組み合わせで直線を繋ぐ
for i = 1:nBatMarker
    for j = i+1 : nBatMarker
        plot3([batPos(i,1), batPos(j,1)], ...
            [batPos(i,2), batPos(j,2)], ...
            [batPos(i,3), batPos(j,3)], '-k', 'LineWidth', 0.5)
    end
end

xlabel('X(mm)')
ylabel('Y(mm)')
legend([batMarkerNameArray, {'peak posture'}], 'Interpreter', 'none')
grid on
axis equal
title('バット軌跡（真上から: XY平面）')