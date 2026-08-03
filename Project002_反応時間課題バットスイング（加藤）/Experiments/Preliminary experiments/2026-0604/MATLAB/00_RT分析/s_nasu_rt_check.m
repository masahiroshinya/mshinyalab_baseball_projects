function s_nasu_rt_check()

% Nasu et al. (2020) 方式のスイング開始検出と、床反力（後ろ足 Fz1）による
% 動作開始検出を比較する（2026-08-03 テストデータ用）。
% 今回はアナログの LED 信号がないため、計測開始（t=0）をキュー提示時刻とみなす。

Prm = parameters ;

folderName = fullfile('x1_RawData', '2026-0803_RT_check') ;
fileNames  = {'RT_6DOF0001', 'RT_6DOF0002', 'RT_6DOF0004', 'RT_6DOF0006'} ;
nTrial     = numel(fileNames) ;

% ---- 第1パス：全試行を読み込み、投手方向の手部速度とそのピークを求める ----
%  閾値は全試行の平均ピーク速度に依存するので、先に全試行分を出しておく。
S = struct('velHandX', {}, 'Fz1', {}, 'fs', {}, 'fsA', {}) ;
peakVel = nan(nTrial, 1) ;

for iTrial = 1:nTrial

    Data = load_qualisys_mat(folderName, fileNames{iTrial}) ;

    fs  = Data.FrameRate ;
    fsA = size(Data.Force1, 1) / (Data.Frames / fs) ;   % = 1000 Hz
    [b, a] = butter(2, Prm.Fc/(fs/2)) ;

    % マーカーごとに補間 → 重心 → フィルタ（この順序が必須。§2.3）
    hand = filtfilt(b, a, mean_marker(Data.Markers, {'Firtst', 'Second', 'Third'})) ;
    pelv = filtfilt(b, a, mean_marker(Data.Markers, {'RASIS', 'LASIS', 'RRPSIS', 'LPSIS'})) ;

    % 手部から骨盤を引き、体幹の並進成分を除く。
    % 単位は mm なので 1000 で割って m にしてから微分する。
    relPos   = (hand - pelv) / 1000 ;                 % [m]
    velRel   = diff3p(relPos, 1/fs) ;                 % [m/s]
    velHandX = velRel(:, 1) ;                         % +X = 投手方向

    S(iTrial).velHandX = velHandX ;
    S(iTrial).Fz1      = Data.Force1(:, 3) ;          % 符号は読み込み時に反転済み
    S(iTrial).fs       = fs ;
    S(iTrial).fsA      = fsA ;

    peakVel(iTrial) = max(velHandX) ;                 % 投手方向の最大値＝スイング本体
end

% ---- 相対閾値：平均ピーク速度の 10% ----
thrVel = 0.10 * mean(peakVel) ;

% ---- 第2パス：スイング開始と床反力の動作開始を検出 ----
Result = table('Size', [nTrial 5], ...
    'VariableTypes', {'string','double','double','double','double'}, ...
    'VariableNames', {'Trial','PeakVel','RTHand','RTForce','Diff'}) ;

for iTrial = 1:nTrial

    fs  = S(iTrial).fs ;
    fsA = S(iTrial).fsA ;
    v   = S(iTrial).velHandX ;

    % スイング開始：ピークから時間を遡り、閾値を下回った最初の点（§2.3）
    [~, idxPeak] = max(v) ;
    idxOn = find(v(1:idxPeak) <= thrVel, 1, 'last') ;
    tHand = idxOn / fs ;                              % [s] キュー = t=0

    % 床反力：キュー直後 0.5 秒を静止区間とし、
    % |Fz1 - mu| > k*sd が 30 ms 続いた最初の時点を動作開始とする。
    Fz1   = S(iTrial).Fz1 ;
    nBase = round(Prm.RT.BaseSec * fsA) ;
    mu    = mean(Fz1(1:nBase)) ;
    sd    = std(Fz1(1:nBase)) ;

    thrFz = Prm.RT.FzK * sd ;
    over  = abs(Fz1 - mu) > thrFz ;
    holdN = round(Prm.RT.DurMs/1000 * fsA) ;
    idxF  = first_sustained(over, holdN) ;
    tForce = idxF / fsA ;                             % [s]

    Result.Trial(iTrial)   = fileNames{iTrial} ;
    Result.PeakVel(iTrial) = peakVel(iTrial) ;
    Result.RTHand(iTrial)  = tHand  * 1000 ;          % [ms]
    Result.RTForce(iTrial) = tForce * 1000 ;          % [ms]
    Result.Diff(iTrial)    = (tHand - tForce) * 1000 ;

    plot_trial(S(iTrial), thrVel, mu, thrFz, tHand, tForce, fileNames{iTrial}) ;
end

fprintf('\n閾値（平均ピーク %.2f m/s の 10%%）= %.3f m/s\n\n', mean(peakVel), thrVel) ;
disp(Result)

end


% ---- 指定マーカーの幾何学的重心 ----
%  各マーカーを個別に補間してから平均する（§2.3）。
function y = mean_marker(Markers, names)
x = nan(size(Markers.(names{1}), 1), 3, numel(names)) ;
for i = 1:numel(names)
    x(:,:,i) = interp_nan_linear(Markers.(names{i})) ;
end
y = mean(x, 3) ;
end


% ---- 列ごとに NaN を線形補間 ----
function x = interp_nan_linear(x)
t = (1:size(x,1))' ;
for col = 1:size(x,2)
    nanIdx = isnan(x(:,col)) ;
    if any(nanIdx) && any(~nanIdx)
        x(nanIdx,col) = interp1(t(~nanIdx), x(~nanIdx,col), t(nanIdx), 'linear', 'extrap') ;
    end
end
end


% ---- 閾値超えが holdN サンプル続いた最初の位置（m3 と同じロジック）----
function idx = first_sustained(over, holdN)
idx = [] ;
d = diff([0; over(:); 0]) ;
starts = find(d==1) ; ends = find(d==-1)-1 ;
run = find((ends-starts+1) >= holdN, 1, 'first') ;
if ~isempty(run), idx = starts(run) ; end
end


% ---- 手部速度と Fz1 を時間軸を揃えて重ね描き ----
%  縦線 = onset（赤 = 手部、青 = 床反力）、破線 = 検出に使った閾値。
%  onset の時刻はタイトルに出す（波形の上には重ねない）。
function plot_trial(s, thrVel, mu, thrFz, tHand, tForce, name)
tM = (1:numel(s.velHandX))' / s.fs ;
tA = (1:numel(s.Fz1))'      / s.fsA ;

figure('Name', name) ;

subplot(2,1,1)
plot(tM, s.velHandX, 'k') ; hold on
yline(thrVel, 'r--') ;
xline(tForce, 'b') ; xline(tHand, 'r') ;
ylabel('手部速度 X [m/s]') ; xlim([0 5])
title(sprintf('%s   手部 %.0f ms / 床反力 %.0f ms （差 %+.0f ms）', ...
      name, tHand*1000, tForce*1000, (tHand-tForce)*1000), 'Interpreter', 'none')

subplot(2,1,2)
plot(tA, s.Fz1, 'k') ; hold on
yline(mu + [-1 1] * thrFz, 'r--') ;
xline(tForce, 'b') ; xline(tHand, 'r') ;
ylabel('後ろ足 Fz1 [N]') ; xlabel('計測開始からの時間 [s]') ; xlim([0 5])
end