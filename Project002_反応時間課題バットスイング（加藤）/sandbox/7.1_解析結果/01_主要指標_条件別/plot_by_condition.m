% plot_by_condition.m
%
% 目的:
%   x8_StatTable の TrialTable（除外適用済み）から、RT・MT・PeakVelTop・PeakFz を
%   条件別_全被験者図（5.6 の p1_plot_by_condition と同じ体裁）で1指標1枚ずつ PNG 出力する。
%
% 入力:
%   Experiments/Main experiments/03_Analysis/x8_StatTable/StatTable.mat（TrialTable）
%
% 出力（このスクリプトと同じフォルダ）:
%   RT_条件別_全被験者.png / MT_条件別_全被験者.png /
%   PeakVelTop_条件別_全被験者.png / PeakFz_条件別_全被験者.png
%
% 備考:
%   - Go 試行のみ（TrialTable.IsGo）。除外は x8 で NaN にされた値をそのまま落とす。
%   - PeakFz は踏み込み足（Fz2）のピーク、体重比（PeakFz2_BW）。
%   - 試行数（n=）は表示しない。
%   - RT は free を描かない（自己ペース条件で cue からの反応ではないため）。
%
% 2026-10-22

clear
close all

thisDir = fileparts( mfilename('fullpath') ) ;
statPath = fullfile(thisDir, '..', '..', '..', 'Experiments', 'Main experiments', ...
    '03_Analysis', 'x8_StatTable', 'StatTable.mat') ;
load(statPath, 'TrialTable')

ConditionNameArray = {'free', 'simple', 'gonogo', 'gostop'} ;

% 指標名（ファイル名の接頭語）・列名・パネルのタイトル
Metric = struct( ...
    'Tag',   {'RT', 'MT', 'PeakVelTop', 'PeakFz'}, ...
    'Col',   {'RTForce_ms', 'MT_ms', 'PeakVelTop', 'PeakFz2_BW'}, ...
    'Title', {'RT  反応時間 [ms]', 'MT  動作時間 [ms]', ...
              'PeakVelTop  バット先端の最大速度 [m/s]', 'PeakFz  踏み込み足の最大鉛直床反力 [BW]'}, ...
    'Conds', {ConditionNameArray(2:end), ConditionNameArray, ConditionNameArray, ConditionNameArray}) ;
% ★ RT は free を描かない（自己ペース条件で cue からの反応ではないため）

SubjColorAll = [0.000 0.447 0.698 ;    % S01  青
                0.835 0.369 0.000 ;    % S02  朱
                0.000 0.620 0.451 ;    % S03  緑
                0.800 0.475 0.655 ;    % S04  紫
                0.902 0.624 0.000 ;    % S05  橙
                0.337 0.706 0.914 ;    % S06  空色
                0.941 0.894 0.259 ;    % S07  黄
                0.000 0.000 0.000 ;    % S08  黒
                0.500 0.500 0.500 ;    % S09  灰
                0.600 0.300 0.100] ;   % S10  茶

T = TrialTable(TrialTable.IsGo, :) ;
SubjectArray = unique(T.Subject)' ;
nS = numel(SubjectArray) ;
SubjColor = SubjColorAll(SubjectArray, :) ;

SubjOffset = linspace(-0.27, 0.27, nS) ;   % 被験者ごとの横位置
JitterW    = 0.05 ;
shadeCol   = [0.93 0.93 0.93] ;

for im = 1:numel(Metric)

    CondNames = Metric(im).Conds ;
    nC        = numel(CondNames) ;

    % ---- 被験者 × 条件 ごとの値（NaN = 除外済み は落とす）----
    V = cell(nS, nC) ;
    for iS = 1:nS
        for ic = 1:nC
            m = T.Subject == SubjectArray(iS) & T.Condition == CondNames{ic} ;
            v = T.(Metric(im).Col)(m) ;
            V{iS,ic} = v(~isnan(v)) ;
        end
    end
    allByCond = cell(1, nC) ;
    for ic = 1:nC, allByCond{ic} = vertcat(V{:,ic}) ; end

    % ---- y 範囲：四分位範囲の3倍で切り、はみ出した点は境界に△▽で置く（表示の都合、除外ではない）----
    allv  = vertcat(allByCond{:}) ;
    q1a   = quantile(allv, 0.25) ; q3a = quantile(allv, 0.75) ; iqra = q3a - q1a ;
    inCap = allv >= q1a - 3*iqra & allv <= q3a + 3*iqra ;
    lo = min(allv(inCap)) ; hi = max(allv(inCap)) ; pad = 0.10*(hi-lo) ;
    yLo = lo - pad ;
    yHi = hi + pad*0.6 ;

    fig = figure('Color', 'w', 'Position', [80 80 900 560]) ;
    ax  = axes('Position', [0.09 0.10 0.80 0.68]) ;
    hold(ax, 'on')
    rng(0)   % ジッタを再現可能にする

    % free の網掛け（参考値）
    if strcmp(CondNames{1}, 'free')
        patch(ax, [0.5 1.5 1.5 0.5], [yLo yLo yHi yHi], shadeCol, 'EdgeColor', 'none') ;
    end

    % 個々の試行
    nOver = 0 ; nUnder = 0 ;
    for ic = 1:nC
        for iS = 1:nS
            a = V{iS,ic} ;
            if isempty(a), continue, end
            xj = ic + SubjOffset(iS) + (rand(numel(a),1) - 0.5) * JitterW ;
            isIn = a >= yLo & a <= yHi ;
            scatter(ax, xj(isIn), a(isIn), 16, SubjColor(iS,:), 'filled', ...
                'MarkerFaceAlpha', 0.60, 'MarkerEdgeColor', 'none') ;
            isUp = a > yHi ; isDn = a < yLo ;
            if any(isUp)
                scatter(ax, xj(isUp), repmat(yHi, sum(isUp), 1), 34, [0.85 0.33 0.20], ...
                    '^', 'filled', 'MarkerEdgeColor', 'none') ;
            end
            if any(isDn)
                scatter(ax, xj(isDn), repmat(yLo, sum(isDn), 1), 34, [0.85 0.33 0.20], ...
                    'v', 'filled', 'MarkerEdgeColor', 'none') ;
            end
            nOver = nOver + sum(isUp) ; nUnder = nUnder + sum(isDn) ;
        end
    end

    % 被験者ごとの中央値（色つきの折れ線）
    subjMed = nan(nS, nC) ;
    for iS = 1:nS
        for ic = 1:nC
            if ~isempty(V{iS,ic}), subjMed(iS,ic) = median(V{iS,ic}) ; end
        end
        plot(ax, 1:nC, subjMed(iS,:), '-', 'Color', SubjColor(iS,:), 'LineWidth', 1.6, ...
            'Marker', 'o', 'MarkerSize', 5, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', SubjColor(iS,:)) ;
    end

    % 条件の中央値（黒の太い横線）と四分位範囲（縦線）
    for ic = 1:nC
        a = allByCond{ic} ;
        if isempty(a), continue, end
        m = median(a) ; q1 = quantile(a, 0.25) ; q3 = quantile(a, 0.75) ;
        plot(ax, [ic ic], [q1 q3], 'k-', 'LineWidth', 1.2) ;
        plot(ax, ic + [-0.34 0.34], [m m], 'k-', 'LineWidth', 3.0) ;
        if abs(m) < 10, medFmt = '%.2f' ; else, medFmt = '%.1f' ; end
        text(ax, ic, yHi + 0.04*(yHi-yLo), sprintf(medFmt, m), 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom', 'FontSize', 15, 'FontWeight', 'bold') ;
    end

    % 被験者ラベル（右端）。重なりを最小間隔で解消する
    lastCol = subjMed(:,nC) ;
    ok = ~isnan(lastCol) ;
    [sv, order] = sort(lastCol(ok), 'descend') ;
    idxOK  = find(ok) ;
    minGap = 0.050*(yHi-yLo) ;
    for k = 2:numel(sv)
        if sv(k-1) - sv(k) < minGap, sv(k) = sv(k-1) - minGap ; end
    end
    % 下端からはみ出したら、下から押し上げる
    if ~isempty(sv) && sv(end) < yLo + minGap/2
        sv(end) = yLo + minGap/2 ;
        for k = numel(sv)-1:-1:1
            if sv(k) - sv(k+1) < minGap, sv(k) = sv(k+1) + minGap ; end
        end
    end
    for k = 1:numel(order)
        iS = idxOK(order(k)) ;
        text(ax, nC+0.36, sv(k), sprintf('S%02d', SubjectArray(iS)), ...
            'FontSize', 10, 'FontWeight', 'bold', 'Color', SubjColor(iS,:), 'VerticalAlignment', 'middle') ;
    end

    % 軸外の点の注記
    if nOver > 0
        text(ax, 0.55, yHi - 0.03*(yHi-yLo), sprintf('\\uparrow 軸外 %d 点（最大 %.1f）', nOver, max(allv)), ...
            'Color', [0.85 0.33 0.20], 'FontSize', 9.5, ...
            'HorizontalAlignment', 'left', 'VerticalAlignment', 'top') ;
    end
    if nUnder > 0
        text(ax, 0.55, yLo + 0.03*(yHi-yLo), sprintf('\\downarrow 軸外 %d 点（最小 %.1f）', nUnder, min(allv)), ...
            'Color', [0.85 0.33 0.20], 'FontSize', 9.5, ...
            'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom') ;
    end

    set(ax, 'XLim', [0.5 nC+0.55], 'YLim', [yLo yHi], ...
        'XTick', 1:nC, 'XTickLabel', CondNames, ...
        'FontSize', 11, 'YGrid', 'on', 'GridColor', [0.85 0.85 0.85], ...
        'GridAlpha', 1, 'Layer', 'bottom', 'Box', 'off') ;
    title(ax, Metric(im).Title, 'FontSize', 14, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0 1.14 0]) ;

    legendStr = ['黒い横線 = 条件の中央値（縦線は四分位範囲） / 色つきの折れ線 = 被験者ごとの中央値 / ' ...
                 '点 = 個々の試行'] ;
    if strcmp(CondNames{1}, 'free'), legendStr = [legendStr '   ※ free は参考値（網掛け）'] ; end
    annotation('textbox', [0 0.91 1 0.08], 'String', legendStr, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontSize', 9.5, 'Color', [0.30 0.30 0.30], 'EdgeColor', 'none') ;

    outPath = fullfile(thisDir, sprintf('%s_条件別_全被験者.png', Metric(im).Tag)) ;
    exportgraphics(fig, outPath, 'Resolution', 200) ;
    fprintf('出力しました: %s\n', outPath) ;
end
