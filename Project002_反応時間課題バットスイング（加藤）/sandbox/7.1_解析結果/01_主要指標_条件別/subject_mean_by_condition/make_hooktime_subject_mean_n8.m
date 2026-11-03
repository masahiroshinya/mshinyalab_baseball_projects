% ① フック局面の時間（HookTime）の被験者ごとの平均の条件比較を、S03・S04 を除いた 8 名で、論文用の図にする（figure-toolkit の流れに従う）
%
% 2026-11-03：10 名の HookTime の図は make_subject_mean_by_condition.m に加えたので、この 8 名の版は図の名前の末尾に _n8 を付けた
%   （ファイル名も make_hooktime_subject_mean.m から変えた。ほかの 8 名の図と同じ付け方）。
%
% 図の種類：bar-points（figure-toolkit/figure-types/bar-points/recipe.md）。体裁は同じフォルダの make_subject_mean_by_condition.m と同じ。
%   棒 = 条件の平均（被験者 8 人の平均）、誤差棒 = SD（棒の背面）、灰色の線 = 被験者ごとの値を条件間で結ぶ、点 = 被験者ごとの平均
% データ：Experiments/Main experiments/03_Analysis/x8_StatTable/StatTable.mat の SubjectTable の HookTime_ms
%   （x8_make_stat_table.m で、除外の後の Go 試行の値を被験者 × 条件ごとに平均したもの。stat_table_subject.csv と同じ）。
%   S03・S04 は top の欠損が多いので除き、8 名（S01・S02・S05〜S10）で描く（RM-ANOVA_2026-1029.jasp のフィルタ Subject != 3 & Subject != 4 と同じ）。
%   このスクリプトで行う計算は、条件ごとの被験者間の平均と SD だけ。
% ① フック局面：Onset からフック頂点（引き始め）まで（sandbox/7.1_解析結果/03_top軌道_MT局面/top_phase_viewer/技術説明.md）。
%
% 体裁で判断したこと：
%   - 縦軸は 0 から（棒グラフのため。recipe.md の 3）。有意差記号（4 段）の分の余白を上に残す
%   - 条件の色は figure-types の既定の 4 色（Okabe-Ito）。MT などの図と同じ
%
% 図の大きさ：single column（90 mm）。80 × 60 mm、軸の枠は共通の既定値（figure-types/defaults.json）
%
% 手順（figure-toolkit のフォルダで実行する。figure-toolkit/AGENTS.md の 4 節）：
%   1. matlab -batch "run('<このスクリプト>')"
%      → デスクトップの affinity_mcp_work/input/hooktime_subject_mean_n8/ に、PNG・SVG・PDF・_components.pdf・JSON・_data.mat を書き出す
%   2. python3 tools/stack_component_pages.py hooktime_subject_mean_n8
%   3. AFFINITY_COLLECT_DIR=<このフォルダ>/output node tools/affinity-mcp.mjs run affinity/compose/compose_single_panels.js --set inputFolder=hooktime_subject_mean_n8
%   4. 確認：node tools/affinity-mcp.mjs run affinity/compose/check_figure.js --set checkFigureTitles=HookTime_subject_mean_n8
%
% 2026-10-30

%% 準備
figureFolder = fileparts(mfilename('fullpath')) ; % このスクリプトのフォルダ
projectFolder = fullfile(figureFolder, '..', '..', '..', '..') ; % Project002 のフォルダ
addpath(fullfile(projectFolder, '..', 'figure-toolkit', 'matlab')) ;
outDir = fullfile(toolkitPaths().input, 'hooktime_subject_mean_n8') ;

%% データ（x8_StatTable の SubjectTable。S03・S04 を除く）
load(fullfile(projectFolder, 'Experiments', 'Main experiments', '03_Analysis', 'x8_StatTable', 'StatTable.mat'), 'SubjectTable')
ExcludeSubjects = [3, 4] ;

ConditionNameArray = {'free', 'simple', 'gonogo', 'gostop'} ;
ConditionLabelArray = {'Free', 'Simple', 'Go/No-go', 'Go/Stop'} ; % 横軸の目盛りの文字

Metric = struct('Tag', 'HookTime', 'Col', 'HookTime_ms', 'YLabel', 'Hook phase duration (ms)', ...
    'YLim', [0, 1000], 'YTick', 0:200:1000) ; % 有意差記号（4 段）が入るよう 1000 ms まで

% 統計の結果（RM-ANOVA_2026-1029.jasp の HookTime。反復測定分散分析の事後検定、Holm の補正。8 名）。
% 有意差記号は有意かどうかだけを示す（p < 0.05 で *。figure-types/bar-points/recipe.md の 4）。有意でない比較は描かない。
%   Condition の主効果 F(1.681, 11.77) = 31.74、p < .001（Greenhouse-Geisser。全指標で GG の値をそろえて報告する方針）
Stats = struct('Pairs', {{'simple', 'gonogo' ; 'simple', 'gostop' ; 'simple', 'free' ; ...
                          'gonogo', 'gostop' ; 'gonogo', 'free' ; 'gostop', 'free'}}, ...
               'PHolm', [0.048 ; 0.014 ; 0.002 ; 0.014 ; 0.001 ; 0.003]) ;

SubjectArray = setdiff(unique(SubjectTable.Subject)', ExcludeSubjects) ;
nS = numel(SubjectArray) ;
CondNames = ConditionNameArray ;
nC = numel(CondNames) ;
yLim = Metric.YLim ;

%% データ：被験者 × 条件 の値（SubjectTable の値のまま）と、条件ごとの被験者間の平均・SD
Y = nan(nS, nC) ;
for iS = 1:nS
    for ic = 1:nC
        m = SubjectTable.Subject == SubjectArray(iS) & SubjectTable.Condition == CondNames{ic} ;
        if any(m), Y(iS,ic) = SubjectTable.(Metric.Col)(m) ; end
    end
end
if any(isnan(Y(:)))
    error('%s：値のない被験者 × 条件があります', Metric.Tag) ;
end
meanY = mean(Y, 1) ;
sdY   = std(Y, 0, 1) ;
if max(meanY + sdY) > yLim(2) || max(Y(:)) > yLim(2)
    error('%s：縦軸の範囲 [%g, %g] に収まりません', Metric.Tag, yLim) ;
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
conditionColours = style.colours(1:nC, :) ;
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
xticklabels(ax, ConditionLabelArray) ;
yticks(ax, Metric.YTick) ;
ylabel(ax, Metric.YLabel) ;

%% 注釈：有意差のブラケットと記号（Affinity で加える。位置はデータ座標）
% 置き方は make_subject_mean_by_condition.m と同じ。
% 描く比較：有意な比較（p < 0.05）だけ。
% 段：間隔の狭い比較から順に、横に重ならない一番下の段に置く（隣り合う比較は同じ段、間隔の広い比較ほど上の段）。
% 高さ：1 段目はデータ（点と誤差棒）の最大値の 2.7 mm 上、段の間隔は 3.8 mm（記号の文字が上の段の線に重ならない間隔）。
% 隣り合う比較のブラケットは、同じ x で接しないように端を少し内側に寄せる
annotations = {} ;
st = Stats ;
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
    error('%s：有意差記号が縦軸の範囲に収まりません', Metric.Tag) ;
end

%% 書き出し：成分は背面から前面の順（誤差棒は棒の背面）
dataComponents = [{'error bars', errorBarHandle} ; ...
    cellfun(@(c) sprintf('bars %s', c), CondNames(:), 'UniformOutput', false), num2cell(barHandles(:)) ; ...
    {'lines participants', participantLineHandles} ; ...
    cellfun(@(c) sprintf('markers %s', c), CondNames(:), 'UniformOutput', false), num2cell(markerHandles(:))] ;
spec = struct() ;
spec.name = sprintf('%s_subject_mean_n8', Metric.Tag) ;
spec.panel = 'A' ;
spec.outDir = outDir ;
spec.style = style ;
spec.components = [dataComponents; {'axes', []}] ;
spec.legend = [] ;
spec.annotations = annotations ;
spec.column = 'single' ;
exportPanel(fig, ax, spec) ;
fprintf('%s mean (SD), n = %d: %s\n', Metric.Tag, nS, sprintf('%.3g (%.3g)  ', [meanY; sdY])) ;
fprintf('有意差の段の最大：%d、記号の上端 %.0f ms\n', max(tier), max(cellfun(@(a) a.y, annotations)) + 3.1*perMm) ;
close(fig) ;
