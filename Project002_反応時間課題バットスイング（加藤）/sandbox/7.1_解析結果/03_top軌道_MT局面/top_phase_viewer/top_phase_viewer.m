function top_phase_viewer()
% top_phase_viewer.m
%
% バット先端（top）の投手方向（X）の動きを 3 つの局面に分け、条件の違いを見るツール。
%   ① フック    Onset → 引き始め        Onset 直後に先端が投手側へ出て、捕手側へ引き始めるまで
%   ② 引き      引き始め → 最も捕手側   先端が最も捕手側に来るまで
%   ③ 振り出し  最も捕手側 → ピーク速度
%   引き始め   = Onset 〜 最も捕手側の間で、X が最も投手側に出た時点
%   最も捕手側 = Onset 〜 ピーク速度の間で、X が最も小さい時点
%
% 画面：
%   左上  X の変位（Onset からの）と時間。▲ 引き始め、● 最も捕手側、★ ピーク速度
%   右上  3 次元の軌道（Onset を原点）に、同じ印
%   左下  選んだ被験者の局面の時間（条件ごとの平均）
%   右下  全被験者の比較（指標を選ぶ。被験者 × 条件の平均）
%   「下の 2 つの図」を「全体の傾向」にすると、被験者ごとの平均値を使って全体を見る
%     左下  局面の時間の、被験者平均の平均（表示する全条件に試行がある被験者）
%     右下  被験者ごとの平均を条件間で線で結び、全体の平均 ± SD を重ねる
%
% データ：../top_trajectory_3d/cache/top_trajectory_cache.mat（top_trajectory_3d.m が作る）。
%   先に top_trajectory_3d を 1 回実行しておく。
%   StrictSubjects の扱いは top_trajectory_3d と同じ（除外基準に引っかかった試行を外す）。
%
% 2026-10-28

%% 設定
StrictSubjects = [3 4] ;   % 除外基準に引っかかった試行を、目視の判断に関係なく外す被験者
fs = 250 ;                 % マーカーのサンプリング周波数 [Hz]（x3 の FrameRate）

ConditionNameArray = {'free', 'simple', 'gonogo', 'gostop'} ;
ConditionLabel     = {'Free', 'Simple', 'Go/No-go', 'Go/Stop'} ;
ConditionColor     = [0.40 0.40 0.40 ;    % free    灰
                      0.00 0.45 0.70 ;    % simple  青
                      0.90 0.62 0.00 ;    % gonogo  橙
                      0.80 0.20 0.20] ;   % gostop  赤
PhaseLabel = {'① フック', '② 引き', '③ 振り出し'} ;
PhaseColor = [0.85 0.85 0.85 ; 0.60 0.60 0.60 ; 0.30 0.30 0.30] ;

% 右下で選べる指標（Ev の列名、表示名）
MetricCol   = {'TPhase1', 'TPhase2', 'TPhase3', 'TMT', 'Hook', 'Back'} ;
MetricLabel = {'① フックの時間 (ms)', '② 引きの時間 (ms)', '③ 振り出しの時間 (ms)', ...
               'MT = ①+②+③ (ms)', 'フックの大きさ：投手側へ出た量 (m)', '引きの深さ：捕手側へ引いた量 (m)'} ;

scriptFolder = fileparts(mfilename('fullpath')) ;
cachePath    = fullfile(scriptFolder, '..', 'top_trajectory_3d', 'cache', 'top_trajectory_cache.mat') ;
outFolder    = fullfile(scriptFolder, 'output') ;

%% データ
if ~exist(cachePath, 'file')
    error('%s がありません。先に top_trajectory_3d を実行してください。', cachePath) ;
end
load(cachePath, 'Traj') ;
if ~isfield(Traj, 'IsFlagged')
    error('キャッシュが古い版のものです。%s を消して top_trajectory_3d を実行し直してください。', cachePath) ;
end
Traj = Traj(~([Traj.IsFlagged] & ismember([Traj.Subject], StrictSubjects))) ;

Ev = detectEvents(Traj, fs) ;   % 試行ごとのイベントと局面の時間（1 行 1 試行）

SubjectArray = unique(Ev.Subject)' ;
nCondition   = numel(ConditionNameArray) ;

%% 画面を作る
fig = uifigure('Name', 'top phase viewer', 'Position', [60 60 1400 860]) ;
gl  = uigridlayout(fig, [2 3]) ;
gl.ColumnWidth = {220, '1x', '1x'} ;
gl.RowHeight   = {'1x', '1x'} ;

% ---- 左：操作パネル ----
pl = uigridlayout(gl, [14 1]) ;
pl.Layout.Row = [1 2] ;
pl.Layout.Column = 1 ;
pl.RowHeight = {20, '1x', 20, 22, 22, 22, 22, 20, 24, 20, 24, 20, 24, 30} ;

uilabel(pl, 'Text', '被験者', 'FontWeight', 'bold') ;
subjItems = arrayfun(@(s) sprintf('S%02d', s), SubjectArray, 'UniformOutput', false) ;
lbSubject = uilistbox(pl, 'Items', subjItems, 'ItemsData', SubjectArray, ...
    'Value', SubjectArray(1), 'ValueChangedFcn', @(~,~) redraw()) ;

uilabel(pl, 'Text', '条件', 'FontWeight', 'bold') ;
cbCondition = gobjects(1, nCondition) ;
for ic = 1:nCondition
    cbCondition(ic) = uicheckbox(pl, 'Text', ConditionLabel{ic}, 'Value', true, ...
        'FontColor', ConditionColor(ic,:), 'FontWeight', 'bold', 'ValueChangedFcn', @(~,~) redraw()) ;
end

uilabel(pl, 'Text', '左上の時間軸', 'FontWeight', 'bold') ;
ddTime = uidropdown(pl, 'Items', {'Onset を 0 にそろえる', '最も捕手側を 0 にそろえる'}, ...
    'ValueChangedFcn', @(~,~) redraw()) ;

uilabel(pl, 'Text', '右下の指標', 'FontWeight', 'bold') ;
ddMetric = uidropdown(pl, 'Items', MetricLabel, 'ItemsData', 1:numel(MetricLabel), ...
    'ValueChangedFcn', @(~,~) redraw()) ;

uilabel(pl, 'Text', '下の 2 つの図', 'FontWeight', 'bold') ;
ddBottom = uidropdown(pl, 'Items', {'選んだ被験者', '全体の傾向（被験者平均）'}, ...
    'ValueChangedFcn', @(~,~) redraw()) ;
uibutton(pl, 'Text', '図を保存（PNG）', 'ButtonPushedFcn', @(~,~) saveFigure()) ;

% ---- 右：4 つの軸 ----
axX  = uiaxes(gl) ;  axX.Layout.Row  = 1 ;  axX.Layout.Column  = 2 ;
ax3  = uiaxes(gl) ;  ax3.Layout.Row  = 1 ;  ax3.Layout.Column  = 3 ;
axP  = uiaxes(gl) ;  axP.Layout.Row  = 2 ;  axP.Layout.Column  = 2 ;
axS  = uiaxes(gl) ;  axS.Layout.Row  = 2 ;  axS.Layout.Column  = 3 ;
view(ax3, 3) ;
rotate3d(ax3, 'on') ;

redraw() ;

%% 入れ子関数（画面の操作で呼ばれる）
    function redraw()
        s       = lbSubject.Value ;
        condOn  = arrayfun(@(c) c.Value, cbCondition) ;
        drawX(s, condOn) ;
        draw3(s, condOn) ;
        if ddBottom.Value == "全体の傾向（被験者平均）"
            drawPhaseGroup(condOn) ;
            drawSummaryGroup(s, condOn) ;
        else
            drawPhase(s, condOn) ;
            drawSummary(s, condOn) ;
        end
    end

    function drawX(s, condOn)
        % 左上：X の変位と時間
        cla(axX) ; hold(axX, 'on') ; grid(axX, 'on') ;
        isBackZero = ddTime.Value == "最も捕手側を 0 にそろえる" ;
        for jc = find(condOn)
            col = ConditionColor(jc,:) ;
            for k = trialsOf(s, jc)
                x  = Traj(k).XYZ(:,1) - Traj(k).XYZ(1,1) ;
                t  = (0:numel(x)-1)' / fs * 1000 ;
                t0 = 0 ;
                if isBackZero, t0 = t(Ev.IBack(k)) ; end
                plot(axX, t - t0, x, '-', 'Color', [col 0.45], 'LineWidth', 0.8) ;
                plotEvents2(axX, t - t0, x, k, col) ;
            end
        end
        yline(axX, 0, ':', 'Color', [0.5 0.5 0.5]) ;
        if isBackZero
            xline(axX, 0, '-', '最も捕手側', 'Color', [0.3 0.3 0.3]) ;
            xlabel(axX, '最も捕手側からの時間 (ms)') ;
        else
            xlabel(axX, 'Onset からの時間 (ms)') ;
        end
        ylabel(axX, 'X：投手方向の変位 (m)') ;
        title(axX, sprintf('S%02d　X の動き（▲ 引き始め　● 最も捕手側　★ ピーク速度）', s), 'FontWeight', 'normal') ;
    end

    function draw3(s, condOn)
        % 右上：3 次元の軌道（Onset を原点）
        [az, el] = view(ax3) ;
        cla(ax3) ; hold(ax3, 'on') ; grid(ax3, 'on') ;
        for jc = find(condOn)
            col = ConditionColor(jc,:) ;
            for k = trialsOf(s, jc)
                P = Traj(k).XYZ - Traj(k).XYZ(1,:) ;
                plot3(ax3, P(:,1), P(:,2), P(:,3), '-', 'Color', [col 0.45], 'LineWidth', 0.8) ;
                ii = [Ev.IHook(k), Ev.IBack(k), Ev.IPeak(k)] ;
                mk = {'^', 'o', 'p'} ;
                for m = 1:3
                    plot3(ax3, P(ii(m),1), P(ii(m),2), P(ii(m),3), mk{m}, 'MarkerSize', 6, ...
                        'MarkerFaceColor', col, 'MarkerEdgeColor', 'k') ;
                end
            end
        end
        axis(ax3, 'equal') ;
        xlabel(ax3, 'X：投手方向 (m)') ; ylabel(ax3, 'Y (m)') ; zlabel(ax3, 'Z：鉛直 (m)') ;
        title(ax3, '軌道（Onset を原点）', 'FontWeight', 'normal') ;
        view(ax3, az, el) ;
    end

    function drawPhase(s, condOn)
        % 左下：局面の時間（条件ごとの平均）を積み上げ棒で
        cla(axP) ; hold(axP, 'on') ;
        jcs = find(condOn) ;
        M = NaN(numel(jcs), 3) ;
        nT = zeros(1, numel(jcs)) ;
        for r = 1:numel(jcs)
            k = trialsOf(s, jcs(r)) ;
            nT(r) = numel(k) ;
            if isempty(k), continue, end
            M(r,:) = mean([Ev.TPhase1(k), Ev.TPhase2(k), Ev.TPhase3(k)], 1) ;
        end
        if isempty(jcs), return, end
        lab = arrayfun(@(r) sprintf('%s（%d）', ConditionLabel{jcs(r)}, nT(r)), 1:numel(jcs), 'UniformOutput', false) ;
        drawPhaseBars(M, nT, lab, '時間 (ms)（条件ごとの平均。括弧は試行数）', sprintf('S%02d　局面の時間', s), []) ;
    end

    function drawPhaseGroup(condOn)
        % 左下（全体）：局面の時間の、被験者平均の平均。表示する全条件に試行がある被験者だけを使う
        cla(axP) ; hold(axP, 'on') ;
        jcs = find(condOn) ;
        if isempty(jcs), return, end
        V1 = subjectMeans('TPhase1') ;  V2 = subjectMeans('TPhase2') ;  V3 = subjectMeans('TPhase3') ;
        ok = all(~isnan(V1(:,jcs)), 2) ;
        M  = [mean(V1(ok,jcs), 1)', mean(V2(ok,jcs), 1)', mean(V3(ok,jcs), 1)'] ;
        sdMT = std(V1(ok,jcs) + V2(ok,jcs) + V3(ok,jcs), 0, 1) ;   % 被験者間の MT の SD
        lab = ConditionLabel(jcs) ;
        drawPhaseBars(M, repmat(sum(ok), 1, numel(jcs)), lab, ...
            sprintf('時間 (ms)（被験者平均の平均、%d 名：%s）', sum(ok), strjoin(compose('S%02d', SubjectArray(ok)), ' ')), ...
            sprintf('全体　局面の時間（%d 名）', sum(ok)), sdMT) ;
    end

    function drawPhaseBars(M, nT, lab, xLabelText, titleText, sdMT)
        % 局面の時間の積み上げ棒（行 = 条件、列 = ①②③）。sdMT が空でなければ MT の ± SD を書く
        b = barh(axP, 1:size(M,1), M, 'stacked', 'BarWidth', 0.6) ;
        for m = 1:3
            b(m).FaceColor = PhaseColor(m,:) ;
            b(m).EdgeColor = 'w' ;
        end
        % 各区分の中に時間を書く
        for r = 1:size(M,1)
            left = 0 ;
            for m = 1:3
                if isnan(M(r,m)), continue, end
                txtCol = 'k' ; if m == 3, txtCol = 'w' ; end
                text(axP, left + M(r,m)/2, r, sprintf('%.0f', M(r,m)), 'Color', txtCol, ...
                    'HorizontalAlignment', 'center', 'FontSize', 10) ;
                left = left + M(r,m) ;
            end
            if nT(r) > 0 && ~isempty(sdMT)
                text(axP, left + 10, r, sprintf('MT %.0f ± %.0f ms', left, sdMT(r)), 'FontSize', 10) ;
            elseif nT(r) > 0
                text(axP, left + 10, r, sprintf('MT %.0f ms', left), 'FontSize', 10) ;
            else
                text(axP, 10, r, '試行なし', 'FontSize', 10, 'Color', [0.5 0.5 0.5]) ;
            end
        end
        axP.YTick = 1:size(M,1) ;
        axP.YTickLabel = lab ;
        axP.YDir = 'reverse' ;
        axP.XLim = [0, 1000] ;
        xlabel(axP, xLabelText) ;
        legend(axP, b, PhaseLabel, 'Location', 'southoutside', 'Orientation', 'horizontal') ;
        title(axP, titleText, 'FontWeight', 'normal') ;
    end

    function drawSummary(s, condOn)
        % 右下：全被験者の比較（被験者 × 条件の平均）
        cla(axS) ; hold(axS, 'on') ; grid(axS, 'on') ;
        axS.XTickLabelRotation = 0 ;
        im  = ddMetric.Value ;
        nS  = numel(SubjectArray) ;
        V   = subjectMeans(MetricCol{im}) ;
        % 選んだ被験者に背景
        iSel = find(SubjectArray == s) ;
        yl = [min(V(:)), max(V(:))] ; yl = yl + [-0.1 0.1] * max(diff(yl), eps) ;
        patch(axS, iSel + [-0.45 0.45 0.45 -0.45], yl([1 1 2 2]), [1 0.95 0.75], 'EdgeColor', 'none') ;
        dx = linspace(-0.24, 0.24, nCondition) ;
        h = gobjects(0) ; lab = {} ;
        for jc = find(condOn)
            h(end+1) = plot(axS, (1:nS) + dx(jc), V(:,jc), 'o', 'MarkerSize', 7, ...
                'MarkerFaceColor', ConditionColor(jc,:), 'MarkerEdgeColor', 'none') ; %#ok<AGROW>
            lab{end+1} = ConditionLabel{jc} ; %#ok<AGROW>
        end
        axS.XTick = 1:nS ;
        axS.XTickLabel = arrayfun(@(x) sprintf('S%02d', x), SubjectArray, 'UniformOutput', false) ;
        axS.XLim = [0.5, nS + 0.5] ;
        axS.YLim = yl ;
        ylabel(axS, MetricLabel{im}) ;
        if ~isempty(h), legend(axS, h, lab, 'Location', 'eastoutside') ; else, legend(axS, 'off') ; end

        % Simple より大きい被験者の数（両方の条件に試行がある被験者のうち）
        txt = {} ;
        for jc = [1 3 4]
            ok = ~isnan(V(:,jc)) & ~isnan(V(:,2)) ;
            txt{end+1} = sprintf('%s %d/%d', ConditionLabel{jc}, sum(V(ok,jc) > V(ok,2)), sum(ok)) ; %#ok<AGROW>
        end
        title(axS, {'全被験者（被験者 × 条件の平均）', ['Simple より大きい被験者：' strjoin(txt, '、')]}, 'FontWeight', 'normal') ;
    end

    function drawSummaryGroup(s, condOn)
        % 右下（全体）：被験者ごとの平均を条件間で線で結び、全体の平均 ± SD（被験者間）を重ねる
        cla(axS) ; hold(axS, 'on') ; grid(axS, 'on') ;
        legend(axS, 'off') ;
        im  = ddMetric.Value ;
        V   = subjectMeans(MetricCol{im}) ;
        jcs = find(condOn) ;
        if isempty(jcs), return, end
        ok  = all(~isnan(V(:,jcs)), 2) ;   % 表示する全条件に試行がある被験者
        xc  = 1:numel(jcs) ;

        % 被験者ごとの平均（灰色の線）。選んだ被験者は黒の太線
        for iS = find(ok)'
            if SubjectArray(iS) == s
                plot(axS, xc, V(iS,jcs), '-o', 'Color', 'k', 'LineWidth', 2, 'MarkerSize', 4, 'MarkerFaceColor', 'k') ;
            else
                plot(axS, xc, V(iS,jcs), '-o', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.8, ...
                    'MarkerSize', 4, 'MarkerFaceColor', [0.7 0.7 0.7], 'MarkerEdgeColor', 'none') ;
            end
        end
        % 全体の平均 ± SD
        mu = mean(V(ok,jcs), 1) ;
        sd = std(V(ok,jcs), 0, 1) ;
        for r = 1:numel(jcs)
            errorbar(axS, xc(r) + 0.15, mu(r), sd(r), 'o', 'Color', ConditionColor(jcs(r),:), 'LineWidth', 1.5, ...
                'MarkerSize', 9, 'MarkerFaceColor', ConditionColor(jcs(r),:), 'CapSize', 8) ;
            text(axS, xc(r) + 0.25, mu(r), sprintf('%.3g', mu(r)), 'Color', ConditionColor(jcs(r),:), 'FontSize', 10) ;
        end
        axS.XTick = xc ;
        axS.XTickLabel = ConditionLabel(jcs) ;
        axS.XLim = [0.5, numel(jcs) + 0.7] ;
        axS.YLimMode = 'auto' ;
        ylabel(axS, MetricLabel{im}) ;

        % Simple より大きい被験者の数（Simple を表示しているとき）
        txt = {} ;
        if condOn(2)
            for jc = setdiff(jcs, 2)
                txt{end+1} = sprintf('%s %d/%d', ConditionLabel{jc}, sum(V(ok,jc) > V(ok,2)), sum(ok)) ; %#ok<AGROW>
            end
        end
        line2 = sprintf('灰線 = 各被験者の平均（%d 名、黒 = S%02d）、色 = 全体の平均 ± SD', sum(ok), s) ;
        if ~isempty(txt), line2 = {line2, ['Simple より大きい被験者：' strjoin(txt, '、')]} ; else, line2 = {line2} ; end
        title(axS, [{'全体の傾向（被験者ごとの平均を使う）'}, line2], 'FontWeight', 'normal') ;
    end

    function V = subjectMeans(col)
        % 被験者 × 条件の平均（試行がなければ NaN）
        V = NaN(numel(SubjectArray), nCondition) ;
        for iS = 1:numel(SubjectArray)
            for jc = 1:nCondition
                k = trialsOf(SubjectArray(iS), jc) ;
                if ~isempty(k), V(iS,jc) = mean(Ev.(col)(k)) ; end
            end
        end
    end

    function plotEvents2(ax, t, x, k, col)
        ii = [Ev.IHook(k), Ev.IBack(k), Ev.IPeak(k)] ;
        mk = {'^', 'o', 'p'} ;
        for m = 1:3
            plot(ax, t(ii(m)), x(ii(m)), mk{m}, 'MarkerSize', 6, ...
                'MarkerFaceColor', col, 'MarkerEdgeColor', 'k') ;
        end
    end

    function k = trialsOf(s, jc)
        k = find(Ev.Subject == s & Ev.Condition == ConditionNameArray{jc})' ;
    end

    function saveFigure()
        if ~exist(outFolder, 'dir'), mkdir(outFolder) ; end
        base = sprintf('top_phase_S%02d_%s', lbSubject.Value, datestr(now, 'yyyymmdd_HHMMSS')) ; %#ok<TNOW1,DATST>
        exportapp(fig, fullfile(outFolder, [base '.png'])) ;
        uialert(fig, sprintf('%s.png に保存しました', fullfile(outFolder, base)), '保存', 'Icon', 'success') ;
    end

end


%% ローカル関数
function Ev = detectEvents(Traj, fs)
% 試行ごとに、引き始め・最も捕手側・ピーク速度のフレームと、局面の時間・量を求める（1 行 1 試行）
n  = numel(Traj) ;
Ev = table('Size', [n 11], ...
    'VariableTypes', {'double', 'string', 'double', 'double', 'double', 'double', ...
                      'double', 'double', 'double', 'double', 'double'}, ...
    'VariableNames', {'Subject', 'Condition', 'Trial', 'IHook', 'IBack', 'IPeak', ...
                      'TPhase1', 'TPhase2', 'TPhase3', 'Hook', 'Back'}) ;
for k = 1:n
    iPeak = Traj(k).IPeak ;
    x = Traj(k).XYZ(1:iPeak, 1) - Traj(k).XYZ(1, 1) ;   % Onset からの X の変位 [m]
    [xBack, iBack] = min(x) ;                            % 最も捕手側
    [xHook, iHook] = max(x(1:iBack)) ;                   % それまでに最も投手側へ出た点 = 引き始め

    Ev.Subject(k)   = Traj(k).Subject ;
    Ev.Condition(k) = Traj(k).Condition ;
    Ev.Trial(k)     = Traj(k).Trial ;
    Ev.IHook(k)     = iHook ;
    Ev.IBack(k)     = iBack ;
    Ev.IPeak(k)     = iPeak ;
    Ev.TPhase1(k)   = (iHook - 1)     / fs * 1000 ;   % ① Onset → 引き始め [ms]
    Ev.TPhase2(k)   = (iBack - iHook) / fs * 1000 ;   % ② 引き始め → 最も捕手側 [ms]
    Ev.TPhase3(k)   = (iPeak - iBack) / fs * 1000 ;   % ③ 最も捕手側 → ピーク速度 [ms]
    Ev.Hook(k)      = xHook ;                         % 投手側へ出た量 [m]
    Ev.Back(k)      = -xBack ;                        % 捕手側へ引いた量 [m]
end
Ev.TMT = Ev.TPhase1 + Ev.TPhase2 + Ev.TPhase3 ;       % = Onset → ピーク速度
end