function Result = m3_analyze_single_trial(Data)

Prm = parameters ;

% filter
fs = Data.FrameRate ;
fc = Prm.Fc ;
[b, a] = butter(2, fc/(fs/2)) ;
M = filt_all_fields(b,a,Data.Markers) ;

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
else
    if led(tCueAnalog) > 0
        cueCode = 1 ;
        cueText = 'Go' ;
    elseif led(tCueAnalog) < 0
        cueCode = 2 ;
        cueText = 'NoGo' ;
    end
end

end
