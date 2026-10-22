% 体幹の最大回旋角速度と球速の関係：散布図、回帰直線と 95 % 信頼帯（ダミーデータ）
%
% 高校生と大学生の投手（各 15 名）を点の色・形で区別し、凡例を付ける。回帰直線は全員（30 名）で求める。
% Affinity で加える注釈：相関係数と p 値の文字。
% 両軸とも非負の量なので、データに合わせた切りのよい範囲にする（docs/figure-panel-style.md の 1 節）。
% 図の種類：scatter（散布図。recipe.md）。
% 実行：matlab -batch "addpath('<figure-toolkit>/matlab') ; run('<figure-toolkit>/figure-types/scatter/example_ball_speed_scatter.m')"

outDir = fullfile(toolkitPaths().input, 'panels') ;

% ダミーデータ：群ごとの体幹の最大回旋角速度 [deg/s] と球速 [m/s]
rng(3) ;
groupNames = {'High school', 'Collegiate'} ;
nPerGroup = 15 ;
groupMeanTrunkVelocity = [1000, 1150] ; % 群ごとの体幹の最大回旋角速度の設定値 [deg/s]
groupSpeedOffset = [33, 34.5] ; % 体幹の角速度 1000 deg/s のときの球速の設定値 [m/s]
speedPerVelocity = 0.02 ; % 体幹の角速度に対する球速の傾きの設定値 [(m/s)/(deg/s)]
nGroups = numel(groupNames) ;
trunkVelocity = cell(1, nGroups) ;
ballSpeed = cell(1, nGroups) ;
for iGroup = 1:nGroups
    trunkVelocity{iGroup} = groupMeanTrunkVelocity(iGroup) + 80*randn(nPerGroup, 1) ;
    ballSpeed{iGroup} = groupSpeedOffset(iGroup) + speedPerVelocity*(trunkVelocity{iGroup} - 1000) + 2.0*randn(nPerGroup, 1) ;
end
allVelocity = vertcat(trunkVelocity{:}) ;
allSpeed = vertcat(ballSpeed{:}) ;
nPitchers = numel(allVelocity) ;

% 回帰直線と、平均の予測値の 95 % 信頼帯
degreesOfFreedom = nPitchers - 2 ;
fitCoefficients = polyfit(allVelocity, allSpeed, 1) ; % [傾き, 切片]
residualSd = sqrt(sum((allSpeed - polyval(fitCoefficients, allVelocity)).^2)/degreesOfFreedom) ; % 残差の標準偏差 [m/s]
meanVelocity = mean(allVelocity) ;
velocitySumSquares = sum((allVelocity - meanVelocity).^2) ;
tCritical = tQuantileTwoTailed(0.05, degreesOfFreedom) ;
fitVelocity = linspace(min(allVelocity), max(allVelocity), 100) ; % 回帰直線はデータの範囲だけに描く
fitSpeed = polyval(fitCoefficients, fitVelocity) ;
confidenceHalfWidth = tCritical*residualSd*sqrt(1/nPitchers + (fitVelocity - meanVelocity).^2/velocitySumSquares) ;

% 相関係数と p 値
correlationMatrix = corrcoef(allVelocity, allSpeed) ;
r = correlationMatrix(1, 2) ;
tValue = r*sqrt(degreesOfFreedom/(1 - r^2)) ;
p = betainc(degreesOfFreedom/(degreesOfFreedom + tValue^2), degreesOfFreedom/2, 0.5) ;
if p < 0.001
    statisticsText = sprintf('r = %.2f, P < 0.001', r) ;
else
    statisticsText = sprintf('r = %.2f, P = %.3f', r, p) ;
end

% 軸の範囲：データが収まることを確認する
xLimits = [900, 1300] ; % [deg/s]
yLimits = [25, 45] ; % [m/s]
if min(allVelocity) < xLimits(1) || max(allVelocity) > xLimits(2) || min(allSpeed) < yLimits(1) || max(allSpeed) > yLimits(2)
    error('データが軸の範囲に収まりません：x %.0f〜%.0f、y %.1f〜%.1f', min(allVelocity), max(allVelocity), min(allSpeed), max(allSpeed)) ;
end

% 作図：信頼帯、回帰直線、群ごとの点
[fig, ax, style] = createPanelAxes('scatter') ;
groupColours = style.colours([1, 2], :) ;
groupMarkers = {'o', 's'} ;
bandHandle = fill(ax, [fitVelocity, fliplr(fitVelocity)], [fitSpeed + confidenceHalfWidth, fliplr(fitSpeed - confidenceHalfWidth)], ...
    style.confidenceBandColour(:).'/255, 'EdgeColor', 'none') ;
fitLineHandle = plot(ax, fitVelocity, fitSpeed, 'k', 'LineWidth', style.lineWidth) ;
markerHandles = gobjects(1, nGroups) ;
for iGroup = 1:nGroups
    markerHandles(iGroup) = plot(ax, trunkVelocity{iGroup}, ballSpeed{iGroup}, 'LineStyle', 'none', 'Marker', groupMarkers{iGroup}, ...
        'MarkerSize', style.markerSizePt, 'MarkerFaceColor', groupColours(iGroup, :), 'MarkerEdgeColor', 'none') ;
end

% 軸
xlim(ax, xLimits) ;
ylim(ax, yLimits) ;
xticks(ax, xLimits(1):100:xLimits(2)) ;
yticks(ax, yLimits(1):5:yLimits(2)) ;
xlabel(ax, 'Peak trunk rotation velocity (deg/s)') ;
ylabel(ax, 'Ball speed (m/s)') ;

% 凡例：点の表示を切り替えても凡例の見た目が変わらないよう、データのない代理の点で作る
proxyHandles = gobjects(1, nGroups) ;
for iGroup = 1:nGroups
    proxyHandles(iGroup) = plot(ax, NaN, NaN, 'LineStyle', 'none', 'Marker', groupMarkers{iGroup}, 'MarkerSize', style.markerSizePt, ...
        'MarkerFaceColor', groupColours(iGroup, :), 'MarkerEdgeColor', 'none') ;
end
legendHandle = legend(ax, proxyHandles, groupNames, 'Location', 'southeast', 'Box', 'off', ...
    'FontName', style.fontName, 'FontSize', style.fontSize) ;
legendHandle.ItemTokenSize = [10, 18] ;

% Affinity で加える注釈（位置はデータ座標）：相関係数と p 値を左上に置く
annotations = { ...
    struct('type', 'text', 'name', 'correlation', 'text', statisticsText, 'position', [xLimits(1), yLimits(2)], ...
        'anchor', 'left-top', 'offsetMm', [2, -1])} ;

% 書き出し：成分は背面から前面の順
spec = struct() ;
spec.name = 'ball_speed_scatter' ;
spec.panel = 'A' ;
spec.outDir = outDir ;
spec.style = style ;
spec.components = { ...
    'confidence band', bandHandle ; ...
    'fit line', fitLineHandle ; ...
    'markers high school', markerHandles(1) ; ...
    'markers collegiate', markerHandles(2) ; ...
    'axes', [] ; ...
    'legend', []} ;
spec.legend = legendHandle ;
spec.annotations = annotations ;
exportPanel(fig, ax, spec) ;
fprintf('%s (n = %d); slope %.4f (m/s)/(deg/s); x %.0f-%.0f, y %.1f-%.1f\n', statisticsText, nPitchers, fitCoefficients(1), ...
    min(allVelocity), max(allVelocity), min(allSpeed), max(allSpeed)) ;
close(fig) ;


%% 関数

% 両側の有意水準 alpha に対応する t 分布の分位点（Statistics Toolbox の tinv を使わず、不完全ベータ関数の逆関数で計算する）
%   両側の p 値は p = betainc(df/(df + t^2), df/2, 0.5) なので、これを t について解く
function tValue = tQuantileTwoTailed(alpha, degreesOfFreedom)
betaValue = betaincinv(alpha, degreesOfFreedom/2, 0.5) ;
tValue = sqrt(degreesOfFreedom*(1/betaValue - 1)) ;
end
