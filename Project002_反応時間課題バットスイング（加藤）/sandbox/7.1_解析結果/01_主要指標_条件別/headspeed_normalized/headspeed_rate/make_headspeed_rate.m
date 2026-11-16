% フリー条件で正規化したヘッドスピード（PeakVelTop）の変化率を、3 つのパネル（A〜C）に横に並べた図にする（figure-toolkit の流れに従う）
%
% 学会のポスター発表の後に受けた依頼（フリー条件を基準に正規化し、対応なしで検定した結果）への回答の図。読み手は専門家。
% 原案：../headspeed_normalized_stats.m の図（figure(1) の subplot 1〜3、体裁は MATLAB の既定のまま）。
%   データの読み込みと計算は原案と同じにし、値は変えない。統計の値（注釈の文字）は、原案のコマンドウィンドウの出力
%   （../技術説明.md の 3 節）を写す。
% 各パネルの段落：データ（原案と同じ計算）、データを描く（原案と同じオブジェクト）、体裁、注釈（Affinity で加える）、書き出し。
%
% パネル：
%   A 被験者単位の変化率（n = 10）：被験者ごとの点と線、条件の平均 ± SD。0 との比較（1 標本 t 検定）と、3 条件の対応なしの比較の結果を注釈に
%   B 試行単位の変化率（455 試行）：試行の点、条件の平均 ± SD。一元配置分散分析と、有意な組（Simple − Go/Stop、Welch の t 検定、Holm）を注釈に
%   C Go/Stop − Simple の差：被験者ごと（試行からの 95% 信頼区間）と、2 つのまとめ方（試行単位・対応なし／被験者単位・対応あり）
% 図全体：double column 190 mm。各パネルは 63 × 65 mm で、軸の枠の位置は 3 パネルで共通（この図だけの値。AGENTS.md の 4 節の 6 の
%   暫定の規則で、3 列は自分で決める場合にあたる）
%
% 体裁で判断したこと：
%   - 変化率は符号付きの量なので、棒は描かず、平均 ± SD を点と誤差棒で描く（bar-points の棒の代わり）。0 の線を破線で描く
%   - A の被験者の点は、原案と同じく線の頂点に付ける（灰色）。B の試行の点は条件の色（figure-types の既定の 4 色を白で淡くしたもの。
%     Free・Simple・Go/No-go・Go/Stop の順で、ポスターと同じ割り当て）
%   - タイトル（A〜C の見出し）は軸ラベルと同じ 9 pt。注釈の文字は短くし、検定の名前と値は図の説明文に書く
%   - B の試行の点は、原案と同じ乱数（rng(0)）で横にずらす
%   - C の縦軸は、S04 の区間（−5.5〜16.8 %）まで入る [−10, 20] にする（区間を切らない）
%
% 手順（figure-toolkit のフォルダで実行する。figure-toolkit/AGENTS.md の 4 節。<ここ> はこのスクリプトのフォルダの絶対パス）：
%   1. matlab -batch "addpath('matlab') ; run('<ここ>/make_headspeed_rate.m')"
%      → デスクトップの affinity_mcp_work/input/headspeed_rate/ に、パネルごとの PNG・SVG・PDF・_components.pdf・JSON・_data.mat と、
%        配置の JSON（headspeed_rate_layout.json）を書き出す
%   2. python <ここ>/combine_headspeed_rate.py
%   3. python tools/stack_component_pages.py test_figures/headspeed_rate.json
%   4. AFFINITY_COLLECT_DIR=<ここ>/output node tools/affinity-mcp.mjs run affinity/compose/compose_test_figure.js --set testFigureName=headspeed_rate
%   5. 確認：node tools/affinity-mcp.mjs run affinity/compose/check_figure.js --set checkFigureTitles=headspeed_rate
%
% 2026-11-16 加藤 和太郎（AI が figure-toolkit の手順で作成）

%% 準備
figureFolder = fileparts(mfilename('fullpath')) ; % このスクリプトのフォルダ
toolFolder = fileparts(figureFolder) ; % 原案（headspeed_normalized_stats.m）のフォルダ
projectFolder = fullfile(toolFolder, '..', '..', '..', '..') ; % Project002 のフォルダ
addpath(fullfile(projectFolder, '..', 'figure-toolkit', 'matlab')) ;

figureName = 'headspeed_rate' ;
outDir = fullfile(toolkitPaths().input, figureName) ;
column = 'double' ; % 図全体の幅の種類（190 mm）
panelSizeCm = [6.3, 6.5] ; % 各パネルの MATLAB の図の大きさ [幅, 高さ] [cm]（3 列で 189 mm）
innerPositionCm = [1.3, 1.5, 4.85, 4.3] ; % 軸の枠の左下の x・y と幅・高さ [cm]（3 パネルで共通。B の横軸の文字が並ぶよう、幅をとる）

%% データ（原案の「準備」「データ」「A」「B」「C」の段落と同じ読み込み・計算）
dataFile = fullfile(projectFolder, 'Experiments', 'Main experiments', '03_Analysis', 'x8_StatTable', 'stat_table_trial.csv') ;
CondArray  = {'free', 'simple', 'gonogo', 'gostop'} ;
CondLabel  = {'Free', 'Simple', 'Go/No-go', 'Go/Stop'} ;
ReactArray = CondArray(2:4) ;

T = readtable(dataFile, 'TextType', 'string') ;
T = T(T.IsGo == 1 & ~isnan(T.PeakVelTop), {'Subject', 'Condition', 'Trial', 'PeakVelTop'}) ;
SubjectArray = unique(T.Subject)' ;
nS = numel(SubjectArray) ;
V = nan(nS, numel(CondArray)) ;
for iS = 1:nS
    for ic = 1:numel(CondArray)
        V(iS,ic) = mean(T.PeakVelTop(T.Subject == SubjectArray(iS) & T.Condition == CondArray{ic})) ;
    end
end
freeMean = V(:,1) ;
Rate = (V(:,2:4)./freeMean - 1)*100 ; % A：被験者単位の変化率（列 = ReactArray）
[~, iSubj] = ismember(T.Subject, SubjectArray) ;
T.Rate = (T.PeakVelTop./freeMean(iSubj) - 1)*100 ; % B：試行単位の変化率

DiffSubj = nan(nS, 3) ; % C：列 = 差、95% 信頼区間の下限、上限
for iS = 1:nS
    xG = T.Rate(T.Subject == SubjectArray(iS) & T.Condition == "gostop") ;
    xS = T.Rate(T.Subject == SubjectArray(iS) & T.Condition == "simple") ;
    [~, ~, ci] = ttest2(xG, xS, 'Vartype', 'unequal') ;
    DiffSubj(iS,:) = [mean(xG) - mean(xS), ci'] ;
end
xG = T.Rate(T.Condition == "gostop") ;
xS = T.Rate(T.Condition == "simple") ;
[~, ~, ci] = ttest2(xG, xS, 'Vartype', 'unequal') ;
DiffTrial = [mean(xG) - mean(xS), ci'] ;
[~, ~, ci] = ttest(Rate(:,3) - Rate(:,1)) ;
DiffPaired = [mean(Rate(:,3) - Rate(:,1)), ci'] ;


%% Panel A：被験者単位の変化率（原案の図の subplot(1, 3, 1)）

% データを描く（原案と同じ）：被験者ごとの線（点は線の頂点に付ける）、条件の平均 ± SD、0 の線
[figA, axA, styleA] = createPanelAxes('bar-points') ;
styleA = applyPanelLayout(figA, axA, styleA, panelSizeCm, innerPositionCm) ;
zeroLineA = yline(axA, 0, '--') ;
participantLineHandlesA = plot(axA, 1:3, Rate') ;
errorBarHandleA = errorbar(axA, 1:3, mean(Rate), std(Rate)) ;

% 体裁
conditionColours = styleA.colours ; % Free・Simple・Go/No-go・Go/Stop の順
set(zeroLineA, 'Color', styleA.participantLineColour(:).'/255, 'LineWidth', styleA.lineWidth) ;
set(participantLineHandlesA, 'Color', styleA.participantLineColour(:).'/255, 'LineWidth', styleA.lineWidth, ...
    'Marker', 'o', 'MarkerSize', styleA.markerSizePt - 1, 'MarkerFaceColor', styleA.participantLineColour(:).'/255, 'MarkerEdgeColor', 'none') ;
set(errorBarHandleA, 'Color', 'k', 'LineStyle', 'none', 'LineWidth', styleA.lineWidth, 'Marker', 'o', ...
    'MarkerSize', styleA.markerSizePt + 1.5, 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'none', 'CapSize', 4) ;
yLimA = [-6, 6] ;
if max(abs([Rate(:) ; mean(Rate)' + std(Rate)' ; mean(Rate)' - std(Rate)'])) > yLimA(2)
    error('Panel A：縦軸の範囲 [%g, %g] に収まりません', yLimA) ;
end
xlim(axA, [0.5, 3.5]) ;
ylim(axA, yLimA) ;
xticks(axA, 1:3) ;
xticklabels(axA, CondLabel(2:4)) ;
axA.XTickLabelRotation = 0 ; % 目盛りの文字を水平にする（MATLAB が自動で斜めにしないように）
yticks(axA, -6:2:6) ;
ylabel(axA, 'Change from Free (%)') ;
title(axA, sprintf('Participant means (n = %d)', nS), 'FontWeight', 'normal', 'FontSize', styleA.fontSizePt.axisLabel) ;

% 注釈：原案の A1（1 標本 t 検定、Holm）と A2（一元配置分散分析、対応なし）の結果
% 文字は短くし、検定の名前と値は図の説明文（../技術説明.md の 6 節）に書く
annotationsA = { ...
    struct('type', 'text', 'name', 'all ns', 'text', 'All n.s.', ...
        'position', [0.5, yLimA(2)], 'anchor', 'left-top', 'offsetMm', [1, 0])} ; % 軸の左上から 1 mm 内側

% 書き出し
specA = struct() ;
specA.name = 'A_participant_means' ;
specA.panel = 'A' ;
specA.outDir = outDir ;
specA.style = styleA ;
specA.column = column ;
specA.components = {'zero line', zeroLineA ; 'lines participants', participantLineHandlesA ; 'mean sd', errorBarHandleA ; 'axes', []} ;
specA.legend = [] ;
specA.annotations = annotationsA ;
exportPanel(figA, axA, specA) ;


%% Panel B：試行単位の変化率（原案の図の subplot(1, 3, 2)）

% データを描く（原案と同じ）：試行の点（原案と同じ乱数で横にずらす）、条件の平均 ± SD、0 の線
[figB, axB, styleB] = createPanelAxes('bar-points') ;
styleB = applyPanelLayout(figB, axB, styleB, panelSizeCm, innerPositionCm) ;
zeroLineB = yline(axB, 0, '--') ;
rng(0) ; % 原案と同じ
markerHandlesB = gobjects(1, 4) ;
errorBarHandlesB = gobjects(1, 4) ;
for ic = 1:4
    r = T.Rate(T.Condition == CondArray{ic}) ;
    markerHandlesB(ic) = scatter(axB, ic + 0.15*(rand(size(r)) - 0.5)*2, r) ;
    errorBarHandlesB(ic) = errorbar(axB, ic, mean(r), std(r)) ;
end

% 体裁
set(zeroLineB, 'Color', styleB.participantLineColour(:).'/255, 'LineWidth', styleB.lineWidth) ;
for ic = 1:4
    set(markerHandlesB(ic), 'SizeData', (styleB.markerSizePt*0.6)^2, 'Marker', 'o', ...
        'MarkerFaceColor', 0.5*conditionColours(ic, :) + 0.5, 'MarkerEdgeColor', 'none') ; % 条件の色を白で淡くする（透明度は PDF で扱いにくいため使わない）
    set(errorBarHandlesB(ic), 'Color', 'k', 'LineStyle', 'none', 'LineWidth', styleB.lineWidth, 'Marker', 'o', ...
        'MarkerSize', styleB.markerSizePt + 1.5, 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'none', 'CapSize', 4) ;
end
yLimB = [-15, 15] ;
if max(abs(T.Rate)) > yLimB(2)
    error('Panel B：縦軸の範囲 [%g, %g] に収まりません', yLimB) ;
end
xlim(axB, [0.55, 4.45]) ; % 条件の間隔を広くとり、横軸の文字（Go/No-go と Go/Stop）がくっつかないようにする
ylim(axB, yLimB) ;
xticks(axB, 1:4) ;
xticklabels(axB, CondLabel) ;
axB.XTickLabelRotation = 0 ; % 目盛りの文字を水平にする（MATLAB が自動で斜めにしないように）
yticks(axB, -15:5:15) ;
ylabel(axB, 'Change from Free (%)') ;
title(axB, sprintf('Pooled trials (n = %d)', height(T)), 'FontWeight', 'normal', 'FontSize', styleA.fontSizePt.axisLabel) ;

% 注釈：原案の B（一元配置分散分析、Welch の t 検定 Holm 6 組）の結果。有意な組（Simple − Go/Stop）だけにブラケット
bracketYB = max(T.Rate(T.Condition == "simple" | T.Condition == "gonogo" | T.Condition == "gostop")) + 1.5 ;
annotationsB = { ...
    struct('type', 'bracket', 'name', 'significance simple-gostop', 'x', [2, 4], 'y', bracketYB, 'legMm', 1.0, ...
        'text', '*', 'textGapMm', 0.5), ...
    struct('type', 'text', 'name', 'anova unpaired', 'text', 'ANOVA p = .025', ...
        'position', [0.55, yLimB(2)], 'anchor', 'left-top', 'offsetMm', [1, 0])} ; % 軸の左上から 1 mm 内側

% 書き出し
specB = struct() ;
specB.name = 'B_pooled_trials' ;
specB.panel = 'B' ;
specB.outDir = outDir ;
specB.style = styleB ;
specB.column = column ;
specB.components = [{'zero line', zeroLineB} ; ...
    [strcat('markers', {' '}, CondArray(:)), num2cell(markerHandlesB(:))] ; ...
    {'mean sd', errorBarHandlesB ; 'axes', []}] ;
specB.legend = [] ;
specB.annotations = annotationsB ;
exportPanel(figB, axB, specB) ;


%% Panel C：Go/Stop − Simple の差（原案の図の subplot(1, 3, 3)）
% 原案は横向き（被験者を縦に並べる）。ここでは、3 パネルで軸の枠を揃えるために縦向き（被験者を横軸に並べる）にする。値は同じ

% データを描く（原案と同じ値）：被験者ごとの差と 95% 信頼区間、2 つのまとめ方、0 の線
[figC, axC, styleC] = createPanelAxes('bar-points') ;
styleC = applyPanelLayout(figC, axC, styleC, panelSizeCm, innerPositionCm) ;
xS_ = 1:nS ;              % 被験者の位置
xSum = nS + [2, 3.5] ;    % まとめの 2 つの位置（1 つあけて右に置く）
zeroLineC = yline(axC, 0, '--') ;
subjectHandleC = errorbar(axC, xS_, DiffSubj(:,1), DiffSubj(:,1) - DiffSubj(:,2), DiffSubj(:,3) - DiffSubj(:,1)) ;
trialHandleC = errorbar(axC, xSum(1), DiffTrial(1), DiffTrial(1) - DiffTrial(2), DiffTrial(3) - DiffTrial(1)) ;
pairedHandleC = errorbar(axC, xSum(2), DiffPaired(1), DiffPaired(1) - DiffPaired(2), DiffPaired(3) - DiffPaired(1)) ;

% 体裁
set(zeroLineC, 'Color', styleC.participantLineColour(:).'/255, 'LineWidth', styleC.lineWidth) ;
set(subjectHandleC, 'Color', [0.45, 0.45, 0.45], 'LineStyle', 'none', 'LineWidth', styleC.lineWidth, 'Marker', 'o', ...
    'MarkerSize', styleC.markerSizePt, 'MarkerFaceColor', [0.45, 0.45, 0.45], 'MarkerEdgeColor', 'none', 'CapSize', 2) ;
set([trialHandleC, pairedHandleC], 'Color', 'k', 'LineStyle', 'none', 'LineWidth', styleC.lineWidth, 'Marker', 'd', ...
    'MarkerSize', styleC.markerSizePt + 2, 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'none', 'CapSize', 4) ;
yLimC = [-10, 20] ;
if min(DiffSubj(:)) < yLimC(1) || max(DiffSubj(:)) > yLimC(2)
    error('Panel C：縦軸の範囲 [%g, %g] に収まりません', yLimC) ;
end
xlim(axC, [0.3, xSum(2) + 0.9]) ;
ylim(axC, yLimC) ;
xticks(axC, [xS_, xSum]) ;
xticklabels(axC, [arrayfun(@num2str, xS_, 'UniformOutput', false), {'T', 'P'}]) ;
axC.XTickLabelRotation = 0 ; % 目盛りの文字を水平にする（MATLAB が自動で斜めにしないように）
yticks(axC, -10:5:20) ;
xlabel(axC, 'Participant') ;
ylabel(axC, 'Go/Stop − Simple (%)') ;
title(axC, 'Mean difference (95% CI)', 'FontWeight', 'normal', 'FontSize', styleA.fontSizePt.axisLabel) ;

% 注釈：まとめの 2 つの説明（T：試行単位・対応なし、P：被験者単位・対応あり）。
% 位置は軸の枠の右上に右揃え（左に置くと S04 の区間の線に重なるため）
xLimC = xlim(axC) ;
annotationsC = { ...
    struct('type', 'text', 'name', 'label trials', 'text', 'T: trials, unpaired', ...
        'position', [xLimC(2), yLimC(2)], 'anchor', 'right-top', 'offsetMm', [0, 0]), ...
    struct('type', 'text', 'name', 'label participants', 'text', 'P: participants, paired', ...
        'position', [xLimC(2), yLimC(2)], 'anchor', 'right-top', 'offsetMm', [0, -3.2])} ;

% 書き出し
specC = struct() ;
specC.name = 'C_gostop_minus_simple' ;
specC.panel = 'C' ;
specC.outDir = outDir ;
specC.style = styleC ;
specC.column = column ;
specC.components = {'zero line', zeroLineC ; 'participants', subjectHandleC ; 'summary', [trialHandleC, pairedHandleC] ; 'axes', []} ;
specC.legend = [] ;
specC.annotations = annotationsC ;
exportPanel(figC, axC, specC) ;


%% 配置の JSON（combine_headspeed_rate.py が読む）：各パネルの左上の位置と、図全体の大きさ
panelWidthMm = panelSizeCm(1)*10 ;
panelHeightMm = panelSizeCm(2)*10 ;
areaWidthMm = styleA.columnWidthMm.(column) ;
areaHeightMm = panelHeightMm ;
if 3*panelWidthMm > areaWidthMm
    error('3 列のパネルの幅 %.1f mm が %s column の幅 %.1f mm を超えています', 3*panelWidthMm, column, areaWidthMm) ;
end
panelSpecs = {specA, specB, specC} ;
layout = struct() ;
layout.name = figureName ;
layout.figureArea = struct('column', column, 'widthMm', areaWidthMm, 'heightMm', areaHeightMm) ;
layout.panels = struct('panel', {}, 'source', {}, 'offsetMm', {}) ;
for iPanel = 1:numel(panelSpecs)
    layout.panels(iPanel) = struct('panel', panelSpecs{iPanel}.panel, 'source', panelSpecs{iPanel}.name, ...
        'offsetMm', [(iPanel - 1)*panelWidthMm, 0]) ;
end
layoutFile = fopen(fullfile(outDir, [figureName, '_layout.json']), 'w', 'n', 'UTF-8') ;
fprintf(layoutFile, '%s', jsonencode(layout, 'PrettyPrint', true)) ;
fclose(layoutFile) ;
fprintf('%s: figure area %s column %g x %g mm; panels %g x %g mm\n', figureName, column, areaWidthMm, areaHeightMm, panelWidthMm, panelHeightMm) ;

close([figA, figB, figC]) ;


%% 関数

% 図の大きさと軸の枠の位置を、この図の値に変える（createPanelAxes の既定の 8 × 6 cm の代わり）。
% style の値も書き換える（exportPanel が JSON に書き、Affinity で図の大きさとして使うため）
function style = applyPanelLayout(fig, ax, style, panelSizeCm, innerPositionCm)
style.figureSizeCm = panelSizeCm ;
style.innerPositionCm = innerPositionCm ;
fig.Position = [2, 2, panelSizeCm] ;
ax.InnerPosition = innerPositionCm ;
end
