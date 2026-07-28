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

%  +X = 投手方向（s3b で両被験者・40/40 で確認済み）。
%  合成速度と違い符号を持つ：正 = 投手方向、負 = 捕手方向（テイクバック）。
velTopX = velTop(:, 1) ;                      % [m/s]  投手方向成分

[peakVelTop,  idxPeak]  = max(netVelTop) ;    % 合成速度のピークとその時刻
[peakVelTopX, idxPeakX] = max(velTopX) ;      % Vx のピークとその時刻

Result.NetVelTop     = netVelTop ;            % 合成速度の波形
Result.VelTopX       = velTopX ;              % 投手方向成分の波形
Result.PeakVelTop    = peakVelTop ;           % 合成速度のピーク [m/s]
Result.TPeakVelTop   = idxPeak ;              % そのフレーム番号（試行先頭から）
Result.PeakVelTopX   = peakVelTopX ;          % Vx のピーク [m/s]
Result.TPeakVelTopX  = idxPeakX ;             % そのフレーム番号（試行先頭から）
Result.VelTopXAtPeak = velTopX(idxPeak) ;     % 合成速度ピーク時の Vx [m/s]


% ---- LED タイミング（ch2 = cue チャンネル。正=Go, 負=NoGo。ch1 は ready cue）----
led_cue  = Data.LEDData(:, 2) ;
tCueGo   = find(led_cue >  2,    1, 'first') ;
tCueNoGo = find(led_cue < -1,    1, 'first') ;


if ~isempty(tCueGo)
    tCueAnalog = tCueGo ;
    cueCode    = 1 ;
    cueText    = 'Go' ;
elseif ~isempty(tCueNoGo)
    tCueAnalog = tCueNoGo ;
    cueCode    = 2 ;
    cueText    = 'NoGo' ;
else
    Result.CueCode     = NaN ;
    Result.CueText     = '' ;
    Result.TCueMarker  = NaN ;
    Result.Fz1BaseMean = NaN ;
    Result.Fz1BaseSD   = NaN ;
    Result.SwingOnset  = NaN ;
    Result.RT          = NaN ;
    return
end


tCueMarker = round(tCueAnalog / Data.AnalogFs * fs) ;
Result.CueCode    = cueCode ;
Result.CueText    = cueText ;
Result.TCueMarker = tCueMarker ;

% ---- スイング開始検出（後ろ足 Fz1）----
%  00 §0.1 の確定仕様。キュー前 0.5 秒を平常時とみなして平均 mu と
%  ばらつき sd を求め、|Fz1 - mu| > k*sd が 30 ms 続いた最初の時点を
%  動作開始とする。角速度 300 deg/s による検出は廃止した（00 §2）。
%  時刻はアナログのサンプル番号のまま扱い、ms への変換は出力時だけ行う。
%  RT を出すのは Go 試行のみ（NoGo には動作開始が存在しない）。
Result.Fz1BaseMean = NaN ;
Result.Fz1BaseSD   = NaN ;
Result.SwingOnset  = NaN ;   % アナログのサンプル番号（試行先頭から）
Result.RT          = NaN ;   % [ms] キュー → 動作開始

if cueCode == 1 && isfield(Data, 'Force1') && ~isempty(Data.Force1)

    fsA   = Data.AnalogFs ;
    Fz1   = Data.Force1(:, 3) ;
    nA    = numel(Fz1) ;
    nBase = round(Prm.RT.BaseSec * fsA) ;

    % 平常時を測る区間がキューの手前に確保できる場合のみ処理する
    if tCueAnalog - nBase >= 1

        base = Fz1(tCueAnalog-nBase : tCueAnalog-1) ;

        if ~any(isnan(base))

            mu = mean(base) ;
            sd = std(base) ;
            Result.Fz1BaseMean = mu ;
            Result.Fz1BaseSD   = sd ;

            % キューから 2 秒先までを探索範囲とする
            w     = tCueAnalog : min(tCueAnalog + round(Prm.RT.WinSec*fsA), nA) ;
            over  = abs(Fz1(w) - mu) > Prm.RT.FzK * sd ;
            holdN = round(Prm.RT.DurMs/1000 * fsA) ;
            idx   = firstSustained(over, holdN) ;   % 探索範囲 w の中での位置

            if ~isempty(idx)
                Result.SwingOnset = tCueAnalog + idx - 1 ;   % 試行先頭からの位置に直す
                Result.RT         = (idx-1) / fsA * 1000 ;   % [ms]（idx=1 なら RT=0）
            end

        end
    end
end

end


% ---- 閾値超えが holdN サンプル続いた最初の位置を返す（s2f と同じロジック）----
function idx = firstSustained(over, holdN)
idx = [] ;
d = diff([0; over(:); 0]) ;
starts = find(d==1) ; ends = find(d==-1)-1 ;
run = find((ends-starts+1) >= holdN, 1, 'first') ;
if ~isempty(run), idx = starts(run) ; end
end
