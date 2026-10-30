% 条件別_全被験者図（RT・MT・PeakVelTop・PeakFz）を、1 指標 1 枚の論文用の図にする（figure-toolkit の流れに従う）
%
% 元の図：Experiments/Main experiments/03_Analysis/x10_plot_by_condition.m の figure(1)〜(4)。
% データ：x8_StatTable/StatTable.mat の TrialTable（Go 試行、x8 で NaN にされた除外の値は落とす）。S01〜S10。
% 4 つの図は同じ作り方なので、指標ごとのループの中を次の段落に分ける（原案と見比べて確かめられるように。
% figure-toolkit/docs/figure-style.md の「原案の作図スクリプトから図を作る」の 3）。
%   データ         原案と同じ読み込み・計算（被験者 × 条件の値、条件の中央値と四分位）
%   データを描く   全試行の点、条件の四分位範囲と中央値。色・線幅などの体裁はここでは指定しない
%   体裁           色・線幅・点・軸範囲・目盛り・軸ラベル（figure-types の既定値。データの値は変えない）
%   注釈           Affinity で加える注釈（条件の中央値の数値。値と書式は原案のまま）
%   書き出し       exportPanel
%
% 原案との違い（体裁だけ。データの値は変えない）：
%   - 被験者ごとの表示（被験者の色、被験者ごとの中央値の折れ線、S01〜S10 のラベル、被験者ごとの横位置）は描かない
%     （2026-10-26、ユーザーの指定：見やすくするため）。全試行の点を灰色 1 色で、条件ごとに横へばらつかせて描く
%   - 縦軸：全試行が入る切りのよい範囲にした。原案は四分位範囲の 3 倍で範囲を切り、外の点（RT 3 点、MT 2 点）を境界に▲で置いていた。
%     論文用の図では、すべての点を実際の値の位置に描く（そのため「軸外 n 点」の注記はない）
%   - 文字は英語（タイトルの代わりに縦軸のラベル。条件名は Free・Simple・Go/No-go・Go/Stop）。
%     原案の上部の説明文（黒い横線 = 条件の中央値 …）は図に入れず、キャプションに書く
%   - 条件の中央値の数値（原案では軸の上の text）は、Affinity の注釈にする
%
% 図の大きさ：single column（90 mm）。各図 80 × 60 mm、軸の枠は共通の既定値（figure-types/defaults.json）
%
% 手順（figure-toolkit のフォルダで実行する。figure-toolkit/AGENTS.md の 4 節）：
%   1. matlab -batch "run('<このスクリプト>')"
%      → デスクトップの affinity_mcp_work/input/by_condition/ に、図ごとの PNG・SVG・PDF・_components.pdf・JSON・_data.mat を書き出す
%   2. python3 tools/stack_component_pages.py by_condition
%   3. AFFINITY_COLLECT_DIR=<このフォルダ>/output node tools/affinity-mcp.mjs run affinity/compose/compose_single_panels.js --set inputFolder=by_condition
%   4. 確認：図ごとに compareFigureData（x10_plot_by_condition.m の figure(n) と <図>_data.mat）、
%      node tools/affinity-mcp.mjs run affinity/compose/check_figure.js --set checkFigureTitles=RT_by_condition,MT_by_condition,PeakVelTop_by_condition,PeakFz_by_condition
%
% 2026-10-26

%% 準備
figureFolder = fileparts(mfilename('fullpath')) ; % このスクリプトのフォルダ
projectFolder = fullfile(figureFolder, '..', '..', '..', '..') ; % Project002 のフォルダ
addpath(fullfile(projectFolder, '..', 'figure-toolkit', 'matlab')) ;
outDir = fullfile(toolkitPaths().input, 'by_condition') ;

%% データ（原案の 21〜53 行）
load(fullfile(projectFolder, 'Experiments', 'Main experiments', '03_Analysis', 'x8_StatTable', 'StatTable.mat'), 'TrialTable')

ConditionNameArray = {'free', 'simple', 'gonogo', 'gostop'} ;
ConditionLabel = containers.Map(ConditionNameArray, {'Free', 'Simple', 'Go/No-go', 'Go/Stop'}) ; % 横軸の目盛りの文字

% 指標名（ファイル名の接頭語）・列名・縦軸のラベル・描く条件（原案の 27〜33 行。RT は free を描かない）
Metric = struct( ...
    'Tag',    {'RT', 'MT', 'PeakVelTop', 'PeakFz'}, ...
    'Col',    {'RTForce_ms', 'MT_ms', 'PeakVelTop', 'PeakFz2_BW'}, ...
    'YLabel', {'Reaction time (ms)', 'Movement time (ms)', 'Peak bat-tip speed (m/s)', 'Peak Fz, lead leg (BW)'}, ...
    'Conds',  {ConditionNameArray(2:end), ConditionNameArray, ConditionNameArray, ConditionNameArray}, ...
    'YLim',   {[100, 600], [400, 1100], [24, 36], [0.8, 1.8]}, ... % 全試行が入る切りのよい範囲
    'YTick',  {100:100:600, 400:100:1100, 24:2:36, 0.8:0.2:1.8}) ;

T = TrialTable(TrialTable.IsGo, :) ;
SubjectArray = unique(T.Subject)' ;
nS = numel(SubjectArray) ;

JitterW  = 0.50 ;   % 点の横のばらつきの幅（条件の間隔に対する割合）
shadeCol = [0.93 0.93 0.93] ;

for im = 1:numel(Metric)

    CondNames = Metric(im).Conds ;
    nC        = numel(CondNames) ;
    yLim      = Metric(im).YLim ;

    %% データ：被験者 × 条件 ごとの値（原案の 60〜70 行。NaN = 除外済み は落とす）
    V = cell(nS, nC) ;
    for iS = 1:nS
        for ic = 1:nC
            m = T.Subject == SubjectArray(iS) & T.Condition == CondNames{ic} ;
            v = T.(Metric(im).Col)(m) ;
            V{iS,ic} = v(~isnan(v)) ;
        end
    end
    allByCond = cell(1, nC) ;
    for ic = 1:nC, allByCond{ic} = vertcat(V{:,ic}) ; end
    allv = vertcat(allByCond{:}) ;
    if min(allv) < yLim(1) || max(allv) > yLim(2)
        error('%s：縦軸の範囲 [%g, %g] の外に点があります（%.3f〜%.3f）', Metric(im).Tag, yLim, min(allv), max(allv)) ;
    end

    % データ：条件の中央値と四分位（原案の 124〜127 行）
    condMed = nan(1, nC) ; condQ1 = nan(1, nC) ; condQ3 = nan(1, nC) ;
    for ic = 1:nC
        a = allByCond{ic} ;
        condMed(ic) = median(a) ; condQ1(ic) = quantile(a, 0.25) ; condQ3(ic) = quantile(a, 0.75) ;
    end

    % 点の横位置：条件の位置のまわりに一様にばらつかせる（表示の都合。rng(0) で再現できるようにする）
    rng(0)
    XJ = cell(1, nC) ;
    for ic = 1:nC
        XJ{ic} = ic + (rand(numel(allByCond{ic}), 1) - 0.5) * JitterW ;
    end

    %% データを描く（原案の 87・98〜99・128〜129 行。被験者ごとの折れ線とラベルは描かない）
    [fig, ax, style] = createPanelAxes() ;

    % free の網掛け（参考値）
    shadeHandle = gobjects(0, 1) ;
    if strcmp(CondNames{1}, 'free')
        shadeHandle = patch(ax, [0.5 1.5 1.5 0.5], [yLim(1) yLim(1) yLim(2) yLim(2)], shadeCol) ;
    end

    % 個々の試行（条件ごとに 1 つ）
    trialHandles = gobjects(nC, 1) ;
    for ic = 1:nC
        trialHandles(ic) = scatter(ax, XJ{ic}, allByCond{ic}, 'filled') ;
    end

    % 条件の四分位範囲（縦線）と中央値（黒の太い横線）
    iqrHandles = gobjects(nC, 1) ;
    medHandles = gobjects(nC, 1) ;
    for ic = 1:nC
        iqrHandles(ic) = plot(ax, [ic ic], [condQ1(ic) condQ3(ic)]) ;
        medHandles(ic) = plot(ax, ic + [-0.34 0.34], [condMed(ic) condMed(ic)]) ;
    end

    %% 体裁（データの値は変えない）
    if ~isempty(shadeHandle)
        set(shadeHandle, 'EdgeColor', 'none') ;
    end
    set(trialHandles, 'SizeData', style.markerSizePt^2, 'CData', [0.55 0.55 0.55], ...
        'MarkerFaceAlpha', 0.45, 'MarkerEdgeColor', 'none') ;
    set(iqrHandles, 'Color', 'k', 'LineWidth', 1.5*style.lineWidth) ;
    set(medHandles, 'Color', 'k', 'LineWidth', 2*style.lineWidth) ;

    xlim(ax, [0.5, nC+0.5]) ;
    ylim(ax, yLim) ;
    xticks(ax, 1:nC) ;
    xticklabels(ax, cellfun(@(c) ConditionLabel(c), CondNames, 'UniformOutput', false)) ;
    yticks(ax, Metric(im).YTick) ;
    ylabel(ax, Metric(im).YLabel) ;

    %% 注釈：条件の中央値の数値（原案の 130〜132 行。軸の上端の 1 mm 上に置く）
    annotations = cell(1, nC) ;
    for ic = 1:nC
        if abs(condMed(ic)) < 10, medFmt = '%.2f' ; else, medFmt = '%.1f' ; end
        annotations{ic} = struct('type', 'text', 'name', sprintf('median %s', CondNames{ic}), ...
            'text', sprintf(medFmt, condMed(ic)), 'position', [ic, yLim(2)], 'offsetMm', [0, 1], 'anchor', 'center-bottom') ;
    end

    %% 書き出し：成分は背面から前面の順
    dataComponents = { ...
        'markers trials', trialHandles ; ...
        'condition IQR', iqrHandles ; ...
        'condition median', medHandles} ;
    if ~isempty(shadeHandle)
        dataComponents = [{'shade free', shadeHandle}; dataComponents] ; %#ok<AGROW>
    end
    spec = struct() ;
    spec.name = sprintf('%s_by_condition', Metric(im).Tag) ;
    spec.panel = 'A' ;
    spec.outDir = outDir ;
    spec.style = style ;
    spec.components = [dataComponents; {'axes', []}] ;
    spec.legend = [] ;
    spec.annotations = annotations ;
    spec.column = 'single' ;
    exportPanel(fig, ax, spec) ;
    fprintf('%s median: %s\n', Metric(im).Tag, sprintf('%g  ', condMed)) ;
    close(fig) ;
end
