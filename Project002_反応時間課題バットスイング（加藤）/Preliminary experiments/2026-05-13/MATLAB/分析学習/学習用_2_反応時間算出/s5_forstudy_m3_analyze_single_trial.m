function Result = s5_forstudy_m3_analyze_single_trial(Data)

Prm = parameters ;

fs = Data.FrameRate ;
fc = Prm.Fc ;
[b, a] = butter(2, fc/(fs/2)) ;
M = filt_all_fields(b, a, Data.Markers) ;

% velocity of 'top'
top = M.top ;
velTop = diff3p(top, 1/fs) ;
netVelTop = sum(velTop.^2, 2).^0.5 ;

peakVelTop = max(netVelTop) ;

Result.PeakVelTop = peakVelTop ;

% LED timing
led = Data.LEDData(:,2) ;
tCueAnalog = find(abs(led) > 2, 1, 'first') ;
tCueMarker = round(tCueAnalog / Data.AnalogFs * fs) ;

if isempty(tCueAnalog)
    errorCode = Prm.ErrorCode.LEDTimingNotDetected ;
    errortext = Prm.ErrorText.LEDTimingNotDetected ;
else
    if led(tCueAnalog) > 0
        cueCode = 1 ;
        cueText = 'Go' ;
    elseif led(tCueAnalog) < 0
        cueCode = 2 ;
        cueText = 'NoGo' ;
    end
    Result.CueCode    = cueCode ;
    Result.CueText    = cueText ;
    Result.TCueMarker = tCueMarker ;
end

% スイング閾値の検出（例：ピーク速度の5%）
threshold = 0.05 * peakVelTop ;

fprintf('peakVelTop = %.1f mm/s\n', peakVelTop) ;
fprintf('threshold = %.1f mm/s\n', threshold) ;

% スイング開始フレームを探す
n = length(netVelTop) ;
searchRange = tCueMarker : n ;

idxAboveThreshold = find(netVelTop(searchRange) > threshold, 1, 'first') ;

if isempty(idxAboveThreshold)
    % 閾値を超えなかった（NoGoで正解、またはデータ異常）
    tSwingOnset = NaN ;
    fprintf('スイング開始が検出されませんでした\n') ;
else
    tSwingOnset = searchRange(1) + idxAboveThreshold - 1 ;
    fprintf('tSwingOnset = %dフレーム目\n', tSwingOnset) ;
end

% 反応時間を算出する
if isnan(tSwingOnset)
    RT = NaN ;
    fprintf('RTは算出できませんでした（スイング未検出）\n') ;
else
    RT = (tSwingOnset - tCueMarker) / fs * 1000 ;
    fprintf('RT = %.1f ms\n', RT) ;
end

Result.SwingOnset = tSwingOnset ;
Result.RT         = RT ;

% figure
figure(2)
plotTimeRange = [-1,3] ;

subplot(3,1,[1:2]) ;
n = length(top) ;
tArray = ([1:n] - tCueMarker) / fs ;
plot(tArray, netVelTop)
set(gca, 'xlim', plotTimeRange) ;

subplot(3,1,3) ;
nAnalog = length(Data.LEDData) ;
tArrayAnalog = ([1:nAnalog] - tCueAnalog) / Data.AnalogFs ;
plot(tArrayAnalog, Data.LEDData)
set(gca, 'xlim', plotTimeRange) ;

end