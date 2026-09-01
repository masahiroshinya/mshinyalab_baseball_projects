% f4_baseline.m
%
% 目的:
%   キュー前の静止区間から体重 BWBase [N] を推定し、
%   被験者中央値から ±20% 外れる試行を計測不良として除外する判定をつくる。
%   BWBase は f6 で Fz を体重正規化する（[BW] 単位にする）ときの分母になる。
%
% 入力:
%   f1_fake_grf.m が作る Data, True
%
% 出力:
%   BWBase   ... 静止時の Fz1 + Fz2 [N]（キュー前全区間の平均）
%   sdBase1  ... キュー直前 0.5 s の Fz1 の SD [N]（f5 以降で RT 閾値に使う）
%   isBad    ... 論理配列。中央値から ±20% 外れた試行が true
%   figure 1 ... ベースライン区間を塗った Fz の時系列
%
% 備考:
%   - BWBase の窓は m3_analyze_single_trial.m に合わせてキュー前全区間とする。
%     SD 用の 0.5 s 窓（Prm.RT.BaseSec）とは目的が違うので別に取る。
%   - mean は NaN が1つでもあると全体が NaN になる。実データでは要チェック（f7）。

clear ;
close all
f1_fake_grf


%% ---- 1. 必要なものを取り出す（f3 と同じ）----

fsA     = Data.AnalogFs ;
Fz1_raw = Data.Force1(:, 3) ;
Fz2_raw = Data.Force2(:, 3) ;
nSample = numel(Fz1_raw) ;


%% ---- 2. フィルタ（f2 と同じ）----

fCut = 30 ;
nOrd = 4 ;
wn   = fCut / (fsA/2) ;               % ★ /2 を忘れると静かに 15 Hz になる

[bF, aF] = butter(nOrd, wn, 'low') ;
Fz1 = filtfilt(bF, aF, Fz1_raw) ;
Fz2 = filtfilt(bF, aF, Fz2_raw) ;


%% ---- 3. キュー時刻と時間軸（f3 と同じ）----

cueThresholdV = 2.5 ;
tCueAnalog = find( Data.LEDData(:,2) > cueThresholdV, 1, 'first' ) ;

if isempty(tCueAnalog)
    error('f4_baseline:NoCue', 'cue パルスが見つかりません')
end

tRel = ( (1:nSample)' - tCueAnalog ) / fsA ;

%% ベースライン区間を決める
%% 方式A
baseAll = 1 : tCueAnalog-1 ;

%% 方式B
baseSec = 0.5 ;
nBase   = round(baseSec * fsA) ;
baseWin = max(1, tCueAnalog - nBase) : tCueAnalog-1 ;

%% 体重推定
BWbase = mean(Fz1(baseAll)) + mean(Fz2(baseAll)) ;

BWwin = mean(Fz1(baseWin)) + mean(Fz2(baseWin)) ;

sdBase1 = std(Fz1(baseWin)) ;
sdBase2 = std(Fz2(baseWin)) ;

%% 検算
fprintf('ベースライン区間: 全区間 %d 点 / 0.5 s 窓 %d 点\n', ...
    numel(baseAll), numel(baseWin)) ;

fprintf('BWBase（全区間）= %.1f N（%.2f kg）  正解 %.1f N, 誤差 %+.2f N\n', ...
    BWBase, BWBase/9.81, True.BW, BWBase - True.BW) ;

fprintf('BWBase（0.5 s） = %.1f N（%.2f kg）  全区間との差 %+.2f N\n', ...
    BWWin, BWWin/9.81, BWWin - BWBase) ;

fprintf('内訳: mean Fz1 = %.2f N, mean Fz2 = %.2f N（Fz2 は 0 付近が正常）\n', ...
    mean(Fz1(baseAll)), mean(Fz2(baseAll))) ;

fprintf('ベースライン SD: Fz1 = %.3f N, Fz2 = %.3f N（10SD = %.1f N ≒ %.1f %%BW）\n', ...
    sdBase1, sdBase2, 10*sdBase1, 10*sdBase1/BWBase*100) ;

%% 計測不良の除外判定
BWList = [BWBase, 716.1, 700.5, 255.1, 378.6, 730.0] ;

tol   = 0.2 ;
bwRef = median(BWList, 'omitnan') ;

isBad = isnan(BWList) | abs(BWList - bwRef) ;

fprintf('\n中央値 = %.1f N, 許容範囲 %.1f 〜 %.1f N（±%d%%）\n', ...
    bwRef, (1-tol)*bwRef, (1+tol)*bwRef, tol*100) ;