function exportPanel(fig, ax, spec)
% 単一パネルの図を書き出す：確認用の PNG・SVG・PDF、Affinity で重ねる成分ごとのページの PDF、その構成を記した JSON、
% 描いたデータの記録（<名前>_data.mat。原案の図との比較用：compareFigureData）
%
% 成分ごとのページ（docs/figure-panel-style.md の 5 節）：
%   1 ページ目        全体の図（比較用。同じ図の 1 回目の書き出しはページの高さが小さくなるため、成分は 2 ページ目以降に置く）
%   2 ページ目以降    spec.components の順（背面から前面の順に並べる）。Affinity ではこの順にサブレイヤーを作る。
%                     成分 'axes' は 3 ページに分ける：横軸（軸線・目盛り線と目盛りの文字）、縦軸（同）、軸ラベル（軸ラベルとタイトル）。
%                     Affinity では、軸線・目盛り線を axes lines、目盛りの文字を tick labels、軸ラベルを axis labels に入れる
%   最後のページ      位置合わせ用の点 2 つ（データ座標 → ページ上の位置の対応を Affinity で求めるため。サブレイヤーには入れない）
% JSON には、ページごとに入れるサブレイヤーの名前、ページ内の要素の振り分け方（select）、文字の揃え（align）を記す。
%   揃え：縦軸の目盛りは右、横軸の目盛り・軸ラベル・タイトルは中央、凡例は左。空のときは Affinity 側で決める（イベント線の名前は線の側、その他は中央）
% 入力：
%   fig, ax   図と軸（createPanelAxes で作成し、xlim・ylim を明示したもの）
%   spec      .name         ファイル名の基になる名前（例：'kinematic_sequence'）
%             .panel        パネル記号（サブレイヤー名の接頭辞。例：'A'）
%             .outDir       出力先（デスクトップの affinity_mcp_work/input/ の下）
%             .style        createPanelAxes が返す既定値（figure-types の defaults.json）
%             .components   {成分名, ハンドル} の N×2 の cell（背面から前面の順）。成分名 'axes' は軸（上の 3 ページに分ける）、
%                           'legend' は凡例。それ以外は、そのハンドルだけを表示したページになる
%             .legend       凡例のハンドル（なければ []）
%             .annotations  Affinity で加える注釈の指定（struct の cell。位置はデータ座標）
%             .column       図全体の幅の種類（'single' または 'double'。省略時は 'single'）。Affinity で、この段の幅と
%                           図の高さの矩形を最背面に置き、ページの大きさをそれに合わせる

% 軸範囲が自動のままだと、位置合わせ用の点を描いたときに範囲が変わるので、明示を求める
if ~strcmp(ax.XLimMode, 'manual') || ~strcmp(ax.YLimMode, 'manual')
    error('exportPanel: xlim と ylim を明示してください（docs/figure-panel-style.md の 1 節）') ;
end
if ~exist(spec.outDir, 'dir')
    mkdir(spec.outDir) ;
end

% 縦軸の目盛りは Affinity で右揃えにするので、小数点以下の桁数を揃える
uniformTickDecimals(ax.YAxis) ;
basePath = fullfile(spec.outDir, spec.name) ;

% 描いたデータの記録（原案の図との比較用：compareFigureData）。位置合わせ用の点を描く前に記録する
snapshot = figureDataSnapshot(ax) ; %#ok<NASGU>
save([basePath, '_data.mat'], 'snapshot') ;
componentsPath = [basePath, '_components.pdf'] ;
if exist(componentsPath, 'file')
    delete(componentsPath) ;
end

% 凡例：後から描く位置合わせ用の点が凡例に加わらないようにする
legendHandle = spec.legend ;
hasLegend = ~isempty(legendHandle) ;
if hasLegend
    legendHandle.AutoUpdate = 'off' ;
end

% 表示を切り替えるデータのハンドル（軸と凡例以外の成分）
componentNames = spec.components(:, 1) ;
nComponents = numel(componentNames) ;
dataHandles = gobjects(0, 1) ;
for iComponent = 1:nComponents
    handles = spec.components{iComponent, 2} ;
    dataHandles = [dataHandles; handles(:)] ; %#ok<AGROW>
end

% 書き出しの設定：背景の矩形を出さず、ページを図の大きさに固定する（docs/figure-panel-style.md の 3 節）
vectorOptions = {'ContentType', 'vector', 'BackgroundColor', 'none', 'Padding', 'figure'} ;

% 1 ページ目：全体の図（比較用）
setPageVisibility(ax, legendHandle, dataHandles, dataHandles, 'all', 'on') ;
exportgraphics(fig, componentsPath, vectorOptions{:}, 'Append', true) ;
fprintf('%s page 1: full\n', spec.name) ;

% 2 ページ目以降：成分ごと。ページの定義は {ページ名, 表示するデータ, 軸の表示, 凡例の表示, サブレイヤーの指定}
%   軸の表示：'off' なし、'x' 横軸だけ、'y' 縦軸だけ、'labels' 軸ラベルとタイトルだけ
%   select：'all' はページ内のすべて、'text' は文字だけ、'nontext' は文字以外
pageDefinitions = cell(0, 5) ;
for iComponent = 1:nComponents
    componentName = componentNames{iComponent} ;
    if strcmp(componentName, 'axes')
        pageDefinitions(end + 1, :) = {'x axis', [], 'x', 'off', ...
            {layerSpec(spec.panel, 'axes lines', 'nontext', ''), layerSpec(spec.panel, 'tick labels', 'text', 'center')}} ; %#ok<AGROW>
        pageDefinitions(end + 1, :) = {'y axis', [], 'y', 'off', ...
            {layerSpec(spec.panel, 'axes lines', 'nontext', ''), layerSpec(spec.panel, 'tick labels', 'text', 'right')}} ; %#ok<AGROW>
        pageDefinitions(end + 1, :) = {'axis labels', [], 'labels', 'off', ...
            {layerSpec(spec.panel, 'axis labels', 'all', 'center')}} ; %#ok<AGROW>
    elseif strcmp(componentName, 'legend')
        pageDefinitions(end + 1, :) = {'legend', [], 'off', 'on', {layerSpec(spec.panel, 'legend', 'all', 'left')}} ; %#ok<AGROW>
    else
        pageDefinitions(end + 1, :) = {componentName, spec.components{iComponent, 2}, 'off', 'off', ...
            {layerSpec(spec.panel, componentName, 'all', '')}} ; %#ok<AGROW>
    end
end
nPages = size(pageDefinitions, 1) ;
pages = cell(1, nPages) ;
for iPage = 1:nPages
    [pageName, visibleHandles, axesMode, legendVisible, layers] = pageDefinitions{iPage, :} ;
    pageNumber = iPage + 1 ;
    setPageVisibility(ax, legendHandle, dataHandles, visibleHandles, axesMode, legendVisible) ;
    exportgraphics(fig, componentsPath, vectorOptions{:}, 'Append', true) ;
    pages{iPage} = struct('page', pageNumber, 'component', pageName, 'layers', {layers}) ;
    fprintf('%s page %d: %s\n', spec.name, pageNumber, pageName) ;
end

% 最後のページ：位置合わせ用の点（軸範囲の 25 % と 75 % の位置）。点の外枠の中心がデータ座標の位置になる
xLimits = xlim(ax) ;
yLimits = ylim(ax) ;
calibrationX = xLimits(1) + [0.25, 0.75]*(xLimits(2) - xLimits(1)) ;
calibrationY = yLimits(1) + [0.25, 0.75]*(yLimits(2) - yLimits(1)) ;
setPageVisibility(ax, legendHandle, dataHandles, [], 'off', 'off') ;
calibrationHandle = plot(ax, calibrationX, calibrationY, 'LineStyle', 'none', 'Marker', 'o', 'MarkerSize', 3, ...
    'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'none') ;
exportgraphics(fig, componentsPath, vectorOptions{:}, 'Append', true) ;
calibrationPage = nPages + 2 ;
fprintf('%s page %d: calibration points\n', spec.name, calibrationPage) ;
delete(calibrationHandle) ;

% 全体の図：PDF（文字を保持したベクター）、SVG、PNG（docs/figure-panel-style.md の 3 節）
setPageVisibility(ax, legendHandle, dataHandles, dataHandles, 'all', 'on') ;
exportgraphics(fig, [basePath, '.pdf'], vectorOptions{:}) ;
try
    exportgraphics(fig, [basePath, '.svg'], 'ContentType', 'vector') ;
catch
    % exportgraphics が SVG に対応しない版では print で出力する
    print(fig, [basePath, '.svg'], '-dsvg', '-vector') ;
end
exportgraphics(fig, [basePath, '.png'], 'Resolution', spec.style.pngResolution, 'Padding', 'figure') ;

% 図全体の領域：幅は段の幅、高さは図の高さ。パネルが段の幅に収まることを確かめる
if isfield(spec, 'column')
    column = spec.column ;
else
    column = 'single' ;
end
areaWidthMm = spec.style.columnWidthMm.(column) ;
areaHeightMm = spec.style.figureSizeCm(2)*10 ;
panelWidthMm = spec.style.figureSizeCm(1)*10 ;
if panelWidthMm > areaWidthMm
    error('exportPanel: パネルの幅 %.1f mm が %s column の幅 %.1f mm を超えています', panelWidthMm, column, areaWidthMm) ;
end

% 構成の JSON（Affinity のスクリプトが読む）
panelInfo.name = spec.name ;
panelInfo.panel = spec.panel ;
panelInfo.componentsPdf = [spec.name, '_components.pdf'] ;
panelInfo.figureSizeCm = spec.style.figureSizeCm ;
panelInfo.figureArea = struct('column', column, 'widthMm', areaWidthMm, 'heightMm', areaHeightMm) ;
panelInfo.innerPositionCm = spec.style.innerPositionCm ;
panelInfo.xlim = xLimits ;
panelInfo.ylim = yLimits ;
% 目盛りの値と文字（Affinity で、取り込み時に 1 つにまとまった目盛りの文字を分けるために使う）
panelInfo.ticks.x = struct('values', {num2cell(ax.XTick)}, 'labels', {cellstr(ax.XTickLabel).'}) ;
panelInfo.ticks.y = struct('values', {num2cell(ax.YTick)}, 'labels', {cellstr(ax.YTickLabel).'}) ;
panelInfo.figureType = spec.style.figureType ;
panelInfo.fontSizePt = spec.style.fontSizePt ; % パネル記号・軸ラベル・目盛りの文字の大きさ [pt]（パネル記号は Affinity で付ける）
panelInfo.lineWidthPt = spec.style.lineWidth ;
panelInfo.pages = pages ;
panelInfo.calibration = struct('page', calibrationPage, 'points', [calibrationX(:), calibrationY(:)]) ;
panelInfo.annotations = spec.annotations ;
jsonFile = fopen([basePath, '.json'], 'w', 'n', 'UTF-8') ;
fprintf(jsonFile, '%s', jsonencode(panelInfo, 'PrettyPrint', true)) ;
fclose(jsonFile) ;
fprintf('%s: wrote %s, %s(.pdf/.svg/.png/.json)\n', spec.name, componentsPath, basePath) ;
end


% ページに表示するものを切り替える（visibleHandles 以外のデータは非表示）
%   axesMode：'all' 軸のすべて、'off' なし、'x' 横軸の軸線・目盛り線・目盛りの文字だけ、'y' 縦軸の同じもの、'labels' 軸ラベルとタイトルだけ
%   横軸・縦軸（XAxis・YAxis）の Visible を一度明示すると ax.Visible = 'off' でも表示されるため、毎回すべてを明示する（2026-10-18 確認）
function setPageVisibility(ax, legendHandle, dataHandles, visibleHandles, axesMode, legendVisible)
set(dataHandles, 'Visible', 'off') ;
if ~isempty(visibleHandles)
    set(visibleHandles, 'Visible', 'on') ;
end
axesVisible = onOff(any(strcmp(axesMode, {'all', 'x', 'y'}))) ;
xAxisVisible = onOff(any(strcmp(axesMode, {'all', 'x'}))) ;
yAxisVisible = onOff(any(strcmp(axesMode, {'all', 'y'}))) ;
labelsVisible = onOff(any(strcmp(axesMode, {'all', 'labels'}))) ;
ax.Visible = axesVisible ;
ax.XAxis.Visible = xAxisVisible ;
ax.YAxis.Visible = yAxisVisible ;
ax.XLabel.Visible = labelsVisible ; % 軸を非表示にしても、軸ラベルの位置は全体の図と同じ
ax.YLabel.Visible = labelsVisible ;
ax.Title.Visible = labelsVisible ;
if ~isempty(legendHandle)
    legendHandle.Visible = legendVisible ;
end
end


% 論理値を 'on'・'off' にする
function value = onOff(flag)
if flag
    value = 'on' ;
else
    value = 'off' ;
end
end


% サブレイヤーの名前（「パネル記号: 成分」）、ページ内の要素の振り分け方、文字の揃え（'left'・'center'・'right'、空は Affinity 側で決める）
function layer = layerSpec(panel, componentName, select, align)
layer = struct('name', sprintf('%s: %s', panel, componentName), 'select', select, 'align', align) ;
end
