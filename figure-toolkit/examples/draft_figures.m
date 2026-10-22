% 手作業で書いた作図スクリプトの例（図の原案。体裁は MATLAB の既定のまま）
%
% 用途：既存の作図スクリプトから、ワークフローに従って論文用の図を作る作業の試験用の入力。
%   例：「figure 1 と figure 2 をパネル A, B として横に並べて、ワークフローに従って論文用の図を作成して」
% 構成：先頭で create_demo_data を呼んでデータと統計解析の結果を受け取り、図ごとに別の figure に描く。
%   figure(1) 投球の運動連鎖（角速度の平均 ± SD、イベントの時刻）
%   figure(2) 走行の鉛直地面反力（群ごとの平均 ± SD）
%   figure(3) 跳躍高の条件比較（平均の棒、SD の誤差棒、参加者ごとの値と線、条件間の有意差のブラケットと記号）
%   figure(4) 体幹の最大回旋角速度と球速（群ごとの点、回帰直線と 95 % 信頼帯、相関係数と p 値）
% 指定しているのは、データと統計の結果を描くオブジェクト（plot、fill、bar、errorbar、xline、text）、軸ラベル、
% 目盛りの名前、凡例だけ。軸範囲、文字の大きさ、線幅、図の大きさは指定しない（MATLAB の既定のまま）。
% 統計解析（検定、相関、回帰）は create_demo_data の中で行う。
% 実行：matlab -batch "run('<figure-toolkit>/examples/draft_figures.m')"

% データと統計解析の結果
addpath(fileparts(mfilename('fullpath'))) ; % create_demo_data.m のあるフォルダ
data = create_demo_data() ;


%% figure(1)：投球の運動連鎖
kinematic = data.kinematicSequence ;
nSegments = numel(kinematic.segmentNames) ;

% 部位ごとの平均と SD（投手間）、イベントの時刻の平均
meanVelocity = squeeze(mean(kinematic.angularVelocity, 1)) ; % 時刻 × 部位 [deg/s]
sdVelocity = squeeze(std(kinematic.angularVelocity, 0, 1)) ; % 時刻 × 部位 [deg/s]
meanEventTimesMs = mean(kinematic.eventTimesMs, 1) ; % イベントごとの平均の時刻 [ms]

figure(1) ;
clf ;
hold on ;
segmentColours = colororder ; % 既定の色の順（線と帯の色を合わせるため）

% 平均 ± SD の帯
for iSegment = 1:nSegments
    upperVelocity = meanVelocity(:, iSegment) + sdVelocity(:, iSegment) ;
    lowerVelocity = meanVelocity(:, iSegment) - sdVelocity(:, iSegment) ;
    fill([kinematic.timeMs, fliplr(kinematic.timeMs)], [upperVelocity.', fliplr(lowerVelocity.')], segmentColours(iSegment, :), ...
        'FaceAlpha', 0.3, 'EdgeColor', 'none') ;
end

% 平均の線
segmentLines = plot(kinematic.timeMs, meanVelocity) ;

% イベントの時刻
xline(meanEventTimesMs, '--', kinematic.eventNames) ;

xlabel('Time from ball release (ms)') ;
ylabel('Angular velocity (deg/s)') ;
legend(segmentLines, kinematic.segmentNames) ;


%% figure(2)：走行の鉛直地面反力
grf = data.runningGrf ;
nGroups = numel(grf.groupNames) ;

% 群ごとの平均と SD（走者間）
meanForce = squeeze(mean(grf.verticalForce, 1)) ; % 時刻 × 群 [BW]
sdForce = squeeze(std(grf.verticalForce, 0, 1)) ; % 時刻 × 群 [BW]

figure(2) ;
clf ;
hold on ;
groupColours = colororder ;

% 平均 ± SD の帯
for iGroup = 1:nGroups
    upperForce = meanForce(:, iGroup) + sdForce(:, iGroup) ;
    lowerForce = meanForce(:, iGroup) - sdForce(:, iGroup) ;
    fill([grf.stancePercent, fliplr(grf.stancePercent)], [upperForce.', fliplr(lowerForce.')], groupColours(iGroup, :), ...
        'FaceAlpha', 0.3, 'EdgeColor', 'none') ;
end

% 平均の線
groupLines = plot(grf.stancePercent, meanForce) ;

xlabel('Stance (%)') ;
ylabel('Vertical GRF (BW)') ;
legend(groupLines, grf.groupNames) ;


%% figure(3)：跳躍高の条件比較
jump = data.jumpHeight ;
nConditions = numel(jump.conditionNames) ;
nParticipants = size(jump.height, 1) ;

% 条件ごとの平均と SD（参加者間）
meanHeight = mean(jump.height, 1) ; % [cm]
sdHeight = std(jump.height, 0, 1) ; % [cm]

figure(3) ;
clf ;
hold on ;

% 平均の棒と SD の誤差棒
bar(1:nConditions, meanHeight) ;
errorbar(1:nConditions, meanHeight, sdHeight, 'k', 'LineStyle', 'none') ;

% 参加者ごとの値：条件間を線で結び（反復測定）、条件ごとに点を描く
plot(1:nConditions, jump.height.', 'Color', [0.5, 0.5, 0.5]) ;
for iCondition = 1:nConditions
    plot(iCondition*ones(nParticipants, 1), jump.height(:, iCondition), 'o') ;
end

% 条件間の有意差：組ごとのブラケットと記号（補正後の p < 0.05 なら *、それ以外は n.s.）
% ブラケットの高さは、全参加者の最大値の上に、隣り合う組は同じ高さ、両端の組はその上に置く
comparisonPairs = jump.stats.pairs ;
bracketHeights = max(jump.height(:)) + [2, 2, 6] ; % 組ごとのブラケットの高さ [cm]
bracketLeg = 0.5 ; % ブラケットの両端の下向きの長さ [cm]
bracketInset = 0.05 ; % 隣り合うブラケットが接しないよう、端を内側に寄せる量 [条件の間隔]
for iComparison = 1:size(comparisonPairs, 1)
    leftX = comparisonPairs(iComparison, 1) + bracketInset ;
    rightX = comparisonPairs(iComparison, 2) - bracketInset ;
    bracketY = bracketHeights(iComparison) ;
    plot([leftX, leftX, rightX, rightX], [bracketY - bracketLeg, bracketY, bracketY, bracketY - bracketLeg], 'k') ;
    if jump.stats.pValues(iComparison) < 0.05
        significanceMark = '*' ;
    else
        significanceMark = 'n.s.' ;
    end
    text(mean([leftX, rightX]), bracketY, significanceMark, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom') ;
end

xticks(1:nConditions) ;
xticklabels(jump.conditionNames) ;
ylabel('Jump height (cm)') ;


%% figure(4)：体幹の最大回旋角速度と球速
speed = data.ballSpeed ;
nSpeedGroups = numel(speed.groupNames) ;

figure(4) ;
clf ;
hold on ;

% 回帰直線（全員）と、平均の予測値の 95 % 信頼帯
fill([speed.stats.fitVelocity, fliplr(speed.stats.fitVelocity)], [speed.stats.confidenceUpper, fliplr(speed.stats.confidenceLower)], ...
    [0.8, 0.8, 0.8], 'EdgeColor', 'none') ;
plot(speed.stats.fitVelocity, speed.stats.fitSpeed, 'k') ;

% 群ごとの点（色と形で区別）
groupMarkers = {'o', 's'} ;
groupPoints = gobjects(1, nSpeedGroups) ;
for iGroup = 1:nSpeedGroups
    groupPoints(iGroup) = plot(speed.trunkVelocity{iGroup}, speed.ballSpeed{iGroup}, groupMarkers{iGroup}) ;
end

% 相関係数と p 値（軸の左上）
if speed.stats.p < 0.001
    statisticsText = sprintf('r = %.2f, P < 0.001', speed.stats.r) ;
else
    statisticsText = sprintf('r = %.2f, P = %.3f', speed.stats.r, speed.stats.p) ;
end
text(0.05, 0.95, statisticsText, 'Units', 'normalized', 'VerticalAlignment', 'top') ;

xlabel('Peak trunk rotation velocity (deg/s)') ;
ylabel('Ball speed (m/s)') ;
legend(groupPoints, speed.groupNames) ;
