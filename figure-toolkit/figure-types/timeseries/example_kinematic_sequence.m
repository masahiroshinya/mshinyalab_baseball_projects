% 投球の運動連鎖（キネマティック・シークエンス）の時系列：骨盤・体幹の回旋角速度と肘の伸展角速度（ダミーデータ）
%
% 12 名の平均 ± SD（帯）、イベント線（FC：踏み出し足の接地、MER：肩の最大外旋、BR：ボールリリース）、凡例。
% Affinity で加える注釈：投球の局面（FC〜MER：Arm cocking、MER〜BR：Acceleration）を示す両矢印と文字。
% 角速度は符号付きの量なので、縦軸は 0 を中心に正負対称にする（docs/figure-panel-style.md の 1 節）。
% 図の種類：timeseries（時系列。recipe.md）。
% 実行：matlab -batch "addpath('<figure-toolkit>/matlab') ; run('<figure-toolkit>/figure-types/timeseries/example_kinematic_sequence.m')"

outDir = fullfile(toolkitPaths().input, 'panels') ;

% ダミーデータ：各投手の角速度をガウス関数の山で作る
rng(1) ;
nPitchers = 12 ;
timeMs = -250:1:50 ; % ボールリリースからの時刻 [ms]
segmentNames = {'Pelvis', 'Trunk', 'Elbow'} ; % 骨盤の回旋、体幹の回旋、肘の伸展
meanPeakVelocity = [650, 1100, 2300] ; % 各部位の最大角速度の設定値 [deg/s]
meanPeakTimeMs = [-100, -60, -8] ; % 最大角速度の時刻の設定値 [ms]
peakWidthMs = [40, 28, 18] ; % 山の幅 [ms]
elbowFlexionVelocity = -400 ; % 肘の伸展の前に生じる屈曲方向の角速度の設定値 [deg/s]
nSegments = numel(segmentNames) ;
nSamples = numel(timeMs) ;
angularVelocity = zeros(nPitchers, nSamples, nSegments) ; % 投手 × 時刻 × 部位 [deg/s]
for iPitcher = 1:nPitchers
    pitcherShiftMs = 3*randn ; % 投手ごとの時刻のずれ [ms]
    for iSegment = 1:nSegments
        amplitude = meanPeakVelocity(iSegment)*(1 + 0.1*randn) ;
        peakTimeMs = meanPeakTimeMs(iSegment) + pitcherShiftMs + 2*randn ;
        velocity = amplitude*exp(-((timeMs - peakTimeMs)/peakWidthMs(iSegment)).^2) ;
        if iSegment == 3
            velocity = velocity + elbowFlexionVelocity*exp(-((timeMs - (peakTimeMs - 40))/20).^2) ;
        end
        angularVelocity(iPitcher, :, iSegment) = velocity ;
    end
end
meanVelocity = squeeze(mean(angularVelocity, 1)) ; % 時刻 × 部位
sdVelocity = squeeze(std(angularVelocity, 0, 1)) ;

% イベントの時刻：各投手の値の平均（BR は時刻の基準なので 0）
footContactMs = mean(-150 + 8*randn(nPitchers, 1)) ;
maxExternalRotationMs = mean(-30 + 3*randn(nPitchers, 1)) ;
ballReleaseMs = 0 ;

% 縦軸の範囲：全系列の平均 + SD の最大絶対値を収める L で [-L, L]
yLimit = 3000 ; % [deg/s]
maxAbsVelocity = max(abs([meanVelocity(:) + sdVelocity(:); meanVelocity(:) - sdVelocity(:)])) ;
if maxAbsVelocity > yLimit
    error('縦軸の範囲 %g に %g が収まりません', yLimit, maxAbsVelocity) ;
end

% 作図：帯（平均 ± SD）、平均の線、イベント線
[fig, ax, style] = createPanelAxes('timeseries') ;
segmentColours = style.colours(1:3, :) ;
bandHandles = gobjects(1, nSegments) ;
lineHandles = gobjects(1, nSegments) ;
for iSegment = 1:nSegments
    upper = meanVelocity(:, iSegment) + sdVelocity(:, iSegment) ;
    lower = meanVelocity(:, iSegment) - sdVelocity(:, iSegment) ;
    bandHandles(iSegment) = fill(ax, [timeMs, fliplr(timeMs)], [upper.', fliplr(lower.')], segmentColours(iSegment, :), ...
        'EdgeColor', 'none', 'FaceAlpha', style.bandOpacity) ;
end
for iSegment = 1:nSegments
    lineHandles(iSegment) = plot(ax, timeMs, meanVelocity(:, iSegment), 'Color', segmentColours(iSegment, :), 'LineWidth', style.lineWidth) ;
end
eventTimesMs = [footContactMs, maxExternalRotationMs, ballReleaseMs] ;
eventNames = {'FC', 'MER', 'BR'} ;
eventLabelSides = {'right', 'left', 'right'} ; % 名前を線の右と左のどちらに置くか（MER と BR の名前が重ならないように）
eventColour = style.eventLineColour(:).'/255 ;
eventHandles = gobjects(1, 3) ;
for iEvent = 1:3
    eventHandles(iEvent) = xline(ax, eventTimesMs(iEvent), '--', eventNames{iEvent}, 'Color', eventColour, 'LineWidth', style.lineWidth, ...
        'LabelVerticalAlignment', 'top', 'LabelHorizontalAlignment', eventLabelSides{iEvent}, 'LabelOrientation', 'horizontal', ...
        'FontName', style.fontName, 'FontSize', style.fontSize) ;
end

% 軸
xlim(ax, [-250, 50]) ;
ylim(ax, [-yLimit, yLimit]) ;
xticks(ax, -250:50:50) ;
yticks(ax, -yLimit:1500:yLimit) ;
xlabel(ax, 'Time from ball release (ms)') ;
ylabel(ax, 'Angular velocity (deg/s)') ;

% 凡例：データ線の表示を切り替えても凡例の見た目が変わらないよう、データのない代理の線で作る
proxyHandles = gobjects(1, nSegments) ;
for iSegment = 1:nSegments
    proxyHandles(iSegment) = plot(ax, NaN, NaN, 'Color', segmentColours(iSegment, :), 'LineWidth', style.lineWidth) ;
end
legendHandle = legend(ax, proxyHandles, segmentNames, 'Location', 'northwest', 'Box', 'off', ...
    'FontName', style.fontName, 'FontSize', style.fontSize) ;
legendHandle.ItemTokenSize = [15, 18] ;

% Affinity で加える注釈（位置はデータ座標）：局面を示す両矢印と文字。
% MER〜BR は約 6 mm で文字が入らないため、Acceleration の矢印は一段下げ、文字を矢印の左（MER の線の左）に置く
cockingArrowY = -1900 ; % Arm cocking の両矢印の高さ [deg/s]
accelerationArrowY = -2500 ; % Acceleration の両矢印の高さ [deg/s]
annotations = { ...
    struct('type', 'arrow', 'name', 'arm cocking arrow', 'from', [footContactMs, cockingArrowY], 'to', [maxExternalRotationMs, cockingArrowY], ...
        'heads', 'both', 'gapMm', 0), ...
    struct('type', 'text', 'name', 'arm cocking label', 'text', 'Arm cocking', 'position', [(footContactMs + maxExternalRotationMs)/2, cockingArrowY], ...
        'anchor', 'center-bottom', 'offsetMm', [0, 0.8]), ...
    struct('type', 'arrow', 'name', 'acceleration arrow', 'from', [maxExternalRotationMs, accelerationArrowY], 'to', [ballReleaseMs, accelerationArrowY], ...
        'heads', 'both', 'gapMm', 0), ...
    struct('type', 'text', 'name', 'acceleration label', 'text', 'Acceleration', 'position', [maxExternalRotationMs, accelerationArrowY], ...
        'anchor', 'right-middle', 'offsetMm', [-0.8, 0])} ;

% 書き出し：成分は背面から前面の順
spec = struct() ;
spec.name = 'kinematic_sequence' ;
spec.panel = 'A' ;
spec.outDir = outDir ;
spec.style = style ;
spec.components = { ...
    'events', eventHandles ; ...
    'bands pelvis', bandHandles(1) ; ...
    'bands trunk', bandHandles(2) ; ...
    'bands elbow', bandHandles(3) ; ...
    'lines pelvis', lineHandles(1) ; ...
    'lines trunk', lineHandles(2) ; ...
    'lines elbow', lineHandles(3) ; ...
    'axes', [] ; ...
    'legend', []} ;
spec.legend = legendHandle ;
spec.annotations = annotations ;
exportPanel(fig, ax, spec) ;
fprintf('events: FC %.1f ms, MER %.1f ms, BR %.1f ms; max |mean +- SD| = %.0f deg/s\n', eventTimesMs, maxAbsVelocity) ;
close(fig) ;
