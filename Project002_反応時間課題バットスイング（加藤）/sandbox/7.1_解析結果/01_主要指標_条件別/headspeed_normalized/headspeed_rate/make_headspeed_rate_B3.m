% フリー条件で正規化したヘッドスピード（PeakVelTop）の変化率を、試行単位で反応課題の 3 条件（Simple・Go/No-go・Go/Stop）だけ
% 1 枚の図にする（figure-toolkit の流れに従う）
%
% 3 パネルの図（make_headspeed_rate.m）の B（試行単位、Free を含む 4 条件）から、Free を外したもの（2026-11-17、ユーザーの依頼）。
% Free の試行は自分たちの平均で割るので平均が定義から 0% になり、比べる相手ではなく基準として扱う、という方針による
% （../技術説明.md の 9.1 節）。読み手は専門家。
% 原案：../headspeed_normalized_stats.m の図（figure(1) の subplot(1, 3, 2)、166〜174 行）。データの読み込みと計算は原案と同じにし、
%   値は変えない。原案は 4 条件を描くので、ここでは Free を描かない。試行の点の横のずらし方は原案と同じ乱数（rng(0)）で、
%   Free の分の乱数も原案と同じ順に引いてから捨てる（3 条件の点の位置を原案と同じにするため）。横の位置も原案と同じ 2〜4。
% 注釈「All n.s.」は、3 条件の検定（一元配置分散分析 p = .085、Welch の t 検定 Holm 3 組 p_holm ≥ .152。技術説明の 9.1 節）による。
%   この 3 条件の検定は原案のコードにはなく、AI が scratchpad の Python で計算した値。
%
% 図：single column（90 mm）、1 パネル 90 × 65 mm（A の図 make_headspeed_rate_A.m と同じ大きさ）。
% 体裁で判断したこと：
%   - 試行の点は条件の色（figure-types の既定の 4 色のうち Simple・Go/No-go・Go/Stop の 3 色。ポスターと同じ割り当て）を白で淡くしたもの
%     （3 パネルの図の B と同じ）。平均 ± SD は黒の点と誤差棒で最前面
%   - 変化率は符号付きの量なので、棒は描かず、0（フリー）の線を破線で描く
%   - 1 枚の図なので、タイトルは付けず、試行数などは図の説明文に書く
%
% 手順（figure-toolkit のフォルダで実行する。figure-toolkit/AGENTS.md の 4 節。<ここ> はこのスクリプトのフォルダの絶対パス）：
%   1. matlab -batch "addpath('matlab') ; run('<ここ>/make_headspeed_rate_B3.m')"
%      → デスクトップの affinity_mcp_work/input/headspeed_rate_B3/ に、PNG・SVG・PDF・_components.pdf・JSON・_data.mat を書き出す
%   2. python tools/stack_component_pages.py headspeed_rate_B3
%   3. AFFINITY_COLLECT_DIR=<ここ>/output node tools/affinity-mcp.mjs run affinity/compose/compose_single_panels.js --set inputFolder=headspeed_rate_B3
%   4. 確認：node tools/affinity-mcp.mjs run affinity/compose/check_figure.js --set checkFigureTitles=headspeed_rate_B3
%
% 2026-11-17 加藤 和太郎（AI が figure-toolkit の手順で作成）

%% 準備
figureFolder = fileparts(mfilename('fullpath')) ; % このスクリプトのフォルダ
toolFolder = fileparts(figureFolder) ; % 原案（headspeed_normalized_stats.m）のフォルダ
projectFolder = fullfile(toolFolder, '..', '..', '..', '..') ; % Project002 のフォルダ
addpath(fullfile(projectFolder, '..', 'figure-toolkit', 'matlab')) ;

figureName = 'headspeed_rate_B3' ;
outDir = fullfile(toolkitPaths().input, figureName) ;
column = 'single' ; % 図全体の幅の種類（90 mm）
panelSizeCm = [9.0, 6.5] ; % MATLAB の図の大きさ [幅, 高さ] [cm]
innerPositionCm = [1.3, 0.8, 7.2, 5.4] ; % 軸の枠の左下の x・y と幅・高さ [cm]

%% データ（原案の「準備」「データ」「B」の段落と同じ読み込み・計算）
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
[~, iSubj] = ismember(T.Subject, SubjectArray) ;
T.Rate = (T.PeakVelTop./freeMean(iSubj) - 1)*100 ; % 試行単位の変化率

% 試行の点の横のずらし量（原案と同じ乱数。Free の分も引いてから捨てる）
rng(0) ;
jitter = cell(1, 4) ;
for ic = 1:4
    r = T.Rate(T.Condition == CondArray{ic}) ;
    jitter{ic} = 0.15*(rand(size(r)) - 0.5)*2 ;
end
ReactIndex = 2:4 ; % 描く条件（Simple・Go/No-go・Go/Stop）。横の位置も原案と同じ 2〜4


%% Panel：試行単位の変化率、3 条件（原案の図の subplot(1, 3, 2) から Free を除いたもの）

% データを描く（原案と同じ）：0 の線、試行の点、条件の平均 ± SD
[fig, ax, style] = createPanelAxes('bar-points') ;
style.figureSizeCm = panelSizeCm ;
style.innerPositionCm = innerPositionCm ;
fig.Position = [2, 2, panelSizeCm] ;
ax.InnerPosition = innerPositionCm ;
zeroLine = yline(ax, 0, '--') ;
markerHandles = gobjects(1, 3) ;
errorBarHandles = gobjects(1, 3) ;
for k = 1:3
    ic = ReactIndex(k) ;
    r = T.Rate(T.Condition == CondArray{ic}) ;
    markerHandles(k) = scatter(ax, ic + jitter{ic}, r) ;
    errorBarHandles(k) = errorbar(ax, ic, mean(r), std(r)) ;
end

% 体裁
conditionColours = style.colours ; % Free・Simple・Go/No-go・Go/Stop の順
set(zeroLine, 'Color', style.participantLineColour(:).'/255, 'LineWidth', style.lineWidth) ;
for k = 1:3
    ic = ReactIndex(k) ;
    set(markerHandles(k), 'SizeData', (style.markerSizePt*0.6)^2, 'Marker', 'o', ...
        'MarkerFaceColor', 0.5*conditionColours(ic, :) + 0.5, 'MarkerEdgeColor', 'none') ; % 条件の色を白で淡くする（透明度は PDF で扱いにくいため使わない）
    set(errorBarHandles(k), 'Color', 'k', 'LineStyle', 'none', 'LineWidth', style.lineWidth, 'Marker', 'o', ...
        'MarkerSize', style.markerSizePt + 1.5, 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'none', 'CapSize', 5) ;
end
yLim = [-15, 15] ;
if max(abs(T.Rate(ismember(T.Condition, CondArray(ReactIndex))))) > yLim(2)
    error('縦軸の範囲 [%g, %g] に収まりません', yLim) ;
end
xlim(ax, [1.5, 4.5]) ;
ylim(ax, yLim) ;
xticks(ax, ReactIndex) ;
xticklabels(ax, CondLabel(ReactIndex)) ;
ax.XTickLabelRotation = 0 ; % 目盛りの文字を水平にする（MATLAB が自動で斜めにしないように）
yticks(ax, -15:5:15) ;
ylabel(ax, 'Change from Free (%)') ;

% 注釈：3 条件の検定の結果（どれも有意でない）。検定の名前と値は図の説明文（../技術説明.md の 9.1 節）に書く
annotations = { ...
    struct('type', 'text', 'name', 'all ns', 'text', 'All n.s.', ...
        'position', [1.5, yLim(2)], 'anchor', 'left-top', 'offsetMm', [1, 0])} ; % 軸の左上から 1 mm 内側

% 書き出し
spec = struct() ;
spec.name = figureName ;
spec.panel = 'A' ;
spec.outDir = outDir ;
spec.style = style ;
spec.column = column ;
spec.components = [{'zero line', zeroLine} ; ...
    [strcat('markers', {' '}, CondArray(ReactIndex)'), num2cell(markerHandles(:))] ; ...
    {'mean sd', errorBarHandles ; 'axes', []}] ;
spec.legend = [] ;
spec.annotations = annotations ;
exportPanel(fig, ax, spec) ;
fprintf('%s: trials Simple %d, Go/No-go %d, Go/Stop %d\n', figureName, ...
    arrayfun(@(ic) sum(T.Condition == CondArray{ic}), ReactIndex)) ;
close(fig) ;
