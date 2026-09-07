% f7_real_grf.m
%
% 目的:
%   f1〜f6 で組み立てた処理を、実データ（x3_DataChecked/Data0x.mat）の
%   全試行に適用する。擬似データ1試行から 15 試行 × 4 条件へ広げる段。
%
% 入力:
%   Experiments/Main experiments/03_Analysis/x3_DataChecked/Data0x.mat
%       → DataArray [15試行 × 4条件]（Force1/Force2/LEDData/AnalogFs を持つ）
%
% 出力:
%   BWArray / Peak1 / Peak2 / tPeak1A / tPeak2A / SD1  ... [15 × 4] の集計行列
%   CueTextA  ... 各試行の cue 種別（'Go' / 'NoGo' / 'Stop' / ''）
%   isBadBW   ... 中央値から ±20% 外れた試行が true
%   figure 1  ... 条件色で重ね描きした Fz の時系列（Go 試行のみ）
%
% 備考:
%   - フィルタは 2 次（m3_analyze_single_trial.m:214 に合わせる）。f2〜f6 は 4 次だった。
%   - 中央値は同一被験者内で取る。被験者をまたぐと体重差が許容範囲に混ざる。
%   - ★ addpath は parameters を呼ぶ前に済ませる。順序を逆にすると
%     「parameters が見つかりません」で止まる。
%   - ★ 後ろ足の PeakFz1 は指標として弱い（2026-09-07 の実測）。
%     静止時にすでに全体重が乗っているため「増える」余地が小さく、
%     Peak1 は 0.992〜1.204 BW で静止レベル 1.0 とほとんど差がない。
%     44 試行のうち 7 試行はピーク時刻が反応時間の生理的下限（150 ms）より早く、
%     動作ではなく静止レベルのゆらぎを拾っている。踏み込み足は 0/44 で健全。
%     m3_analyze_single_trial.m / x7_3_visualize_grf.m も同じ max を使うので、
%     既存パイプラインの PeakFz1 にも同じ性質がある（コードの誤りではない）。

clear ;
close all


%% ---- 1. パスの解決（parameters を呼ぶ前に済ませる）----

% このスクリプトが置かれているフォルダを起点にする。
%   thisDir     = .../sandbox/5.7_床反力分析
%   projectRoot = .../Project002_反応時間課題バットスイング（加藤）
% 絶対パスを直書きしないのは、GitHub で共有している他の人の環境でも動くようにするため。
thisDir     = fileparts( mfilename('fullpath') ) ;
projectRoot = fileparts( fileparts(thisDir) ) ;      % 5.7 を1つ、sandbox を1つ上る

analysisDir = fullfile(projectRoot, 'Experiments', 'Main experiments', '03_Analysis') ;
dataDir     = fullfile(analysisDir, 'x3_DataChecked') ;

% parameters.m を呼べるようにする。addpath は「先頭に」追加されるので、
% 予備実験フォルダにある同名の parameters.m よりこちらが優先される。
addpath(analysisDir)

% どちらの parameters.m を読んだかを毎回表示する。値が違う可能性があるので、
% 意図しないほうを読むと エラーは出ないまま結果が変わる。
fprintf('parameters.m の場所: %s\n', which('parameters')) ;


%% ---- 2. 設定と読み込み ----

iSubject = 1 ;

Prm = parameters ;                     % 直書きをやめて参照実装と同じ値を使う

ConditionNameArray = {'free', 'simple', 'gonogo', 'gostop'} ;
ConditionColor     = {'g', 'b', 'r', 'm'} ;

fCut    = Prm.Fc ;                     % 30 Hz
nOrd    = 2 ;                          % ★ m3_analyze_single_trial.m:214 と同じ 2 次
winSec  = Prm.GRF.WinSec ;             % 2.0 s
baseSec = Prm.RT.BaseSec ;             % 0.5 s

% load には fullfile で組んだ絶対パスを渡す。相対パスは現在のフォルダ基準に
% なるので、どこから実行したかで結果が変わってしまう。
load( fullfile(dataDir, sprintf('Data%02d.mat', iSubject)) )

[nTrial, nCondition] = size(DataArray) ;

fprintf('=== Subject %02d: %d 試行 × %d 条件 ===\n', iSubject, nTrial, nCondition) ;


%% ---- 3. 試行ループ（f1〜f6 の処理をそのまま回す）----

BWArray  = nan(nTrial, nCondition) ;
Peak1    = nan(nTrial, nCondition) ;   Peak2   = nan(nTrial, nCondition) ;
tPeak1A  = nan(nTrial, nCondition) ;   tPeak2A = nan(nTrial, nCondition) ;
SD1      = nan(nTrial, nCondition) ;
CueTextA = repmat({''}, nTrial, nCondition) ;
SkipText = repmat({''}, nTrial, nCondition) ;
Fz1nCell = cell(nTrial, nCondition) ;  Fz2nCell = cell(nTrial, nCondition) ;
tRelCell = cell(nTrial, nCondition) ;

for iCondition = 1:nCondition
for iTrial = 1:nTrial

    Data = DataArray(iTrial, iCondition) ;

    % ---- 3-1. 使える試行かの確認（f4/f6 の申し送り）----
    % isfield と ~isempty の両方が必要。条件間で試行数が違うと
    % DataArray の余りが埋め要素（ErrorCode 3）になり Force1 が空になる。
    if ~isfield(Data, 'Force1') || isempty(Data.Force1) || ...
       ~isfield(Data, 'Force2') || isempty(Data.Force2)
        SkipText{iTrial, iCondition} = 'Force なし' ; continue
    end
    if isempty(Data.LEDData)
        SkipText{iTrial, iCondition} = 'LED なし' ; continue
    end

    fsA     = Data.AnalogFs ;
    Fz1_raw = Data.Force1(:, 3) ;
    Fz2_raw = Data.Force2(:, 3) ;

    % ★ filtfilt は NaN が1つでもあると全体を NaN にする。フィルタの前に弾く。
    %   'omitnan' で逃げず、試行自体を計測不良として扱う（m3:213 と同じ方針）。
    if any(isnan(Fz1_raw)) || any(isnan(Fz2_raw))
        SkipText{iTrial, iCondition} = 'Fz に NaN' ; continue
    end

    % ---- 3-2. cue 判定（f3 の申し送り）----
    % 擬似データは正のパルス1本だけだったが、実データは3種類ある。
    %   gonogo: 正か負のどちらか一方だけ出る
    %   gostop: stop 試行でも必ず先に正が出て、その後に負が出る
    %           → 正の後に負が続く試行を Stop と判定する。
    %             これを入れないと stop 試行が全部 Go に混ざる。
    led  = Data.LEDData(:, 2) ;
    tGo  = find(led > Prm.Cue.GoThresholdV,  1, 'first') ;
    tNeg = find(led < Prm.Cue.NegThresholdV, 1, 'first') ;

    if ~isempty(tGo) && (isempty(tNeg) || tNeg > tGo)
        tCueAnalog = tGo ;
        stopWin = round(Prm.Cue.StopWinSec * fsA) ;
        if ~isempty(tNeg) && (tNeg - tGo) <= stopWin
            cueText = 'Stop' ;
        else
            cueText = 'Go' ;
        end
    elseif ~isempty(tNeg)
        tCueAnalog = tNeg ;
        cueText    = 'NoGo' ;
    else
        SkipText{iTrial, iCondition} = 'cue 検出できず' ; continue
    end
    CueTextA{iTrial, iCondition} = cueText ;

    % baseAll = 1:tCueAnalog-1 が空にならないための条件（m3 の実行条件と同じ）
    if tCueAnalog < 2
        SkipText{iTrial, iCondition} = 'cue が先頭' ; continue
    end

    % ---- 3-3. フィルタと時間軸（f2/f3 と同じ）----
    nSample = numel(Fz1_raw) ;
    wn = fCut / (fsA/2) ;
    [bF, aF] = butter(nOrd, wn, 'low') ;
    Fz1 = filtfilt(bF, aF, Fz1_raw) ;
    Fz2 = filtfilt(bF, aF, Fz2_raw) ;
    tRel = ( (1:nSample)' - tCueAnalog ) / fsA ;

    % ---- 3-4. ベースライン（f4 と同じ）----
    baseAll = 1 : tCueAnalog-1 ;
    BWBase  = mean(Fz1(baseAll)) + mean(Fz2(baseAll)) ;

    nBase   = round(baseSec * fsA) ;
    baseWin = max(1, tCueAnalog - nBase) : tCueAnalog-1 ;
    SD1(iTrial, iCondition) = std(Fz1(baseWin)) ;

    % ---- 3-5. ピーク（f5 と同じ）----
    swingEnd   = min( tCueAnalog + round(winSec*fsA), nSample ) ;
    swingRange = tCueAnalog : swingEnd ;

    [p1, i1] = max( Fz1(swingRange) ) ;
    [p2, i2] = max( Fz2(swingRange) ) ;

    BWArray(iTrial, iCondition) = BWBase ;
    Peak1(iTrial, iCondition)   = p1 ;
    Peak2(iTrial, iCondition)   = p2 ;
    tPeak1A(iTrial, iCondition) = tRel(swingRange(1) + i1 - 1) ;
    tPeak2A(iTrial, iCondition) = tRel(swingRange(1) + i2 - 1) ;

    % ---- 3-6. 正規化（f6 と同じ）。波形は描画用に取っておく ----
    Fz1nCell{iTrial, iCondition} = Fz1 / BWBase ;
    Fz2nCell{iTrial, iCondition} = Fz2 / BWBase ;
    tRelCell{iTrial, iCondition} = tRel ;

end % iTrial
end % iCondition


%% ---- 4. 処理できなかった試行の内訳 ----

% スキップした理由を必ず表示する。黙って落とすと、あとで n が合わない理由が
% 分からなくなる。何件がどの理由で落ちたかは結果の一部として報告する。
fprintf('\n--- 処理できなかった試行 ---\n') ;
for iCondition = 1:nCondition
    for iTrial = 1:nTrial
        if ~isempty(SkipText{iTrial, iCondition})
            fprintf('  %-8s 行%2d: %s\n', ConditionNameArray{iCondition}, ...
                iTrial, SkipText{iTrial, iCondition}) ;
        end
    end
end


%% ---- 5. cue 判定の内訳 ----

% f3 の申し送りが効いているかの確認。
% gonogo に NoGo が、gostop に Stop が出ていなければ判定が入っていない。
fprintf('\n--- cue 判定の内訳 ---\n') ;
for iCondition = 1:nCondition
    c = CueTextA(:, iCondition) ;
    fprintf('  %-8s: Go %2d, NoGo %2d, Stop %2d, 判定なし %2d\n', ...
        ConditionNameArray{iCondition}, ...
        sum(strcmp(c, 'Go')), sum(strcmp(c, 'NoGo')), ...
        sum(strcmp(c, 'Stop')), sum(strcmp(c, ''))) ;
end


%% ---- 6. 中央値ベースの除外判定（f4 と同じ判定を実データで）----

% ★ 中央値は同一被験者内で取る。BWArray(:) は 1 被験者分の 60 要素。
%   被験者をまたぐと体重差（実データで 60〜88 kg）が許容範囲に混ざり、
%   判定が機能しなくなる。
bwRef   = median(BWArray(:), 'omitnan') ;
isBadBW = isnan(BWArray) | abs(BWArray - bwRef) > Prm.GRF.BWTolerance * bwRef ;

fprintf('\n体重の代表値 = %.1f N（%.1f kg）, 許容 %.1f 〜 %.1f N\n', ...
    bwRef, bwRef/9.81, ...
    (1-Prm.GRF.BWTolerance)*bwRef, (1+Prm.GRF.BWTolerance)*bwRef) ;

fprintf('--- 除外（ベースライン荷重が異常）---\n') ;
for iCondition = 1:nCondition
    for iTrial = find(isBadBW(:, iCondition))'
        fprintf('  %-8s 行%2d: bw = %.1f N (%.1f kg)\n', ...
            ConditionNameArray{iCondition}, iTrial, ...
            BWArray(iTrial, iCondition), BWArray(iTrial, iCondition)/9.81) ;
    end
end


%% ---- 7. 条件別の集計 ----

% ★ 「Go である」という肯定形で選ぶ。
%   ~ismember(CueTextA, ExcludedCueTextArray) という否定形だと、
%   cue が検出できなかった試行（CueText = ''）が Go 扱いで通ってしまう。
%   参照実装も時系列側は strcmp(..., 'Go') を使っている（x7_3:204）。
isGo  = strcmp(CueTextA, 'Go') ;
isUse = isGo & ~isBadBW ;

fprintf('\n--- 条件別の有効試行数と平均ピーク Fz [BW] ---\n') ;
for iCondition = 1:nCondition
    k = isUse(:, iCondition) ;
    fprintf('  %-8s: n=%2d,  後ろ足 %.3f BW / 踏み込み足 %.3f BW\n', ...
        ConditionNameArray{iCondition}, sum(k), ...
        mean(Peak1(k, iCondition) ./ BWArray(k, iCondition)), ...
        mean(Peak2(k, iCondition) ./ BWArray(k, iCondition))) ;
end

% f4 で保留にしていた RT 閾値の妥当性。実データでは ≒15 %BW という
% parameters.m のコメントが正しいかをここで確定させる。
sdRef = median(SD1(:), 'omitnan') ;
fprintf('ベースライン SD の中央値 = %.2f N（10SD = %.1f N ≒ %.1f %%BW）\n', ...
    sdRef, Prm.RT.FzK*sdRef, Prm.RT.FzK*sdRef/bwRef*100) ;

fprintf('ピーク時刻の中央値: 後ろ足 %.3f s, 踏み込み足 %.3f s\n', ...
    median(tPeak1A(isUse), 'omitnan'), median(tPeak2A(isUse), 'omitnan')) ;

% ★ ピークが動作によるものかの検算。反応時間の生理的下限（150 ms）より
%   早いピークは、動作ではなく静止レベルのゆらぎを拾っている。
floorSec    = Prm.RT.FloorMs / 1000 ;
isTooEarly1 = isUse & (tPeak1A < floorSec) ;
isTooEarly2 = isUse & (tPeak2A < floorSec) ;
fprintf('生理的下限 %.0f ms より早いピーク: 後ろ足 %d/%d, 踏み込み足 %d/%d\n', ...
    Prm.RT.FloorMs, sum(isTooEarly1(:)), sum(isUse(:)), ...
    sum(isTooEarly2(:)), sum(isUse(:))) ;
fprintf('Peak1 の範囲: %.3f 〜 %.3f BW（静止が 1.0 なので、超えない試行がある）\n', ...
    min(Peak1(isUse)./BWArray(isUse)), max(Peak1(isUse)./BWArray(isUse))) ;
fprintf('Peak2 の範囲: %.3f 〜 %.3f BW\n', ...
    min(Peak2(isUse)./BWArray(isUse)), max(Peak2(isUse)./BWArray(isUse))) ;


%% ---- 8. 描画（Go 試行の重ね描き）----

plotRange = [-1 2] ;
YLimBW    = [-0.1 1.8] ;               % 実データは 1.78 BW まで出るので f6 より広げる

% f6 の Plate 構造体を、波形1本から「試行ごとのセル配列」に差し替える。
Plate(1).Cell = Fz1nCell ; Plate(1).Name = 'プレート1（後ろ足）' ;
Plate(2).Cell = Fz2nCell ; Plate(2).Name = 'プレート2（踏み込み足）' ;

figure
for k = 1:2

    subplot(2, 1, k)
    ax = gca ;                          % subplot の軸を受け取る（f6 と同じ理由）
    hold on

    for iCondition = 1:nCondition

        nShown = 0 ;

        for iTrial = 1:nTrial

            if ~isUse(iTrial, iCondition), continue, end

            nShown = nShown + 1 ;

            % 凡例は各条件の1本目にだけ付ける。全部に付けると
            % 凡例が 44 行になって図が読めない。
            if nShown == 1
                visArg = {'DisplayName', ConditionNameArray{iCondition}} ;
            else
                visArg = {'HandleVisibility', 'off'} ;
            end

            plot(tRelCell{iTrial, iCondition}, Plate(k).Cell{iTrial, iCondition}, ...
                '-', 'Color', ConditionColor{iCondition}, 'LineWidth', 0.8, visArg{:}) ;

        end % iTrial
    end % iCondition

    yline(1, 'k--', '1 BW', 'LineWidth', 1.0) ;
    xline(0, 'k--', 'Cue') ;

    set(ax, 'XLim', plotRange, 'YLim', YLimBW)
    xlabel('Time from cue [s]')
    ylabel('Fz [BW]')
    legend('Location', 'northwest')
    title(Plate(k).Name)
    grid on

end

sgtitle(sprintf('Subject %02d: 体重正規化した Fz の時系列（Go 試行）', iSubject))

fprintf('\n描画完了: 有効 Go 試行 %d 本\n', sum(isUse(:))) ;

% 図で確認すること
%   上段（後ろ足）が 1 BW の線から下へ落ちていく形になっているか。
%     擬似データ（f1）は 1.2 BW の山を作ったが、実データにその山はない。
%   下段（踏み込み足）が 0 付近から立ち上がり、0.6〜1.2 s に山を作っているか。
%   どの試行も 1 BW 線の上（キューより左）で平坦か。
%     ここが揺れている試行は、キュー前に構え直している（BWBase が方式A と方式B で食い違う）。
%   線が消えている条件がないか。あれば isUse で全試行が落ちている
%     （NoGo/Stop だけの条件、または BWBase 異常）。

