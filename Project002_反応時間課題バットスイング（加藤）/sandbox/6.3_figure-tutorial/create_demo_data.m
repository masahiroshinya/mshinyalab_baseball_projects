function data = create_demo_data()
% 作図の例に使うダミーデータを作る（スポーツバイオメカニクスの 4 種類の測定を模したもの）
%
% figure-types/ の例（example_*.m）の「ダミーデータ」の部分と同じ乱数の種と消費順序で作るので、値は例と一致する。
% 乱数の状態は、呼び出し前の状態に戻してから返す（呼び出し側の乱数に影響しないように）。
% 出力：data（構造体）
%   data.kinematicSequence  投球の運動連鎖（12 名の投手）
%     .timeMs            ボールリリースからの時刻 [ms]（1 × 時刻）
%     .segmentNames      部位の名前 {'Pelvis', 'Trunk', 'Elbow'}（骨盤の回旋、体幹の回旋、肘の伸展）
%     .angularVelocity   角速度 [deg/s]（投手 × 時刻 × 部位）
%     .eventNames        イベントの名前 {'FC', 'MER', 'BR'}（踏み出し足の接地、肩の最大外旋、ボールリリース）
%     .eventTimesMs      投手ごとのイベントの時刻 [ms]（投手 × イベント。BR は時刻の基準なので 0）
%   data.runningGrf         走行の立脚期の鉛直地面反力（群ごとに 12 名）
%     .stancePercent     立脚期に対する割合 [%]（1 × 時刻）
%     .groupNames        群の名前 {'Rearfoot strike', 'Forefoot strike'}
%     .verticalForce     鉛直地面反力 [BW]（走者 × 時刻 × 群）
%   data.jumpHeight         跳躍高の条件比較（10 名の参加者の反復測定）
%     .conditionNames    条件の名前 {'SJ', 'CMJ', 'CMJ+AS'}（スクワットジャンプ、反動あり、反動と腕の振りあり）
%     .height            跳躍高 [cm]（参加者 × 条件）
%     .stats             条件間の比較（対応のある t 検定、Bonferroni 補正）
%       .method          検定の説明
%       .pairs           比較した条件の組（組 × 2。conditionNames の番号）
%       .pValues         補正後の p 値（組ごと）
%   data.ballSpeed          体幹の最大回旋角速度と球速（群ごとに 15 名の投手）
%     .groupNames        群の名前 {'High school', 'Collegiate'}
%     .trunkVelocity     体幹の最大回旋角速度 [deg/s]（群ごとの列ベクトルを並べたセル）
%     .ballSpeed         球速 [m/s]（群ごとの列ベクトルを並べたセル）
%     .stats             全員（30 名）での相関と回帰
%       .r, .p, .n       Pearson の相関係数、両側の p 値、人数
%       .fitCoefficients 回帰直線の係数 [傾き, 切片]
%       .fitVelocity     回帰直線を描く横軸の値 [deg/s]（データの範囲）
%       .fitSpeed        回帰直線の値 [m/s]
%       .confidenceLower, .confidenceUpper  平均の予測値の 95 % 信頼区間 [m/s]
% 統計解析は、作図のスクリプトを簡潔にするためにここで行う（乱数は使わないので、データの値には影響しない）。

previousRngState = rng ;
data = struct() ;
data.kinematicSequence = createKinematicSequence() ;
data.jumpHeight = createJumpHeight() ;
data.ballSpeed = createBallSpeed() ;
data.runningGrf = createRunningGrf() ;
rng(previousRngState) ;

% 統計解析
data.jumpHeight.stats = analyzeJumpHeight(data.jumpHeight.height) ;
data.ballSpeed.stats = analyzeBallSpeed(data.ballSpeed) ;
end


% 投球の運動連鎖：各投手の角速度をガウス関数の山で作る（example_kinematic_sequence.m と同じ）
function kinematic = createKinematicSequence()
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

% 投手ごとのイベントの時刻（例のスクリプトでは、この平均をイベント線の時刻にしている）
footContactMs = -150 + 8*randn(nPitchers, 1) ; % 踏み出し足の接地 [ms]
maxExternalRotationMs = -30 + 3*randn(nPitchers, 1) ; % 肩の最大外旋 [ms]
ballReleaseMs = zeros(nPitchers, 1) ; % ボールリリース（時刻の基準）[ms]

kinematic = struct() ;
kinematic.timeMs = timeMs ;
kinematic.segmentNames = segmentNames ;
kinematic.angularVelocity = angularVelocity ;
kinematic.eventNames = {'FC', 'MER', 'BR'} ;
kinematic.eventTimesMs = [footContactMs, maxExternalRotationMs, ballReleaseMs] ;
end


% 跳躍高の条件比較：参加者 × 条件（example_jump_height.m と同じ）
function jump = createJumpHeight()
rng(2) ;
nParticipants = 10 ;
squatJumpHeight = 30 + 4*randn(nParticipants, 1) ; % SJ の跳躍高 [cm]
countermovementGain = 3 + 1.2*randn(nParticipants, 1) ; % 反動による増加 [cm]
armSwingGain = 6 + 1.5*randn(nParticipants, 1) ; % 腕の振りによる増加 [cm]

jump = struct() ;
jump.conditionNames = {'SJ', 'CMJ', 'CMJ+AS'} ;
jump.height = [squatJumpHeight, ...
               squatJumpHeight + countermovementGain, ...
               squatJumpHeight + countermovementGain + armSwingGain] ;
end


% 体幹の最大回旋角速度と球速：群ごと（example_ball_speed_scatter.m と同じ）
function speed = createBallSpeed()
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

speed = struct() ;
speed.groupNames = groupNames ;
speed.trunkVelocity = trunkVelocity ;
speed.ballSpeed = ballSpeed ;
end


% 走行の鉛直地面反力：能動ピークの山（ピークが立脚期の約 46 % になるよう時間軸をゆがめた正弦）と、
% 後足部接地だけにある衝撃の山（example_running_grf.m と同じ）
function grf = createRunningGrf()
rng(4) ;
nRunners = 12 ;
stancePercent = 0:1:100 ; % 立脚期に対する割合 [%]
groupNames = {'Rearfoot strike', 'Forefoot strike'} ;
activePeakForce = [2.5, 2.6] ; % 能動ピークの設定値 [BW]
impactPeakForce = [0.8, 0] ; % 衝撃の山の高さの設定値 [BW]（前足部接地は 0）
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

grf = struct() ;
grf.stancePercent = stancePercent ;
grf.groupNames = groupNames ;
grf.verticalForce = verticalForce ;
end


% 跳躍高の条件間の比較：対応のある t 検定（3 組）と Bonferroni 補正（example_jump_height.m と同じ計算）
% 入力：height ... 跳躍高 [cm]（参加者 × 条件）
function stats = analyzeJumpHeight(height)
nParticipants = size(height, 1) ;
pairs = [1, 2; 2, 3; 1, 3] ; % SJ-CMJ、CMJ-CMJ+AS、SJ-CMJ+AS
nComparisons = size(pairs, 1) ;
pValues = zeros(nComparisons, 1) ;
for iComparison = 1:nComparisons
    difference = height(:, pairs(iComparison, 2)) - height(:, pairs(iComparison, 1)) ; % 条件の差 [cm]
    tValue = mean(difference)/(std(difference)/sqrt(nParticipants)) ;
    pValues(iComparison) = min(1, nComparisons*twoTailedP(tValue, nParticipants - 1)) ;
end

stats = struct() ;
stats.method = 'paired t-test, Bonferroni correction (3 comparisons)' ;
stats.pairs = pairs ;
stats.pValues = pValues ;
end


% 体幹の最大回旋角速度と球速：全員での相関、回帰直線、平均の予測値の 95 % 信頼区間（example_ball_speed_scatter.m と同じ計算）
function stats = analyzeBallSpeed(speed)
allVelocity = vertcat(speed.trunkVelocity{:}) ; % 全員の体幹の最大回旋角速度 [deg/s]
allSpeed = vertcat(speed.ballSpeed{:}) ; % 全員の球速 [m/s]
nPitchers = numel(allVelocity) ;
degreesOfFreedom = nPitchers - 2 ;

% 相関係数と p 値
correlationMatrix = corrcoef(allVelocity, allSpeed) ;
r = correlationMatrix(1, 2) ;
tValue = r*sqrt(degreesOfFreedom/(1 - r^2)) ;

% 回帰直線と信頼区間
fitCoefficients = polyfit(allVelocity, allSpeed, 1) ; % [傾き, 切片]
residualSd = sqrt(sum((allSpeed - polyval(fitCoefficients, allVelocity)).^2)/degreesOfFreedom) ; % 残差の標準偏差 [m/s]
meanVelocity = mean(allVelocity) ;
velocitySumSquares = sum((allVelocity - meanVelocity).^2) ;
tCritical = tQuantileTwoTailed(0.05, degreesOfFreedom) ;
fitVelocity = linspace(min(allVelocity), max(allVelocity), 100) ; % 回帰直線はデータの範囲だけに描く
fitSpeed = polyval(fitCoefficients, fitVelocity) ;
confidenceHalfWidth = tCritical*residualSd*sqrt(1/nPitchers + (fitVelocity - meanVelocity).^2/velocitySumSquares) ;

stats = struct() ;
stats.r = r ;
stats.p = twoTailedP(tValue, degreesOfFreedom) ;
stats.n = nPitchers ;
stats.fitCoefficients = fitCoefficients ;
stats.fitVelocity = fitVelocity ;
stats.fitSpeed = fitSpeed ;
stats.confidenceLower = fitSpeed - confidenceHalfWidth ;
stats.confidenceUpper = fitSpeed + confidenceHalfWidth ;
end


% t 値と自由度から両側の p 値を求める（Statistics Toolbox の tcdf の代わり。不完全ベータ関数で計算する）
function p = twoTailedP(tValue, degreesOfFreedom)
p = betainc(degreesOfFreedom/(degreesOfFreedom + tValue^2), degreesOfFreedom/2, 0.5) ;
end


% 両側の有意水準 alpha に対応する t 分布の分位点（Statistics Toolbox の tinv の代わり。不完全ベータ関数の逆関数で計算する）
%   両側の p 値は p = betainc(df/(df + t^2), df/2, 0.5) なので、これを t について解く
function tValue = tQuantileTwoTailed(alpha, degreesOfFreedom)
betaValue = betaincinv(alpha, degreesOfFreedom/2, 0.5) ;
tValue = sqrt(degreesOfFreedom*(1/betaValue - 1)) ;
end
