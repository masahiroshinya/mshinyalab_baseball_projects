% g0_calc_grf_metrics.m
%
% 目的:
%   f7 の処理を全被験者（S01〜S05）に広げ、推奨GRF指標を試行ごとに算出する。
%   算出だけを担当し、描画は g1_plot_grf_by_condition.m が行う。
%
% 入力:
%   Experiments/Main experiments/03_Analysis/x3_DataChecked/Data0x.mat（S01〜S05）
%
% 出力（ワークスペースに残す）:
%   V          ... {被験者 × 条件 × 指標} のセル配列。各セルに試行の値を縦に積む
%   BWest      ... [1 × 5] 推定体重 [N]（%BW の分母）
%   MetricName ... 指標名（g1 の図のタイトルに使う）
%   SubjectArray / ConditionNameArray / nS / nC / nM
%
% 算出する指標（f7 の検討で決定）:
%   1. 踏み込み足 ピーク鉛直GRF   [%BW]   Orishimo 2023: 159 ± 29
%   2. 踏み込み足 ピーク後方GRF   [%BW]   Orishimo 2023: -57 ± 12
%   3. 踏み込み足 ピーク合成GRF   [%BW]   Orishimo 2023: 170 ± 30
%   4. 後ろ足     荷重の抜け始め  [ms]    m3 の SwingOnsetForce と同じ定義
%
% 備考:
%   - ★ 分母は「記録末端 0.5 s の Fz1+Fz2 の中央値（外れ値除去）」で推定した体重。
%     2026-09-07 の方針決定による。プレートは分子と同じ計測系なので校正誤差が比で
%     相殺され、体重計（別デバイス・別時点・着衣条件が異なる）より精度が高い。
%     キュー前の BWBase を分母にすると、S03 は踏み込み足をプレート外に置いて
%     構えるため体重を 24% 過小に見積もり、%BW が 24% 過大になる（技術説明 §3-6）。
%     他4名は BWBase と ±2% 以内で一致するので、この定義で全被験者を統一できる。
%   - ★ 後ろ足の正のピーク（PeakFz1）は算出しない。静止時に全体重が乗っており
%     上に伸びる余地がないため、223試行のうち 76 試行でピーク時刻が反応時間の
%     生理的下限より早くなる（f7 の節）。代わりに「荷重の抜け始め」を使う。
%   - 試行の除外は被験者内 BWBase 中央値の ±20%（Prm.GRF.BWTolerance）。
%     これは「その被験者の普段の構えから外れた試行」を弾くもので、分母とは別役割。
%   - ★ addpath は parameters を呼ぶ前に済ませる（技術説明 §4-4）。

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

MetricName = { ...
    '踏み込み足  ピーク鉛直GRF [%BW]', ...
    '踏み込み足  ピーク後方GRF [%BW]', ...
    '踏み込み足  ピーク合成GRF [%BW]', ...
    '後ろ足  荷重の抜け始め [ms]'} ;

nS = numel(SubjectArray) ;
nC = numel(ConditionNameArray) ;
nM = numel(MetricName) ;

% ★ 2次（m3_analyze_single_trial.m:214 と同じ）。f2〜f6 は 4 次だった。
%   アナログ系は全試行 1000 Hz なので、係数はループの外で一度だけ設計する。
[bF, aF] = butter(2, Prm.Fc/(1000/2), 'low') ;


%% ---- 3. 試行ごとの値を集める ----

V     = cell(nS, nC, nM) ;
BWest = nan(1, nS) ;

for iS = 1:nS

    load( fullfile(dataDir, sprintf('Data%02d.mat', SubjectArray(iS))) )
    nTrial = size(DataArray, 1) ;

    % --- 3-1. 体重の推定（記録末端 0.5 s、外れ値除去、中央値）---
    % 末端は全被験者で両足がプレート上にあるので、構えの違いに依存しない。
    E = [] ;
    for ic = 1:nC
        for it = 1:nTrial
            D = DataArray(it, ic) ;
            if ~isfield(D,'Force1') || isempty(D.Force1) || isempty(D.Force2), continue, end
            if any(isnan(D.Force1(:))) || any(isnan(D.Force2(:))), continue, end
            F1 = filtfilt(bF, aF, D.Force1) ;
            F2 = filtfilt(bF, aF, D.Force2) ;
            tot = F1(:,3) + F2(:,3) ;
            E = [E ; mean(tot(end-499:end))] ;                              %#ok<AGROW>
        end
    end
    % 末端でプレートから降りている試行を外す（中央値の 70% 未満）。
    % S03 では 57 試行のうち 11 試行が該当した。
    BWest(iS) = median( E(E > 0.7*median(E)) ) ;

    % --- 3-2. cue 判定と BWBase（除外判定用）---
    BB = nan(nTrial, nC) ;
    TC = nan(nTrial, nC) ;
    CT = repmat({''}, nTrial, nC) ;

    for ic = 1:nC
        for it = 1:nTrial

            D = DataArray(it, ic) ;

            % isfield と ~isempty の両方が必要（埋め要素は Force1 が空）
            if ~isfield(D,'Force1') || isempty(D.Force1) || isempty(D.Force2) ...
                    || isempty(D.LEDData), continue, end

            % filtfilt は NaN が1つでもあると全体を NaN にするので先に弾く
            if any(isnan(D.Force1(:))) || any(isnan(D.Force2(:))), continue, end

            % Go / NoGo / Stop の判定（gostop は「正の後に負」）
            led  = D.LEDData(:,2) ;
            tGo  = find(led >  Prm.Cue.GoThresholdV,  1, 'first') ;
            tNeg = find(led <  Prm.Cue.NegThresholdV, 1, 'first') ;

            if ~isempty(tGo) && (isempty(tNeg) || tNeg > tGo)
                tc = tGo ;
                stopWin = round(Prm.Cue.StopWinSec * D.AnalogFs) ;
                if ~isempty(tNeg) && (tNeg - tGo) <= stopWin
                    CT{it,ic} = 'Stop' ;
                else
                    CT{it,ic} = 'Go' ;
                end
            elseif ~isempty(tNeg)
                tc = tNeg ; CT{it,ic} = 'NoGo' ;
            else
                continue
            end
            if tc < 2, continue, end

            F1 = filtfilt(bF, aF, D.Force1) ;
            F2 = filtfilt(bF, aF, D.Force2) ;
            BB(it,ic) = mean(F1(1:tc-1,3)) + mean(F2(1:tc-1,3)) ;
            TC(it,ic) = tc ;
        end
    end

    % ★ 中央値は同一被験者内で取る。被験者をまたぐと体重差が許容範囲に混ざる。
    bwRef = median(BB(:), 'omitnan') ;
    isBad = isnan(BB) | abs(BB - bwRef) > Prm.GRF.BWTolerance * bwRef ;

    % --- 3-3. 指標の算出（Go かつ除外されていない試行のみ）---
    % ★ 「Go である」という肯定形で選ぶ。否定形だと cue 未検出の試行が通る。
    for ic = 1:nC
        for it = 1:nTrial

            if ~strcmp(CT{it,ic}, 'Go') || isBad(it,ic), continue, end

            D   = DataArray(it, ic) ;
            fsA = D.AnalogFs ;
            tc  = TC(it, ic) ;

            % 3成分すべてにフィルタを掛ける（f7 は 3列目だけだった）
            F1 = filtfilt(bF, aF, D.Force1) ;
            F2 = filtfilt(bF, aF, D.Force2) ;

            nSample    = size(F1, 1) ;
            swingEnd   = min(tc + round(Prm.GRF.WinSec*fsA), nSample) ;
            swingRange = tc : swingEnd ;

            bw = BWest(iS) ;

            % 1. 鉛直（踏み込み足）：3列目の最大
            V{iS,ic,1} = [V{iS,ic,1} ; max(F2(swingRange,3))/bw*100] ;

            % 2. 後方（踏み込み足）：1列目の最小。+X が投手方向なので
            %    負がブレーキ力。全被験者で負に出るのが正常。
            V{iS,ic,2} = [V{iS,ic,2} ; min(F2(swingRange,1))/bw*100] ;

            % 3. 合成（踏み込み足）：3成分のノルムの最大
            V{iS,ic,3} = [V{iS,ic,3} ; max(sqrt(sum(F2(swingRange,:).^2,2)))/bw*100] ;

            % 4. 後ろ足の抜け始め：|Fz1-mu| > 10SD が 30 ms 持続した最初の時点
            %    m3_analyze_single_trial.m の SwingOnsetForce と同じ定義。
            %    5.6 の RT（Fx のピーク相対閾値）とは別指標で、250〜300 ms 遅い。
            nBase = round(Prm.RT.BaseSec * fsA) ;
            if tc - nBase >= 1
                base = F1(tc-nBase : tc-1, 3) ;
                mu = mean(base) ;
                sd = std(base) ;
                over  = abs(F1(swingRange,3) - mu) > Prm.RT.FzK * sd ;
                holdN = round(Prm.RT.DurMs/1000 * fsA) ;
                % 閾値超えが holdN サンプル続いた最初の位置（m3 の firstSustained と同じ）
                d  = diff([0 ; over(:) ; 0]) ;
                st = find(d ==  1) ;
                en = find(d == -1) - 1 ;
                k  = find((en - st + 1) >= holdN, 1, 'first') ;
                if ~isempty(k)
                    V{iS,ic,4} = [V{iS,ic,4} ; (st(k)-1)/fsA*1000] ;
                end
            end
        end
    end
end


%% ---- 4. 検算（被験者ごとの中央値の表）----

fprintf('\n推定体重: ') ;
for iS = 1:nS
    fprintf('S%02d %.1f kg  ', SubjectArray(iS), BWest(iS)/9.81) ;
end
fprintf('\n') ;

for im = 1:nM

    fprintf('\n===== %s =====\n', MetricName{im}) ;
    fprintf('       |  free  | simple | gonogo | gostop |\n') ;

    for iS = 1:nS
        fprintf(' S%02d   |', SubjectArray(iS)) ;
        for ic = 1:nC
            if isempty(V{iS,ic,im})
                fprintf('   -    |') ;
            else
                fprintf(' %6.1f |', median(V{iS,ic,im})) ;
            end
        end
        fprintf('\n') ;
    end

    fprintf('-------+--------+--------+--------+--------+\n') ;

    fprintf(' 中央値|') ;
    for ic = 1:nC
        a = vertcat(V{:,ic,im}) ;
        fprintf(' %6.1f |', median(a)) ;
    end
    fprintf('\n     n |') ;
    for ic = 1:nC
        a = vertcat(V{:,ic,im}) ;
        fprintf(' %6d |', numel(a)) ;
    end
    fprintf('\n') ;
end

% 確認すること
%   推定体重が S01 74.6 / S02 87.4 / S03 60.5 / S04 72.3 / S05 69.9 kg になるか。
%     S03 が 46 kg なら分母が BWBase になっている（キュー前で取っている）。
%   鉛直・後方・合成が Orishimo 2023（159±29 / -57±12 / 170±30 %BW）の範囲か。
%   後方が全被験者・全条件で負か。正なら符号系か列の指定を間違えている。
%   n が free 69 / simple 63 / gonogo 46 / gostop 45 になるか
%     （free が多いのは NoGo・Stop の除外がないため）。
