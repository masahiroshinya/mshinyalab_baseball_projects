% 被験者ごとの平均の条件比較（RT・MT・PeakVelTop・PeakFz）を、1 指標 1 枚の論文用の図にする（figure-toolkit の流れに従う）
%
% 図の種類：bar-points（figure-toolkit/figure-types/bar-points/recipe.md）。
%   棒 = 条件の平均（被験者 10 人の平均）、誤差棒 = SD（棒の背面）、灰色の線 = 被験者ごとの値を条件間で結ぶ、点 = 被験者ごとの平均
% データ：Experiments/Main experiments/03_Analysis/x8_StatTable/StatTable.mat の SubjectTable
%   （x8_make_stat_table.m で、除外の後の Go 試行の値を被験者 × 条件ごとに平均したもの。stat_table_subject.csv と同じ）。S01〜S10。
%   このスクリプトで行う計算は、条件ごとの被験者間の平均と SD だけ。
% 統計（JASP）と同じ単位（被験者ごとの平均、n = 10）で描く。全試行を描いた図は ../by_condition/。
% 有意差記号は、統計の結果（下の Stats）を Affinity の注釈で加える。2026-10-26 時点で結果があるのは RT と MT。
%
% 体裁で判断したこと：
%   - RT は free を描かない（x10_plot_by_condition.m と同じ。自己ペース条件で cue からの反応ではないため）
%   - 縦軸は 0 から（棒グラフのため。recipe.md の 3）。有意差記号の分の余白を上に残す
%   - 条件の色は figure-types の既定の 4 色（Okabe-Ito）。RT は simple 以降の 3 条件に、MT などと同じ色を当てる
%
% 図の大きさ：single column（90 mm）。各図 80 × 60 mm、軸の枠は共通の既定値（figure-types/defaults.json）
%
% 手順（figure-toolkit のフォルダで実行する。figure-toolkit/AGENTS.md の 4 節）：
%   1. matlab -batch "run('<このスクリプト>')"
%      → デスクトップの affinity_mcp_work/input/subject_mean_by_condition/ に、図ごとの PNG・SVG・PDF・_components.pdf・JSON・_data.mat を書き出す
%   2. python3 tools/stack_component_pages.py subject_mean_by_condition
%   3. AFFINITY_COLLECT_DIR=<このフォルダ>/output node tools/affinity-mcp.mjs run affinity/compose/compose_single_panels.js --set inputFolder=subject_mean_by_condition
%   4. 確認：node tools/affinity-mcp.mjs run affinity/compose/check_figure.js --set checkFigureTitles=RT_subject_mean,MT_subject_mean,PeakVelTop_subject_mean,PeakFz_subject_mean
%
% 2026-10-26

%% 準備
figureFolder = fileparts(mfilename('fullpath')) ; % このスクリプトのフォルダ
projectFolder = fullfile(figureFolder, '..', '..', '..', '..') ; % Project002 のフォルダ
addpath(fullfile(projectFolder, '..', 'figure-toolkit', 'matlab')) ;
outDir = fullfile(toolkitPaths().input, 'subject_mean_by_condition') ;

%% データ（x8_StatTable の SubjectTable）
load(fullfile(projectFolder, 'Experiments', 'Main experiments', '03_Analysis', 'x8_StatTable', 'StatTable.mat'), 'SubjectTable')

ConditionNameArray = {'free', 'simple', 'gonogo', 'gostop'} ;
ConditionLabelArray = {'Free', 'Simple', 'Go/No-go', 'Go/Stop'} ; % 横軸の目盛りの文字

% 指標名（ファイル名の接頭語）・列名・縦軸のラベル・描く条件（ConditionNameArray の番号）・縦軸
Metric = struct( ...
    'Tag',    {'RT', 'MT', 'PeakVelTop', 'PeakFz'}, ...
    'Col',    {'RTForce_ms', 'MT_ms', 'PeakVelTop', 'PeakFz2_BW'}, ...
    'YLabel', {'Reaction time (ms)', 'Movement time (ms)', 'Peak bat-tip speed (m/s)', 'Peak Fz, lead leg (BW)'}, ...
    'Conds',  {2:4, 1:4, 1:4, 1:4}, ...
    'YLim',   {[0, 400], [0, 1200], [0, 40], [0, 2]}, ... % MT は有意差記号（3 段）が入るよう 1200 ms まで
    'YTick',  {0:100:400, 0:200:1200, 0:10:40, 0:0.5:2}) ;

% 統計の結果（JASP の反復測定分散分析の事後検定、Holm の補正。2026-10-26 にユーザーから受け取った値）。
% 有意差記号は有意かどうかだけを示す（p < 0.05 で *。figure-types/bar-points/recipe.md の 4）。
% 有意でない比較（n.s.）は描かない（2026-10-26、ユーザーの指定：記号が多く見づらいため）。キャプションに「表示していない比較は有意差なし」と書く。
% 比較は条件名の組、pHolm の < .001 は 0.001 と書く。統計の結果がまだない指標は空
%   RT：Condition の主効果 F(1.296, 11.67) = 10.29、p = .005（Greenhouse-Geisser。Mauchly で球面性が棄却されたため）
%   MT：Condition の主効果 F(1.433, 12.90) = 31.63、p < .001（同）
Stats = struct() ;
Stats.RT = struct('Pairs', {{'simple', 'gonogo' ; 'simple', 'gostop' ; 'gonogo', 'gostop'}}, ...
                  'PHolm', [0.451 ; 0.001 ; 0.049]) ;
Stats.MT = struct('Pairs', {{'simple', 'gonogo' ; 'simple', 'gostop' ; 'simple', 'free' ; ...
                             'gonogo', 'gostop' ; 'gonogo', 'free' ; 'gostop', 'free'}}, ...
                  'PHolm', [0.086 ; 0.004 ; 0.001 ; 0.086 ; 0.001 ; 0.001]) ;

SubjectArray = unique(SubjectTable.Subject)' ;
nS = numel(SubjectArray) ;

for im = 1:numel(Metric)

    condIdx   = Metric(im).Conds ;
    CondNames = ConditionNameArray(condIdx) ;
    nC        = numel(CondNames) ;
    yLim      = Metric(im).YLim ;

    %% データ：被験者 × 条件 の値（SubjectTable の値のまま）と、条件ごとの被験者間の平均・SD
    Y = nan(nS, nC) ;
    for iS = 1:nS
        for ic = 1:nC
            m = SubjectTable.Subject == SubjectArray(iS) & SubjectTable.Condition == CondNames{ic} ;
            if any(m), Y(iS,ic) = SubjectTable.(Metric(im).Col)(m) ; end
        end
    end
    if any(isnan(Y(:)))
        error('%s：値のない被験者 × 条件があります', Metric(im).Tag) ;
    end
    meanY = mean(Y, 1) ;
    sdY   = std(Y, 0, 1) ;
    if max(meanY + sdY) > yLim(2) || max(Y(:)) > yLim(2)
        error('%s：縦軸の範囲 [%g, %g] に収まりません', Metric(im).Tag, yLim) ;
    end

    %% データを描く：誤差棒（棒の背面）、棒（条件ごとに 1 つ）、被験者ごとの線、条件ごとの点
    [fig, ax, style] = createPanelAxes('bar-points') ;
    errorBarHandle = errorbar(ax, 1:nC, meanY, sdY) ;
    barHandles = gobjects(1, nC) ;
    for ic = 1:nC
        barHandles(ic) = bar(ax, ic, meanY(ic), style.barWidth) ;
    end
    participantLineHandles = gobjects(nS, 1) ;
    for iS = 1:nS
        participantLineHandles(iS) = plot(ax, 1:nC, Y(iS,:)) ;
    end
    markerHandles = gobjects(1, nC) ;
    for ic = 1:nC
        markerHandles(ic) = plot(ax, ic*ones(nS, 1), Y(:,ic)) ;
    end

    %% 体裁（データの値は変えない）
    conditionColours = style.colours(condIdx, :) ;
    barShare = style.barColourPercent/100 ; % 棒の塗り：条件の色の割合（残りは白）
    paleColours = barShare*conditionColours + (1 - barShare) ;
    set(errorBarHandle, 'Color', 'k', 'LineStyle', 'none', 'LineWidth', style.lineWidth) ;
    for ic = 1:nC
        set(barHandles(ic), 'FaceColor', paleColours(ic,:), 'EdgeColor', 'k', 'LineWidth', style.lineWidth, 'ShowBaseLine', 'off') ;
        set(markerHandles(ic), 'LineStyle', 'none', 'Marker', 'o', 'MarkerSize', style.markerSizePt, ...
            'MarkerFaceColor', conditionColours(ic,:), 'MarkerEdgeColor', 'none') ;
    end
    set(participantLineHandles, 'Color', style.participantLineColour(:).'/255, 'LineWidth', style.lineWidth) ;

    xlim(ax, [0.4, nC + 0.6]) ;
    ylim(ax, yLim) ;
    xticks(ax, 1:nC) ;
    xticklabels(ax, ConditionLabelArray(condIdx)) ;
    yticks(ax, Metric(im).YTick) ;
    ylabel(ax, Metric(im).YLabel) ;

    %% 注釈：有意差のブラケットと記号（Affinity で加える。位置はデータ座標）
    % 描く比較：有意な比較（p < 0.05）だけ。
    % 段：間隔の狭い比較から順に、横に重ならない一番下の段に置く（隣り合う比較は同じ段、間隔の広い比較ほど上の段）。
    % 高さ：1 段目はデータ（点と誤差棒）の最大値の 2.7 mm 上、段の間隔は 3.8 mm（記号の文字が上の段の線に重ならない間隔）。
    % 隣り合う比較のブラケットは、同じ x で接しないように端を少し内側に寄せる
    annotations = {} ;
    if isfield(Stats, Metric(im).Tag)
        st = Stats.(Metric(im).Tag) ;
        isSig = st.PHolm < 0.05 ;
        st.Pairs = st.Pairs(isSig,:) ;
        st.PHolm = st.PHolm(isSig) ;
        perMm = (yLim(2) - yLim(1))/(10*style.innerPositionCm(4)) ; % 縦軸の 1 mm のデータの単位
        yTop = max([Y(:) ; (meanY + sdY)']) ;
        nPair = numel(st.PHolm) ;
        pairX = zeros(nPair, 2) ;
        for k = 1:nPair
            pair = sort([find(strcmp(CondNames, st.Pairs{k,1})), find(strcmp(CondNames, st.Pairs{k,2}))]) ;
            inset = 0.06*(pair(2) - pair(1) == 1) ;
            pairX(k,:) = [pair(1) + inset, pair(2) - inset] ;
        end
        tier = zeros(nPair, 1) ;
        [~, placeOrder] = sortrows([pairX(:,2) - pairX(:,1), pairX(:,1)]) ;
        for k = placeOrder'
            tier(k) = 1 ;
            while any(tier > 0 & tier == tier(k) & (1:nPair)' ~= k & pairX(:,1) < pairX(k,2) & pairX(k,1) < pairX(:,2))
                tier(k) = tier(k) + 1 ;
            end
        end
        for k = 1:nPair
            level = yTop + perMm*(2.7 + 3.8*(tier(k) - 1)) ;
            annotations{end+1} = struct('type', 'bracket', 'name', sprintf('significance %s-%s', st.Pairs{k,:}), ...
                'x', pairX(k,:), 'y', level, 'legMm', 1.0, ...
                'text', '*', 'textGapMm', 0.5) ; %#ok<AGROW>
        end
        if ~isempty(annotations) && max(cellfun(@(a) a.y, annotations)) + 3.1*perMm > yLim(2) % 記号の文字（7.5 pt、約 2.6 mm）と間隔（0.5 mm）の分
            error('%s：有意差記号が縦軸の範囲に収まりません', Metric(im).Tag) ;
        end
    end

    %% 書き出し：成分は背面から前面の順（誤差棒は棒の背面）
    dataComponents = [{'error bars', errorBarHandle} ; ...
        cellfun(@(c) sprintf('bars %s', c), CondNames(:), 'UniformOutput', false), num2cell(barHandles(:)) ; ...
        {'lines participants', participantLineHandles} ; ...
        cellfun(@(c) sprintf('markers %s', c), CondNames(:), 'UniformOutput', false), num2cell(markerHandles(:))] ;
    spec = struct() ;
    spec.name = sprintf('%s_subject_mean', Metric(im).Tag) ;
    spec.panel = 'A' ;
    spec.outDir = outDir ;
    spec.style = style ;
    spec.components = [dataComponents; {'axes', []}] ;
    spec.legend = [] ;
    spec.annotations = annotations ;
    spec.column = 'single' ;
    exportPanel(fig, ax, spec) ;
    fprintf('%s mean (SD): %s\n', Metric(im).Tag, sprintf('%.3g (%.3g)  ', [meanY; sdY])) ;
    close(fig) ;
end
