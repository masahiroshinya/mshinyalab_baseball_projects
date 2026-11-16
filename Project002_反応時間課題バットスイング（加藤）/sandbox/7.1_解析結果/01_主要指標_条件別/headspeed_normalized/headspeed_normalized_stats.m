% ヘッドスピード（PeakVelTop：バット先端 top のピーク合成速度）を、被験者ごとのフリー条件の平均で正規化し、
% フリー条件に対する変化率（%）で条件を比べる。学会のポスター発表の後に受けた依頼
% 「フリー条件のヘッドスピードを基準に他の条件を正規化し、対応なしで検定した結果」への回答用。
%
% 変化率 = (その条件のヘッドスピード / その被験者のフリー条件の平均 − 1) × 100
%
% 2 つの単位で計算する（依頼の「対応なし」がどちらを指すかが分からないため）：
%   A. 被験者単位（n = 10）：被験者ごとの条件平均を変化率にする。フリーは全員 0% になるので比較に入れず、
%      A1 = 各条件の変化率が 0 と違うか（1 標本 t 検定、Holm 3 組。確認用に Wilcoxon の符号付順位検定）
%      A2 = 反応課題 3 条件の変化率の比較を対応なしで（一元配置分散分析・Kruskal-Wallis、対応のない t 検定 Holm 3 組）
%      A3 = 参考：同じ比較を対応ありで（対応のある t 検定 Holm 3 組）
%   B. 試行単位（455 試行）：試行ごとの値をその被験者のフリーの平均で割る。フリーの試行にもばらつきが残るので 4 条件を比べる。
%      一元配置分散分析・Kruskal-Wallis、Levene 検定、Welch の t 検定 Holm 6 組
%      （試行を独立とみなすので、被験者の中の試行の似かよい（擬似反復）を無視することに注意）
%
% データ：x8_StatTable/stat_table_trial.csv（x8_make_stat_table.m の出力）。除外の後の Go 試行（PeakVelTop が NaN でない試行）を使う。
%   被験者 × 条件の平均は stat_table_subject.csv の PeakVelTop と一致する。
% C. Go/Stop − Simple の差を、被験者ごと（試行から、95% 信頼区間）と、2 つのまとめ方（試行単位・対応なし／被験者単位・対応あり）で求める。
%   B の有意差が被験者単位で残らない理由（差の向きが被験者で違う）を示すため（2026-11-16 に追加）。
% 出力：output/ に変化率の CSV（被験者単位・試行単位）、C の差の CSV、図（PNG。A・B・C）
%
% 2026-11-16 加藤 和太郎（AI 補助で作成した案）

%% 準備
toolFolder = fileparts(mfilename('fullpath')) ;
projectFolder = fullfile(toolFolder, '..', '..', '..', '..') ; % Project002 のフォルダ
dataFile = fullfile(projectFolder, 'Experiments', 'Main experiments', '03_Analysis', 'x8_StatTable', 'stat_table_trial.csv') ;
outDir = fullfile(toolFolder, 'output') ;
if ~exist(outDir, 'dir'), mkdir(outDir) ; end

CondArray  = {'free', 'simple', 'gonogo', 'gostop'} ;
CondLabel  = {'Free', 'Simple', 'Go/No-go', 'Go/Stop'} ;
ReactArray = CondArray(2:4) ; % 反応課題の 3 条件

%% データ：除外の後の Go 試行
T = readtable(dataFile, 'TextType', 'string') ;
T = T(T.IsGo == 1 & ~isnan(T.PeakVelTop), {'Subject', 'Condition', 'Trial', 'PeakVelTop'}) ;
SubjectArray = unique(T.Subject)' ;
nS = numel(SubjectArray) ;

% 被験者 × 条件の平均（行 = 被験者、列 = CondArray）
V = nan(nS, numel(CondArray)) ;
for iS = 1:nS
    for ic = 1:numel(CondArray)
        V(iS,ic) = mean(T.PeakVelTop(T.Subject == SubjectArray(iS) & T.Condition == CondArray{ic})) ;
    end
end
freeMean = V(:,1) ;

%% A. 被験者単位の変化率（n = 10）
Rate = (V(:,2:4)./freeMean - 1)*100 ; % 列 = ReactArray
fprintf('\n== A. 被験者単位の変化率（%%）、n = %d ==\n', nS) ;
for ic = 1:3
    fprintf('  %-7s %6.2f ± %.2f（最小 %.2f、最大 %.2f）\n', ReactArray{ic}, mean(Rate(:,ic)), std(Rate(:,ic)), min(Rate(:,ic)), max(Rate(:,ic))) ;
end

% A1：変化率が 0 と違うか（1 標本 t 検定、Holm 3 組）
p = zeros(3,1) ; t = zeros(3,1) ; pW = zeros(3,1) ;
for ic = 1:3
    [~, p(ic), ~, st] = ttest(Rate(:,ic)) ; t(ic) = st.tstat ;
    pW(ic) = signrank(Rate(:,ic)) ;
end
pH = holm(p) ;
fprintf('A1 変化率 ≠ 0（1 標本 t 検定、Holm 3 組）\n') ;
for ic = 1:3
    fprintf('  %-7s t(%d) = %5.2f, p = %.3f, pHolm = %.3f, d = %5.2f（Wilcoxon p = %.3f）\n', ...
        ReactArray{ic}, nS - 1, t(ic), p(ic), pH(ic), mean(Rate(:,ic))/std(Rate(:,ic)), pW(ic)) ;
end

% A2：3 条件の比較、対応なし
y = Rate(:) ; g = repelem(ReactArray(:), nS) ;
[pA, tbl] = anova1(y, g, 'off') ;
[pK, tblK] = kruskalwallis(y, g, 'off') ;
pL = vartestn(y, g, 'TestType', 'LeveneAbsolute', 'Display', 'off') ;
fprintf('A2 3 条件の比較、対応なし\n') ;
fprintf('  一元配置分散分析 F(%d, %d) = %.2f, p = %.3f ／ Kruskal-Wallis χ²(%d) = %.2f, p = %.3f ／ Levene p = %.3f\n', ...
    tbl{2,3}, tbl{3,3}, tbl{2,5}, pA, tblK{2,3}, tblK{2,5}, pK, pL) ;
Pairs = nchoosek(1:3, 2) ;
p = zeros(3,1) ; t = zeros(3,1) ; df = zeros(3,1) ;
for k = 1:3
    [~, p(k), ~, st] = ttest2(Rate(:,Pairs(k,1)), Rate(:,Pairs(k,2))) ; t(k) = st.tstat ; df(k) = st.df ;
end
pH = holm(p) ;
for k = 1:3
    fprintf('  対応のない t 検定 %s - %s：t(%d) = %5.2f, p = %.3f, pHolm = %.3f\n', ReactArray{Pairs(k,:)}, df(k), t(k), p(k), pH(k)) ;
end

% A3：参考、対応あり
fprintf('A3 参考：対応のある t 検定（Holm 3 組）\n') ;
for k = 1:3
    [~, p(k), ~, st] = ttest(Rate(:,Pairs(k,1)), Rate(:,Pairs(k,2))) ; t(k) = st.tstat ;
end
pH = holm(p) ;
for k = 1:3
    fprintf('  %s - %s：t(%d) = %5.2f, p = %.3f, pHolm = %.3f\n', ReactArray{Pairs(k,:)}, nS - 1, t(k), p(k), pH(k)) ;
end

%% B. 試行単位の変化率（全試行）
[~, iSubj] = ismember(T.Subject, SubjectArray) ;
T.Rate = (T.PeakVelTop./freeMean(iSubj) - 1)*100 ;
fprintf('\n== B. 試行単位の変化率（%%）==\n') ;
for ic = 1:4
    r = T.Rate(T.Condition == CondArray{ic}) ;
    fprintf('  %-7s n = %3d, %5.2f ± %.2f\n', CondArray{ic}, numel(r), mean(r), std(r)) ;
end
[pA, tbl] = anova1(T.Rate, T.Condition, 'off') ;
[pK, tblK] = kruskalwallis(T.Rate, T.Condition, 'off') ;
pL = vartestn(T.Rate, T.Condition, 'TestType', 'LeveneAbsolute', 'Display', 'off') ;
fprintf('  一元配置分散分析 F(%d, %d) = %.2f, p = %.3f ／ Kruskal-Wallis χ²(%d) = %.2f, p = %.3f ／ Levene p = %.3f\n', ...
    tbl{2,3}, tbl{3,3}, tbl{2,5}, pA, tblK{2,3}, tblK{2,5}, pK, pL) ;
Pairs = nchoosek(1:4, 2) ;
nP = size(Pairs, 1) ;
p = zeros(nP,1) ; t = zeros(nP,1) ; df = zeros(nP,1) ;
for k = 1:nP
    [~, p(k), ~, st] = ttest2(T.Rate(T.Condition == CondArray{Pairs(k,1)}), T.Rate(T.Condition == CondArray{Pairs(k,2)}), 'Vartype', 'unequal') ;
    t(k) = st.tstat ; df(k) = st.df ;
end
pH = holm(p) ;
for k = 1:nP
    fprintf('  Welch の t 検定 %s - %s：t(%.1f) = %5.2f, p = %.3f, pHolm = %.3f\n', CondArray{Pairs(k,:)}, df(k), t(k), p(k), pH(k)) ;
end

%% C. Go/Stop − Simple の差：被験者ごとと、2 つのまとめ方
% 被験者ごと：その被験者の Go/Stop の試行と Simple の試行の変化率の平均の差と、95% 信頼区間（Welch の t 検定の区間）。
%   差は A の Rate(:,3) − Rate(:,1) と同じ値になる。
% まとめ①（試行単位・対応なし）：全被験者の試行をまとめた差と 95% 信頼区間（B の Welch の t 検定と同じ）
% まとめ②（被験者単位・対応あり）：被験者ごとの差の平均と 95% 信頼区間（A3 の対応のある t 検定と同じ、n = 10）
DiffSubj = nan(nS, 3) ; % 列 = 差、95% 信頼区間の下限、上限
for iS = 1:nS
    xG = T.Rate(T.Subject == SubjectArray(iS) & T.Condition == "gostop") ;
    xS = T.Rate(T.Subject == SubjectArray(iS) & T.Condition == "simple") ;
    [~, ~, ci] = ttest2(xG, xS, 'Vartype', 'unequal') ;
    DiffSubj(iS,:) = [mean(xG) - mean(xS), ci'] ;
end
xG = T.Rate(T.Condition == "gostop") ;
xS = T.Rate(T.Condition == "simple") ;
[~, ~, ci] = ttest2(xG, xS, 'Vartype', 'unequal') ;
DiffTrial = [mean(xG) - mean(xS), ci'] ;
[~, ~, ci] = ttest(Rate(:,3) - Rate(:,1)) ;
DiffPaired = [mean(Rate(:,3) - Rate(:,1)), ci'] ;
fprintf('\n== C. Go/Stop − Simple の差（%%、95%% 信頼区間）==\n') ;
for iS = 1:nS
    fprintf('  S%02d  %5.2f [%5.2f, %5.2f]\n', SubjectArray(iS), DiffSubj(iS,:)) ;
end
fprintf('  試行単位・対応なし   %5.2f [%5.2f, %5.2f]\n', DiffTrial) ;
fprintf('  被験者単位・対応あり %5.2f [%5.2f, %5.2f]\n', DiffPaired) ;

%% 書き出し：変化率の CSV
RateTable = array2table([SubjectArray(:), V, Rate], 'VariableNames', ...
    [{'Subject'}, strcat('PeakVelTop_', CondArray), strcat('Rate_', ReactArray)]) ;
writetable(RateTable, fullfile(outDir, 'headspeed_rate_subject.csv')) ;
writetable(T, fullfile(outDir, 'headspeed_rate_trial.csv')) ;
DiffTable = array2table([[SubjectArray(:) ; NaN ; NaN], [DiffSubj ; DiffTrial ; DiffPaired]], ...
    'VariableNames', {'Subject', 'Diff', 'CILow', 'CIHigh'}) ;
DiffTable.Row = [compose('S%02d', SubjectArray(:)) ; {'trial_unpaired'} ; {'subject_paired'}] ;
writetable(DiffTable, fullfile(outDir, 'headspeed_diff_gostop_simple.csv'), 'WriteRowNames', true) ;

%% 図：A = 被験者単位の変化率、B = 試行単位の変化率、C = Go/Stop − Simple の差
fig = figure('Units', 'centimeters', 'Position', [2, 2, 27, 8]) ;
ax = subplot(1, 3, 1) ; hold(ax, 'on') ;
plot(ax, 1:3, Rate', '-', 'Color', [0.75, 0.75, 0.75]) ;
errorbar(ax, 1:3, mean(Rate), std(Rate), 'ko', 'MarkerFaceColor', 'k', 'LineWidth', 1) ;
yline(ax, 0, 'k--') ;
xlim(ax, [0.5, 3.5]) ; xticks(ax, 1:3) ; xticklabels(ax, CondLabel(2:4)) ;
ylabel(ax, 'Change from Free (%)') ; title(ax, sprintf('A. Subject means (n = %d)', nS)) ;
ax = subplot(1, 3, 2) ; hold(ax, 'on') ;
rng(0) ; % 試行の点を横にずらす量（乱数）を、実行のたびに同じにする
for ic = 1:4
    r = T.Rate(T.Condition == CondArray{ic}) ;
    scatter(ax, ic + 0.15*(rand(size(r)) - 0.5)*2, r, 8, [0.6, 0.6, 0.6], 'filled', 'MarkerFaceAlpha', 0.5) ;
    errorbar(ax, ic, mean(r), std(r), 'ko', 'MarkerFaceColor', 'k', 'LineWidth', 1) ;
end
yline(ax, 0, 'k--') ;
xlim(ax, [0.5, 4.5]) ; xticks(ax, 1:4) ; xticklabels(ax, CondLabel) ;
ylabel(ax, 'Change from Free (%)') ; title(ax, sprintf('B. Trials (n = %d)', height(T))) ;
ax = subplot(1, 3, 3) ; hold(ax, 'on') ;
xS = 1:nS ;                 % 被験者の位置（横軸）
xSum = nS + [2, 3.5] ;      % まとめの 2 つの位置（1 つあけて右に置く。T = 試行単位・対応なし、P = 被験者単位・対応あり）
errorbar(ax, xS, DiffSubj(:,1), DiffSubj(:,1) - DiffSubj(:,2), DiffSubj(:,3) - DiffSubj(:,1), ...
    'ko', 'MarkerFaceColor', [0.6, 0.6, 0.6]) ;
errorbar(ax, xSum, [DiffTrial(1), DiffPaired(1)], [DiffTrial(1) - DiffTrial(2), DiffPaired(1) - DiffPaired(2)], ...
    [DiffTrial(3) - DiffTrial(1), DiffPaired(3) - DiffPaired(1)], 'kd', 'MarkerFaceColor', 'k', 'LineWidth', 1) ;
yline(ax, 0, 'k--') ;
xlim(ax, [0, xSum(2) + 1]) ; xticks(ax, [xS, xSum]) ;
xticklabels(ax, [arrayfun(@num2str, xS, 'UniformOutput', false), {'T', 'P'}]) ;
xlabel(ax, 'Participant') ; ylabel(ax, 'Go/Stop − Simple (%)') ; title(ax, 'C. Go/Stop − Simple (95% CI)') ;
exportgraphics(fig, fullfile(outDir, 'headspeed_rate.png'), 'Resolution', 300) ;

%% Holm の方法で p 値を補正する
function pH = holm(p)
    m = numel(p) ;
    [ps, ix] = sort(p(:)) ;
    adj = min(cummax((m - (1:m)' + 1).*ps), 1) ;
    pH = zeros(m, 1) ;
    pH(ix) = adj ;
end