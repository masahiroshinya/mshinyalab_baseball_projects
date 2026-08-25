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

% ---- ③ 手部の投手方向速度（Nasu et al., 2020 準拠）----
%  手部・骨盤とも複数マーカーの幾何学的重心を代表点とし、手部から骨盤を引いて
%  体幹の並進成分を除く。原法は「補間→重心→フィルタ」の順だが、filtfilt も
%  平均も線形操作なので、M（補間・フィルタ済み）から重心を取っても数学的に同一。
if all(isfield(M, Prm.RT.HandMarkerNames)) && all(isfield(M, Prm.RT.PelvisMarkerNames))
    hand = meanMarker(M, Prm.RT.HandMarkerNames) ;
    pelv = meanMarker(M, Prm.RT.PelvisMarkerNames) ;

    relPos   = (hand - pelv) / 1000 ;
    velRel   = diff3p(relPos, 1/fs) ;
    velHandX = velRel(:, 1) ;
else
    velHandX = [] ;      % 手部 RT だけ諦める。top と床反力は通常どおり計算される
end

Result.VelHandX = velHandX ;                  % 波形（閾値は x4 で確定するため onset はここでは出さない）


% ---- LED タイミング（ch2 = cue チャンネル。正=Go（緑）, 負=NoGo/Stop（赤）。ch1 は ready cue）----
%  gonogo 課題: 正か負のどちらか一方のパルスだけが出る。
%  gostop 課題: stop 試行でも必ず先に go（正）が出て、0.35 s 後に stop（負）が出る。
%               → 正のパルスの後に負のパルスが続く試行を Stop と判定する。
%               この判定を入れないと、stop 試行がすべて Go に混ざる。
led_cue = Data.LEDData(:, 2) ;
tCueGo  = find(led_cue > Prm.Cue.GoThresholdV,  1, 'first') ;
tCueNeg = find(led_cue < Prm.Cue.NegThresholdV, 1, 'first') ;


if ~isempty(tCueGo) && (isempty(tCueNeg) || tCueNeg > tCueGo)

    % 正のパルスが先 → go cue を起点にする
    tCueAnalog = tCueGo ;

    stopWin = round(Prm.Cue.StopWinSec * Data.AnalogFs) ;
    if ~isempty(tCueNeg) && (tCueNeg - tCueGo) <= stopWin
        cueCode = Prm.CueCode.Stop ;
        cueText = 'Stop' ;
    else
        cueCode = Prm.CueCode.Go ;
        cueText = 'Go' ;
    end

elseif ~isempty(tCueNeg)
    tCueAnalog = tCueNeg ;
    cueCode    = Prm.CueCode.NoGo ;
    cueText    = 'NoGo' ;
else
    Result.CueCode     = NaN ;
    Result.CueText     = '' ;
    Result.TCueMarker  = NaN ;
    Result.PeakVelHandX    = NaN ;      % ← Fz1Base* より前に移動
    Result.TPeakVelHandX   = NaN ;      % ← 追加（元は欠落していた）
    Result.SwingOnsetHand  = NaN ;
    Result.RTHand          = NaN ;
    Result.Fz1BaseMean = NaN ;          % ← ここに移動
    Result.Fz1BaseSD   = NaN ;
    Result.SwingOnsetForce = NaN ;
    Result.RTForce         = NaN ;
    Result.BWBase  = NaN ;
    Result.PeakFz1 = NaN ;
    Result.PeakFz2 = NaN ;
    Result.Fz1Filt = [] ;               % ★追加：正常経路と並び順を揃える
    Result.Fz2Filt = [] ;               % ★追加
    return
end


tCueMarker = round(tCueAnalog / Data.AnalogFs * fs) ;
Result.CueCode    = cueCode ;
Result.CueText    = cueText ;
Result.TCueMarker = tCueMarker ;

% ---- 手部速度のピーク（キュー後 2 秒の窓内）----
%  閾値そのものは全試行の平均に依存するので x4 で決める。ここでは各試行のピークだけ出す。
%  max(abs(v)) ではなく max(v) に限定する：テイクバックの逆方向ピークを拾わないため。
if isempty(velHandX)
    Result.PeakVelHandX  = NaN ;
    Result.TPeakVelHandX = NaN ;
else
    wHand = tCueMarker : min(tCueMarker + round(Prm.RT.WinSec*fs), numel(velHandX)) ;
    [peakVelHandX, idxPeakRel] = max(velHandX(wHand)) ;
    Result.PeakVelHandX  = peakVelHandX ;
    Result.TPeakVelHandX = wHand(1) + idxPeakRel - 1 ;
end

Result.SwingOnsetHand = NaN ;                          % x4 の第2パスで埋める
Result.RTHand         = NaN ;

% ---- スイング開始検出（後ろ足 Fz1）----
%  00 §0.1 の確定仕様。キュー前 0.5 秒を平常時とみなして平均 mu と
%  ばらつき sd を求め、|Fz1 - mu| > k*sd が 30 ms 続いた最初の時点を
%  動作開始とする。角速度 300 deg/s による検出は廃止した（00 §2）。
%  時刻はアナログのサンプル番号のまま扱い、ms への変換は出力時だけ行う。
%  NoGo / Stop 試行も含めて全試行で算出する。抑制試行でも姿勢制御による
%  荷重変化は生じるため、検出値そのものを見て判断できるようにしておく。
%  報告時にどの試行を反応時間として扱うかは、下流（x6 以降）で決める。

Result.Fz1BaseMean = NaN ;
Result.Fz1BaseSD   = NaN ;
Result.SwingOnsetForce = NaN ;   % アナログのサンプル番号（試行先頭から）
Result.RTForce         = NaN ;   % [ms] キュー → 動作開始

if isfield(Data, 'Force1') && ~isempty(Data.Force1)

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
                Result.SwingOnsetForce = tCueAnalog + idx - 1 ;   % 試行先頭からの位置に直す
                Result.RTForce         = (idx-1) / fsA * 1000 ;   % [ms]（idx=1 なら RT=0）

            end

        end
    end
end

% ---- 床反力のピーク鉛直分力（統計用）----
%  正規化はここでは行わない。分母となる体重の妥当性は被験者内の全試行を
%  見ないと判定できない（x8 の isBadBW）ため、生値 [N] とベースライン
%  荷重 [N] だけを出し、%BW への変換は x8 側で行う。
%  NoGo / Stop 試行も含めて全試行で算出する。除外は下流（x8）で決める。
%
%  フィルタ後の波形（Fz1Filt / Fz2Filt）も出力する。x7_3 が時系列を描く際に
%  生データから再計算せず、この波形をそのまま使うため（x7_2 が NetVelTop を
%  使うのと同じ方針）。二重計算をなくし、値の食い違いを構造的に防ぐ。
%
%  初期化は必ず if の外に置くこと。Force1 を持たない試行でフィールドが
%  作られないと、x4 の構造体配列への代入が「異なる構造体での添字による
%  代入です」で落ちる（技術説明 §3.5）。
Result.BWBase  = NaN ;   % 静止時 Fz1+Fz2 [N]
Result.PeakFz1 = NaN ;   % 後ろ足   ピーク鉛直分力 [N]
Result.PeakFz2 = NaN ;   % 踏み込み足 ピーク鉛直分力 [N]
Result.Fz1Filt = [] ;    % ★追加：30 Hz フィルタ後の Fz1 波形 [N]
Result.Fz2Filt = [] ;    % ★追加：30 Hz フィルタ後の Fz2 波形 [N]

if isfield(Data, 'Force1') && ~isempty(Data.Force1) ...
        && isfield(Data, 'Force2') && ~isempty(Data.Force2) ...
        && tCueAnalog >= 2

    fsA     = Data.AnalogFs ;
    Fz1_raw = Data.Force1(:, 3) ;
    Fz2_raw = Data.Force2(:, 3) ;

    % filtfilt は NaN が1つでもあると全体を NaN にするので、先に弾く
    if ~any(isnan(Fz1_raw)) && ~any(isnan(Fz2_raw))

        % Methods 2-4-3 に従い、マーカーと同じ 30 Hz・2次でローパスする
        [bF, aF] = butter(2, fc/(fsA/2)) ;
        Fz1_filt = filtfilt(bF, aF, Fz1_raw) ;
        Fz2_filt = filtfilt(bF, aF, Fz2_raw) ;

        Result.BWBase = mean(Fz1_filt(1:tCueAnalog-1)) + mean(Fz2_filt(1:tCueAnalog-1)) ;

        swingEnd   = min(tCueAnalog + round(Prm.GRF.WinSec*fsA), numel(Fz1_filt)) ;
        swingRange = tCueAnalog : swingEnd ;

        Result.PeakFz1 = max(Fz1_filt(swingRange)) ;
        Result.PeakFz2 = max(Fz2_filt(swingRange)) ;

        Result.Fz1Filt = Fz1_filt ;   % ★追加：波形をそのまま下流へ渡す
        Result.Fz2Filt = Fz2_filt ;   % ★追加
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

% ---- 指定マーカーの幾何学的重心（各マーカーは補間・フィルタ済みの前提）----
function y = meanMarker(M, names)
x = nan(size(M.(names{1}), 1), 3, numel(names)) ;
for i = 1:numel(names)
    x(:,:,i) = M.(names{i}) ;
end
y = mean(x, 3) ;
end
