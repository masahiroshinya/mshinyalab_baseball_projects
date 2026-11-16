% フリー条件で正規化したヘッドスピード（PeakVelTop）の変化率の図のうち、A（被験者単位の変化率、n = 10）だけを 1 枚の図にする
% （figure-toolkit の流れに従う）
%
% 3 パネルの図（make_headspeed_rate.m）から、A だけを先方に渡す図として独立させたもの（2026-11-16、ユーザーの依頼：
% 「A だけでいいので、A だけ綺麗に整えて出力。個人間で色が違ってもよい」）。読み手は専門家。
% 原案：../headspeed_normalized_stats.m の図（figure(1) の subplot(1, 3, 1)、160〜165 行）。データの読み込みと計算は原案と同じにし、
%   値は変えない。統計の値（注釈の文字）は、原案のコマンドウィンドウの出力（../技術説明.md の 3 節）を写す。
%
% 図：single column（90 mm）、1 パネル 90 × 65 mm。
% 体裁で判断したこと：
%   - 被験者ごとに線と点の色を変える（ユーザーの依頼）。色は Paul Tol の muted の 9 色と、Okabe-Ito の vermilion（10 色目）。
%     figure-toolkit の palettes/make_ase_palettes.py の値。平均 ± SD の黒と区別できるよう、黒と灰色は使わない
%   - 被験者の線は 0.75 pt、点は 3.5 pt にして、平均 ± SD（黒、線 1 pt、点 5.5 pt）より細く小さくする。平均 ± SD は最前面
%   - 凡例（被験者の番号 1〜10）は軸の枠の右の外に縦に並べる（線が軸の中で重なり、線の端に番号を置くと重なるため）
%   - 1 枚の図なので、3 パネルの図にあったタイトル（Participant means (n = 10)）は付けず、図の説明文に書く
%   - 変化率は符号付きの量なので、棒は描かず、平均 ± SD を点と誤差棒で描き、0（フリー）の線を破線で描く（3 パネルの図と同じ）
%
% 手順（figure-toolkit のフォルダで実行する。figure-toolkit/AGENTS.md の 4 節。<ここ> はこのスクリプトのフォルダの絶対パス）：
%   1. matlab -batch "addpath('matlab') ; run('<ここ>/make_headspeed_rate_A.m')"
%      → デスクトップの affinity_mcp_work/input/headspeed_rate_A/ に、PNG・SVG・PDF・_components.pdf・JSON・_data.mat を書き出す
%   2. python tools/stack_component_pages.py headspeed_rate_A
%   3. AFFINITY_COLLECT_DIR=<ここ>/output node tools/affinity-mcp.mjs run affinity/compose/compose_single_panels.js --set inputFolder=headspeed_rate_A
%   4. 確認：node tools/affinity-mcp.mjs run affinity/compose/check_figure.js --set checkFigureTitles=headspeed_rate_A
%
% 2026-11-16 加藤 和太郎（AI が figure-toolkit の手順で作成）

%% 準備
figureFolder = fileparts(mfilename('fullpath')) ; % このスクリプトのフォルダ
toolFolder = fileparts(figureFolder) ; % 原案（headspeed_normalized_stats.m）のフォルダ
projectFolder = fullfile(toolFolder, '..', '..', '..', '..') ; % Project002 のフォルダ
addpath(fullfile(projectFolder, '..', 'figure-toolkit', 'matlab')) ;

figureName = 'headspeed_rate_A' ;
outDir = fullfile(toolkitPaths().input, figureName) ;
column = 'single' ; % 図全体の幅の種類（90 mm）
panelSizeCm = [9.0, 6.5] ; % MATLAB の図の大きさ [幅, 高さ] [cm]
innerPositionCm = [1.3, 0.8, 5.6, 5.4] ; % 軸の枠の左下の x・y と幅・高さ [cm]（右に凡例の場所をあける）

% 被験者の色（RGB、0〜255）：Tol muted の 9 色（indigo, cyan, teal, green, olive, sand, rose, wine, purple）と Okabe-Ito の vermilion
participantColours = [ ...
    51, 34, 136 ; 136, 204, 238 ; 68, 170, 153 ; 17, 119, 51 ; 153, 153, 51 ; ...
    221, 204, 119 ; 204, 102, 119 ; 136, 34, 85 ; 170, 68, 153 ; 213, 94, 0]/255 ;

%% データ（原案の「準備」「データ」「A」の段落と同じ読み込み・計算）
dataFile = fullfile(projectFolder, 'Experiments', 'Main experiments', '03_Analysis', 'x8_StatTable', 'stat_table_trial.csv') ;
CondArray  = {'free', 'simple', 'gonogo', 'gostop'} ;
CondLabel  = {'Free', 'Simple', 'Go/No-go', 'Go/Stop'} ;

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
Rate = (V(:,2:4)./freeMean - 1)*100 ; % 被験者単位の変化率（行 = 被験者、列 = Simple・Go/No-go・Go/Stop）
if nS ~= size(participantColours, 1)
    error('被験者の数 %d と色の数 %d が合いません', nS, size(participantColours, 1)) ;
end


%% Panel A：被験者単位の変化率（原案の図の subplot(1, 3, 1)）

% データを描く（原案と同じ）：0 の線、被験者ごとの線（点は線の頂点に付ける）、条件の平均 ± SD
[fig, ax, style] = createPanelAxes('bar-points') ;
style.figureSizeCm = panelSizeCm ;
style.innerPositionCm = innerPositionCm ;
fig.Position = [2, 2, panelSizeCm] ;
ax.InnerPosition = innerPositionCm ;
zeroLine = yline(ax, 0, '--') ;
participantLineHandles = plot(ax, 1:3, Rate') ;
errorBarHandle = errorbar(ax, 1:3, mean(Rate), std(Rate)) ;

% 体裁
set(zeroLine, 'Color', style.participantLineColour(:).'/255, 'LineWidth', style.lineWidth) ;
for iS = 1:nS
    set(participantLineHandles(iS), 'Color', participantColours(iS,:), 'LineWidth', 0.75, ...
        'Marker', 'o', 'MarkerSize', 3.5, 'MarkerFaceColor', participantColours(iS,:), 'MarkerEdgeColor', 'none') ;
end
set(errorBarHandle, 'Color', 'k', 'LineStyle', 'none', 'LineWidth', style.lineWidth, 'Marker', 'o', ...
    'MarkerSize', style.markerSizePt + 1.5, 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'none', 'CapSize', 5) ;
yLim = [-6, 6] ;
if max(abs([Rate(:) ; mean(Rate)' + std(Rate)' ; mean(Rate)' - std(Rate)'])) > yLim(2)
    error('縦軸の範囲 [%g, %g] に収まりません', yLim) ;
end
xlim(ax, [0.6, 3.4]) ;
ylim(ax, yLim) ;
xticks(ax, 1:3) ;
xticklabels(ax, CondLabel(2:4)) ;
ax.XTickLabelRotation = 0 ; % 目盛りの文字を水平にする（MATLAB が自動で斜めにしないように）
yticks(ax, -6:2:6) ;
ylabel(ax, 'Change from Free (%)') ;

% 凡例：被験者の番号（軸の枠の右の外、上揃え）。
% 成分のページで線を非表示にしても凡例が薄くならないよう、データのない代理の線で作る（figure-types/timeseries の例と同じ）
proxyHandles = gobjects(1, nS) ;
for iS = 1:nS
    proxyHandles(iS) = plot(ax, NaN, NaN, 'Color', participantColours(iS,:), 'LineWidth', 0.75, ...
        'Marker', 'o', 'MarkerSize', 3.5, 'MarkerFaceColor', participantColours(iS,:), 'MarkerEdgeColor', 'none') ;
end
legendHandle = legend(ax, proxyHandles, arrayfun(@num2str, 1:nS, 'UniformOutput', false), ...
    'Box', 'off', 'FontSize', style.fontSize, 'Units', 'centimeters') ;
legendHandle.ItemTokenSize = [12, 18] ;
title(legendHandle, 'Participant', 'FontWeight', 'normal', 'FontSize', style.fontSize) ;
legendHandle.Position(1) = innerPositionCm(1) + innerPositionCm(3) + 0.2 ;
legendHandle.Position(2) = innerPositionCm(2) + innerPositionCm(4) - legendHandle.Position(4) ;

% 注釈：原案の A1（1 標本 t 検定、Holm）と A2（一元配置分散分析・対応のない t 検定）の結果。どれも有意でない
% 文字は短くし、検定の名前と値は図の説明文（../技術説明.md の 6 節）に書く
annotations = { ...
    struct('type', 'text', 'name', 'all ns', 'text', 'All n.s.', ...
        'position', [0.6, yLim(2)], 'anchor', 'left-top', 'offsetMm', [1, 0])} ; % 軸の左上から 1 mm 内側

% 書き出し
spec = struct() ;
spec.name = figureName ;
spec.panel = 'A' ;
spec.outDir = outDir ;
spec.style = style ;
spec.column = column ;
spec.components = {'zero line', zeroLine ; 'lines participants', participantLineHandles ; 'mean sd', errorBarHandle ; ...
    'axes', [] ; 'legend', []} ;
spec.legend = legendHandle ;
spec.annotations = annotations ;
exportPanel(fig, ax, spec) ;
close(fig) ;
