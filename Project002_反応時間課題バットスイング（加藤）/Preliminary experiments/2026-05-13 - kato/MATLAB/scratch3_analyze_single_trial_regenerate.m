% 

clear
close all
clc

iSubject   = 1 ;
iCondition = 1 ;
iTrial     = 1 ;

ConditionNameArray = {'free', 'simple', 'gonogo'} ;
nCondition = length(ConditionNameArray) ;

dataFilePath = sprintf('x3_DataChecked/Data%02d', iSubject) ;
load(dataFilePath)

Data = DataArray(iTrial, iCondition) ;
Prm  = parameters ;

errorCode = Data.ErrorCode ;
errorText = Data.ErrorText ;

% filter
fs         = Data.FrameRate ;
fc         = Prm.Fc ;
windowSize = round(fs / fc) ;
fields     = fieldnames(Data.Markers) ;
M          = Data.Markers ;
for i = 1:length(fields)
    M.(fields{i}) = movmean(Data.Markers.(fields{i}), windowSize) ;
end

% velocity of 'top'
top       = M.top ;
velTop    = diff3p(top, 1/fs) ;
netVelTop = sum(velTop.^2, 2).^0.5 ;

peakVelTop       = max(netVelTop) ;
Result.PeakVelTop = peakVelTop ;

% LED timing
led        = Data.LEDData(:,2) ;
tCueAnalog = find(abs(led) > 2, 1, 'first') ;

if isempty(tCueAnalog)
    errorCode = Prm.ErrorCode.LEDTimingNotDetected ;
    errorText = Prm.ErrorText.LEDTimingNotDetected ;
    return
end

tCueMarker = round(tCueAnalog / Data.AnalogFs * fs) ;

if led(tCueAnalog) > 0
    cueCode = 1 ; cueText = 'Go' ;
elseif led(tCueAnalog) < 0
    cueCode = 2 ; cueText = 'NoGo' ;
end

% 時間軸
n            = length(top) ;
tArray       = ([1:n] - tCueMarker) / fs ;
nAnalog      = length(Data.LEDData) ;
tArrayAnalog = ([1:nAnalog] - tCueAnalog) / Data.AnalogFs ;
plotTimeRange = [-1, 3] ;

% -------------------------------------------------------
% Figure：横並びレイアウト
% -------------------------------------------------------
fig = figure('Position', [100, 100, 1400, 700]) ;

% 左：スティック図
ax1 = subplot(3, 2, [1, 3, 5]) ;
plot3(M.top(:,1), M.top(:,2), M.top(:,3), 'k-') ; hold on
set(ax1, 'xlim', [-1000,2000], 'ylim', [-1000,1000], 'zlim', [0,3000])
grid on
iFrame = 1 ;
h1 = draw_stick_picture(M, {'top', 'bottom'}, iFrame, 'xyz', '-o') ;

% 右上：速度
ax2 = subplot(3, 2, 2) ;
plot(ax2, tArray, netVelTop)
set(ax2, 'xlim', plotTimeRange) ;
hold on
hTimeLine1 = plot(ax2, [tArray(1), tArray(1)], ylim(ax2), 'r-', 'LineWidth', 1.5) ;

% 右中：アナログ（LED）
ax3 = subplot(3, 2, 4) ;
plot(ax3, tArrayAnalog, Data.LEDData)
set(ax3, 'xlim', plotTimeRange) ;
hold on
hTimeLine2 = plot(ax3, [tArray(1), tArray(1)], ylim(ax3), 'r-', 'LineWidth', 1.5) ;

% -------------------------------------------------------
% コントロール（速度メニュー → 再生ボタンの順に定義）
% -------------------------------------------------------

% 速度ラベル
uicontrol('Style', 'text', 'Units', 'normalized', ...
    'Position', [0.6, 0.17, 0.15, 0.03], ...
    'String', '再生速度', 'FontSize', 11) ;

% 速度ドロップダウン（先に定義する）
popSpeed = uicontrol('Style', 'popupmenu', ...
    'Units', 'normalized', ...
    'Position', [0.6, 0.12, 0.15, 0.05], ...
    'String', {'×0.5', '×1', '×1.5', '×2'}, ...
    'Value', 2, ...          % デフォルト：×1
    'FontSize', 11) ;

% 再生ボタン（popSpeed の後に定義する）
uicontrol('Style', 'pushbutton', ...
    'String', '▶  再生', ...
    'Units', 'normalized', ...
    'Position', [0.6, 0.02, 0.15, 0.08], ...
    'FontSize', 12, ...
    'Callback', @(src,evt) playAnimation(h1, hTimeLine1, hTimeLine2, M, tArray, n, fs, popSpeed)) ;

% -------------------------------------------------------
% ローカル関数
% -------------------------------------------------------
function playAnimation(h1, hTimeLine1, hTimeLine2, M, tArray, n, fs, popSpeed)
    speedOptions = [0.5, 1.0, 1.5, 2.0] ;

    for iFrame = 1:n
        xdata = [M.top(iFrame,1), M.bottom(iFrame,1)] ;
        ydata = [M.top(iFrame,2), M.bottom(iFrame,2)] ;
        zdata = [M.top(iFrame,3), M.bottom(iFrame,3)] ;
        set(h1, 'xdata', xdata, 'ydata', ydata, 'zdata', zdata) ;

        currentTime = tArray(iFrame) ;
        set(hTimeLine1, 'xdata', [currentTime, currentTime]) ;
        set(hTimeLine2, 'xdata', [currentTime, currentTime]) ;

        % 毎フレーム速度を読み取る
        multiplier = speedOptions(get(popSpeed, 'Value')) ;
        pauseTime  = max(0, (1/fs) / multiplier - 0.015) ;
        pause(pauseTime) ;

        drawnow
    end
end
