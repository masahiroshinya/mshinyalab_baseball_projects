% MT を HT（Hook Time）・LT（Loop Time）・AT（Accel Time）の 3 つに分けた時間を、条件ごとの積み上げ横棒にする（10 名の平均。figure-toolkit の流れに従う）
%
% 2026-11-04：3 つ → HT とそれ以外の 2 つ → ふたたび 3 つ（ユーザーの指定）。名前はポスターの説明図（hooktime_schematic_all_phases.svg）と同じ HT・LT・AT
%
% 元の図：s06_top_trajectory の パネル D（S06 の代表 1 試行）。これを全員の平均にし、ポスターのグラフと同じ配色にした（2026-11-04）。
% 図の種類：figure-types にない積み上げ横棒。体裁（文字・線・色）は bar-points の既定値（figure-types/bar-points/defaults.json）を使う。
%   棒 = 時間の、被験者平均の平均（n = 10）。左から HT・LT・AT
%   誤差棒 = MT の SD（被験者間）。ポスターの棒グラフと同じく棒の背面に置くので、棒の右端から右側だけが見える
%   棒の中の数 = HT・LT・AT の平均 [ms]。棒の右の数 = MT の平均 [ms]
% データ：Experiments/Main experiments/03_Analysis/x8_StatTable/StatTable.mat の SubjectTable
%   （x8_make_stat_table.m で、除外の後の Go 試行の値を被験者 × 条件ごとに平均したもの）。S01〜S10。
%   列：HookTime_ms・LoopTime_ms・AccelTime_ms・MT_ms。このスクリプトで行う計算は、条件ごとの被験者間の平均と SD だけ。
%   HT + LT + AT の平均と MT の平均の差は 1 ms 以内（局面はマーカー 250 Hz、MT は床反力 1000 Hz で求めるため）
%
% 体裁で判断したこと：
%   - 色：条件の色はポスターのグラフと同じ（Okabe-Ito の 4 色。Free 青・Simple 朱・Go/No-go 緑・Go/Stop 橙）。
%     HT・LT・AT は色の濃さで分ける：HT 75%、LT 40%（ポスターの棒と同じ）、AT 15%（残りは白）。凡例は同じ濃さの灰色
%   - 文字は英語（ポスターのほかのグラフと同じ）。横軸は 0〜900 ms、上から Free・Simple・Go/No-go・Go/Stop（元の図と同じ並び）
%   - 凡例は軸の上に 1 列で置く。そのため図の高さを 6.6 cm にした（幅は既定の 8 cm）
%
% 手順（figure-toolkit のフォルダで実行する。figure-toolkit/AGENTS.md の 4 節）：
%   1. matlab -batch "addpath('matlab') ; run('<このスクリプト>')"
%      → デスクトップの affinity_mcp_work/input/phase_time_stack/ に、PNG・SVG・PDF・_components.pdf・JSON・_data.mat を書き出す
%   2. python3 tools/stack_component_pages.py phase_time_stack
%   3. AFFINITY_COLLECT_DIR=<このフォルダ>/output node tools/affinity-mcp.mjs run affinity/compose/compose_single_panels.js --set inputFolder=phase_time_stack
%   4. 確認：node tools/affinity-mcp.mjs run affinity/compose/check_figure.js --set checkFigureTitles=phase_time_stack
%
% 2026-11-04

%% 準備
figureFolder = fileparts(mfilename('fullpath')) ; % このスクリプトのフォルダ
projectFolder = fullfile(figureFolder, '..', '..', '..', '..') ; % Project002 のフォルダ
addpath(fullfile(projectFolder, '..', 'figure-toolkit', 'matlab')) ;
outDir = fullfile(toolkitPaths().input, 'phase_time_stack') ;

%% データ（x8_StatTable の SubjectTable）
load(fullfile(projectFolder, 'Experiments', 'Main experiments', '03_Analysis', 'x8_StatTable', 'StatTable.mat'), 'SubjectTable')

ConditionNameArray = {'free', 'simple', 'gonogo', 'gostop'} ;
ConditionLabelArray = {'Free', 'Simple', 'Go/No-go', 'Go/Stop'} ;
PhaseLabel = {'HT', 'LT', 'AT'} ;
PhaseShare = [0.75, 0.40, 0.15] ; % 色の濃さ（条件の色の割合。残りは白）
PhaseCol = {'HookTime_ms', 'LoopTime_ms', 'AccelTime_ms'} ;

SubjectArray = unique(SubjectTable.Subject)' ;
nS = numel(SubjectArray) ;
nC = numel(ConditionNameArray) ;
nP = numel(PhaseCol) ;
phaseMean = nan(nC, nP) ;
mtMean = nan(nC, 1) ;
mtSd = nan(nC, 1) ;
for ic = 1:nC
    m = SubjectTable.Condition == ConditionNameArray{ic} ;
    if sum(m) ~= nS
        error('%s：被験者の数が %d ではありません', ConditionNameArray{ic}, nS) ;
    end
    for ip = 1:nP
        phaseMean(ic, ip) = mean(SubjectTable.(PhaseCol{ip})(m)) ;
    end
    mtMean(ic) = mean(SubjectTable.MT_ms(m)) ;
    mtSd(ic) = std(SubjectTable.MT_ms(m)) ;
end
if max(abs(sum(phaseMean, 2) - mtMean)) > 2
    error('HT + LT + AT の平均と MT の平均が 2 ms 以上違います') ;
end

%% データを描く：誤差棒（棒の背面）、積み上げ横棒（局面ごとに 1 つ）、凡例用の灰色の棒
yPos = nC:-1:1 ; % 上から Free・Simple・Go/No-go・Go/Stop
[fig, ax, style] = createPanelAxes('bar-points') ;
style.figureSizeCm = [8, 6.6] ;
style.innerPositionCm = [1.6, 1.1, 5.8, 4.3] ;
fig.Position = [2, 2, style.figureSizeCm] ;
ax.InnerPosition = style.innerPositionCm ;
errorBarHandle = errorbar(ax, mtMean, yPos, [], [], mtSd, mtSd) ;
% barh は棒を縦の位置の順（下から）に並べ替え、CData もその順に当てるので、データを位置の順（下から Go/Stop … Free）に並べて渡す
order = fliplr(1:nC) ; % yPos が 1, 2, … になる条件の順
barHandles = barh(ax, yPos(order), phaseMean(order, :), style.barWidth, 'stacked') ;
legendHandles = gobjects(1, nP) ;
for ip = 1:nP
    legendHandles(ip) = barh(ax, NaN, NaN) ; % 凡例の見本だけ（データはない）
end

%% 体裁（データの値は変えない）
conditionColours = style.colours(1:nC, :) ;
set(errorBarHandle, 'Color', 'k', 'LineStyle', 'none', 'LineWidth', style.lineWidth) ;
for ip = 1:nP
    set(barHandles(ip), 'FaceColor', 'flat', 'CData', PhaseShare(ip)*conditionColours(order, :) + (1 - PhaseShare(ip)), ...
        'EdgeColor', 'k', 'LineWidth', style.lineWidth, 'ShowBaseLine', 'off') ;
    set(legendHandles(ip), 'FaceColor', (1 - PhaseShare(ip))*[1, 1, 1], 'EdgeColor', 'k', 'LineWidth', style.lineWidth) ;
end
xlim(ax, [0, 900]) ;
ylim(ax, [0.4, nC + 0.6]) ;
xticks(ax, 0:300:900) ;
yticks(ax, 1:nC) ;
yticklabels(ax, flip(ConditionLabelArray)) ;
ax.YAxis.TickLength = [0, 0] ;
xlabel(ax, 'Time from onset (ms)') ;
legendHandle = legend(ax, legendHandles, PhaseLabel, 'Orientation', 'horizontal', 'Box', 'off', ...
    'FontName', style.fontName, 'FontSize', style.fontSize, 'AutoUpdate', 'off') ;
legendHandle.ItemTokenSize = [12, 8] ; % 見本の四角を短くして、凡例を図の幅に収める
legendHandle.Units = 'centimeters' ;
legendHandle.Position(1:2) = [style.innerPositionCm(1), style.innerPositionCm(2) + style.innerPositionCm(4) + 0.25] ;

%% 注釈：棒の中の数（HT・LT・AT）と、棒の右の MT の平均（Affinity で加える。位置はデータ座標）
annotations = {} ;
for ic = 1:nC
    left = 0 ;
    for ip = 1:nP
        annotations{end+1} = struct('type', 'text', 'name', sprintf('%s %s', ConditionNameArray{ic}, PhaseLabel{ip}), ...
            'text', sprintf('%.0f', phaseMean(ic, ip)), 'position', [left + phaseMean(ic, ip)/2, yPos(ic)], 'anchor', 'center-middle') ; %#ok<AGROW>
        left = left + phaseMean(ic, ip) ;
    end
    annotations{end+1} = struct('type', 'text', 'name', sprintf('%s MT', ConditionNameArray{ic}), ...
        'text', sprintf('%.0f', mtMean(ic)), 'position', [mtMean(ic) + mtSd(ic), yPos(ic)], 'offsetMm', [1.5, 0], 'anchor', 'left-middle') ; %#ok<AGROW>
end

%% 書き出し：成分は背面から前面の順（誤差棒は棒の背面）
dataComponents = [{'error bars', errorBarHandle} ; ...
    cellfun(@(c) sprintf('bars %s', c), {'HT', 'LT', 'AT'}', 'UniformOutput', false), num2cell(barHandles(:))] ;
spec = struct() ;
spec.name = 'phase_time_stack' ;
spec.panel = 'A' ;
spec.outDir = outDir ;
spec.style = style ;
spec.components = [dataComponents; {'axes', []}; {'legend', []}] ;
spec.legend = legendHandle ;
spec.annotations = annotations ;
spec.column = 'single' ;
exportPanel(fig, ax, spec) ;
for ic = 1:nC
    fprintf('%s：HT %.1f LT %.1f AT %.1f（計 %.1f）MT %.1f ± %.1f ms\n', ConditionLabelArray{ic}, phaseMean(ic, :), sum(phaseMean(ic, :)), mtMean(ic), mtSd(ic)) ;
end
close(fig) ;
