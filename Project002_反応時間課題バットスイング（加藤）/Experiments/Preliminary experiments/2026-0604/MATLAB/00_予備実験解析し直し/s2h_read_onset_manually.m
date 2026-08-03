% s2h_read_onset_manually.m
% 目的：Fz1 波形を1試行ずつ拡大表示し、動作開始を人がクリックして記録する。
%       ここで作った「正解」に対して、あとから k を合わせにいく。
% カレントは 2026-0604/MATLAB にすること。

clear ; close all ; clc

SUBJECT   = 1 ;
CONDITION = 2 ;              % 1=free, 2=simple, 3=gonogo
TRIALS    = 1:20 ;

load(sprintf('x3_DataChecked/Data%02d', SUBJECT))
onsetMs = nan(numel(TRIALS), 1) ;

for i = 1:numel(TRIALS)
    iTrial = TRIALS(i) ;
    D = DataArray(iTrial, CONDITION) ;

    fsA  = D.AnalogFs ;
    Fz1  = D.Force1(:,3) ;
    tCue = find(D.LEDData(:,2) > 2, 1, 'first') ;
    if isempty(tCue), continue, end

    t  = ((1:numel(Fz1))' - tCue) / fsA * 1000 ;
    mu = mean(Fz1(tCue-round(0.5*fsA) : tCue-1)) ;

    figure(1) ; clf
    plot(t, Fz1, 'k-') ; hold on
    yline(mu, 'b:') ;
    xline(0, 'g-', 'LineWidth', 1.5) ;
    xlim([-300 800]) ;
    ylim([mu-120, mu+120]) ;          % ← 縦を拡大するのが肝心
    grid on
    xlabel('キューからの時間 [ms]') ; ylabel('Fz1 [N]') ;
    title(sprintf('Trial %d：動作開始と読める点をクリック（読めなければ右クリック）', iTrial)) ;

    [x, ~, button] = ginput(1) ;
    if button == 1
        onsetMs(i) = x ;
        fprintf('Trial %2d : %6.0f ms\n', iTrial, x) ;
    else
        fprintf('Trial %2d : 見送り\n', iTrial) ;
    end
end

save('予備実験解析し直し/ManualOnset01_simple.mat', 'onsetMs', 'TRIALS') ;
fprintf('\n中央値 : %.0f ms\n', median(onsetMs,'omitnan')) ;
