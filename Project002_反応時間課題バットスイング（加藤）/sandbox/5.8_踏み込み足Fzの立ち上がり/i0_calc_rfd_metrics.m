% i0_calc_rfd_metrics.m
%
% ★ h0_calc_rfd_metrics.m を 2026-09-10 の新しい除外基準で作り直したもの。
%   **指標の定義は h0 と完全に同一**で、違いは除外基準だけである。
%   比較を済ませたうえで h0 と旧 PNG は削除した。以下の h0 への言及は
%   削除前の実装を指す（git 履歴から復元できる）。
%
%   h0: Go 試行のうち、BWBase（cue 前の Fz1+Fz2）が被験者内中央値から ±20% を
%       超えてずれる試行を除外していた。
%   i0: **その除外を撤回した。** 03_Analysis 技術説明 §10.8 の実測で、
%       この基準が落としていた試行の PeakFz2 分布は残す試行とほぼ同一
%       （中央値 130.1 vs 135.9 %BW）で、正常データを 247 試行中 53 本（21%）
%       捨てていたことが分かった。末端で被験者がプレートから降りたかどうかは
%       スイング時の計測が壊れている証拠にならない。
%       除外は「床反力が正常に計測できていない」＝欠損だけにする。
%       BWest は %BW の分母としてのみ使う（この点は h0 から変わらない）。
%
%   ★ 本フォルダの5指標はすべて床反力ベースなので、新しい除外基準①
%     （top マーカーの欠損）は関係しない。②（床反力の欠損）だけが効く。
%     ②は h0 の時点で既に Trial.ok のゲートとして実装されていた。
%
% ★ 2026-09-11 追記：バット先端のピーク速度（tPeakVel）と、それを終点とする
%   MT を算出して Rec に残すようにした。i3 の図で MT の区間を 5.6_プロット と
%   同じ定義で描くためで、下の5指標そのものは変えていない（すべて床反力ベース）。
%   これに伴い、除外基準①（top マーカーの欠損）が本スクリプトでも効くようになった。
%   ①に掛かる試行は MT だけが NaN になり、5指標は従来どおり算出する。
%
% 目的:
%   踏み込み足の鉛直床反力（Fz2）について、
%     1. ピーク値                        [%BW]
%     2. RT からピークまでの時間          [ms]
%     3. その間の力の立ち上がり速度（RFD） [%BW/s]
%   を試行ごとに算出する。RT は 5.6_プロット と同じ定義（Fx のピーク相対閾値）。
%   算出だけを担当し、描画は i1_plot_rfd_by_condition.m が行う。
%
% 入力:
%   Experiments/Main experiments/03_Analysis/x3_DataChecked/Data0x.mat（S01〜S05）
%
% 出力（ワークスペースに残す）:
%   V          ... {被験者 × 条件 × 指標} のセル配列。各セルに試行の値を縦に積む
%   BWest      ... [1 × nS] 推定体重 [N]（%BW の分母）
%   MetricName ... 指標名（i1 の図のタイトルに使う）
%   SubjectArray / ConditionNameArray / nS / nC / nM
%   SubjColor  ... [nS × 3] 被験者ごとの線の色（i1・i2・i4 が共通で使う）
%   Diag       ... 検出の内訳（除外理由の集計）。nBadBWRef は「旧 h0 なら
%                  除外されていた試行数」で、参考のために数えるだけである
%   Rec        ... 試行ごとの素性と検出時刻（i3_plot_example_trials.m が波形確認に使う）
%                  tPeakVel / mtMs / peakVel も入る（5.6 と同じ定義の MT）
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
%       ★ 2026-09-11：onset が取れた試行だけを積むように変えた。5指標の n を
%          そろえるため（§3-3 の (f) 直前のコメント）。このぶん g0 の図とは
%          n が合わなくなった。
%       ★ ただし 2026-09-10 に「ピークが接地から PrmPk.MaxAfterFCSec 以上
%          離れていたら試行ごと落とす」判定を追加した（§3-7）。該当は1試行のみ
%          なので g0 との照合はほぼ従来どおりできる。
%
%   [3] Onset → Fzピーク の時間 [ms]
%       (tPeak - tOnset) / fs * 1000。踏み込み足の接地はこの区間の中にある。
%
%   ★ スイング速度ピーク時の Fz2（Rec.fzAtPV）もここで算出するが、V には積まない。
%      top マーカーに依存するので n が他の5指標とそろわず、i1 の図に混ぜると
%      同じ図の中で母集団が違うパネルができてしまう。作図は i4 が単独で行う。
%
%   [4] 力の立ち上がり速度 [%BW/s]
%       (Fz2ピーク − Onset 時点の Fz2) / 体重 * 100 / 区間の秒数。
%       ★ 分子から Onset 時点の値を引く。5.6 の AveSlopeTopVel は
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
resultDir   = fullfile(analysisDir, 'x4_SingleTrialAnalysisResults') ;

addpath(analysisDir)

fprintf('parameters.m の場所: %s\n', which('parameters')) ;


%% ---- 2. 設定 ----

Prm = parameters ;

SubjectArray       = 1:5 ;
ConditionNameArray = {'free', 'simple', 'gonogo', 'gostop'} ;

% ★ 被験者ごとの色（2026-09-14）。i1・i2・i4 が共通で使う。
%   同じ被験者が図をまたいで同じ色になるように、算出側で一度だけ決める。
%   色は Okabe & Ito のカラーユニバーサルデザイン推奨色から5色。
%   グレースケール印刷でも明度が分かれ、2型・3型色覚でも区別できる。
%   ★ 行の順序は SubjectArray に対応する。被験者を増やすときはここに足す。
SubjColor = [0.000 0.447 0.698 ;    % S01  青
             0.835 0.369 0.000 ;    % S02  朱
             0.000 0.620 0.451 ;    % S03  緑
             0.800 0.475 0.655 ;    % S04  紫
             0.902 0.624 0.000] ;   % S05  橙

% ★ 指標の追加はここ（1/2）。名前を足したら 3-3 に算出を足す。
MetricName = { ...
    'RT（5.6 の定義） [ms]', ...
    '踏み込み足  ピーク鉛直GRF [%BW]', ...
    'Onset → Fzピーク の時間 [ms]', ...
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

% --- ピークの位置の妥当性（2026-09-10 追加。技術説明 §3-7）---
%  スイングのピークは踏み込み足の接地の直後に来る（実測で 0.1〜0.2 s 後）。
%  接地から大きく離れたピークは、スイングではなく後続動作のものである。
%  ★ 「1580 ms は長すぎる」という値による判定ではなく、位置による判定にする。
%    値で切ると 2026-09-10 に廃止した種類の基準に戻ってしまう（§7）。
PrmPk.MaxAfterFCSec = 0.5 ;   % 接地からこれ以上離れたピークは採らない
%  ★ 位置の判定に使う「接地」は、RT 検出のゲート（PrmRT.MinWinSample = 50 ms）より
%    厳しく見る必要がある。cue から 64〜91 ms で 50 N を超える試行が2件あり、
%    これは接地ではなく浮かせ残りである。真の接地は実測で 351〜1116 ms
%    （中央値 600 ms）なので、250 ms を境にすれば安全に分離できる。
%    この2件はピーク自体は正常な位置（0.58〜0.59 s）にあるので、
%    位置の判定に掛けてはいけない。
PrmPk.MinFCSec      = 0.25 ;  % 接地がこれより早い試行は、接地が信用できない

% アナログ系は全試行 1000 Hz なので、係数はループの外で一度だけ設計する。
% 2 次：GRF 指標は m3_analyze_single_trial.m:214 と同じ。
[bG, aG] = butter(2, Prm.Fc   /(1000/2), 'low') ;   % GRF 指標用（30 Hz）
[bR, aR] = butter(2, PrmRT.Fc /(1000/2), 'low') ;   % RT 検出用（50 Hz）


%% ---- 3. 試行ごとの値を集める ----

V     = cell(nS, nC, nM) ;
BWest = nan(1, nS) ;

Diag = struct('nGo',0, 'nBadBWRef',0, 'nNoFootContact',0, 'nShortWin',0, ...
              'nNoPeakFx',0, 'nNoOnset',0, 'nPeakBeforeOnset',0, 'nOK',0, ...
              'nTrimmedNan',0, 'nRTShort',0, 'nPeakFarFromFC',0, ...
              'nBadTop',0, 'nNoMT',0) ;

% ★ 波形確認（i3）用。5指標すべてを算出できた試行の素性と検出時刻を残す。
%   ここに残さないと、あとから「どの試行のどのサンプルを測ったか」を再現できない。
Rec = struct('iS',{}, 'sub',{}, 'ic',{}, 'it',{}, 'tc',{}, 'tOnset',{}, ...
             'tFC',{}, 'tPeak',{}, 'fs',{}, 'bw',{}, 'rtMs',{}, 'pkBW',{}, ...
             'onsetBW',{}, 'dtMs',{}, 'rfd',{}, 'baseFx',{}, 'thrFx',{}, ...
             'tPeakVel',{}, 'fsM',{}, 'mtMs',{}, 'peakVel',{}, 'fzAtPV',{}) ;
RTAll      = [] ;   % 診断用に RT を全部ためる
OnsetBWAll = [] ;   % 診断用に Onset 時点の Fz2 [%BW] をためる
RatioAll   = [] ;   % 診断用に (1 - onsetBW/pkBW) をためる

for iS = 1:nS

    load( fullfile(dataDir, sprintf('Data%02d.mat', SubjectArray(iS))) )
    % ★ 除外基準①（top マーカーの欠損）は x4 の判定をそのまま使う。
    %   MT がバット先端のピーク速度に依存するようになったので、ここから必要になった。
    load( fullfile(resultDir, sprintf('SingleTrialAnalysisResults%02d.mat', ...
                                      SubjectArray(iS))) )
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

    % ==== 3-2. BWBase の逸脱（★ 参考値。除外には使わない）====
    % ★ 旧 h0 はここで作った isBadBW で試行を落としていたが、i0 では落とさない。
    %   03_Analysis 技術説明 §10.8 の実測で、この基準が筋を外していることが
    %   分かったため（詳細はファイル冒頭）。数だけ数えて h0 と比較できるようにする。
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
    isBadBWRef = isnan(BB) | abs(BB - bwRef) > Prm.GRF.BWTolerance * bwRef ;

    % ==== 3-3. 指標の算出（Go かつ除外されていない試行のみ）====
    % ★ 「Go である」という肯定形で選ぶ。否定形だと cue 未検出の試行が通る。
    for ic = 1:nC
        for it = 1:nTrial

            if ~Trial(it,ic).ok, continue, end
            if ~strcmp(Trial(it,ic).cueText, 'Go'), continue, end
            Diag.nGo = Diag.nGo + 1 ;
            % ★ ここで continue しないのが h0 との唯一の違い。数だけ数える。
            if isBadBWRef(it,ic), Diag.nBadBWRef = Diag.nBadBWRef + 1 ; end

            T   = Trial(it,ic) ;
            fsA = T.fs ;
            tc  = T.tc ;
            bw  = BWest(iS) ;
            n   = size(T.F2g, 1) ;

            % --- (a) 踏み込み足の接地 ---
            %  踏み込み足は構えでは浮いている（実測で cue 時点の Fz2 は全被験者
            %  約3 N）ので閾値 50 N で拾える。
            %  ★ 見つからなくてもここでは試行を捨てない。指標2（ピーク）は onset の
            %    成否によらず入れる設計なので（(c)）、接地はゲートに使わず、
            %    (b) の位置の判定と (d) の RT 検出のためだけに先に求めておく。
            iFC       = find( T.F2r(tc:n, 3) > PrmRT.FootContactN, 1, 'first') ;
            tFC       = NaN ;
            isFCforRT = false ;   % RT 検出の探索窓として使えるか（従来の判定）
            isFCforPk = false ;   % ピークの位置の判定に使えるか（より厳しい）
            if ~isempty(iFC)
                tFC = iFC + tc - 1 ;
                % ★ cue から MinWinSample 以内に 50 N を超えた試行は、接地ではなく
                %   「浮かせ残り」を拾っている（§4-4）。
                isFCforRT = (tFC - tc) >= PrmRT.MinWinSample ;
                % ★ 位置の判定にはもっと厳しい基準を使う。理由は PrmPk の定義箇所。
                isFCforPk = (tFC - tc) >= round(PrmPk.MinFCSec*fsA) ;
            end

            % --- (b) Fz2 のピーク（探索窓は g0 と同じ cue → cue + 2 s）---
            swingEnd   = min(tc + round(Prm.GRF.WinSec*fsA), n) ;
            swingRange = tc : swingEnd ;
            [pkFz2, iRel] = max( T.F2g(swingRange, 3) ) ;
            tPeak = swingRange(1) + iRel - 1 ;
            pkBW  = pkFz2 / bw * 100 ;                          % [%BW]

            % ★ ピークの位置の妥当性（2026-09-10 追加。技術説明 §3-7）
            %   S02 gonogo 行13 は、後続動作の山（1.806 s、152.1 %BW）が
            %   スイングのピーク（0.662 s、147.9 %BW）を 2.8% だけ上回ったため
            %   そちらが選ばれ、Onset → ピーク が 1580 ms（中央値の 3.1 倍）に
            %   なっていた。ピーク値そのものは無害だが、時間を分母に持つ
            %   指標3〜5 が壊れるので、試行ごと落とす。
            %   ★ 全 225 試行でこの1件しか該当しない（§3-7 で走査済み）。
            if isFCforPk && tPeak > tFC + round(PrmPk.MaxAfterFCSec*fsA)
                Diag.nPeakFarFromFC = Diag.nPeakFarFromFC + 1 ;
                continue
            end

            % --- (b2) バット先端のピーク速度（5.6_プロット/p0 の §3-5 と同一）---
            %  MT の終点をここに合わせるために算出する。探索窓は cue → 記録末尾で、
            %  5.6 と同じにしてある（窓を変えると 5.6 の MT と値が合わなくなる）。
            %  ★ 除外基準①は x4 が付けた IsBadTop をそのまま使う。判定を二重に
            %    実装すると、5.6 の図と 5.8 の図で落ちる試行が食い違う。
            D   = DataArray(it, ic) ;
            Rx  = SingleTrialResultArray(it, ic) ;
            fsM = D.FrameRate ;

            tPeakVel = NaN ; peakVel = NaN ;
            if Rx.IsBadTop
                Diag.nBadTop = Diag.nBadTop + 1 ;
            elseif isfield(D.Markers, Prm.Excl.TopMarkerName)
                topMk   = D.Markers.(Prm.Excl.TopMarkerName) ;
                velNorm = sum(diff3p(topMk, 1/fsM).^2, 2).^0.5 ;   % [mm/s]

                % ピークは cue 以降に限る（構え直しを拾わないため）。
                % マーカーは 250 Hz、アナログは 1000 Hz なので番号を直してから探す。
                iGoFrame   = max(1, round(tc / (fsA/fsM))) ;
                [pv, iRel] = max( velNorm(iGoFrame:end) ) ;
                tPeakVel   = iRel + iGoFrame - 1 ;
                peakVel    = pv / 1000 ;                           % [m/s]
            end

            % --- (d) RT 検出（5.6_プロット/untitled.m と同一）---
            %  探索窓は cue → 踏み込み足の接地。
            if isempty(iFC), Diag.nNoFootContact = Diag.nNoFootContact + 1 ; continue, end
            if ~isFCforRT,    Diag.nShortWin      = Diag.nShortWin      + 1 ; continue, end

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

            % --- (e) 区間と立ち上がり速度 ---
            % ピークは接地の後、onset は接地の前なので順序は通常保証されるが、
            % 念のため確認する。逆転していたら区間が負になり指標が壊れる。
            if tPeak <= tOnset, Diag.nPeakBeforeOnset = Diag.nPeakBeforeOnset + 1 ; continue, end

            dtSec     = (tPeak - tOnset) / fsA ;
            onsetBW   = T.F2g(tOnset,3) / bw * 100 ;           % [%BW] Onset 時点の Fz2
            dFzBW     = pkBW - onsetBW ;                       % [%BW]
            rfd       = dFzBW / dtSec ;                        % [%BW/s]

            % ★ 指標の追加はここ（2/2）。
            % ★ 2026-09-11：ピーク（指標2）もここで積むようにした。以前は (c) の
            %   位置、つまり RT 検出のゲートより手前で積んでいたので、onset が
            %   取れなかった試行でもピークだけ残り、指標2 の n だけ他より多かった
            %   （73/75/49/49 対 72/66/45/41）。同じ図の中で指標ごとに母集団が
            %   違うと、条件間の差を読むときに何と何を比べているのか分からない。
            %   ★ 引き換えに、5.7 の g0 が出したピークの図とは n が合わなくなる。
            %     照合したいときは、この行を (d) の手前に戻せばよい。
            V{iS,ic,1} = [V{iS,ic,1} ; rtMs] ;
            V{iS,ic,2} = [V{iS,ic,2} ; pkBW] ;
            V{iS,ic,3} = [V{iS,ic,3} ; dtSec*1000] ;
            V{iS,ic,4} = [V{iS,ic,4} ; rfd] ;

            % [5] 立ち上がり速度をピーク力で割る（正規化 RFD）[1/s]
            %     「達成した力の大きさに対して、どれだけ速く立ち上がれたか」。
            %     ★ 分子は (pkBW - onsetBW)/dtSec なので、この指標は恒等的に
            %        (1 - onsetBW/pkBW) / dtSec に等しい。onsetBW が pkBW に比べて
            %        小さければ 1/dtSec そのものになる。§3-5 で実測して確認すること。
            V{iS,ic,5} = [V{iS,ic,5} ; rfd / pkBW] ;

            % --- スイング速度がピークのときの踏み込み足 Fz2 [%BW]（i4 が使う）---
            %  ★ V には積まない。top マーカーに依存するので n が他とそろわず、
            %    i1 の図に混ぜられない（指標定義のコメント参照）。Rec に残す。
            %  ★ tPeakVel はマーカー（250 Hz）の番号なので、アナログ（1000 Hz）の
            %    番号に直してから Fz2 を読む。直さずに読むと 4 倍ずれた場所の値を拾う。
            fzAtPV = NaN ;
            if ~isnan(tPeakVel)
                iPV    = min( max(1, round(tPeakVel * fsA/fsM)), n ) ;
                fzAtPV = T.F2g(iPV,3) / bw * 100 ;
            end

            % 診断：上の恒等式がどれだけ 1/dtSec に近いかを見るための材料
            OnsetBWAll = [OnsetBWAll ; onsetBW] ;                            %#ok<AGROW>
            RatioAll   = [RatioAll   ; (rfd/pkBW) * dtSec] ;                 %#ok<AGROW>

            % --- (f) MT（5.6 の定義：onset → バット先端のピーク速度）---
            %  ★ マーカー 250 Hz とアナログ 1000 Hz なので、どちらも秒に直してから引く。
            %    サンプル番号のまま引くと 4 倍ずれる。
            %  ★ ここは i0 の指標には入れない（5.8 の5指標は床反力ベースのまま）。
            %    Rec に残して i3 の作図だけが使う。
            mtMs = NaN ;
            if ~isnan(tPeakVel)
                mtMs = (tPeakVel/fsM - tOnset/fsA) * 1000 ;
                if mtMs <= 0
                    % ピークが onset より前。区間が負になるので値を出さない。
                    mtMs = NaN ;
                end
            end
            if isnan(mtMs), Diag.nNoMT = Diag.nNoMT + 1 ; end

            % ★ 波形確認（i3）用の記録。ここに来るのは5指標すべてが算出できた試行だけ。
            %   mtMs だけは NaN のことがある（top マーカーの欠損など）。
            Rec(end+1) = struct('iS',iS, 'sub',SubjectArray(iS), 'ic',ic, 'it',it, ...
                'tc',tc, 'tOnset',tOnset, 'tFC',tFC, 'tPeak',tPeak, 'fs',fsA, ...
                'bw',bw, 'rtMs',rtMs, 'pkBW',pkBW, 'onsetBW',onsetBW, ...
                'dtMs',dtSec*1000, 'rfd',rfd, 'baseFx',baseFx, 'thrFx',thrFx, ...
                'tPeakVel',tPeakVel, 'fsM',fsM, 'mtMs',mtMs, ...
                'peakVel',peakVel, 'fzAtPV',fzAtPV) ; %#ok<SAGROW>

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
fprintf('  BWBase 逸脱（★参考。除外せず）: %d\n', Diag.nBadBWRef) ;
fprintf('  接地が見つからない         : %d\n', Diag.nNoFootContact) ;
fprintf('  cue→接地 の窓が短い       : %d\n', Diag.nShortWin) ;
fprintf('  窓内で Fx がベースを超えず : %d\n', Diag.nNoPeakFx) ;
fprintf('  onset 未検出               : %d\n', Diag.nNoOnset) ;
fprintf('  ピークが onset より前      : %d\n', Diag.nPeakBeforeOnset) ;
fprintf('  ピークが接地から %.1f s 以上離れて除外 : %d\n', ...
    PrmPk.MaxAfterFCSec, Diag.nPeakFarFromFC) ;
fprintf('  【除外①】top の欠損（窓内）: %d\n', Diag.nBadTop) ;
fprintf('  MT が出せない（①・ピークが onset より前）: %d\n', Diag.nNoMT) ;
fprintf('  4指標すべて算出できた試行  : %d\n', Diag.nOK) ;
fprintf('  うち RT < %d ms            : %d (%.1f%%)\n', ...
    Prm.RT.FloorMs, Diag.nRTShort, Diag.nRTShort/max(1,numel(RTAll))*100) ;

% 指標5（正規化 RFD）が実質 1/dtSec になっていないかの確認。
% Onset 時点の踏み込み足はまだ空中にあるはずなので onsetBW は 0 付近になる。
fprintf('\n--- 指標5 の検算 ---\n') ;
fprintf('  Onset 時点の Fz2 [%%BW]  : 中央値 %.2f  （5〜95%%点 %.2f 〜 %.2f）\n', ...
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
%   Onset → ピーク の時間が正で、RT より長いか（接地を挟むので数百 ms になるはず）。
