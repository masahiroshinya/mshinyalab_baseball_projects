clear ;
close all

%% ---- 1. 疑似データ（d1 と同じ）----
fs      = 250 ;
dur     = 3 ;
nSample = dur * fs ;

idx = (1:nSample)' ;
t   = (idx - 1) / fs ;

tCue   = 1.0 ;
rtTrue = 0.45 ;
tOnset = tCue + rtTrue ;

peakVel = 5 ;
tPeak   = tOnset + 0.20 ;
vel     = peakVel * exp( -(t - tPeak).^2 / (2*0.08^2) ) ;

rng(0)
vel = vel + 0.02 * randn(nSample, 1) ;

%% ---- 2. 時間軸をキュー基準に直す ----
tRel = t - tCue ; % キューが0になる

%% ---- 3. ベースライン統計と閾値 ----
isBase = tRel >= -0.5 & tRel < 0 ;
baseMean = mean( vel(isBase) ) ;
baseSD   = std(  vel(isBase) ) ;

k   = 10 ; % 実データと同じく
thr = baseMean + k * baseSD ;

fprintf('baseMean = %.4f, baseSD = %.4f, thr = %.4f m/s\n', baseMean, baseSD, thr)

%% ---- 4. 描画 ----
figure
ax = axes ;

plot(tRel, vel, 'k', 'LineWidth', 1.0, 'DisplayName', 'HandVelocity')
hold on

set(ax, 'Xlim', [-0.5 1.5])

