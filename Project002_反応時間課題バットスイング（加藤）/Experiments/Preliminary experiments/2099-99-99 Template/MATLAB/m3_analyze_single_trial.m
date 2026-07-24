function Result = m3_analyze_single_trial(Data)

Prm = parameters ;
fs  = Data.FrameRate ;
fc  = Prm.Fc ;
[b, a] = butter(2, fc/(fs/2)) ;

% ---- NaN 補間（filtfilt の前に必須）----
fields = fieldnames(Data.Markers) ;
for i = 1:numel(fields)
    f = fields{i} ;
    x = Data.Markers.(f) ;
    t = (1:size(x,1))' ;
    for col = 1:size(x,2)
        nanIdx = isnan(x(:,col)) ;
        if any(nanIdx) && any(~nanIdx)
            x(nanIdx,col) = interp1(t(~nanIdx), x(~nanIdx,col), t(nanIdx), 'linear', 'extrap') ;
        end
    end
    Data.Markers.(f) = x ;
end

M = filt_all_fields(b, a, Data.Markers) ;

% ---- Shinya 角速度法（学習用_6 で確認済み）----
r_bottom    = M.bottom ;
r_top       = M.top ;
v_long      = r_top - r_bottom ;
v_long_norm = sum(v_long.^2, 2).^0.5 ;
e_long      = v_long ./ v_long_norm ;
de_long     = diff3p(e_long, 1/fs) ;
omega_rad   = sum(de_long.^2, 2).^0.5 ;
omega_deg   = omega_rad * (180/pi) ;

Result.PeakOmegaDeg = max(omega_deg) ;      % スイング中の最大角速度

% ---- LED タイミング（Go=列2, NoGo=列1 を個別検索）----
led_go   = Data.LEDData(:, 2) ;
led_nogo = Data.LEDData(:, 1) ;
tCueGo   = find(led_go   >  2, 1, 'first') ;
tCueNoGo = find(led_nogo < -2, 1, 'first') ;

if ~isempty(tCueGo)
    tCueAnalog = tCueGo ;
    cueCode    = 1 ;
    cueText    = 'Go' ;
elseif ~isempty(tCueNoGo)
    tCueAnalog = tCueNoGo ;
    cueCode    = 2 ;
    cueText    = 'NoGo' ;
else
    Result.CueCode    = NaN ;
    Result.CueText    = '' ;
    Result.TCueMarker = NaN ;
    Result.SwingOnset = NaN ;
    Result.RT         = NaN ;
    return
end

tCueMarker = round(tCueAnalog / Data.AnalogFs * fs) ;
Result.CueCode    = cueCode ;
Result.CueText    = cueText ;
Result.TCueMarker = tCueMarker ;

% ---- スイング開始検出（絶対閾値 300 deg/s）----
THRESHOLD_OMEGA = 300 ;
nFrames         = length(omega_deg) ;
searchRange     = tCueMarker : nFrames ;
idxAbove        = find(omega_deg(searchRange) > THRESHOLD_OMEGA, 1, 'first') ;

if isempty(idxAbove)
    tSwingOnset = NaN ;
else
    tSwingOnset = searchRange(1) + idxAbove - 1 ;
end

% ---- 反応時間 ----
if isnan(tSwingOnset)
    RT = NaN ;
else
    RT = (tSwingOnset - tCueMarker) / fs * 1000 ;
end

Result.SwingOnset = tSwingOnset ;
Result.RT         = RT ;

end
