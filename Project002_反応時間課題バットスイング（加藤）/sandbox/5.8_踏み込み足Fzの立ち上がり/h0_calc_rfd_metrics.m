% h0_calc_rfd_metrics.m
%
% 目的:
%   踏み込み足の鉛直床反力（Fz2）について、
%     1. ピーク値                        [%BW]
%     2. RT からピークまでの時間          [ms]
%     3. その間の力の立ち上がり速度（RFD） [%BW/s]
%   を試行ごとに算出する。RT は 5.6_プロット と同じ定義（Fx のピーク相対閾値）。
%   算出だけを担当し、描画は h1_plot_rfd_by_condition.m が行う。
%
% 入力:
%   Experiments/Main experiments/03_Analysis/x3_DataChecked/Data0x.mat（S01〜S05）
%
% 出力（ワークスペースに残す）:
%   V          ... {被験者 × 条件 × 指標} のセル配列。各セルに試行の値を縦に積む
%   BWest      ... [1 × nS] 推定体重 [N]（%BW の分母）
%   MetricName ... 指標名（h1 の図のタイトルに使う）
%   SubjectArray / ConditionNameArray / nS / nC / nM
%   Diag       ... 検出の内訳（除外理由の集計）
%   Rec        ... 試行ごとの素性と検出時刻（h3_plot_example_trials.m が波形確認に使う）
%
% 指標の定義:
%   [1] RT [ms]（参考）
%       5.6_プロット/untitled.m と同一。Fx = Fz 方向ではなく前後方向の合成床反力
%       （Force1(:,1) + Force2(:,1)）が、
%         閾値 = ベースライン中央値 + 0.20 ×（窓内ピーク − ベースライン中央値）
%       を 20 ms continuously 超えた最初の時点。探索窓は cue → 踏み込み足接地。
%       ★ g0_calc_grf_metrics.m の「荷重の抜け始め」（Fz1 の 10SD 逸脱）とは別物。
%          あちらは 250〜300 ms 遅い。ここでは 5.6 の RT を使う（ユーザー指示）。
%
%   [2] 踏み込み足 ピーク鉛直GRF [%BW]
%       g0 の指標1と同一。探索窓は cue → cue + Prm.GRF.WinSec（2 s）。
%       窓を g0 とそろえてあるので、条件中央値は g0 の図と照合できる。
%
%   [3] RT → Fzピーク の時間 [ms]
%       (tPeak - tOnset) / fs * 1000。踏み込み足の接地はこの区間の中にある。
%
%   [4] 力の立ち上がり速度 [%BW/s]
%       (Fz2ピーク − RT時点の Fz2) / 体重 * 100 / 区間の秒数。
%       ★ 分子から RT 時点の値を引く。5.6 の AveSlopeTopVel は
%          「ピーク速度 ÷ MT」で引き算をしていないが、あれは onset 時点の
%          バット速度がほぼ 0 だから成り立つ。Fz2 は onset 時点で 0 とは限らない
%          （踏み込み足が浮いていれば約 3 N、乗っていれば体重の数割）ので、
%          引かないと構えの違いがそのまま指標に混ざる。
%
% 備考:
%   - ★ 分母は「記録末端 0.5 s の Fz1+Fz2 の中央値（外れ値除去）」で推定した体重。
%     2026-09-07 の方針決定による（g0 と同じ）。理由は g0 のヘッダと 5.7 の技術説明 §3-6。
%   - ★ フィルタを 2 種類使う。RT 検出は 5.6 と同じ 50 Hz、GRF 指標は本番の
%     m3 と同じ Prm.Fc（30 Hz）。filtfilt は零位相なので、両者を突き合わせても
%     時間のずれは生じない。1本にそろえたい場合は FcRT を Prm.Fc にすればよい。
%   - ★ アナログ末尾の NaN は落としてから使う（5.6 と同じ）。
%     g0 は NaN を含む試行を丸ごと捨てていたので、n が g0 より少し多くなる。
%   - ★ addpath は parameters を呼ぶ前に済ませる（5.7 の技術説明 §4-4）。
%   - 指標を増やすときは「★ 指標の追加はここ」の 2 か所（MetricName と算出）だけ触る。

clear ;
close all


%% ---- 1. パスの解決（parameters を呼ぶ前に済ませる）----

thisDir     = fileparts( mfilename('fullpath') ) ;
projectRoot = fileparts( fileparts(thisDir) ) ;
analysisDir = fullfile(projectRoot, 'Experiments', 'Main experiments', '03_Analysis') ;
dataDir     = fullfile(analysisDir, 'x3_DataChecked') ;

addpath(analysisDir)

fprintf('parameters.m の場所: %s\n', which('parameters')) ;


%% ---- 2. 設定 ----

Prm = parameters ;

SubjectArray       = 1:5 ;
ConditionNameArray = {'free', 'simple', 'gonogo', 'gostop'} ;

% ★ 指標の追加はここ（1/2）。名前を足したら 3-3 に算出を足す。
MetricName = { ...
    'RT（5.6 の定義） [ms]', ...
    '踏み込み足  ピーク鉛直GRF [%BW]', ...
    'RT → Fzピーク の時間 [ms]', ...
    '力の立ち上がり速度 [%BW/s]', ...
    '立ち上がり速度 ÷ ピーク力 [1/s]'} ;

nS = numel(SubjectArray) ;
nC = numel(ConditionNameArray) ;
nM = numel(MetricName) ;

% --- RT 検出のパラメータ（5.6_プロット/untitled.m と同一）---
PrmRT.Fc           = 50 ;    % ローパス遮断周波数 [Hz]
PrmRT.FootContactN = 50 ;    % 踏み込み足の接地とみなす Fz2 の閾値 [N]
PrmRT.BaseSec      = 0.5 ;   % ベースライン窓（cue 直前）[s]
PrmRT.RatioFx      = 0.20 ;  % 閾値 = ベース + 比率 ×（窓内ピーク − ベース）
PrmRT.DurMs        = 20 ;    % 閾値超えの持続時間 [ms]
PrmRT.MinWinSample = 50 ;    % cue → 接地 がこれ未満なら探索窓が短すぎる

% アナログ系は全試行 1000 Hz なので、係数はループの外で一度だけ設計する。
% 2 次：GRF 指標は m3_analyze_single_trial.m:214 と同じ。
[bG, aG] = butter(2, Prm.Fc   /(1000/2), 'low') ;   % GRF 指標用（30 Hz）
[bR, aR] = butter(2, PrmRT.Fc /(1000/2), 'low') ;   % RT 検出用（50 Hz）


%% ---- 3. 試行ごとの値を集める ----

V     = cell(nS, nC, nM) ;
BWest = nan(1, nS) ;

Diag = struct('nGo',0, 'nBadBW',0, 'nNoFootContact',0, 'nShortWin',0, ...
              'nNoPeakFx',0, 'nNoOnset',0, 'nPeakBeforeOnset',0, 'nOK',0, ...
              'nTrimmedNan',0, 'nRTShort',0) ;

% ★ 波形確認（h3）用。5指標すべてを算出できた試行の素性と検出時刻を残す。
%   ここに残さないと、あとから「どの試行のどのサンプルを測ったか」を再現できない。
Rec = struct('iS',{}, 'sub',{}, 'ic',{}, 'it',{}, 'tc',{}, 'tOnset',{}, ...
             'tFC',{}, 'tPeak',{}, 'fs',{}, 'bw',{}, 'rtMs',{}, 'pkBW',{}, ...
             'onsetBW',{}, 'dtMs',{}, 'rfd',{}, 'baseFx',{}, 'thrFx',{}) ;
RTAll      = [] ;   % 診断用に RT を全部ためる
OnsetBWAll = [] ;   % 診断用に RT 時点の Fz2 [%BW] をためる
RatioAll   = [] ;   % 診断用に (1 - onsetBW/pkBW) をためる

for iS = 1:nS

    load( fullfile(dataDir, sprintf('Data%02d.mat', SubjectArray(iS))) )
    nTrial = size(DataArray, 1) ;

    % ==== 3-0. 使える試行だけを先に整形しておく ====
    % 末尾 NaN の切り落とし・cue 判定・ベースライン体重を 1 回のループで済ませ、
    % 整形済みの波形を Trial に持たせる。3-1〜3-3 はこれを見るだけにする。
    Trial = struct('ok', num2cell(false(nTrial, nC))) ;

    for ic = 1:nC
        for it = 1:nTrial

            D = DataArray(it, ic) ;

            % isfield と ~isempty の両方が必要（埋め要素は Force1 が空）
            if ~isfield(D,'Force1') || isempty(D.Force1) || isempty(D.Force2) ...
                    || isempty(D.LEDData), continue, end

            % --- アナログ末尾の NaN を落とす（5.6 と同じ）---
            %  QTM の記録終端に NaN が残っている試行がある。filtfilt は NaN を
            %  受け付けないので、ここで切る。切っても内部に NaN が残る試行は捨てる。
            isBad = any(isnan(D.LEDData),2) | any(isnan(D.Force1),2) | any(isnan(D.Force2),2) ;
            lastValid = find(~isBad, 1, 'last') ;
            if isempty(lastValid) || lastValid < 100, continue, end
            if lastValid < numel(isBad), Diag.nTrimmedNan = Diag.nTrimmedNan + 1 ; end

            led = D.LEDData(1:lastValid, 2) ;
            F1r = D.Force1( 1:lastValid, :) ;
            F2r = D.Force2( 1:lastValid, :) ;
            if any(isnan(F1r(:))) || any(isnan(F2r(:))), continue, end

            % --- Go / NoGo / Stop の判定（gostop は「正の後に負」）---
            tGo  = find(led >  Prm.Cue.GoThresholdV,  1, 'first') ;
            tNeg = find(led <  Prm.Cue.NegThresholdV, 1, 'first') ;

            if ~isempty(tGo) && (isempty(tNeg) || tNeg > tGo)
                tc = tGo ;
                stopWin = round(Prm.Cue.StopWinSec * D.AnalogFs) ;
                if ~isempty(tNeg) && (tNeg - tGo) <= stopWin
                    cueText = 'Stop' ;
                else
                    cueText = 'Go' ;
                end
            elseif ~isempty(tNeg)
                tc = tNeg ; cueText = 'NoGo' ;
            else
                continue
            end
            if tc < 2, continue, end

            Trial(it,ic).ok      = true ;
            Trial(it,ic).cueText = cueText ;
            Trial(it,ic).tc      = tc ;
            Trial(it,ic).fs      = D.AnalogFs ;
            Trial(it,ic).F1g     = filtfilt(bG, aG, F1r) ;   % 30 Hz（GRF 指標）
            Trial(it,ic).F2g     = filtfilt(bG, aG, F2r) ;
            Trial(it,ic).F1r     = filtfilt(bR, aR, F1r) ;   % 50 Hz（RT 検出）
            Trial(it,ic).F2r     = filtfilt(bR, aR, F2r) ;
        end
    end

    % ==== 3-1. 体重の推定（記録末端 0.5 s、外れ値除去、中央値）====
    % 末端は全被験者で両足がプレート上にあるので、構えの違いに依存しない。
    E = [] ;
    for ic = 1:nC
        for it = 1:nTrial
            if ~Trial(it,ic).ok, continue, end
            tot = Trial(it,ic).F1g(:,3) + Trial(it,ic).F2g(:,3) ;
            E = [E ; mean(tot(end-499:end))] ;                              %#ok<AGROW>
        end
    end
    % 末端でプレートから降りている試行を外す（中央値の 70% 未満）。
    BWest(iS) = median( E(E > 0.7*median(E)) ) ;

    % ==== 3-2. BWBase による計測不良の除外判定 ====
    % ★ 中央値は同一被験者内で取る。被験者をまたぐと体重差が許容範囲に混ざる。
    BB = nan(nTrial, nC) ;
    for ic = 1:nC
        for it = 1:nTrial
            if ~Trial(it,ic).ok, continue, end
            tc = Trial(it,ic).tc ;
            BB(it,ic) = mean(Trial(it,ic).F1g(1:tc-1,3)) + mean(Trial(it,ic).F2g(1:tc-1,3)) ;
        end
    end
    bwRef = median(BB(:), 'omitnan') ;
    isBadBW = isnan(BB) | abs(BB - bwRef) > Prm.GRF.BWTolerance * bwRef ;

    % ==== 3-3. 指標の算出（Go かつ除外されていない試行のみ）====
    % ★ 「Go である」という肯定形で選ぶ。否定形だと cue 未検出の試行が通る。
    for ic = 1:nC
        for it = 1:nTrial

            if ~Trial(it,ic).ok, continue, end
            if ~strcmp(Trial(it,ic).cueText, 'Go'), continue, end
            Diag.nGo = Diag.nGo + 1 ;
            if isBadBW(it,ic), Diag.nBadBW = Diag.nBadBW + 1 ; continue, end

            T   = Trial(it,ic) ;
            fsA = T.fs ;
            tc  = T.tc ;
            bw  = BWest(iS) ;
            n   = size(T.F2g, 1) ;

            % --- (a) Fz2 のピーク（探索窓は g0 と同じ cue → cue + 2 s）---
            swingEnd   = min(tc + round(Prm.GRF.WinSec*fsA), n) ;
            swingRange = tc : swingEnd ;
            [pkFz2, iRel] = max( T.F2g(swingRange, 3) ) ;
            tPeak = swingRange(1) + iRel - 1 ;
            pkBW  = pkFz2 / bw * 100 ;                          % [%BW]

            % ★ 指標の追加はここ（2/2）。ピークだけは onset の成否によらず入れる
            %    （g0 の図と n をそろえて照合できるようにするため）。
            V{iS,ic,2} = [V{iS,ic,2} ; pkBW] ;

            % --- (b) RT 検出（5.6_プロット/untitled.m と同一）---
            %  探索窓は cue → 踏み込み足の接地。踏み込み足は構えでは浮いている
            %  （実測で cue 時点の Fz2 は全被験者 約3 N）ので閾値 50 N で拾える。
            iFC = find( T.F2r(tc:n, 3) > PrmRT.FootContactN, 1, 'first') ;
            if isempty(iFC), Diag.nNoFootContact = Diag.nNoFootContact + 1 ; continue, end
            tFC = iFC + tc - 1 ;
            if tFC - tc < PrmRT.MinWinSample, Diag.nShortWin = Diag.nShortWin + 1 ; continue, end

            fx     = T.F1r(:,1) + T.F2r(:,1) ;            % 前後方向の合成床反力 [N]
            iBase  = max(1, tc - round(PrmRT.BaseSec*fsA)) : tc-1 ;
            baseFx = median( fx(iBase) ) ;                % SD ではなく中央値（5.6 §3-3）
            peakFx = max( fx(tc:tFC) - baseFx ) ;
            if peakFx <= 0, Diag.nNoPeakFx = Diag.nNoPeakFx + 1 ; continue, end

            thrFx  = baseFx + peakFx * PrmRT.RatioFx ;
            isOver = fx > thrFx ;
            nDur   = round(PrmRT.DurMs/1000 * fsA) ;

            tOnset = NaN ;      % 見つからなければ NaN。1 にすると偽の RT が出る
            for k = tc+1 : (tFC - nDur + 1)
                if ~isOver(k-1) && all( isOver(k : k+nDur-1) )
                    tOnset = k ; break
                end
            end
            if isnan(tOnset), Diag.nNoOnset = Diag.nNoOnset + 1 ; continue, end

            rtMs = (tOnset - tc)/fsA*1000 ;
            RTAll = [RTAll ; rtMs] ;                                        %#ok<AGROW>
            if rtMs < Prm.RT.FloorMs, Diag.nRTShort = Diag.nRTShort + 1 ; end

            % --- (c) 区間と立ち上がり速度 ---
            % ピークは接地の後、onset は接地の前なので順序は通常保証されるが、
            % 念のため確認する。逆転していたら区間が負になり指標が壊れる。
            if tPeak <= tOnset, Diag.nPeakBeforeOnset = Diag.nPeakBeforeOnset + 1 ; continue, end

            dtSec     = (tPeak - tOnset) / fsA ;
            onsetBW   = T.F2g(tOnset,3) / bw * 100 ;           % [%BW] RT 時点の Fz2
            dFzBW     = pkBW - onsetBW ;                       % [%BW]
            rfd       = dFzBW / dtSec ;                        % [%BW/s]

            V{iS,ic,1} = [V{iS,ic,1} ; rtMs] ;
            V{iS,ic,3} = [V{iS,ic,3} ; dtSec*1000] ;
            V{iS,ic,4} = [V{iS,ic,4} ; rfd] ;

            % [5] 立ち上がり速度をピーク力で割る（正規化 RFD）[1/s]
            %     「達成した力の大きさに対して、どれだけ速く立ち上がれたか」。
            %     ★ 分子は (pkBW - onsetBW)/dtSec なので、この指標は恒等的に
            %        (1 - onsetBW/pkBW) / dtSec に等しい。onsetBW が pkBW に比べて
            %        小さければ 1/dtSec そのものになる。§3-5 で実測して確認すること。
            V{iS,ic,5} = [V{iS,ic,5} ; rfd / pkBW] ;

            % 診断：上の恒等式がどれだけ 1/dtSec に近いかを見るための材料
            OnsetBWAll = [OnsetBWAll ; onsetBW] ;                            %#ok<AGROW>
            RatioAll   = [RatioAll   ; (rfd/pkBW) * dtSec] ;                 %#ok<AGROW>

            % ★ 波形確認（h3）用の記録。ここに来るのは5指標すべてが算出できた試行だけ。
            Rec(end+1) = struct('iS',iS, 'sub',SubjectArray(iS), 'ic',ic, 'it',it, ...
                'tc',tc, 'tOnset',tOnset, 'tFC',tFC, 'tPeak',tPeak, 'fs',fsA, ...
                'bw',bw, 'rtMs',rtMs, 'pkBW',pkBW, 'onsetBW',onsetBW, ...
                'dtMs',dtSec*1000, 'rfd',rfd, 'baseFx',baseFx, 'thrFx',thrFx) ; %#ok<SAGROW>

            Diag.nOK = Diag.nOK + 1 ;
        end
    end
end


%% ---- 4. 検算（被験者ごとの中央値の表）----

fprintf('\n推定体重: ') ;
for iS = 1:nS
    fprintf('S%02d %.1f kg  ', SubjectArray(iS), BWest(iS)/9.81) ;
end
fprintf('\n') ;

fprintf('\n--- 試行の内訳 ---\n') ;
fprintf('  Go 試行                    : %d\n', Diag.nGo) ;
fprintf('  末尾 NaN を切った試行      : %d\n', Diag.nTrimmedNan) ;
fprintf('  BWBase 逸脱で除外          : %d\n', Diag.nBadBW) ;
fprintf('  接地が見つからない         : %d\n', Diag.nNoFootContact) ;
fprintf('  cue→接地 の窓が短い       : %d\n', Diag.nShortWin) ;
fprintf('  窓内で Fx がベースを超えず : %d\n', Diag.nNoPeakFx) ;
fprintf('  onset 未検出               : %d\n', Diag.nNoOnset) ;
fprintf('  ピークが onset より前      : %d\n', Diag.nPeakBeforeOnset) ;
fprintf('  4指標すべて算出できた試行  : %d\n', Diag.nOK) ;
fprintf('  うち RT < %d ms            : %d (%.1f%%)\n', ...
    Prm.RT.FloorMs, Diag.nRTShort, Diag.nRTShort/max(1,numel(RTAll))*100) ;

% 指標5（正規化 RFD）が実質 1/dtSec になっていないかの確認。
% RT 時点の踏み込み足はまだ空中にあるはずなので onsetBW は 0 付近になる。
fprintf('\n--- 指標5 の検算 ---\n') ;
fprintf('  RT 時点の Fz2 [%%BW]  : 中央値 %.2f  （5〜95%%点 %.2f 〜 %.2f）\n', ...
    median(OnsetBWAll), quantile(OnsetBWAll,0.05), quantile(OnsetBWAll,0.95)) ;
fprintf('  1 - onsetBW/pkBW     : 中央値 %.4f （最小 %.4f）\n', ...
    median(RatioAll), min(RatioAll)) ;
fprintf('  → この値が 1 に近いほど、指標5 は 1/(RT→ピークの時間) と同じものになる\n') ;

for im = 1:nM

    fprintf('\n===== %s =====\n', MetricName{im}) ;
    fprintf('       |  free  | simple | gonogo | gostop |\n') ;

    for iS = 1:nS
        fprintf(' S%02d   |', SubjectArray(iS)) ;
        for ic = 1:nC
            if isempty(V{iS,ic,im})
                fprintf('   -    |') ;
            else
                % 1/s の指標は 1〜2 のオーダーなので、小数1桁だと差が潰れる
                m = median(V{iS,ic,im}) ;
                if abs(m) < 10, fprintf(' %6.2f |', m) ; else, fprintf(' %6.1f |', m) ; end
            end
        end
        fprintf('\n') ;
    end

    fprintf('-------+--------+--------+--------+--------+\n') ;

    fprintf(' 中央値|') ;
    for ic = 1:nC
        a = vertcat(V{:,ic,im}) ;
        m = median(a) ;
        if abs(m) < 10, fprintf(' %6.2f |', m) ; else, fprintf(' %6.1f |', m) ; end
    end
    fprintf('\n     n |') ;
    for ic = 1:nC
        a = vertcat(V{:,ic,im}) ;
        fprintf(' %6d |', numel(a)) ;
    end
    fprintf('\n') ;
end

% 確認すること
%   推定体重が S01 74.6 / S02 87.4 / S03 60.5 / S04 72.3 / S05 69.9 kg になるか
%     （g0 と同じ値。ここが違うなら分母の取り方がずれている）。
%   ピーク鉛直GRF の条件中央値が g0 の図（144.8 / 127.5 / 131.2 / 137.7 %BW）と
%     ほぼ一致するか。大きく違うならフィルタか探索窓の指定を間違えている。
%   RT が 150〜400 ms のオーダーに収まるか。
%   RT → ピーク の時間が正で、RT より長いか（接地を挟むので数百 ms になるはず）。
