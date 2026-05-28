function Result = m3_analyze_single_trial(Data)

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
    errorText = Prm.ErrorText.LEDTimingNotDetected ;
    Result.CueCode = NaN ;
    Result.CueText = '' ;
    Result.TCueMarker = NaN ;
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

% スイング開始フレームを探す
n = length(netVelTop) ;
searchRange = tCueMarker : n ;

idxAboveThreshold = find(netVelTop(searchRange) > threshold, 1, 'first') ;

if isempty(idxAboveThreshold)
    % 閾値を超えなかった（NoGoで正解、またはデータ異常）
    tSwingOnset = NaN ;
else
    tSwingOnset = searchRange(1) + idxAboveThreshold - 1 ;
end

% 反応時間を算出する
if isnan(tSwingOnset)
    RT = NaN ;
else
    RT = (tSwingOnset - tCueMarker) / fs * 1000 ;
end

Result.SwingOnset = tSwingOnset ;
Result.RT         = RT ;

end