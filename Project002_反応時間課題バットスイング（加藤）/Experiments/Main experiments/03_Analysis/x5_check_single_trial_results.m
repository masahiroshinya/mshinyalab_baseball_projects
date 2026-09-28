% x5_check_single_trial_results.m
%
% 目的:
%   x4 の単一試行分析結果を目視確認し、問題がなければ
%   x5_SingleTrialAnalysisResultsChecked/ に保存する。
%
% 操作方法:
%   iSubject と iCondition を指定して実行すると、その条件の全試行の
%   「top マーカー速度」「床反力 Fz」が1枚のウインドウに並んで表示される。
%   確認後、保存するか確認メッセージが出る。
%
% 備考:
%   波形は m3 が計算済みのもの（Result.NetVelTop / Fz1Filt / Fz2Filt）を読む（再計算しない）。
%   縦線：黒破線 = キュー（t=0）、赤実線 = 床反力による動作開始（RTForce）。

clear
close all
clc

% -----------------------------------------------------------------------
% 設定
% -----------------------------------------------------------------------
iSubject   = 3 ;
iCondition = 1 ;   % 1=free, 2=simple, 3=gonogo, 4=gostop
ConditionNameArray = {'free', 'simple', 'gonogo', 'gostop'} ;
condName           = ConditionNameArray{iCondition} ;
XLim = [-0.5, 2.5] ;   % キューからの時間 [s]
nCol = 5 ;             % 1行に並べる試行数

% -----------------------------------------------------------------------
% データ読み込み
% -----------------------------------------------------------------------
load(sprintf('x3_DataChecked/Data%02d', iSubject))
load(sprintf('x4_SingleTrialAnalysisResults/SingleTrialAnalysisResults%02d', iSubject))

nTrials   = size(SingleTrialResultArray, 1) ;
nRowBlock = ceil(nTrials / nCol) ;   % 速度・Fz の2段を1組とした組数

% グラフの配置（ウインドウ全体を 0〜1 とした割合）
top      = 0.90 ;   % グラフ上端（上はメインタイトル用に空ける）
bottom   = 0.06 ;   % グラフ下端（下は凡例用に空ける）
left     = 0.05 ;
right    = 0.99 ;
pairGap  = 0.04 ;   % 同じ組の「速度」と「Fz」の間
blockGap = 0.10 ;   % 組と組の間（行の境目を広めにとる）
colGap   = 0.03 ;   % 列の間

blockH = (top - bottom - (nRowBlock-1)*blockGap) / nRowBlock ;   % 1組の高さ
axH    = (blockH - pairGap) / 2 ;                                 % グラフ1枚の高さ
axW    = (right - left - (nCol-1)*colGap) / nCol ;                % グラフ1枚の幅


% -----------------------------------------------------------------------
% 全試行を並べて描画
% -----------------------------------------------------------------------
figure(1) ; clf
set(gcf, 'Position', [50 50 1600 900]) ;
axVel = gobjects(1, nTrials) ;
axFz  = gobjects(1, nTrials) ;

for iTrial = 1:nTrials

    Data   = DataArray(iTrial, iCondition) ;
    Result = SingleTrialResultArray(iTrial, iCondition) ;

    % この試行の描画位置（速度の段と、その直下の Fz の段）
    iBlock = ceil(iTrial / nCol) ;
    iCol   = mod(iTrial - 1, nCol) + 1 ;
    x    = left + (iCol - 1) * (axW + colGap) ;
    yTop = top  - (iBlock - 1) * (blockH + blockGap) ;   % この組の上端
    axVel(iTrial) = axes('Position', [x, yTop - axH,             axW, axH]) ;
    axFz(iTrial)  = axes('Position', [x, yTop - 2*axH - pairGap, axW, axH]) ;

    % 存在しない試行・キュー未検出の試行は枠だけ出す
    if Result.IsNoData || isnan(Result.TCueMarker)
        title(axVel(iTrial), sprintf('Trial %d：データなし', iTrial)) ;
        continue
    end

    fs  = Data.FrameRate ;
    fsA = Data.AnalogFs ;
    rtS = Result.RTForce / 1000 ;   % 動作開始（キュー基準）[s]

    % ---- top マーカー速度 ----
    axes(axVel(iTrial)) ; hold on
    if ~isempty(Result.NetVelTop)
        t = ((1:numel(Result.NetVelTop)) - Result.TCueMarker) / fs ;
        plot(t, Result.NetVelTop, 'b-', 'LineWidth', 1) ;
    end
    xline(0, 'k--') ;
    if ~isnan(rtS), xline(rtS, 'r-') ; end
    xlim(XLim) ; grid on
    if iCol == 1, ylabel('top (m/s)') ; end
    title(sprintf('Trial %d [%s]  Peak %.1f', iTrial, Result.CueText, Result.PeakVelTop)) ;

    % ---- 床反力 Fz ----
    axes(axFz(iTrial)) ; hold on
    if ~isempty(Result.Fz1Filt)
        tCueAnalog = round(Result.TCueMarker / fs * fsA) ;
        tA = ((1:numel(Result.Fz1Filt)) - tCueAnalog) / fsA ;
        hFz = plot(tA, Result.Fz1Filt, tA, Result.Fz2Filt, 'LineWidth', 1) ;
    end
    xline(0, 'k--') ;
    if ~isnan(rtS), xline(rtS, 'r-') ; end
    xlim(XLim) ; grid on
    if iCol == 1, ylabel('Fz (N)') ; end
    title(sprintf('RTForce %.0f ms', Result.RTForce)) ;

end

% 全試行で縦軸をそろえる（データなしの枠は除く）
linkaxes(axVel(isgraphics(axVel)), 'y') ;
linkaxes(axFz(isgraphics(axFz)),   'y') ;

sgtitle(sprintf('Subject %02d  %s（全 %d 試行）', iSubject, condName, nTrials)) ;

% 凡例は1つだけ、ウインドウ左下（グラフの外）に置く
if exist('hFz', 'var')
    lgd = legend(hFz, {'Fz1 後ろ足', 'Fz2 踏み込み足'}, 'Orientation', 'horizontal') ;
    lgd.Units = 'normalized' ;
    lgd.Position(1:2) = [0.01, 0.005] ;
end

% -----------------------------------------------------------------------
% 確認完了後に保存
% -----------------------------------------------------------------------
answer = input(sprintf('\n%s 条件を確認しました。x5 に保存しますか？ [y/n]: ', condName), 's') ;
if strcmpi(answer, 'y')
    savePath = sprintf('x5_SingleTrialAnalysisResultsChecked/SingleTrialAnalysisResults%02d', iSubject) ;
    save(savePath, 'SingleTrialResultArray') ;
    fprintf('保存完了: %s.mat\n', savePath) ;
else
    fprintf('保存をキャンセルしました。\n') ;
end
