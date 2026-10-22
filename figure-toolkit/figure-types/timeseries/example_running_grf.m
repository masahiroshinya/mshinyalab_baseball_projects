% 走行の立脚期の鉛直地面反力：後足部接地（RFS）と前足部接地（FFS）の比較（ダミーデータ）
%
% 群ごと（各 12 名）の平均 ± SD（帯）と凡例。横軸は立脚期を 0〜100 % に正規化した時間。
% Affinity で加える注釈：RFS の衝撃ピーク（Impact peak）と能動ピーク（Active peak）を指す矢印と文字。
% 鉛直地面反力は非負の量なので、縦軸は 0 から切りのよい値までとする（docs/figure-panel-style.md の 1 節）。
% 図の種類：timeseries（時系列。recipe.md）。
% 実行：matlab -batch "addpath('<figure-toolkit>/matlab') ; run('<figure-toolkit>/figure-types/timeseries/example_running_grf.m')"

outDir = fullfile(toolkitPaths().input, 'panels') ;

% ダミーデータ：能動ピークの山（ピークが立脚期の約 46 % になるよう時間軸をゆがめた正弦）と、RFS だけにある衝撃の山
rng(4) ;
nRunners = 12 ;
stancePercent = 0:1:100 ; % 立脚期に対する割合 [%]
groupNames = {'Rearfoot strike', 'Forefoot strike'} ;
activePeakForce = [2.5, 2.6] ; % 能動ピークの設定値 [BW]
impactPeakForce = [0.8, 0] ; % 衝撃の山の高さの設定値 [BW]（FFS は 0）
impactTimePercent = 10 ; % 衝撃の山の時刻の設定値 [%]
nGroups = numel(groupNames) ;
nSamples = numel(stancePercent) ;
verticalForce = zeros(nRunners, nSamples, nGroups) ; % 走者 × 時刻 × 群 [BW]
for iGroup = 1:nGroups
    for iRunner = 1:nRunners
        warpedTime = (stancePercent/100).^(0.9 + 0.03*randn) ; % 能動ピークの時刻を走者ごとにずらす
        activeForce = activePeakForce(iGroup)*(1 + 0.06*randn)*sin(pi*warpedTime) ;
        impactForce = impactPeakForce(iGroup)*(1 + 0.15*randn)*exp(-((stancePercent - (impactTimePercent + randn))/3.5).^2) ;
        verticalForce(iRunner, :, iGroup) = activeForce + impactForce ;
    end
end
meanForce = squeeze(mean(verticalForce, 1)) ; % 時刻 × 群
sdForce = squeeze(std(verticalForce, 0, 1)) ;

% 注釈が指す点：RFS の平均の衝撃ピーク（5〜20 % の極大）と能動ピーク（最大値）
rearfootMean = meanForce(:, 1) ;
impactWindow = find(stancePercent >= 5 & stancePercent <= 20) ;
[impactPeakValue, impactIndex] = max(rearfootMean(impactWindow)) ;
impactPeakTime = stancePercent(impactWindow(impactIndex)) ;
[activePeakValue, activeIndex] = max(rearfootMean) ;
activePeakTime = stancePercent(activeIndex) ;

% 縦軸の範囲：平均 + SD の最大値を収める
yLimit = 3 ; % [BW]
maxForce = max(meanForce(:) + sdForce(:)) ;
if maxForce > yLimit
    error('縦軸の範囲 %g BW に %.2f BW が収まりません', yLimit, maxForce) ;
end

% 作図：帯（平均 ± SD）と平均の線
[fig, ax, style] = createPanelAxes('timeseries') ;
groupColours = style.colours([1, 2], :) ;
bandHandles = gobjects(1, nGroups) ;
lineHandles = gobjects(1, nGroups) ;
for iGroup = 1:nGroups
    upper = meanForce(:, iGroup) + sdForce(:, iGroup) ;
    lower = meanForce(:, iGroup) - sdForce(:, iGroup) ;
    bandHandles(iGroup) = fill(ax, [stancePercent, fliplr(stancePercent)], [upper.', fliplr(lower.')], groupColours(iGroup, :), ...
        'EdgeColor', 'none', 'FaceAlpha', style.bandOpacity) ;
end
for iGroup = 1:nGroups
    lineHandles(iGroup) = plot(ax, stancePercent, meanForce(:, iGroup), 'Color', groupColours(iGroup, :), 'LineWidth', style.lineWidth) ;
end

% 軸
xlim(ax, [0, 100]) ;
ylim(ax, [0, yLimit]) ;
xticks(ax, 0:25:100) ;
yticks(ax, 0:1:yLimit) ;
xlabel(ax, 'Stance (%)') ;
ylabel(ax, 'Vertical GRF (BW)') ;

% 凡例：データ線の表示を切り替えても凡例の見た目が変わらないよう、データのない代理の線で作る
proxyHandles = gobjects(1, nGroups) ;
for iGroup = 1:nGroups
    proxyHandles(iGroup) = plot(ax, NaN, NaN, 'Color', groupColours(iGroup, :), 'LineWidth', style.lineWidth) ;
end
legendHandle = legend(ax, proxyHandles, groupNames, 'Location', 'south', 'Box', 'off', ...
    'FontName', style.fontName, 'FontSize', style.fontSize) ;
legendHandle.ItemTokenSize = [15, 18] ;

% Affinity で加える注釈（位置はデータ座標）：ピークを指す矢印と文字。矢印の先はピークから gapMm だけ離す。
% RFS の能動ピークは FFS の線より下にあるので、FFS の線と交差しないよう下（山の内側）から指す
impactLabelPosition = [impactPeakTime + 2, 2.5] ; % 衝撃ピークの文字の位置（下端の中央）[%, BW]
activeLabelPosition = [activePeakTime + 10, 1.5] ; % 能動ピークの文字の位置（上端の中央）[%, BW]
annotations = { ...
    struct('type', 'arrow', 'name', 'impact peak arrow', 'from', impactLabelPosition, 'to', [impactPeakTime, impactPeakValue], ...
        'heads', 'end', 'gapMm', 0.8), ...
    struct('type', 'text', 'name', 'impact peak label', 'text', 'Impact peak', 'position', impactLabelPosition, ...
        'anchor', 'center-bottom', 'offsetMm', [0, 0.5]), ...
    struct('type', 'arrow', 'name', 'active peak arrow', 'from', activeLabelPosition, 'to', [activePeakTime, activePeakValue], ...
        'heads', 'end', 'gapMm', 0.8), ...
    struct('type', 'text', 'name', 'active peak label', 'text', 'Active peak', 'position', activeLabelPosition, ...
        'anchor', 'center-top', 'offsetMm', [0, -0.5])} ;

% 書き出し：成分は背面から前面の順
spec = struct() ;
spec.name = 'running_grf' ;
spec.panel = 'A' ;
spec.outDir = outDir ;
spec.style = style ;
spec.components = { ...
    'bands rearfoot', bandHandles(1) ; ...
    'bands forefoot', bandHandles(2) ; ...
    'lines rearfoot', lineHandles(1) ; ...
    'lines forefoot', lineHandles(2) ; ...
    'axes', [] ; ...
    'legend', []} ;
spec.legend = legendHandle ;
spec.annotations = annotations ;
exportPanel(fig, ax, spec) ;
fprintf('RFS impact peak %.2f BW at %d %%, active peak %.2f BW at %d %%; max mean + SD %.2f BW\n', ...
    impactPeakValue, impactPeakTime, activePeakValue, activePeakTime, maxForce) ;
close(fig) ;
