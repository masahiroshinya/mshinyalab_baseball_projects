clear
close all
clc

% 分析対象の設定
iSubject   = 1;
iCondition = 1;
iTrial     = 1;

ConditionNameArray = {'free', 'simple', 'gonogo'};

% 元データ（Data Array）の読み込み
dataFilePath = sprintf('x3_DataChecked/Data%02d', iSubject);
load(dataFilePath)

Data = DataArray(iTrial, iCondition);

Prm = parameters;

% Data.Markers に含まれる全マーカー名を確認
markerNameArray = fieldnames(Data.Markers);
disp(markerNameArray)

batMarkerNameArray = {'top', 'first', 'second', 'third', 'bottom'};

nBatMarker = length(batMarkerNameArray);

% フィルター処理
fs = Data.FrameRate;
fc = Prm.Fc;
[b, a] = butter(2, fc/(fs/2));
M = filt_all_fields(b, a, Data.Markers);

% 各バットマーカーの合成速度を計算
BatMarkerVelocity = struct;
BatMarkerPeakVelocity = struct;

for iMarker = 1:nBatMarker
    markerName = batMarkerNameArray{iMarker};

    markerPosition = M.(markerName);
    markerVelocity = diff3p(markerPosition, 1/fs);
    markerNetVelocity = sum(markerVelocity.^2, 2).^0.5;

    BatMarkerVelocity.(markerName) = markerNetVelocity;
    BatMarkerPeakVelocity.(markerName) = max(markerNetVelocity);
end

% 欠損フレーム数を確認
BatMarkerMissingFrameCount = struct;

for iMarker = 1:nBatMarker
     markerName = batMarkerNameArray{iMarker};
     markerPosition = Data.Markers.(markerName);

     missingFrame = any(isnan(markerPosition), 2);
     BatMarkerMissingFrameCount.(markerName) = sum(missingFrame);
end

disp(BatMarkerMissingFrameCount)

% 速度波形を重ねて可視化する
figure(1)
clf
hold on

nFrame = length(BatMarkerVelocity.(batMarkerNameArray{1}));
tArray = [1:nFrame] / fs;

for iMarker = 1:nBatMarker
     markerName = batMarkerNameArray{iMarker};
     plot(tArray, BatMarkerVelocity.(markerName), 'LineWidth', 1.2)
end

xlabel('Time(s)')
ylabel('Velocity(mm/s)')
legend(batMarkerNameArray, 'Interpreter', 'none')
grid on

% LED点灯を0秒にした時間軸で確認する
led = Data.LEDData(:, 2);
tCueAnalog = find(abs(led) > 2, 1, 'first');
tCueMarker = round(tCueAnalog / Data.AnalogFs * fs);

if isempty(tCueAnalog)
      tArrayCue = [1:nFrame] / fs;
else
      tArrayCue = ([1:nFrame] - tCueMarker) / fs;
end

figure(2)
clf
hold on
for iMarker = 1:nBatMarker
     markerName = batMarkerNameArray{iMarker};
     plot(tArrayCue, BatMarkerVelocity.(markerName), 'LineWidth', 1.2)
end

xlabel('Time from LED onset(s)')
ylabel('Velocity(mm/s)')
legend(batMarkerNameArray, 'Interpreter', 'none')
set(gca, 'xlim', [-1,3])
grid on