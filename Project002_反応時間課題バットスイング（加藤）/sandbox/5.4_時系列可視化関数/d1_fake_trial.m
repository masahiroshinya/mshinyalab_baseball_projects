clear ; 
close all

fs      = 250 ;
dur     = 3 ;          % 記録長[s]
nSumple = dur * fs ;   % 総サンプル数 = 750

idx = (1:nSumple)' ;   % サンプル番号
t   = (idx - 1) / fs ; % 時刻[s]

% ---- 正解として決めておく値 ----
tCue   = 1.0 ;          % キュー提示の時刻[s]
rtCue  = 0.45 ;         % 真の反応時間
tOnset = tCue + rtCue ; % 動作開始の時刻

% ---- 速度波形 ----
peakVel = 5 ;
tPeak = tOnset + 0.20 ;
vel = peakVel * exp( -(t - tPeak).^2 / (2*0.08^2) ) ;

% ---- ノイズを足す ----
rng(0)
vel = vel + 0.02 * randn(nSumple, 1) ;

figure
plot(t, vel)
xlabel('Time [s]')
ylabel('Velocity [m/s]')
title('擬似1試行データ')