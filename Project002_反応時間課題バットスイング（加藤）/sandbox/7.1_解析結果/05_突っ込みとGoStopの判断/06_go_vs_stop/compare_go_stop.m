% compare_go_stop.m
%
% Go/Stop 条件の Go 試行と Stop 試行で、バット先端（top）の動きがいつ分かれるかを調べる。
% 1 回目の Go cue を 0 にそろえる（2 回目の刺激は Go でも Stop でも 350 ms 後）。
%
% 分かれ始めた時刻（主に使う）：
%   被験者ごとに Go 試行・Stop 試行の平均の曲線を作り、各時刻で 10 名の対応のある t 検定をする。
%   2 回目の刺激より後で、p < .05 が MinDurMs 続いた最初の時刻（速さと X のそれぞれ）。
% 分かれた時刻（Stop 試行ごと、参考）：
%   同じ被験者の Go 試行の速さの「平均 − 2 SD」を Stop 試行の速さが下回り、MinDurMs 続いた最初の時刻。
%   Go 試行は振り始めのばらつきで加速の時期がずれ、SD が大きくなるので、この基準は遅めに出る
% 比べる相手：Go 試行の HT の終わり（Go cue から、RT + HT の平均）
%
% 試行：Go 試行 = x8 の除外のあと MT がある Go 試行。Stop 試行 = Onset があり、top の品質に問題がなく、RT ≥ 150 ms の試行
%   （x8 の IsShortRT は Go 試行にしか付かないので、Stop 試行の見越し反応はここで除く）
% top：NaN の線形補間 → 30 Hz の 2 次 Butterworth で filtfilt → m。速さは中心差分（250 Hz）
%
% 2026-11-09（2026-11-11：Stop 試行の見越し反応を除き、速さの向きの限定をやめた）

%% 設定
T2ms     = 350 ;
WinMs    = [-100 1000] ;    % Go cue からの範囲
MinDurMs = 20 ;             % 下回った状態が続く長さ
NSD      = 2 ;

scriptFolder   = fileparts(mfilename('fullpath')) ;
projectFolder  = fullfile(scriptFolder, '..', '..', '..', '..') ;   % Project002 のフォルダ
analysisFolder = fullfile(projectFolder, 'Experiments', 'Main experiments', '03_Analysis') ;
outFolder      = fullfile(scriptFolder, 'output') ;
addpath(analysisFolder) ;
Prm = parameters ;
load(fullfile(analysisFolder, 'x8_StatTable', 'StatTable.mat'), 'TrialTable') ;
T = TrialTable(TrialTable.Condition == "gostop", :) ;
T.Use = (T.CueText == "Go"   & ~isnan(T.MT_ms) & ~isnan(T.HookTime_ms)) | ...
        (T.CueText == "Stop" & ~isnan(T.SwingOnsetForce) & ~T.IsBadTop & T.RTForce_ms >= Prm.RT.FloorMs) ;
T = T(T.Use, :) ;
Subjects = unique(T.Subject)' ;

fsM  = 250 ;
tAx  = (WinMs(1) : 1000/fsM : WinMs(2))' ;   % Go cue からの時刻 [ms]（4 ms ごと）
nT   = numel(tAx) ;
Spd  = NaN(height(T), nT) ;                   % top の速さ [m/s]
PosX = NaN(height(T), nT) ;                   % top の X（Go cue の位置を 0）[m]

%% 試行ごとに曲線を取り出す
for iSubject = Subjects
    fprintf('S%02d の x3 を読み込み中...\n', iSubject) ;
    S = load(fullfile(analysisFolder, 'x3_DataChecked', sprintf('Data%02d.mat', iSubject)), 'DataArray') ;
    for r = find(T.Subject == iSubject)'
        Data = S.DataArray(T.Trial(r), 4) ;
        fsA = Data.AnalogFs ;  fsMk = Data.FrameRate ;
        top = prepMarker(Data.Markers.top, fsMk, Prm.Fc) ;
        v   = [NaN(1,3) ; (top(3:end,:) - top(1:end-2,:)) * fsMk / 2 ; NaN(1,3)] ;
        sp  = sqrt(sum(v.^2, 2)) ;
        tCue = find(Data.LEDData(:,2) > Prm.Cue.GoThresholdV, 1, 'first') ;
        tM   = ((1:size(top,1))' / fsMk * fsA - tCue) / fsA * 1000 ;   % 各フレームの Go cue からの時刻
        Spd(r, :)  = interp1(tM, sp, tAx) ;
        x0         = interp1(tM, top(:,1), 0) ;
        PosX(r, :) = interp1(tM, top(:,1), tAx) - x0 ;
    end
    clear S
end

%% 分かれ始めた時刻（被験者平均の曲線どうしの、各時刻の対応のある t 検定）
isGo = T.CueText == "Go" ;
nDur = round(MinDurMs / (1000/fsM)) ;
kStart = find(tAx >= T2ms, 1) ;
TDivGroup = NaN(1, 2) ;  Pt = cell(1, 2) ;
for p = 1:2
    Y = Spd ;  if p == 2, Y = PosX ; end
    Mg = NaN(numel(Subjects), nT) ;  Ms = Mg ;
    for is = 1:numel(Subjects)
        Mg(is, :) = mean(Y(isGo  & T.Subject == Subjects(is), :), 1, 'omitnan') ;
        Ms(is, :) = mean(Y(~isGo & T.Subject == Subjects(is), :), 1, 'omitnan') ;
    end
    [~, pv] = ttest(Mg, Ms) ;
    sig = pv < 0.05 ;  sig(1:kStart-1) = false ;
    run = conv(double(sig), ones(1, nDur), 'valid') == nDur ;
    k = find(run, 1, 'first') ;
    if ~isempty(k), TDivGroup(p) = tAx(k) ; end
    Pt{p} = pv ;
end
fprintf('分かれ始めた時刻（対応のある t 検定、p < .05 が %d ms 続いた最初）：速さ %.0f ms、X %.0f ms（Go cue から）\n', MinDurMs, TDivGroup) ;
rg = groupsummary(T(isGo, :), 'Subject', 'mean', 'RTForce_ms') ;  rs = groupsummary(T(~isGo, :), 'Subject', 'mean', 'RTForce_ms') ;
[~, pRT] = ttest(rs.mean_RTForce_ms, rg.mean_RTForce_ms) ;
fprintf('RT：Go %.0f ms、Stop %.0f ms（p = %.3f）\n', mean(rg.mean_RTForce_ms), mean(rs.mean_RTForce_ms), pRT) ;
fprintf('  2 回目の刺激から：速さ %.0f ms、X %.0f ms\n', TDivGroup - T2ms) ;

%% 分かれた時刻（Stop 試行ごと、参考）
T.TDiv_ms = NaN(height(T), 1) ;
SubRes = table() ;
for iSubject = Subjects
    g = isGo & T.Subject == iSubject ;
    s = ~isGo & T.Subject == iSubject ;
    lo = mean(Spd(g, :), 1, 'omitnan') - NSD * std(Spd(g, :), 0, 1, 'omitnan') ;
    for r = find(s)'
        below = Spd(r, :) < lo ;
        below(1:kStart-1) = false ;
        run = conv(double(below), ones(1, nDur), 'valid') == nDur ;
        k = find(run, 1, 'first') ;
        if ~isempty(k), T.TDiv_ms(r) = tAx(k) ; end
    end
    htEnd = mean(T.RTForce_ms(g) + T.HookTime_ms(g)) ;
    onGo  = mean(T.RTForce_ms(g)) ;
    SubRes = [SubRes ; table(iSubject, sum(g), sum(s), onGo, htEnd, median(T.TDiv_ms(s), 'omitnan'), sum(~isnan(T.TDiv_ms(s))), ...
        'VariableNames', {'Subject', 'nGo', 'nStop', 'GoOnset_ms', 'GoHTEnd_ms', 'StopDiv_ms', 'nDiv'})] ; %#ok<AGROW>
end
disp(SubRes) ;
d = SubRes.StopDiv_ms - SubRes.GoHTEnd_ms ;
fprintf('（参考）Stop 試行ごとの分かれた時刻（Go cue から、被験者の中央値の平均）：%.0f ms（2 回目の刺激から %.0f ms）\n', mean(SubRes.StopDiv_ms, 'omitnan'), mean(SubRes.StopDiv_ms, 'omitnan') - T2ms) ;
fprintf('Go の HT の終わり（平均）：%.0f ms。分かれた時刻 − HT の終わり：平均 %.0f ms（範囲 %.0f〜%.0f）、HT の終わりより前の被験者 %d/%d\n', ...
    mean(SubRes.GoHTEnd_ms), mean(d, 'omitnan'), min(d), max(d), sum(d < 0), sum(~isnan(d))) ;
sd = T(~isGo, :) ;
dTrial = sd.TDiv_ms - SubRes.GoHTEnd_ms(arrayfun(@(x) find(SubRes.Subject == x), sd.Subject)) ;
fprintf('Stop 試行ごと：分かれた %d / %d 本。そのうち Go の HT の終わりより前 %d 本\n', sum(~isnan(dTrial)), height(sd), sum(dTrial < 0)) ;

%% 図
fig = figure('Color', 'w', 'Position', [60 60 1300 430]) ;
tl  = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact') ;
title(tl, sprintf('Go/Stop：Go 試行と Stop 試行の比較（%d 名、Go %d 本・Stop %d 本）', numel(Subjects), sum(isGo), sum(~isGo))) ;
Col = [0.10 0.60 0.10 ; 0.85 0.15 0.15] ;
for p = 1:2
    ax = nexttile(tl) ; hold(ax, 'on') ; grid(ax, 'on') ;
    Y = Spd ; yl = '先端の速さ (m/s)' ;
    if p == 2, Y = PosX ; yl = '先端の X（Go cue の位置を 0）(m)' ; end
    for c = 1:2
        k = isGo == (c == 1) ;
        M = NaN(numel(Subjects), nT) ;
        for is = 1:numel(Subjects)
            M(is, :) = mean(Y(k & T.Subject == Subjects(is), :), 1, 'omitnan') ;
        end
        mu = mean(M, 1, 'omitnan') ; se = std(M, 0, 1, 'omitnan') / sqrt(numel(Subjects)) ;
        fill(ax, [tAx ; flipud(tAx)], [mu - se, fliplr(mu + se)]', Col(c,:), 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off') ;
        h(c) = plot(ax, tAx, mu, '-', 'Color', Col(c,:), 'LineWidth', 2) ; %#ok<SAGROW>
    end
    xline(ax, T2ms, 'k--', '2 回目の刺激', 'LabelVerticalAlignment', 'bottom', 'FontSize', 9) ;
    xline(ax, mean(SubRes.GoOnset_ms), 'k:', 'Onset', 'LabelVerticalAlignment', 'bottom', 'FontSize', 9) ;
    xline(ax, mean(SubRes.GoHTEnd_ms), '-', 'HT の終わり（Go）', 'Color', [0.9 0.6 0], 'LineWidth', 1.5, 'LabelVerticalAlignment', 'bottom', 'FontSize', 9) ;
    if ~isnan(TDivGroup(p))
        xline(ax, TDivGroup(p), '-', sprintf('分かれ始め %.0f ms', TDivGroup(p)), 'Color', Col(2,:), 'LineWidth', 1.5, 'LabelVerticalAlignment', 'top', 'FontSize', 9) ;
    end
    xlabel(ax, '1 回目の Go cue からの時間 (ms)') ; ylabel(ax, yl) ; xlim(ax, [0 1000]) ;
    legend(ax, h, {'Go 試行', 'Stop 試行'}, 'Location', 'northwest') ;
    title(ax, '平均 ± SE（被験者平均の平均）', 'FontWeight', 'normal') ;
end
ax = nexttile(tl) ; hold(ax, 'on') ; grid(ax, 'on') ;
for is = 1:numel(Subjects)
    plot(ax, [SubRes.GoHTEnd_ms(is) SubRes.StopDiv_ms(is)], is * [1 1], '-', 'Color', [0.7 0.7 0.7]) ;
end
h1 = scatter(ax, SubRes.GoHTEnd_ms, 1:numel(Subjects), 40, [0.9 0.6 0], 'filled') ;
h2 = scatter(ax, SubRes.StopDiv_ms, 1:numel(Subjects), 40, Col(2,:), 'filled') ;
xline(ax, T2ms, 'k--') ;
ax.YTick = 1:numel(Subjects) ; ax.YTickLabel = compose('S%02d', Subjects) ; ax.YDir = 'reverse' ;
xlabel(ax, '1 回目の Go cue からの時間 (ms)') ; xlim(ax, [300 1000]) ;
legend(ax, [h1 h2], {'Go の HT の終わり', 'Stop が分かれた時刻（参考：試行ごとの基準、中央値）'}, 'Location', 'southoutside') ;
title(ax, '被験者ごと（参考）', 'FontWeight', 'normal') ;

if ~exist(outFolder, 'dir'), mkdir(outFolder) ; end
exportgraphics(fig, fullfile(outFolder, 'compare_go_stop.png'), 'Resolution', 200) ;
writetable(T(:, {'Subject', 'Trial', 'CueText', 'RTForce_ms', 'HookTime_ms', 'TDiv_ms'}), fullfile(outFolder, 'compare_go_stop_trial.csv')) ;
fprintf('output/ に PNG と CSV を保存しました\n') ;

%% ローカル関数
function x = prepMarker(x, fs, fc)
% NaN を線形補間して、2 次 Butterworth で filtfilt し、m に直す（top_trajectory_3d と同じ）
t = (1:size(x,1))' ;
for col = 1:3
    nanIdx = isnan(x(:,col)) ;
    if any(nanIdx) && any(~nanIdx)
        x(nanIdx,col) = interp1(t(~nanIdx), x(~nanIdx,col), t(nanIdx), 'linear', 'extrap') ;
    end
end
[b, a] = butter(2, fc/(fs/2)) ;
x = filtfilt(b, a, x) / 1000 ;
end