% q3_plot_example_trials.m
%
% 目的:
%   5.8 の i3_plot_example_trials.m と同じ体裁で、バット先端（top）の合成速度の
%   時系列を代表試行について描く。p0 が出した RT・MT・Peak velocity が
%   波形のどこを測っているのかを目で確かめる。
%
% 代表試行の選び方:
%   条件ごとに、Peak velocity がその条件の中央値に最も近い試行を1本選ぶ。
%   4指標（RT・MT・Peak velocity・Slope）すべてを算出できた試行だけから選ぶ。
%
% 出力（03_代表試行プロット/）:
%   代表試行波形_全被験者.png ... 全被験者の試行からまとめて選んだ図
%   代表試行波形_S01.png 〜  ... 被験者ごとに選んだ図
%
% 備考:
%   - 速度は p0 と同じ計算（未フィルタの top 座標を diff3p で微分した合成速度）。
%     別の計算をすると、印の位置と波形がずれて確認にならない。
%   - 4条件で縦軸をそろえる（山の高さを条件間で見比べるため）。

clearvars -except TargetSubjects
close all

p0_calc_metrics

thisDir = fileparts( mfilename('fullpath') ) ;
outDir  = fullfile(thisDir, '03_代表試行プロット') ;
if ~isfolder(outDir), mkdir(outDir) ; end

if isscalar(SubjectArray), PickSubject = 1 ; else, PickSubject = [0, 1:nS] ; end

xLim    = [-0.5 1.5] ;     % cue からの表示範囲 [s]
lastSub = -1 ;

for ip = 1:numel(PickSubject)

    iPick = PickSubject(ip) ;
    if iPick == 0
        tagText = '全被験者' ;
        outName = '代表試行波形_全被験者.png' ;
    else
        tagText = sprintf('S%02d', SubjectArray(iPick)) ;
        outName = sprintf('代表試行波形_S%02d.png', SubjectArray(iPick)) ;
    end

    %% ---- 代表試行を選ぶ（Peak velocity が条件中央値に最も近い試行）----
    Sel    = Rec([]) ;
    hasAll = true ;
    for ic = 1:nC
        isPick = [Rec.ic] == ic ;
        if iPick > 0, isPick = isPick & ([Rec.iS] == iPick) ; end
        idx = find(isPick) ;
        if isempty(idx), hasAll = false ; break, end
        v        = [Rec(idx).peakVel] ;
        [~, ord] = sort( abs(v - median(v)) ) ;
        Sel(ic)  = Rec( idx(ord(1)) ) ;
    end
    if ~hasAll
        fprintf('%s: 代表試行を選べない条件があるので図を作りません\n', tagText) ;
        continue
    end

    %% ---- 波形を用意する（縦軸をそろえるため、描く前に全条件ぶん集める）----
    W = struct('tRel',{}, 'vel',{}) ;
    for ic = 1:nC
        R = Sel(ic) ;
        if R.sub ~= lastSub
            load( fullfile(dataDir, sprintf('Data%02d.mat', R.sub)) )
            lastSub = R.sub ;
        end
        D   = DataArray(R.it, R.ic) ;
        top = D.Markers.(Prm.Excl.TopMarkerName) ;
        vel = sum(diff3p(top, 1/R.fs).^2, 2).^0.5 / 1000 ;          % [m/s]（p0 と同じ）
        W(ic).tRel = ( (1:numel(vel))' / R.fs ) - R.tc / R.fsA ;     % cue を 0 とした時間 [s]
        W(ic).vel  = vel ;
    end

    vIn = [] ;
    for ic = 1:nC
        inWin = W(ic).tRel >= xLim(1) & W(ic).tRel <= xLim(2) ;
        vIn   = [vIn ; W(ic).vel(inWin)] ;                                  %#ok<AGROW>
    end
    yLim = [0, max(vIn)*1.10] ;

    %% ---- 描画（1行 × 4条件、縦軸は共通）----
    fig = figure('Color','w', 'Position', [60 80 380*nC 380]) ;

    for ic = 1:nC
        R  = Sel(ic) ;
        ax = subplot(1, nC, ic) ;
        hold(ax, 'on')

        tOn = R.rtMs / 1000 ;              % cue からの onset 時刻 [s]
        tPv = tOn + R.mtMs / 1000 ;        % cue からのピーク速度の時刻 [s]（帯の長さ = MT）

        patch(ax, [0 tOn tOn 0],     yLim([1 1 2 2]), [0.86 0.91 0.97], 'EdgeColor','none') ;
        patch(ax, [tOn tPv tPv tOn], yLim([1 1 2 2]), [1.00 0.92 0.83], 'EdgeColor','none') ;

        plot(ax, W(ic).tRel, W(ic).vel, '-', 'Color', [0.20 0.35 0.70], 'LineWidth', 1.4) ;

        xline(ax, 0, 'k--', 'Cue', 'LabelHorizontalAlignment','left', ...
            'LabelVerticalAlignment','bottom', 'FontSize', 9) ;
        xline(ax, tOn, '-', 'RT onset', 'Color', [0.85 0.35 0.10], ...
            'LineWidth', 1.4, 'LabelHorizontalAlignment','right', ...
            'LabelVerticalAlignment','bottom', 'FontSize', 9) ;

        % ピーク速度の印（p0 が選んだフレーム）
        plot(ax, W(ic).tRel(R.tPeakVel), W(ic).vel(R.tPeakVel), 'ko', 'MarkerSize', 8, 'LineWidth', 1.5) ;

        set(ax, 'XLim', xLim, 'YLim', yLim, 'FontSize', 10, 'Box','off', 'YGrid','on') ;
        title(ax, sprintf('%s   S%02d  試行%d', ConditionNameArray{ic}, R.sub, R.it), ...
            'FontSize', 12, 'FontWeight','bold') ;
        subtitle(ax, sprintf('Peak %.1f m/s', R.peakVel), 'FontSize', 10) ;
        xlabel(ax, 'Time from cue [s]') ;
        if ic == 1, ylabel(ax, 'バット先端の合成速度 [m/s]') ; end
    end

    sgtitle(sprintf(['%s   条件別 代表1試行：RT（青）と ' ...
        'MT（橙, onset → バット先端ピーク速度）の区間'], tagText), ...
        'FontSize', 14, 'FontWeight','bold') ;

    exportgraphics(fig, fullfile(outDir, outName), 'Resolution', 200) ;
    fprintf('出力しました: %s\n', fullfile(outDir, outName)) ;
    close(fig)
end
