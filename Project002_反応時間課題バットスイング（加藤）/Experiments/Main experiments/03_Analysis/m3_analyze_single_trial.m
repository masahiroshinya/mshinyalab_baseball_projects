function Result = m3_analyze_single_trial(Data)

Prm = parameters ;
fs  = Data.FrameRate ;
fc  = Prm.Fc ;
[b, a] = butter(2, fc/(fs/2)) ;

% ---- 除外基準①用：top の欠損マスクを、補間で埋める前に保存する ----
%  ★ 下の補間ループは NaN の長さに関係なく linear/extrap で全部埋めてしまうので、
%    ここで取っておかないと「どこが補間の産物か」が永久に分からなくなる。
%    x2 の interp_nan_spline が Prm.MaxNumNans 以下を既に埋めているため、
%    ここで NaN として残っているのは「埋めるべきでなかった長い欠損」だけである。
if isfield(Data.Markers, Prm.Excl.TopMarkerName)
    isNanTop = any(isnan(Data.Markers.(Prm.Excl.TopMarkerName)), 2) ;
else
    isNanTop = true ;                  % top が無い試行は全区間欠損とみなす
end

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

% ---- 試行の識別と品質フラグ（★ 必ず Result の先頭に置く）----
%  先頭に置くと、下の LED 未検出による早期 return でも自動的に埋まるので、
%  §3.5 の「3か所同時更新」の対象が1つ減る。
%  x6 は DataArray を読まないため、x2 が付けた top の判定はここで持ち回る。
%  古い中間ファイル（x2 修正前の x3_DataChecked）で回すと分かりにくい
%  「認識できないフィールド名」になるので、ここで明示的に止める。
if ~isfield(Data, 'MaxNanRunTop')
    error('m3_analyze_single_trial:StaleData', ...
        ['DataArray に MaxNanRunTop がありません。' ...
         'x2_import_data.m から実行し直してください（技術説明 §10.7）。']) ;
end

%  ★ IsBadTop は保守的に true で初期化する。cue が判定できて初めて
%    解析窓を切れるので、LED 未検出で早期 return する試行は不良のまま残す。
%    （その試行は PeakVelTop の時間基準そのものが無く、使えない。）
Result.IsNoData      = false ;
Result.IsBadTop      = true ;
Result.MaxNanRunTop  = Data.MaxNanRunTop ;   % 記録全体（参考情報）
Result.NNanInWinTop  = NaN ;                 % 解析窓内の欠損フレーム数

% ---- ② バット先端（top）の並進速度 ----
%  Qualisys の座標は mm なので、1000 で割って m に直してから微分する。
%  こうすると velTop の単位が最初から m/s になり、以降で単位を意識せずに済む。
%  ★ top が無い試行でも床反力は算出したいので、ここで落とさず NaN にする。
%    従来は M.top の参照で例外になり、x4 の try/catch が試行ごと捨てていた（§3.9）。
if isfield(M, Prm.Excl.TopMarkerName)
    posTop    = M.(Prm.Excl.TopMarkerName) / 1000 ; % [m]    各列 = x, y, z
    velTop    = diff3p(posTop, 1/fs) ;              % [m/s]  中心差分（3点法）
    netVelTop = sum(velTop.^2, 2).^0.5 ;            % [m/s]  ノルム（＝速さ）

    %  +X = 投手方向（s3b で両被験者・40/40 で確認済み）。
    %  合成速度と違い符号を持つ：正 = 投手方向、負 = 捕手方向（テイクバック）。
    velTopX = velTop(:, 1) ;                        % [m/s]  投手方向成分

    [peakVelTop,  idxPeak]  = max(netVelTop) ;      % 合成速度のピークとその時刻
    [peakVelTopX, idxPeakX] = max(velTopX) ;        % Vx のピークとその時刻
    velTopXAtPeak = velTopX(idxPeak) ;              % 合成速度ピーク時の Vx [m/s]
else
    netVelTop   = [] ;   velTopX  = [] ;
    peakVelTop  = NaN ;  idxPeak  = NaN ;
    peakVelTopX = NaN ;  idxPeakX = NaN ;  velTopXAtPeak = NaN ;
end

Result.NetVelTop     = netVelTop ;            % 合成速度の波形
Result.VelTopX       = velTopX ;              % 投手方向成分の波形
Result.PeakVelTop    = peakVelTop ;           % 合成速度のピーク [m/s]
Result.TPeakVelTop   = idxPeak ;              % そのフレーム番号（試行先頭から）
Result.PeakVelTopX   = peakVelTopX ;          % Vx のピーク [m/s]
Result.TPeakVelTopX  = idxPeakX ;             % そのフレーム番号（試行先頭から）
Result.VelTopXAtPeak = velTopXAtPeak ;        % 合成速度ピーク時の Vx [m/s]

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
    Result.FxBase  = NaN ;              % ★変更：Fz1BaseMean から改名（Fx 方式へ移行）
    Result.FxThr   = NaN ;              % ★変更：Fz1BaseSD から改名
    Result.SwingOnsetForce = NaN ;
    Result.RTForce         = NaN ;
    Result.BWTail  = NaN ;              % ★追加：正常経路と並び順を揃える
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

% ---- 除外基準①：解析窓内（cue 後 0〜Prm.Excl.WinSec）に top の欠損があるか ----
%  §9.4 の「判定すべきは欠損の総量ではなく、指標に実害のある位置に欠損があるか」
%  に対応する。範囲は §10.8 の実測比較を経て解析窓内に確定した。
wTop = max(1, tCueMarker) : ...
       min(tCueMarker + round(Prm.Excl.WinSec*fs), numel(isNanTop)) ;
Result.NNanInWinTop = sum(isNanTop(wTop)) ;
Result.IsBadTop     = Result.NNanInWinTop > 0 ;

% ---- スイング開始検出（前後方向の合成床反力 Fx）----
%  sandbox/5.6_プロット 00_技術説明 §3 で検証した方式（2026-09-28 本番へ移植）。
%  Fx = Force1(:,1) + Force2(:,1) をローパスし、キュー前 0.5 s の中央値 base を基準に
%    閾値 = base + 0.20 ×（キュー → 踏み込み足接地 の窓内ピーク − base）
%  を 20 ms 続けて超えた最初の時点を動作開始とする。
%  SD 基準（旧 Fz1 方式）をやめたのは、キュー前の揺れで閾値が届かなくなるため
%  （技術説明 §12）。
%  時刻はアナログのサンプル番号のまま扱い、ms への変換は出力時だけ行う。
%  NoGo / Stop 試行も含めて全試行で算出する。報告時にどの試行を
%  反応時間として扱うかは、下流（x6 以降）で決める。
%  ★ キューの前から踏み込み足が乗っている試行は、接地がすぐ成立して探索窓が
%    短くなり NaN になる（sandbox 5.6 技術説明 §12.2、未解決）。

Result.FxBase          = NaN ;   % キュー前 0.5 s の Fx 中央値 [N]
Result.FxThr           = NaN ;   % onset の閾値 [N]
Result.SwingOnsetForce = NaN ;   % アナログのサンプル番号（試行先頭から）
Result.RTForce         = NaN ;   % [ms] キュー → 動作開始

if isfield(Data, 'Force1') && ~isempty(Data.Force1) ...
        && isfield(Data, 'Force2') && ~isempty(Data.Force2) ...
        && tCueAnalog >= 2

    fsA = Data.AnalogFs ;
    F1  = Data.Force1 ;
    F2  = Data.Force2 ;

    % 末尾の NaN を切り落とす（filtfilt は NaN を受け付けない）
    lastValid = find(~any(isnan(F1), 2) & ~any(isnan(F2), 2), 1, 'last') ;

    if ~isempty(lastValid) && lastValid > tCueAnalog
        F1 = F1(1:lastValid, :) ;
        F2 = F2(1:lastValid, :) ;

        % 切っても内部に NaN が残る試行は諦める
        if ~any(isnan(F1(:))) && ~any(isnan(F2(:)))

            [bR, aR] = butter(2, Prm.RT.FxFc/(fsA/2)) ;
            F1f = filtfilt(bR, aR, F1) ;
            F2f = filtfilt(bR, aR, F2) ;
            fx  = F1f(:,1) + F2f(:,1) ;          % 前後方向の合成床反力 [N]
            nA  = numel(fx) ;

            nBase = round(Prm.RT.BaseSec * fsA) ;
            Result.FxBase = median( fx(max(1, tCueAnalog-nBase) : tCueAnalog-1) ) ;

            % 踏み込み足の接地：キュー後に Fz2 が初めて閾値を超えた点
            tFC = find(F2f(tCueAnalog:nA, 3) > Prm.RT.FootContactN, 1, 'first') ;

            if ~isempty(tFC) && (tFC - 1) >= round(Prm.RT.MinWinMs/1000 * fsA)
                tFC    = tFC + tCueAnalog - 1 ;      % 試行先頭からの位置に直す
                peakFx = max( fx(tCueAnalog:tFC) - Result.FxBase ) ;

                if peakFx > 0
                    Result.FxThr = Result.FxBase + Prm.RT.FxRatio * peakFx ;
                    isOver = fx > Result.FxThr ;
                    nDur   = round(Prm.RT.DurMs/1000 * fsA) ;

                    % 下から閾値を跨ぎ、nDur サンプル続いた最初の点
                    for k = tCueAnalog+1 : (tFC - nDur + 1)
                        if ~isOver(k-1) && all(isOver(k : k+nDur-1))
                            Result.SwingOnsetForce = k ;
                            Result.RTForce = (k - tCueAnalog) / fsA * 1000 ;   % [ms]
                            break
                        end
                    end
                end
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
Result.BWTail  = NaN ;   % ★追加：記録末端 0.5 s の Fz1+Fz2 [N]（体重推定用）
Result.BWBase  = NaN ;   % 静止時（キュー前）Fz1+Fz2 [N]（参照用に残す）
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
    nTail   = round(Prm.Excl.BWTailSec * fsA) ;

    % ★変更：末尾の NaN を切り落としてから使う（sandbox 5.8 h0 と同じ）。
    %   従来は any(isnan(記録全体)) で弾いていたため、QTM の記録終端に NaN が
    %   1つ残っているだけで試行ごと床反力を失っていた（§7.9 の
    %   gonogo Trial 5 / gostop Trial 5 がこれ）。技術説明 §10。
    lastValid = find(~isnan(Fz1_raw) & ~isnan(Fz2_raw), 1, 'last') ;

    if ~isempty(lastValid) && lastValid > tCueAnalog + nTail
        Fz1_raw = Fz1_raw(1:lastValid) ;
        Fz2_raw = Fz2_raw(1:lastValid) ;

        % 切っても内部に NaN が残る試行は諦める（filtfilt が全体を NaN にする）
        if ~any(isnan(Fz1_raw)) && ~any(isnan(Fz2_raw))

            % Methods 2-4-3 に従い、マーカーと同じ 30 Hz・2次でローパスする
            [bF, aF] = butter(2, fc/(fsA/2)) ;
            Fz1_filt = filtfilt(bF, aF, Fz1_raw) ;
            Fz2_filt = filtfilt(bF, aF, Fz2_raw) ;

            % ★追加：記録末端 0.5 s の Fz1+Fz2。被験者の体重推定に使う（x8）。
            %   末端は全被験者で両足がプレート上にあるので構えの違いに依存しない。
            tot           = Fz1_filt + Fz2_filt ;
            Result.BWTail = mean(tot(end-nTail+1 : end)) ;

            Result.BWBase = mean(Fz1_filt(1:tCueAnalog-1)) ...
                          + mean(Fz2_filt(1:tCueAnalog-1)) ;

            swingEnd   = min(tCueAnalog + round(Prm.GRF.WinSec*fsA), numel(Fz1_filt)) ;
            swingRange = tCueAnalog : swingEnd ;

            Result.PeakFz1 = max(Fz1_filt(swingRange)) ;
            Result.PeakFz2 = max(Fz2_filt(swingRange)) ;

            Result.Fz1Filt = Fz1_filt ;   % ★追加：波形をそのまま下流へ渡す
            Result.Fz2Filt = Fz2_filt ;   % ★追加
        end
    end
end

end
