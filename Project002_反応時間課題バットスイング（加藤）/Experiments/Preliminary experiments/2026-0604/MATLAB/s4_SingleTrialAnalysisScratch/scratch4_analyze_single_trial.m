clear
close all
clc

iSubject = 1 ;
iCondition = 1 ;
iTrial = 1 ;


ConditionNameArray = {'free', 'simple', 'gonogo'} ;
nCondition = length(ConditionNameArray) ;


dataFilePath = sprintf('x3_DataChecked/Data%02d', iSubject) ;
load(dataFilePath)

Data = DataArray(iTrial, iCondition) ;

Prm = parameters ;

% ------
% scratch for single trial analysis


errorCode = Data.ErrorCode ;
errorText = Data.ErrorText ;


% filter
fs = Data.FrameRate ;
fc = Prm.Fc ;
[b,a] = butter(2, fc/(fs/2)) ;
M = filt_all_fields(b,a,Data.Markers) ;


% velocity of 'top'
top = M.top ;
velTop = diff3p(top, 1/fs) ;
netVelTop = sum(velTop.^2,2).^0.5 ;

peakVelTop = max(netVelTop) ;

Result.PeakVelTop = peakVelTop ;


% LED timing
led = Data.LEDData(:,2) ;
tCueAnalog = find(abs(led) > 2, 1, 'first') ;
tCueMarker = round(tCueAnalog / Data.AnalogFs * fs) ;

if isempty(tCueAnalog)
    errorCode = Prm.ErrorCode.LEDTimingNotDetected ;
    errorText = Prm.ErrorText.LEDTimingNotDetected ;
else
    if led(tCueAnalog) > 0 
        cueCode = 1 ;
        cueText = 'Go' ;
    elseif led(tCueAnalog) < 0
        cueCode = 2 ;
        cueText = 'NoGo' ;
    end
end





% figure

figure(2)
plotTimeRange = [-1,3] ;

subplot(3,1,[1:2]) ;
n = length(top) ;
tArray = ([1:n]- tCueMarker)/fs ;
plot(tArray, netVelTop)

set(gca, 'xlim', plotTimeRange) ;
% lineplot(tArray(tCue), 'v', 'r-') ;

subplot(3,1,3) ;
nAnalog = length(Data.LEDData) ;
tArrayAnalog = ([1:nAnalog] - tCueAnalog)/Data.AnalogFs ;
plot(tArrayAnalog, Data.LEDData)
set(gca, 'xlim', plotTimeRange) ;

% lineplot(tArray(tCue), 'v', 'r-') ;


% stick picture
figure(1)
plot3(M.top(:,1), M.top(:,2), M.top(:,3), 'k-') ; hold on

set(gca, 'xlim', [-1000,2000], 'ylim', [-1000,1000], 'zlim', [0,3000])
grid on

iFrame = 1 ;
h1 = draw_stick_picture(M, {'top', 'bottom'}, iFrame, 'xyz', '-o') ;

% animation
% for iFrame = 1:1:3000 
%     xdata = [M.top(iFrame,1), M.bottom(iFrame,1)] ;
%     ydata = [M.top(iFrame,2), M.bottom(iFrame,2)] ;
%     zdata = [M.top(iFrame,3), M.bottom(iFrame,3)] ;
%     set(h1, 'xdata', xdata, 'ydata', ydata, 'zdata', zdata) ;
%     drawnow
% end



% Result 




