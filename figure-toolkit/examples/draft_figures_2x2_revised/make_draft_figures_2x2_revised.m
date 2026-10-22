% draft_figures.m の figure(1)〜(4) を、2 × 2 のパネル（A〜D）に並べた論文用の図にする（figure-toolkit の流れに従う）
% （2026-10-19：チャットでの修正依頼の試験用に、examples/draft_figures_2x2/ から名前を変えて写したもの。その後の修正は下の「個別の注文」）
%
% 元の図：examples/draft_figures.m（体裁は MATLAB の既定のまま）。データと統計解析の結果は create_demo_data から受け取り、値は変えない。
% 各パネルの段落は、次のように分ける（元データを加工していないことを、draft_figures.m と見比べて確かめられるように。docs/figure-style.md の
% 「原案の作図スクリプトから図を作る」の 3）。
%   データの集計   draft_figures.m と同じ計算（平均と SD、イベントの時刻の平均）。Panel D は「データ」（計算済みの値を受け取るだけ）
%   データを描く   draft_figures.m と同じデータを描くオブジェクト。色・線幅などの体裁はここでは指定しない
%   体裁           色・線幅・点・軸範囲・目盛り・軸ラベル・凡例。figure-types の recipe.md と defaults.json に従う。データの値は変えない
%   注釈           Affinity で加える注釈の指定（draft_figures.m にある注釈は値をそのまま写す。個別の注文で加えたものを含む）
%   書き出し       exportPanel
% draft_figures.m で MATLAB に描いていた有意差のブラケットと記号（figure(3)）、相関係数と P 値の文字（figure(4)）は、
% 作図方針に従い Affinity で加える注釈（JSON の annotations）にする（docs/figure-style.md の「MATLAB と Affinity の分担」）。
% 注釈の位置と記号は draft_figures.m と同じにし、線幅・文字の大きさなどは figure-types の既定に従う。
%
% パネル：A 投球の運動連鎖（timeseries）、B 走行の鉛直地面反力（timeseries）、C 跳躍高の条件比較（bar-points）、
%         D 体幹の最大回旋角速度と球速（scatter）
% 図全体：double column 190 mm × 130 mm。各パネルは 95 × 65 mm で、軸の枠の位置は 4 パネルで共通（この図だけの値。
%         共通の既定の 80 × 60 mm では、2 列に並べたときに 190 mm の幅のうち 15 mm が空くため。docs/figure-style.md の「個別の注文の扱い」
%         に従い、defaults.json は変えずにこのスクリプトで style を書き換える）
% 1 回目の出力の後の個別の注文（2026-10-19。この図だけに反映し、createPanelAxes・recipe.md・defaults.json は変えない）：
%   - Panel A の横軸を -200〜50 ms、目盛りを 50 ms ごとにする（データは draft_figures.m と同じく -250 ms から描き、-250〜-200 ms は軸の外になる）
%   - Panel D の縦軸を 28〜44 m/s、目盛りを 4 m/s ごとにする
%   - 全パネルの目盛り線を内向きにし、軸を四角で囲む（createPanelAxes の既定の TickDir 'out'・Box 'off' を、このスクリプトで書き換える。
%     MATLAB の Box 'on' では、上辺・右辺にも目盛り線が付く）
%   - 上の注文に伴う変更（注文にはないが、重なりを避けるため）：Panel A の凡例を左上から下の中央へ移す
%     （横軸を -200 ms からにすると、左上の凡例の文字に FC の線が重なるため）
% 2 回目の個別の注文（2026-10-19）：
%   - Panel C の有意差のブラケットの脚（両端の縦線）をなくし、横線だけにする（注釈の legMm を 0 にする）
%   - Panel B に、衝撃ピーク（Rearfoot strike の平均の 5〜20 % の極大）を指す矢印と「Impact peak」の文字を加える
%   - Panel A に、FC から MER までの区間を示す両矢印と「Arm cocking」の文字を加える
%   いずれも draft_figures.m にない注釈で、Affinity で加える（JSON の annotations）。位置を決めるための計算はするが、データの値は変えない
% 3 回目の個別の注文（2026-10-19）：
%   - 全パネルで、横軸と縦軸の目盛りの数字を軸から少し離す（MATLAB の既定の間隔 2 pt を 4 pt にする。軸ラベルも同じだけ外へ動く）
%   - Panel C の参加者ごとの点の横位置を乱数で少しずらし（条件の位置 ± 0.1）、参加者を結ぶ線も点に合わせる。
%     ずらすのは表示上の横位置だけで、跳躍高の値は変えない。このため compareFigureData では、線の点の横位置が draft_figures.m と一致しない
%
% 手順（figure-toolkit のフォルダで実行する。AGENTS.md の 4 節。2026-10-19 に、作成時の手順（前置きの JS の連結）から今の toolkit の手順に直した）：
%   1. matlab -batch "run('examples/draft_figures_2x2_revised/make_draft_figures_2x2_revised.m')"
%      → デスクトップの affinity_mcp_work/input/draft_figures_2x2_revised/ に、パネルごとの PNG・SVG・PDF・_components.pdf・JSON・_data.mat と、
%        配置の JSON（draft_figures_2x2_revised_layout.json）を書き出す
%   2. python examples/draft_figures_2x2_revised/combine_draft_figures_2x2_revised.py
%      → 4 パネルの成分のページを 1 つの PDF にまとめ、affinity_mcp_work/input/test_figures/ に置く
%   3. python tools/stack_component_pages.py test_figures/draft_figures_2x2_revised.json
%      → 成分のページを 1 ページに並べる（.af に空のページを残さないため）
%   4. AFFINITY_COLLECT_DIR=examples/draft_figures_2x2_revised/output node tools/affinity-mcp.mjs run affinity/compose/compose_test_figure.js --set testFigureName=draft_figures_2x2_revised
%      → Affinity で組み立て、affinity_mcp_work/panels/draft_figures_2x2_revised.af を保存し、PDF・PNG を output/ に移す
%   5. 確認：パネルごとに compareFigureData（draft_figures.m の figure(n) と <パネル>_data.mat）、
%      node tools/affinity-mcp.mjs run affinity/compose/check_figure.js --set checkFigureTitles=draft_figures_2x2_revised
%   6. 途中のファイルの削除：affinity_mcp_work/input/draft_figures_2x2_revised/、input/test_figures/draft_figures_2x2_revised*、affinity_mcp_work/check_draft_figures_2x2_revised.pdf

%% 準備
figureFolder = fileparts(mfilename('fullpath')) ; % このスクリプトのフォルダ
examplesFolder = fileparts(figureFolder) ; % create_demo_data.m と draft_figures.m のあるフォルダ
addpath(fullfile(fileparts(examplesFolder), 'matlab')) ; % figure-toolkit/matlab
addpath(examplesFolder) ;

% データと統計解析の結果（draft_figures.m と同じ）
data = create_demo_data() ;

% 図全体の配置（この図だけの値）
figureName = 'draft_figures_2x2_revised' ;
outDir = fullfile(toolkitPaths().input, figureName) ;
column = 'double' ; % 図全体の幅の種類（190 mm）
panelSizeCm = [9.5, 6.5] ; % 各パネルの MATLAB の図の大きさ [幅, 高さ] [cm]（2 列で 190 mm）
innerPositionCm = [1.6, 1.1, 7.4, 4.9] ; % 軸の枠の左下の x・y と幅・高さ [cm]（4 パネルで共通にして、行と列で軸を揃える）
tickDirection = 'in' ; % 目盛り線の向き（個別の注文。既定は 'out'）
axesBox = 'on' ; % 軸を四角で囲むか（個別の注文。既定は 'off'）
tickLabelGapPt = 4 ; % 目盛りの数字と軸の間隔の設定値 [pt]（個別の注文。MATLAB の既定は 2。2 pt 増やすと数字が約 0.7 mm 軸から離れる）


%% Panel A：投球の運動連鎖（draft_figures.m の figure(1)。図の種類 timeseries）

% データの集計（draft_figures.m と同じ計算）
kinematic = data.kinematicSequence ;
nSegments = numel(kinematic.segmentNames) ;
meanVelocity = squeeze(mean(kinematic.angularVelocity, 1)) ; % 時刻 × 部位 [deg/s]
sdVelocity = squeeze(std(kinematic.angularVelocity, 0, 1)) ; % 時刻 × 部位 [deg/s]
meanEventTimesMs = mean(kinematic.eventTimesMs, 1) ; % イベントごとの平均の時刻 [ms]

% 図と軸
[figA, axA, styleA] = createPanelAxes('timeseries') ;
styleA = applyPanelLayout(figA, axA, styleA, panelSizeCm, innerPositionCm) ;
applyAxesFrame(axA, tickDirection, axesBox, tickLabelGapPt) ;

% データを描く：平均 ± SD の帯、平均の線、イベントの時刻（draft_figures.m と同じデータ）
bandHandlesA = gobjects(1, nSegments) ;
for iSegment = 1:nSegments
    upperVelocity = meanVelocity(:, iSegment) + sdVelocity(:, iSegment) ;
    lowerVelocity = meanVelocity(:, iSegment) - sdVelocity(:, iSegment) ;
    bandHandlesA(iSegment) = fill(axA, [kinematic.timeMs, fliplr(kinematic.timeMs)], [upperVelocity.', fliplr(lowerVelocity.')], 'k') ;
end
lineHandlesA = plot(axA, kinematic.timeMs, meanVelocity) ;
eventHandlesA = xline(axA, meanEventTimesMs, '--', kinematic.eventNames) ;

% 体裁：系列の色、帯の不透明度、線幅（timeseries の recipe.md）
segmentColours = styleA.colours(1:nSegments, :) ;
for iSegment = 1:nSegments
    set(bandHandlesA(iSegment), 'FaceColor', segmentColours(iSegment, :), 'EdgeColor', 'none', 'FaceAlpha', styleA.bandOpacity) ;
    set(lineHandlesA(iSegment), 'Color', segmentColours(iSegment, :), 'LineWidth', styleA.lineWidth) ;
end

% 体裁：イベント線と名前（灰色。名前は横書きで、隣の線の名前と重ならない側に置く）
eventLabelSides = {'right', 'left', 'right'} ; % FC、MER、BR の名前を線の右と左のどちらに置くか（MER と BR の名前が重ならないように）
set(eventHandlesA, 'Color', styleA.eventLineColour(:).'/255, 'LineWidth', styleA.lineWidth, ...
    'LabelVerticalAlignment', 'top', 'LabelOrientation', 'horizontal', 'FontName', styleA.fontName, 'FontSize', styleA.fontSize) ;
for iEvent = 1:numel(eventHandlesA)
    eventHandlesA(iEvent).LabelHorizontalAlignment = eventLabelSides{iEvent} ;
end

% 体裁：軸。角速度は符号付きの量なので、縦軸は 0 を中心に正負対称にする（docs/figure-panel-style.md の 1 節）
% 横軸の範囲と目盛りは個別の注文による（-200〜50 ms、50 ms ごと）。-200 ms より前のデータは描いたまま、軸の範囲で切る
velocityLimit = 3000 ; % 縦軸の範囲 [-L, L] の L [deg/s]
timeLimitsA = [-200, 50] ; % 横軸の範囲 [ms]（ボールリリースからの時刻）
timeTickStepA = 50 ; % 横軸の目盛りの間隔 [ms]
maxAbsVelocity = max(abs([meanVelocity(:) + sdVelocity(:); meanVelocity(:) - sdVelocity(:)])) ; % 平均 ± SD の最大絶対値 [deg/s]
if maxAbsVelocity > velocityLimit
    error('Panel A：縦軸の範囲 %g に %g が収まりません', velocityLimit, maxAbsVelocity) ;
end
if any(meanEventTimesMs < timeLimitsA(1) | meanEventTimesMs > timeLimitsA(2))
    error('Panel A：イベントの時刻が横軸の範囲 [%g, %g] ms の外にあります', timeLimitsA) ;
end
xlim(axA, timeLimitsA) ;
ylim(axA, [-velocityLimit, velocityLimit]) ;
xticks(axA, timeLimitsA(1):timeTickStepA:timeLimitsA(2)) ;
yticks(axA, -velocityLimit:1500:velocityLimit) ;
xlabel(axA, 'Time from ball release (ms)') ;
ylabel(axA, 'Angular velocity (deg/s)') ;

% 体裁：凡例（draft_figures.m と同じ項目）。データ線の表示を切り替えても凡例の見た目が変わらないよう、データのない代理の線で作る
% 位置は下の中央（横軸を -200〜50 ms にすると、左上の凡例の文字に FC の線（-152 ms）が重なるため。2026-10-19）。
% 下の中央は FC と MER の線の間で、データのない負の側にあたる
proxyHandlesA = gobjects(1, nSegments) ;
for iSegment = 1:nSegments
    proxyHandlesA(iSegment) = plot(axA, NaN, NaN, 'Color', segmentColours(iSegment, :), 'LineWidth', styleA.lineWidth) ;
end
legendA = legend(axA, proxyHandlesA, kinematic.segmentNames, 'Location', 'south', 'Box', 'off', ...
    'FontName', styleA.fontName, 'FontSize', styleA.fontSize) ;
legendA.ItemTokenSize = [15, 18] ;

% 注釈：FC から MER までの区間（Arm cocking）を示す両矢印と文字（個別の注文。Affinity で加える。位置はデータ座標）。
% 矢印の両端は FC と MER の線（平均の時刻）に合わせる。下の中央には凡例があるため、矢印はデータの山の上、
% イベント線の名前の下の空いた高さに置き、文字は矢印の上の中央に置く（timeseries の recipe.md の 4 節）
cockingStartMs = meanEventTimesMs(strcmp(kinematic.eventNames, 'FC')) ; % 区間の始まり（FC の平均の時刻）[ms]
cockingEndMs = meanEventTimesMs(strcmp(kinematic.eventNames, 'MER')) ; % 区間の終わり（MER の平均の時刻）[ms]
cockingArrowY = 2000 ; % 両矢印の高さ [deg/s]
isCockingPhase = kinematic.timeMs >= cockingStartMs & kinematic.timeMs <= cockingEndMs ; % 区間の中の時刻
maxCockingVelocity = max(meanVelocity(isCockingPhase, :) + sdVelocity(isCockingPhase, :), [], 'all') ; % 区間の中の平均 + SD の最大値 [deg/s]（配置の確認用）
if maxCockingVelocity > cockingArrowY - 500
    error('Panel A：Arm cocking の矢印（%g deg/s）がデータ（最大 %.0f deg/s）に近すぎます', cockingArrowY, maxCockingVelocity) ;
end
annotationsA = { ...
    struct('type', 'arrow', 'name', 'arm cocking arrow', 'from', [cockingStartMs, cockingArrowY], 'to', [cockingEndMs, cockingArrowY], ...
        'heads', 'both', 'gapMm', 0), ...
    struct('type', 'text', 'name', 'arm cocking label', 'text', 'Arm cocking', 'position', [(cockingStartMs + cockingEndMs)/2, cockingArrowY], ...
        'anchor', 'center-bottom', 'offsetMm', [0, 0.8])} ; % offsetMm：矢印と文字の間隔（例 example_kinematic_sequence.m と同じ）

% 書き出し：成分は背面から前面の順（サブレイヤー名の系列は部位の名前の小文字）
seriesNamesA = lower(kinematic.segmentNames) ;
specA = struct() ;
specA.name = 'A_kinematic_sequence' ;
specA.panel = 'A' ;
specA.outDir = outDir ;
specA.style = styleA ;
specA.column = column ;
specA.components = [{'events', eventHandlesA}; ...
    [strcat('bands', {' '}, seriesNamesA(:)), num2cell(bandHandlesA(:))]; ...
    [strcat('lines', {' '}, seriesNamesA(:)), num2cell(lineHandlesA(:))]; ...
    {'axes', []; 'legend', []}] ;
specA.legend = legendA ;
specA.annotations = annotationsA ;
exportPanel(figA, axA, specA) ;


%% Panel B：走行の鉛直地面反力（draft_figures.m の figure(2)。図の種類 timeseries）

% データの集計（draft_figures.m と同じ計算）
grf = data.runningGrf ;
nGroups = numel(grf.groupNames) ;
meanForce = squeeze(mean(grf.verticalForce, 1)) ; % 時刻 × 群 [BW]
sdForce = squeeze(std(grf.verticalForce, 0, 1)) ; % 時刻 × 群 [BW]

% 図と軸
[figB, axB, styleB] = createPanelAxes('timeseries') ;
styleB = applyPanelLayout(figB, axB, styleB, panelSizeCm, innerPositionCm) ;
applyAxesFrame(axB, tickDirection, axesBox, tickLabelGapPt) ;

% データを描く：平均 ± SD の帯、平均の線（draft_figures.m と同じデータ）
bandHandlesB = gobjects(1, nGroups) ;
for iGroup = 1:nGroups
    upperForce = meanForce(:, iGroup) + sdForce(:, iGroup) ;
    lowerForce = meanForce(:, iGroup) - sdForce(:, iGroup) ;
    bandHandlesB(iGroup) = fill(axB, [grf.stancePercent, fliplr(grf.stancePercent)], [upperForce.', fliplr(lowerForce.')], 'k') ;
end
lineHandlesB = plot(axB, grf.stancePercent, meanForce) ;

% 体裁：系列の色、帯の不透明度、線幅（timeseries の recipe.md）
groupColoursB = styleB.colours(1:nGroups, :) ;
for iGroup = 1:nGroups
    set(bandHandlesB(iGroup), 'FaceColor', groupColoursB(iGroup, :), 'EdgeColor', 'none', 'FaceAlpha', styleB.bandOpacity) ;
    set(lineHandlesB(iGroup), 'Color', groupColoursB(iGroup, :), 'LineWidth', styleB.lineWidth) ;
end

% 体裁：軸。鉛直地面反力は非負の量なので、縦軸は 0 から切りのよい値までとする（docs/figure-panel-style.md の 1 節）
forceLimit = 3 ; % 縦軸の上限 [BW]
maxForce = max(meanForce(:) + sdForce(:)) ; % 平均 + SD の最大値 [BW]
if maxForce > forceLimit
    error('Panel B：縦軸の範囲 %g BW に %.2f BW が収まりません', forceLimit, maxForce) ;
end
xlim(axB, [0, 100]) ;
ylim(axB, [0, forceLimit]) ;
xticks(axB, 0:25:100) ;
yticks(axB, 0:1:forceLimit) ;
xlabel(axB, 'Stance (%)') ;
ylabel(axB, 'Vertical GRF (BW)') ;

% 体裁：凡例（draft_figures.m と同じ項目。代理の線で作る）
proxyHandlesB = gobjects(1, nGroups) ;
for iGroup = 1:nGroups
    proxyHandlesB(iGroup) = plot(axB, NaN, NaN, 'Color', groupColoursB(iGroup, :), 'LineWidth', styleB.lineWidth) ;
end
legendB = legend(axB, proxyHandlesB, grf.groupNames, 'Location', 'south', 'Box', 'off', ...
    'FontName', styleB.fontName, 'FontSize', styleB.fontSize) ;
legendB.ItemTokenSize = [15, 18] ;

% 注釈：衝撃ピークを指す矢印と文字（個別の注文。Affinity で加える。位置はデータ座標）。
% 指す点は Rearfoot strike の平均の線の 5〜20 % の極大（10 % 付近の山。figure-types/timeseries/example_running_grf.m と同じ求め方）。
% この計算は矢印の位置を決めるためだけで、データの値は変えず、図に数値も出さない。
% 文字は山の右上の空いた所に置き、矢印は文字の下端の中央から山を指す（矢印の先は山から gapMm だけ離す）
rearfootMeanForce = meanForce(:, strcmp(grf.groupNames, 'Rearfoot strike')) ; % Rearfoot strike の平均 [BW]
impactWindow = find(grf.stancePercent >= 5 & grf.stancePercent <= 20) ; % 衝撃ピークを探す範囲（立脚期の 5〜20 %）
[impactPeakForce, impactPeakIndex] = max(rearfootMeanForce(impactWindow)) ; % 衝撃ピークの高さ [BW]
impactPeakPercent = grf.stancePercent(impactWindow(impactPeakIndex)) ; % 衝撃ピークの時刻 [%]
impactLabelPosition = [impactPeakPercent + 2, 2.5] ; % 文字の下端の中央、矢印の始まり [%, BW]
annotationsB = { ...
    struct('type', 'arrow', 'name', 'impact peak arrow', 'from', impactLabelPosition, 'to', [impactPeakPercent, impactPeakForce], ...
        'heads', 'end', 'gapMm', 0.8), ...
    struct('type', 'text', 'name', 'impact peak label', 'text', 'Impact peak', 'position', impactLabelPosition, ...
        'anchor', 'center-bottom', 'offsetMm', [0, 0.5])} ;

% 書き出し：成分は背面から前面の順
seriesNamesB = {'rearfoot', 'forefoot'} ; % サブレイヤー名の系列（grf.groupNames の順）
specB = struct() ;
specB.name = 'B_running_grf' ;
specB.panel = 'B' ;
specB.outDir = outDir ;
specB.style = styleB ;
specB.column = column ;
specB.components = [[strcat('bands', {' '}, seriesNamesB(:)), num2cell(bandHandlesB(:))]; ...
    [strcat('lines', {' '}, seriesNamesB(:)), num2cell(lineHandlesB(:))]; ...
    {'axes', []; 'legend', []}] ;
specB.legend = legendB ;
specB.annotations = annotationsB ;
exportPanel(figB, axB, specB) ;


%% Panel C：跳躍高の条件比較（draft_figures.m の figure(3)。図の種類 bar-points）

% データの集計（draft_figures.m と同じ計算）
jump = data.jumpHeight ;
nConditions = numel(jump.conditionNames) ;
nParticipants = size(jump.height, 1) ;
meanHeight = mean(jump.height, 1) ; % 条件ごとの平均 [cm]
sdHeight = std(jump.height, 0, 1) ; % 条件ごとの SD [cm]

% 図と軸
[figC, axC, styleC] = createPanelAxes('bar-points') ;
styleC = applyPanelLayout(figC, axC, styleC, panelSizeCm, innerPositionCm) ;
applyAxesFrame(axC, tickDirection, axesBox, tickLabelGapPt) ;

% データを描く：平均の棒、SD の誤差棒、参加者ごとの値を結ぶ線（反復測定）、参加者ごとの値の点（draft_figures.m と同じデータ）
% 棒は、条件ごとに色とサブレイヤーを分けるため、条件ごとに 1 本ずつ描く（位置と高さは draft_figures.m の bar と同じ）
barHandlesC = gobjects(1, nConditions) ;
for iCondition = 1:nConditions
    barHandlesC(iCondition) = bar(axC, iCondition, meanHeight(iCondition)) ;
end
errorBarHandleC = errorbar(axC, 1:nConditions, meanHeight, sdHeight) ;
% 参加者ごとの点と線の横位置は、条件の位置から乱数で少しずらす（個別の注文。draft_figures.m では条件の位置そのもの）。
% ずらすのは表示上の横位置だけで、跳躍高の値（縦位置）は draft_figures.m と同じ。点ごと（参加者 × 条件）に独立にずらし、線は点を結ぶ。
% 乱数は種を固定したこの図だけの乱数の流れから取る（作り直しても同じ位置になり、ほかの乱数の状態に影響しない）
jitterHalfWidth = 0.1 ; % ずらす幅の片側 [条件の間隔]（棒の幅 0.6 の半分 0.3 より小さく、点は棒の幅の中に収まる）
jitterStream = RandStream('mt19937ar', 'Seed', 1) ; % ずらしの乱数の流れ
participantX = (1:nConditions) + jitterHalfWidth*(2*rand(jitterStream, nParticipants, nConditions) - 1) ; % 参加者 × 条件の点の横位置 [条件の番号]
participantLineHandlesC = plot(axC, participantX.', jump.height.') ;
markerHandlesC = gobjects(1, nConditions) ;
for iCondition = 1:nConditions
    markerHandlesC(iCondition) = plot(axC, participantX(:, iCondition), jump.height(:, iCondition)) ;
end

% 体裁：棒（条件の色を白で淡くした塗りと黒の枠線）、誤差棒、参加者の線（灰色）、点（条件の色）（bar-points の recipe.md）
conditionColours = styleC.colours(1:nConditions, :) ;
barShare = styleC.barColourPercent/100 ; % 棒の塗りに占める条件の色の割合（残りは白）
paleColours = barShare*conditionColours + (1 - barShare) ;
for iCondition = 1:nConditions
    set(barHandlesC(iCondition), 'BarWidth', styleC.barWidth, 'FaceColor', paleColours(iCondition, :), ...
        'EdgeColor', 'k', 'LineWidth', styleC.lineWidth, 'ShowBaseLine', 'off') ;
    set(markerHandlesC(iCondition), 'LineStyle', 'none', 'Marker', 'o', 'MarkerSize', styleC.markerSizePt, ...
        'MarkerFaceColor', conditionColours(iCondition, :), 'MarkerEdgeColor', 'none') ;
end
set(errorBarHandleC, 'Color', 'k', 'LineStyle', 'none', 'LineWidth', styleC.lineWidth) ;
set(participantLineHandlesC, 'Color', styleC.participantLineColour(:).'/255, 'LineWidth', styleC.lineWidth) ;
if styleC.errorBarsBehindBars
    uistack(errorBarHandleC, 'bottom') ; % 誤差棒を棒の背面に置く（棒から上に出た部分だけが見える）
end

% 注釈：条件間の有意差のブラケットと記号（Affinity で加える。位置はデータ座標）。
% 高さ・端の寄せ方・記号は draft_figures.m と同じ：全参加者の最大値の上に、隣り合う組は同じ高さ、両端の組はその上に置き、
% 端を内側に寄せる。記号は補正後の p < 0.05 なら *、それ以外は n.s.
% ブラケットの脚（両端の縦線）は描かず、横線だけにする（個別の注文。recipe.md の既定の legMm 1 mm の代わりに 0）
comparisonPairs = jump.stats.pairs ;
nComparisons = size(comparisonPairs, 1) ;
bracketHeights = max(jump.height(:)) + [2, 2, 6] ; % 組ごとのブラケットの高さ [cm]
bracketInset = 0.05 ; % 隣り合うブラケットが接しないよう、端を内側に寄せる量 [条件の間隔]
bracketLegMm = 0 ; % ブラケットの脚の長さ [mm]（0 は脚なし）
annotationsC = cell(1, nComparisons) ;
for iComparison = 1:nComparisons
    pair = comparisonPairs(iComparison, :) ;
    if jump.stats.pValues(iComparison) < 0.05
        significanceMark = '*' ;
    else
        significanceMark = 'n.s.' ;
    end
    annotationsC{iComparison} = struct('type', 'bracket', 'name', sprintf('significance %s-%s', jump.conditionNames{pair}), ...
        'x', [pair(1) + bracketInset, pair(2) - bracketInset], 'y', bracketHeights(iComparison), 'legMm', bracketLegMm, ...
        'text', significanceMark, 'textGapMm', 0.5) ; % textGapMm：ブラケットと記号の間隔（recipe.md の既定）
end

% 体裁：軸。跳躍高は非負の量なので、縦軸は 0 から、有意差記号の分の余白を含めて切りのよい値までとする
heightLimit = 50 ; % 縦軸の上限 [cm]
if max(bracketHeights) + 4 > heightLimit
    error('Panel C：有意差記号が縦軸の範囲 %g cm に収まりません（最も高いブラケット %.1f cm）', heightLimit, max(bracketHeights)) ;
end
xlim(axC, [0.4, nConditions + 0.6]) ;
ylim(axC, [0, heightLimit]) ;
xticks(axC, 1:nConditions) ;
xticklabels(axC, jump.conditionNames) ;
yticks(axC, 0:10:heightLimit) ;
ylabel(axC, 'Jump height (cm)') ;

% 書き出し：成分は背面から前面の順（誤差棒は既定では棒の背面）
dataComponentsC = [[strcat('bars', {' '}, jump.conditionNames(:)), num2cell(barHandlesC(:))]; ...
    {'lines participants', participantLineHandlesC}; ...
    [strcat('markers', {' '}, jump.conditionNames(:)), num2cell(markerHandlesC(:))]] ;
if styleC.errorBarsBehindBars
    dataComponentsC = [{'error bars', errorBarHandleC}; dataComponentsC] ;
else
    dataComponentsC = [dataComponentsC; {'error bars', errorBarHandleC}] ;
end
specC = struct() ;
specC.name = 'C_jump_height' ;
specC.panel = 'C' ;
specC.outDir = outDir ;
specC.style = styleC ;
specC.column = column ;
specC.components = [dataComponentsC; {'axes', []}] ;
specC.legend = [] ;
specC.annotations = annotationsC ;
exportPanel(figC, axC, specC) ;


%% Panel D：体幹の最大回旋角速度と球速（draft_figures.m の figure(4)。図の種類 scatter）

% データ（統計解析の結果は create_demo_data で計算済み）
speed = data.ballSpeed ;
nSpeedGroups = numel(speed.groupNames) ;

% 図と軸
[figD, axD, styleD] = createPanelAxes('scatter') ;
styleD = applyPanelLayout(figD, axD, styleD, panelSizeCm, innerPositionCm) ;
applyAxesFrame(axD, tickDirection, axesBox, tickLabelGapPt) ;

% データを描く：平均の予測値の 95 % 信頼帯、回帰直線（全員）、群ごとの点（draft_figures.m と同じデータ）
bandHandleD = fill(axD, [speed.stats.fitVelocity, fliplr(speed.stats.fitVelocity)], ...
    [speed.stats.confidenceUpper, fliplr(speed.stats.confidenceLower)], 'k') ;
fitLineHandleD = plot(axD, speed.stats.fitVelocity, speed.stats.fitSpeed) ;
markerHandlesD = gobjects(1, nSpeedGroups) ;
for iGroup = 1:nSpeedGroups
    markerHandlesD(iGroup) = plot(axD, speed.trunkVelocity{iGroup}, speed.ballSpeed{iGroup}) ;
end

% 体裁：信頼帯（灰色）、回帰直線（黒）、群ごとの点（色と形で区別）（scatter の recipe.md）
groupColoursD = styleD.colours(1:nSpeedGroups, :) ;
groupMarkers = {'o', 's'} ; % 群ごとの点の形（draft_figures.m と同じ）
set(bandHandleD, 'FaceColor', styleD.confidenceBandColour(:).'/255, 'EdgeColor', 'none') ;
set(fitLineHandleD, 'Color', 'k', 'LineWidth', styleD.lineWidth) ;
for iGroup = 1:nSpeedGroups
    set(markerHandlesD(iGroup), 'LineStyle', 'none', 'Marker', groupMarkers{iGroup}, 'MarkerSize', styleD.markerSizePt, ...
        'MarkerFaceColor', groupColoursD(iGroup, :), 'MarkerEdgeColor', 'none') ;
end

% 体裁：軸。両軸とも非負の量なので、データ（点と信頼帯）が収まる切りのよい範囲にする（docs/figure-panel-style.md の 1 節）
% 縦軸の範囲と目盛りは個別の注文による（28〜44 m/s、4 m/s ごと）
velocityLimitsD = [900, 1300] ; % 横軸の範囲 [deg/s]
speedLimitsD = [28, 44] ; % 縦軸の範囲 [m/s]
speedTickStepD = 4 ; % 縦軸の目盛りの間隔 [m/s]
allVelocity = vertcat(speed.trunkVelocity{:}) ; % 全員の体幹の最大回旋角速度 [deg/s]（範囲の確認用）
allSpeed = [vertcat(speed.ballSpeed{:}); speed.stats.confidenceLower(:); speed.stats.confidenceUpper(:)] ; % 球速と信頼帯の値 [m/s]（範囲の確認用）
if min(allVelocity) < velocityLimitsD(1) || max(allVelocity) > velocityLimitsD(2) || min(allSpeed) < speedLimitsD(1) || max(allSpeed) > speedLimitsD(2)
    error('Panel D：データが軸の範囲に収まりません：x %.0f〜%.0f、y %.1f〜%.1f', min(allVelocity), max(allVelocity), min(allSpeed), max(allSpeed)) ;
end
xlim(axD, velocityLimitsD) ;
ylim(axD, speedLimitsD) ;
xticks(axD, velocityLimitsD(1):100:velocityLimitsD(2)) ;
yticks(axD, speedLimitsD(1):speedTickStepD:speedLimitsD(2)) ;
xlabel(axD, 'Peak trunk rotation velocity (deg/s)') ;
ylabel(axD, 'Ball speed (m/s)') ;

% 体裁：凡例（draft_figures.m と同じ項目。代理の点で作る）
proxyHandlesD = gobjects(1, nSpeedGroups) ;
for iGroup = 1:nSpeedGroups
    proxyHandlesD(iGroup) = plot(axD, NaN, NaN, 'LineStyle', 'none', 'Marker', groupMarkers{iGroup}, 'MarkerSize', styleD.markerSizePt, ...
        'MarkerFaceColor', groupColoursD(iGroup, :), 'MarkerEdgeColor', 'none') ;
end
legendD = legend(axD, proxyHandlesD, speed.groupNames, 'Location', 'southeast', 'Box', 'off', ...
    'FontName', styleD.fontName, 'FontSize', styleD.fontSize) ;
legendD.ItemTokenSize = [10, 18] ;

% 注釈：相関係数と P 値（Affinity で加える。文字と位置は draft_figures.m と同じ：軸の枠の左から 5 %、上から 5 % を文字の左上に合わせる）
if speed.stats.p < 0.001
    statisticsText = sprintf('r = %.2f, P < 0.001', speed.stats.r) ;
else
    statisticsText = sprintf('r = %.2f, P = %.3f', speed.stats.r, speed.stats.p) ;
end
statisticsPosition = [velocityLimitsD(1) + 0.05*(velocityLimitsD(2) - velocityLimitsD(1)), ...
    speedLimitsD(1) + 0.95*(speedLimitsD(2) - speedLimitsD(1))] ; % 文字の左上の位置（データ座標）[deg/s, m/s]
annotationsD = {struct('type', 'text', 'name', 'correlation', 'text', statisticsText, 'position', statisticsPosition, ...
    'anchor', 'left-top', 'offsetMm', [0, 0])} ;

% 書き出し：成分は背面から前面の順
seriesNamesD = lower(speed.groupNames) ; % サブレイヤー名の系列（群の名前の小文字）
specD = struct() ;
specD.name = 'D_ball_speed_scatter' ;
specD.panel = 'D' ;
specD.outDir = outDir ;
specD.style = styleD ;
specD.column = column ;
specD.components = [{'confidence band', bandHandleD; 'fit line', fitLineHandleD}; ...
    [strcat('markers', {' '}, seriesNamesD(:)), num2cell(markerHandlesD(:))]; ...
    {'axes', []; 'legend', []}] ;
specD.legend = legendD ;
specD.annotations = annotationsD ;
exportPanel(figD, axD, specD) ;


%% 配置の JSON（combine_draft_figures_2x2_revised.py が読む）：各パネルの左上の位置と、図全体の大きさ
panelWidthMm = panelSizeCm(1)*10 ;
panelHeightMm = panelSizeCm(2)*10 ;
areaWidthMm = styleA.columnWidthMm.(column) ; % 図全体の幅（段の幅）[mm]
areaHeightMm = 2*panelHeightMm ; % 図全体の高さ（2 行）[mm]
if 2*panelWidthMm > areaWidthMm
    error('2 列のパネルの幅 %.1f mm が %s column の幅 %.1f mm を超えています', 2*panelWidthMm, column, areaWidthMm) ;
end
panelSpecs = {specA, specB, specC, specD} ;
panelRows = [1, 1, 2, 2] ; % A・B が上の行、C・D が下の行
panelColumns = [1, 2, 1, 2] ; % A・C が左の列、B・D が右の列
layout = struct() ;
layout.name = figureName ;
layout.figureArea = struct('column', column, 'widthMm', areaWidthMm, 'heightMm', areaHeightMm) ;
layout.panels = struct('panel', {}, 'source', {}, 'offsetMm', {}) ;
for iPanel = 1:numel(panelSpecs)
    offsetMm = [(panelColumns(iPanel) - 1)*panelWidthMm, (panelRows(iPanel) - 1)*panelHeightMm] ; % パネルの左上の、図の左上からの位置 [mm]
    layout.panels(iPanel) = struct('panel', panelSpecs{iPanel}.panel, 'source', panelSpecs{iPanel}.name, 'offsetMm', offsetMm) ;
end
layoutFile = fopen(fullfile(outDir, [figureName, '_layout.json']), 'w', 'n', 'UTF-8') ;
fprintf(layoutFile, '%s', jsonencode(layout, 'PrettyPrint', true)) ;
fclose(layoutFile) ;
fprintf('%s: figure area %s column %g x %g mm; panels %g x %g mm\n', figureName, column, areaWidthMm, areaHeightMm, panelWidthMm, panelHeightMm) ;

close([figA, figB, figC, figD]) ;


%% 関数

% 図の大きさと軸の枠の位置を、この図の値に変える（createPanelAxes の既定の 8 × 6 cm の代わり）。
% style の値も書き換える（exportPanel が JSON に書き、Affinity で図の大きさとして使うため）
function style = applyPanelLayout(fig, ax, style, panelSizeCm, innerPositionCm)
style.figureSizeCm = panelSizeCm ;
style.innerPositionCm = innerPositionCm ;
fig.Position = [2, 2, panelSizeCm] ;
ax.InnerPosition = innerPositionCm ;
end

% 目盛り線の向き、軸を四角で囲むか、目盛りの数字と軸の間隔を、この図の値に変える
% （createPanelAxes の既定の TickDir 'out'・Box 'off' と、MATLAB の既定の間隔の代わり）。
% Box 'on' の上辺・右辺は、exportPanel の横軸・縦軸のページに含まれ、Affinity では axes lines に入る。
% 間隔の TickLabelGapOffset は MATLAB の非公開（文書にない）プロパティで、単位は pt（R2025a で、1 増やすと数字が 0.35 mm 離れ、
% 軸ラベルも同じだけ外へ動くことを確認）。版が変わると使えなくなることがある
function applyAxesFrame(ax, tickDirection, axesBox, tickLabelGapPt)
ax.TickDir = tickDirection ;
ax.Box = axesBox ;
ax.XAxis.TickLabelGapOffset = tickLabelGapPt ;
ax.YAxis.TickLabelGapOffset = tickLabelGapPt ;
end
