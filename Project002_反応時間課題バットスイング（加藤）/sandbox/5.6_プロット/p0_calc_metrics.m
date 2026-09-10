% p0_calc_metrics.m
%
% 目的:
%   条件別_全被験者_RT-MT-PeakVel-Slope.png（2026-08-26）と同じ4指標を、
%   2026-09-10 に確定した新しい除外基準で算出し直す。
%   算出だけを担当し、描画は p1_plot_by_condition.m が行う（5.8 の h0/h1 と同じ分担）。
%
% 入力:
%   Experiments/Main experiments/03_Analysis/x3_DataChecked/Data0x.mat
%     … 波形（Markers / Force1 / Force2 / LEDData）
%   Experiments/Main experiments/03_Analysis/x4_SingleTrialAnalysisResults/*.mat
%     … CueText と IsBadTop / NNanInWinTop（新しい除外基準の判定結果）
%
% 出力（ワークスペースに残す）:
%   V          ... {被験者 × 条件 × 指標} のセル配列。各セルに有効な試行の値を縦に積む
%   MetricName ... 指標名（p1 の図のタイトルに使う）
%   SubjectArray / ConditionNameArray / nS / nC / nM
%   Diag       ... 検出と除外の内訳
%
% 指標の定義（★ 旧図と完全に同一。比較できるように変えていない）:
%   [1] RT [ms]
%       Fx（前後方向の合成床反力 Force1(:,1)+Force2(:,1)）が
%         閾値 = ベースライン中央値 + 0.20 ×（窓内ピーク − ベースライン中央値）
%       を 20 ms continuously 超えた最初の時点。探索窓は cue → 踏み込み足接地。
%       経緯と、この方式を採る理由は 技術説明.md §3。
%   [2] MT [ms]      = バット先端の最大速度の時点 − onset
%   [3] Peak velocity [m/s] = cue 以降のバット先端合成速度の最大値
%   [4] Slope [m/s^2]       = Peak velocity ÷ MT
%
% ★ 旧図との違いは「除外基準」だけである（技術説明.md §6）:
%
%   旧図: 検出できた 258 試行に対し、値の範囲による事後フィルタをかけていた。
%         PeakVel 5〜40 m/s、MT > 0、RT 100〜600 ms → 217 試行
%         これは「値がおかしい試行を値で落とす」やり方で、
%         03_Analysis で 2026-09-10 に廃止した種類の基準である。
%
%   新図: 03_Analysis 技術説明 §10.1 の2基準だけを使う。
%         ① top マーカーの欠損（解析窓内 = cue 後 0〜2 s）→ PeakVel・MT・Slope を除外
%         ② 床反力が正常に計測できていない          → RT・MT・Slope を除外
%         判定①は x4 が付けた Result.IsBadTop をそのまま使う（判定を二重に
%         実装しない。実装が食い違うと図と統計で違う試行が落ちる）。
%         NoGo・Stop 試行の除外は課題設計上の選別として維持する。
%
% 備考:
%   - ★ 値の範囲による除外は入れていない。スイングを止めた試行（gostop に数本）は
%     PeakVel が 5 m/s 台で残る。落とすべきかは値ではなく課題遂行の失敗として
%     判定すべきで、その仕組みは 03_Analysis にまだ無い（§10.1 の議論）。
%   - ★ MT と Slope は onset（床反力）とピーク（top マーカー）の両方に依存するので、
%     ①②のどちらかに掛かれば落ちる。指標ごとに前提条件を確かめる
%     （03_Analysis 技術説明 §3.9 の教訓）。
%   - ★ addpath は parameters を呼ぶ前に済ませる（5.7 の技術説明 §4-4）。
%   - ★ PeakVel の探索窓は cue → 記録末尾で、①の判定窓（cue → cue+2 s）より広い。
%     旧図と同じ定義を保つためにこうしてある。窓の外にピークがある試行の数を
%     診断に出すので、増えたら定義をそろえることを検討する（03_Analysis §10.4）。
%
% 2026-09-10

clear ;
close all


%% ---- 1. パスの解決（parameters を呼ぶ前に済ませる）----

thisDir     = fileparts( mfilename('fullpath') ) ;
projectRoot = fileparts( fileparts(thisDir) ) ;
analysisDir = fullfile(projectRoot, 'Experiments', 'Main experiments', '03_Analysis') ;
dataDir     = fullfile(analysisDir, 'x3_DataChecked') ;
resultDir   = fullfile(analysisDir, 'x4_SingleTrialAnalysisResults') ;

addpath(analysisDir)

fprintf('parameters.m の場所: %s\n', which('parameters')) ;


%% ---- 2. 設定 ----

Prm = parameters ;

SubjectArray       = 1:5 ;
ConditionNameArray = {'free', 'simple', 'gonogo', 'gostop'} ;

MetricName = { ...
    'RT  反応時間 [ms]', ...
    'MT  動作時間 [ms]', ...
    'Peak velocity  最大速度 [m/s]', ...
    'Slope  平均加速度 [m/s^2]'} ;

nS = numel(SubjectArray) ;
nC = numel(ConditionNameArray) ;
nM = numel(MetricName) ;

% --- RT 検出のパラメータ（untitled.m / 5.8 の h0 と同一）---
PrmRT.Fc           = 50 ;    % ローパス遮断周波数 [Hz]
PrmRT.FootContactN = 50 ;    % 踏み込み足の接地とみなす Fz2 の閾値 [N]
PrmRT.BaseSec      = 0.5 ;   % ベースライン窓（cue 直前）[s]
PrmRT.RatioFx      = 0.20 ;  % 閾値 = ベース + 比率 ×（窓内ピーク − ベース）
PrmRT.DurMs        = 20 ;    % 閾値超えの持続時間 [ms]
PrmRT.MinWinSample = 50 ;    % cue → 接地 がこれ未満なら探索窓が短すぎる

% アナログ系は全試行 1000 Hz なので、係数はループの外で一度だけ設計する。
[bR, aR] = butter(2, PrmRT.Fc/(1000/2), 'low') ;


%% ---- 3. 試行ごとの値を集める ----

V = cell(nS, nC, nM) ;

Diag = struct('nGo',0, 'nTrimmedNan',0, 'nAnalogNan',0, ...
              'nNoFootContact',0, 'nShortWin',0, 'nNoPeakFx',0, 'nNoOnset',0, ...
              'nBadTop',0, 'nPeakOutOfWin',0, 'nCueMismatch',0, ...
              'nOKrt',0, 'nOKvel',0, 'nOKmt',0) ;

for iS = 1:nS

    load( fullfile(dataDir,   sprintf('Data%02d.mat', SubjectArray(iS))) )
    load( fullfile(resultDir, sprintf('SingleTrialAnalysisResults%02d.mat', ...
                                      SubjectArray(iS))) )

    nTrial = size(DataArray, 1) ;

    for ic = 1:nC
        for it = 1:nTrial

            D = DataArray(it, ic) ;
            R = SingleTrialResultArray(it, ic) ;

            % 存在しない試行（埋め要素）
            if isempty(D.ErrorCode) || isequal(D.ErrorCode, Prm.ErrorCode.NoData)
                continue
            end

            % ---- NoGo・Stop の除外（課題設計上の選別。データ品質とは別軸）----
            if ~strcmp(R.CueText, 'Go'), continue, end
            Diag.nGo = Diag.nGo + 1 ;

            % ==== 3-1. アナログの整形 ====
            if ~isfield(D,'Force1') || isempty(D.Force1) || isempty(D.Force2) ...
                    || isempty(D.LEDData)
                Diag.nAnalogNan = Diag.nAnalogNan + 1 ;
                continue
            end

            % 末尾の NaN を落とす（filtfilt は NaN を受け付けない）
            isBadSample = any(isnan(D.LEDData),2) | any(isnan(D.Force1),2) ...
                        | any(isnan(D.Force2),2) ;
            lastValid   = find(~isBadSample, 1, 'last') ;

            if isempty(lastValid) || lastValid < 100
                Diag.nAnalogNan = Diag.nAnalogNan + 1 ;
                continue
            end
            if lastValid < numel(isBadSample)
                Diag.nTrimmedNan = Diag.nTrimmedNan + 1 ;
            end

            led = D.LEDData(1:lastValid, 2) ;
            F1  = D.Force1( 1:lastValid, :) ;
            F2  = D.Force2( 1:lastValid, :) ;

            % 切っても内部に NaN が残る試行は床反力を諦める（除外基準②）
            if any(isnan(F1(:))) || any(isnan(F2(:)))
                Diag.nAnalogNan = Diag.nAnalogNan + 1 ;
                continue
            end

            fsA = D.AnalogFs ;
            fs  = D.FrameRate ;

            % ==== 3-2. cue の位置 ====
            % 分類そのものは x4（m3）の CueText に従う。ここで取るのは時刻だけ。
            tGoStim = find(led > Prm.Cue.GoThresholdV, 1, 'first') ;
            if isempty(tGoStim) || tGoStim < 2
                Diag.nCueMismatch = Diag.nCueMismatch + 1 ;
                continue
            end

            % ==== 3-3. 床反力のフィルタと踏み込み足の接地 ====
            F1f = filtfilt(bR, aR, F1) ;
            F2f = filtfilt(bR, aR, F2) ;
            fx  = F1f(:,1) + F2f(:,1) ;      % 前後方向の合成床反力 [N]

            nA  = size(F2f, 1) ;
            tFC = find(F2f(tGoStim:nA, 3) > PrmRT.FootContactN, 1, 'first') ;

            if isempty(tFC)
                Diag.nNoFootContact = Diag.nNoFootContact + 1 ;
                tOnset = NaN ;
            else
                tFC = tFC + tGoStim - 1 ;

                if tFC - tGoStim < PrmRT.MinWinSample
                    Diag.nShortWin = Diag.nShortWin + 1 ;
                    tOnset = NaN ;
                else
                    % ==== 3-4. RT 検出（Fx のピーク相対閾値・持続条件つき）====
                    nDur   = round(PrmRT.DurMs/1000 * fsA) ;
                    nBase  = round(PrmRT.BaseSec    * fsA) ;
                    iBase  = max(1, tGoStim-nBase) : tGoStim-1 ;
                    baseFx = median( fx(iBase) ) ;
                    peakFx = max( fx(tGoStim:tFC) - baseFx ) ;

                    if peakFx <= 0
                        Diag.nNoPeakFx = Diag.nNoPeakFx + 1 ;
                        tOnset = NaN ;
                    else
                        thrFx  = baseFx + peakFx * PrmRT.RatioFx ;
                        isOver = fx > thrFx ;

                        tOnset = NaN ;
                        for k = tGoStim+1 : (tFC - nDur + 1)
                            if ~isOver(k-1) && all( isOver(k : k+nDur-1) )
                                tOnset = k ;
                                break
                            end
                        end
                        if isnan(tOnset)
                            Diag.nNoOnset = Diag.nNoOnset + 1 ;
                        end
                    end
                end
            end

            % ==== 3-5. バット先端の速度 ====
            % ★ 除外基準①は x4 が付けた判定をそのまま使う（二重実装をしない）。
            isBadTop = R.IsBadTop ;
            if isBadTop, Diag.nBadTop = Diag.nBadTop + 1 ; end

            peakVel = NaN ; tPeak = NaN ;
            if ~isBadTop && isfield(D.Markers, Prm.Excl.TopMarkerName)
                top     = D.Markers.(Prm.Excl.TopMarkerName) ;
                velNorm = sum(diff3p(top, 1/fs).^2, 2).^0.5 ;   % [mm/s]

                % ピークは cue 以降に限定する（構え直しを拾わないため）。
                % analogFs/fs = 4 なので、アナログ番号をマーカー番号に直す。
                iGoFrame = max(1, round(tGoStim / (fsA/fs))) ;
                [pv, iRel] = max( velNorm(iGoFrame:end) ) ;
                tPeak      = iRel + iGoFrame - 1 ;
                peakVel    = pv / 1000 ;                        % [m/s]

                % ①の判定窓（cue → cue+Prm.Excl.WinSec）の外にピークがあるか
                if tPeak > iGoFrame + round(Prm.Excl.WinSec*fs)
                    Diag.nPeakOutOfWin = Diag.nPeakOutOfWin + 1 ;
                end
            end

            % ==== 3-6. 指標の確定 ====
            rtMs = NaN ; mtMs = NaN ; slope = NaN ;

            if ~isnan(tOnset)
                rtMs = (tOnset - tGoStim) / fsA * 1000 ;        % [ms]
                Diag.nOKrt = Diag.nOKrt + 1 ;
            end
            if ~isnan(peakVel)
                Diag.nOKvel = Diag.nOKvel + 1 ;
            end
            if ~isnan(tOnset) && ~isnan(tPeak)
                % 時間軸をそろえてから引く（マーカー 250 Hz / アナログ 1000 Hz）
                mtMs = (tPeak/fs - tOnset/fsA) * 1000 ;         % [ms]
                if mtMs > 0
                    slope = peakVel / (mtMs/1000) ;             % [m/s^2]
                    Diag.nOKmt = Diag.nOKmt + 1 ;
                else
                    % ピークが onset より前。時間の定義が崩れるので値を出さない。
                    mtMs = NaN ;
                end
            end

            % ★ 指標ごとに、算出できたものだけを積む
            if ~isnan(rtMs),    V{iS,ic,1} = [V{iS,ic,1} ; rtMs   ] ; end
            if ~isnan(mtMs),    V{iS,ic,2} = [V{iS,ic,2} ; mtMs   ] ; end
            if ~isnan(peakVel), V{iS,ic,3} = [V{iS,ic,3} ; peakVel] ; end
            if ~isnan(slope),   V{iS,ic,4} = [V{iS,ic,4} ; slope  ] ; end

        end
    end

    clear DataArray SingleTrialResultArray

end


%% ---- 4. 検算と診断 ----

fprintf('\n--- 試行の内訳 ---\n') ;
fprintf('  Go 試行                        : %d\n', Diag.nGo) ;
fprintf('  末尾 NaN を切った試行          : %d\n', Diag.nTrimmedNan) ;
fprintf('  【除外②】床反力が使えない     : %d\n', Diag.nAnalogNan) ;
fprintf('  【除外①】top の欠損（窓内）   : %d\n', Diag.nBadTop) ;
fprintf('  接地が見つからない             : %d\n', Diag.nNoFootContact) ;
fprintf('  cue→接地 の窓が短い           : %d\n', Diag.nShortWin) ;
fprintf('  窓内で Fx がベースを超えず     : %d\n', Diag.nNoPeakFx) ;
fprintf('  onset 未検出                   : %d\n', Diag.nNoOnset) ;
fprintf('  cue が取れない                 : %d\n', Diag.nCueMismatch) ;
fprintf('  ピークが判定窓の外             : %d', Diag.nPeakOutOfWin) ;
if Diag.nPeakOutOfWin == 0
    fprintf('（判定窓と探索窓の食い違いは実測では生じていない）\n') ;
else
    fprintf(' ★ 定義をそろえることを検討（03_Analysis §10.4）\n') ;
end
fprintf('\n  算出できた試行: RT %d / PeakVel %d / MT・Slope %d\n', ...
    Diag.nOKrt, Diag.nOKvel, Diag.nOKmt) ;

fprintf('\n--- 条件別の中央値（括弧内は n）---\n') ;
fprintf('%-8s', '条件') ;
for im = 1:nM, fprintf('%22s', MetricName{im}) ; end
fprintf('\n') ;
for ic = 1:nC
    fprintf('%-8s', ConditionNameArray{ic}) ;
    for im = 1:nM
        a = [] ;
        for iS = 1:nS, a = [a ; V{iS,ic,im}] ; end                         %#ok<AGROW>
        if isempty(a)
            fprintf('%22s', '—') ;
        else
            fprintf('%16.1f (%3d)', median(a), numel(a)) ;
        end
    end
    fprintf('\n') ;
end

% 旧図（2026-08-26、値の範囲で事後フィルタ）との比較。
% 定義は同じなので、差はまるごと除外基準の違いによるもの。
fprintf('\n--- 旧図との比較（旧 = 値の範囲による事後フィルタ、217試行）---\n') ;
OldMed = [258.0 710.0 32.22 43.2 ;      % free
          190.0 553.0 32.66 58.2 ;      % simple
          200.0 570.0 31.83 53.0 ;      % gonogo
          206.5 604.5 32.48 51.4] ;     % gostop
OldN   = [67 61 43 46] ;
for im = 1:nM
    fprintf('  %s\n', MetricName{im}) ;
    for ic = 1:nC
        a = [] ;
        for iS = 1:nS, a = [a ; V{iS,ic,im}] ; end                         %#ok<AGROW>
        if isempty(a), continue, end
        fprintf('    %-8s 旧 %7.1f (n=%2d)  →  新 %7.1f (n=%2d)   差 %+7.1f\n', ...
            ConditionNameArray{ic}, OldMed(ic,im), OldN(ic), ...
            median(a), numel(a), median(a) - OldMed(ic,im)) ;
    end
end
