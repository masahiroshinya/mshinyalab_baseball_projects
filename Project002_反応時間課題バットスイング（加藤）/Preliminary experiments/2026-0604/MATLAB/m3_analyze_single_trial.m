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

% ---- ② バット先端（top）の並進速度 ----
%  Qualisys の座標は mm なので、1000 で割って m に直してから微分する。
%  こうすると velTop の単位が最初から m/s になり、以降で単位を意識せずに済む。
posTop    = M.top / 1000 ;                    % [m]    各列 = x, y, z
velTop    = diff3p(posTop, 1/fs) ;            % [m/s]  中心差分（3点法）
netVelTop = sum(velTop.^2, 2).^0.5 ;          % [m/s]  速度ベクトルのノルム（＝速さ）

Result.NetVelTop  = netVelTop ;
Result.PeakVelTop = max(netVelTop) ;

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

% ---- スイング開始検出 ----
%  角速度 300 deg/s による検出は廃止した（00 §2 の決定）。
%  新しい検出信号（バット先端速度 or 床反力 Fz）は 00 で検討中のため、
%  それが決まるまで RT は NaN とする。フィールドは残す（消すと x4 で
%  構造体配列のフィールド不一致エラーになる）。
Result.SwingOnset = NaN ;
Result.RT         = NaN ;

end
