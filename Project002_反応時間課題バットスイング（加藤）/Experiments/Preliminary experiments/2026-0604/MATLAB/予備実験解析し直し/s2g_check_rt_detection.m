% s2g_check_rt_detection.m
% 目的：m3 が出した RT が遅すぎる原因を切り分ける。
%       ① Fz1 波形にキュー・閾値・検出点を重ねて目視する
%       ② 閾値 k を変えたときに RT がどう動くかを見る
% カレントは 2026-0604/MATLAB にすること。

clear ; close all ; clc

SUBJECT   = 1 ;
CONDITION = 2 ;                % 1=free, 2=simple, 3=gonogo
TRIALS    = [13 8 1 19] ;      % 速い順に：213, 445, 565, 932 ms

ConditionNameArray = {'free','simple','gonogo'} ;
Prm = parameters ;

load(sprintf('x3_DataChecked/Data%02d', SUBJECT))
load(sprintf('x4_SingleTrialAnalysisResults/SingleTrialAnalysisResults%02d', SUBJECT))

% ---------- ① 波形の目視 ----------
figure('Name', 'Fz1 と検出点')
for i = 1:numel(TRIALS)
    iTrial = TRIALS(i) ;
    D = DataArray(iTrial, CONDITION) ;
    R = SingleTrialResultArray(iTrial, CONDITION) ;

    fsA  = D.AnalogFs ;
    Fz1  = D.Force1(:,3) ;
    tCue = find(D.LEDData(:,2) > 2, 1, 'first') ;
    t    = ((1:numel(Fz1))' - tCue) / fsA * 1000 ;   % キューを 0 ms とする

    subplot(numel(TRIALS), 1, i)
    plot(t, Fz1, 'k') ; hold on
    yline(R.Fz1BaseMean, 'b:', 'ベースライン') ;
    yline(R.Fz1BaseMean + Prm.RT.FzK*R.Fz1BaseSD, 'r--') ;
    yline(R.Fz1BaseMean - Prm.RT.FzK*R.Fz1BaseSD, 'r--') ;
    xline(0, 'g-', 'LineWidth', 1.5) ;                       % キュー
    if ~isnan(R.RT)
        xline(R.RT, 'm-', 'LineWidth', 1.5) ;                % 検出点
    end

    xlim([-500 1500]) ; ylabel('Fz1 [N]') ; grid on
    title(sprintf('%s Trial %d : RT = %.0f ms （赤破線 = 10×SD）', ...
        ConditionNameArray{CONDITION}, iTrial, R.RT)) ;
end
xlabel('キューからの時間 [ms]') ;

% ---------- ② 閾値 k のスイープ ----------
kList  = [2 3 4 5 7 10] ;
nTrial = size(DataArray, 1) ;

fprintf('\n===== Subject %02d / %s =====\n', SUBJECT, ConditionNameArray{CONDITION}) ;
fprintf('%6s %8s %10s %8s %10s\n', 'k', '検出数', '中央値', '最小', '150ms未満') ;

for k = kList
    rtAll = nan(nTrial, 1) ;
    for iTrial = 1:nTrial
        D = DataArray(iTrial, CONDITION) ;
        if ~isfield(D,'Force1') || isempty(D.Force1), continue, end
        if isnan(D.AnalogFs), continue, end

        fsA  = D.AnalogFs ;
        Fz1  = D.Force1(:,3) ;
        tCue = find(D.LEDData(:,2) > 2, 1, 'first') ;   % Go のみ
        if isempty(tCue), continue, end

        nBase = round(Prm.RT.BaseSec*fsA) ;
        if tCue - nBase < 1, continue, end
        base = Fz1(tCue-nBase : tCue-1) ;
        if any(isnan(base)), continue, end

        mu   = mean(base) ; sd = std(base) ;
        w    = tCue : min(tCue + round(Prm.RT.WinSec*fsA), numel(Fz1)) ;
        over = abs(Fz1(w) - mu) > k*sd ;
        idx  = firstSustained(over, round(Prm.RT.DurMs/1000*fsA)) ;
        if ~isempty(idx), rtAll(iTrial) = (idx-1)/fsA*1000 ; end
    end
    fprintf('%6d %8d %10.0f %8.0f %10d\n', k, sum(~isnan(rtAll)), ...
        median(rtAll,'omitnan'), min(rtAll), sum(rtAll < 150)) ;
end

% ---- 閾値超えが holdN サンプル続いた最初の位置を返す（m3・s2f と同一）----
function idx = firstSustained(over, holdN)
idx = [] ;
d = diff([0; over(:); 0]) ;
starts = find(d==1) ; ends = find(d==-1)-1 ;
run = find((ends-starts+1) >= holdN, 1, 'first') ;
if ~isempty(run), idx = starts(run) ; end
end
