% untitled_v0_jx.m
%
% 【保存版・実行非推奨】untitled.m の初版（2026-08-26 に書き換える前の状態）。
%
% RT 検出を dFx/dt（変数名 jx）のピークの 20% で行っていた版。
% 全300試行に適用したところ、次の問題が判明したため Fx 基準に置き換えた。
%
%   - RT 中央値 142 ms、生理的下限 150 ms 未満が 59%、50 ms 未満が 44試行
%   - 原因1：探索窓内で jx が正にならない試行があり、thresholdJx が負になる。
%            負の閾値は 60 行目の条件がキュー直後のノイズで即成立する
%   - 原因2：peakJx 自体が被験者内で 4〜136 倍ぶれ、基準として機能しない
%   - 根本原因：微分がノイズを増幅する一方、スイング開始時の力の立ち上がりは
%               緩やかなので dFx/dt のピークが小さく不安定になる
%
% 検証の詳細は 技術説明.md §3、現行版は untitled.m を参照。
% 比較・再現のために残しているだけなので、解析には使わないこと。
%
% 保存：2026-08-26

clear
close all
clc

%% ---- 1. データの場所と、読みたい試行を指定 ----
AnalysisDir = fullfile('..', '..', 'Experiments', 'Main experiments', '03_Analysis') ;

iSubject   = 5 ;   % 被験者番号
iCondition = 2 ;   % 1=free, 2=simple, 3=gonogo, 4=gostop
iTrial     = 7 ;   % DataArray の行番号（ファイル名上の試行番号とは別物）

%% ---- 2. 被験者1人分の .mat を読み込む ----
% x3_DataChecked/DataXX.mat の中身は DataArray（試行 × 条件 の構造体配列）
S = load( fullfile(AnalysisDir, 'x3_DataChecked', sprintf('Data%02d.mat', iSubject)) ) ;
DataArray = S.DataArray ;

%% ---- 3. 1試行だけ取り出す ----
Data = DataArray(iTrial, iCondition) ;



%% ---- 4. よく使う中身を変数に出しておく ----
fs       = Data.FrameRate ;   % マーカー系のサンプリング周波数 [Hz]
analogFs = Data.AnalogFs ;    % アナログ系（LED）の周波数 [Hz]
Markers  = Data.Markers ;     % 構造体。Markers.top などが [nFrame x 3] [mm]
ledData  = Data.LEDData ;     % [nAnalog x 2] ch1, ch2

nFrames = size(Markers.top, 1) ;
nAnalog = length(ledData) ;
t = (0:nFrames-1)' / fs ;     % 試行先頭を 0 とする時刻 [s]]
tAnalog = [0:nAnalog-1]' / analogFs ;

%% 
tGoStim = find(ledData(:,2)>1, 1, 'first') ;
t = t - tAnalog(tGoStim) ;
tAnalog = tAnalog - tAnalog(tGoStim) ;


%% force]

force1 = Data.Force1 ;
force2 = Data.Force2 ;

[b,a] = butter(2, 50/(analogFs/2), 'low') ;
force1 = filtfilt(b,a,force1) ;
force2 = filtfilt(b,a,force2) ;

force = force1 + force2 ;

fx = force(:,1) ;

tFootContact = find(force2(tGoStim:nAnalog,3)>50, 1, "first") + tGoStim - 1 

jx = diff3p(fx, 1/analogFs) ;
peakJx = max(jx(tGoStim:tFootContact))
thresholdJx = peakJx * 0.2 ;

tOnsetJx = 1 ;
for k = tGoStim:nAnalog
    if jx(k-1) < thresholdJx && jx(k) > thresholdJx
        tOnsetJx = k ;
        break
    end
end



%% marker
top = Markers.top ;
topVel = diff3p(top,1/fs) ;
topVelNorm = sum(topVel.^2,2).^0.5 ;

[peakTopVel, tPeakTopVel] = max(topVelNorm) ;


%% outcome
Result.RT = (tAnalog(tOnsetJx) - tAnalog(tGoStim))*1000 ;
Result.MT = (t(tPeakTopVel) - tAnalog(tOnsetJx) )*1000 ;
Result.PeakTopVel = peakTopVel / 1000 ; % [m/s]
Result.AveSlopeTopVel = peakTopVel/Result.MT



%% figure
figure ;
subplot(2,1,1) ;
plot(t, topVelNorm) ; hold on
xline(t(tPeakTopVel)) ;
yline(peakTopVel) ;

xline(tAnalog(tGoStim))

set(gca, 'xlim', [-1,3]) ;

subplot(4,1,3) ;
% plot(tAnalog, [force1(:,1),force2(:,1),force(:,1)]) ;
plot(tAnalog, jx) ;


xline(tAnalog(tGoStim))
xline(tAnalog(tOnsetJx))
xline(tAnalog(tFootContact))

set(gca, 'xlim', [-1,3]) ;


subplot(4,1,4) ;
plot(tAnalog, force(:,1)) ; hold on
xline(tAnalog(tGoStim))
xline(tAnalog(tOnsetJx))
xline(tAnalog(tFootContact))
set(gca, 'xlim', [-1,3]) ;


