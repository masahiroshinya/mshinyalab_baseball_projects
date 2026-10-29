function fx_onset_viewer()
% fx_onset_viewer.m
%
% スイング開始（Onset）の検出に使う前後方向の合成床反力 Fx を、試行ごとに描いて比べるツール。
% 被験者と条件を出し入れし、条件または被験者で色分けする。下段に踏み込み足の Fz（Fz2）を描き、
% Onset の探索窓の終わり（踏み込み足の接地）も見られるようにする。
%
% データ：
%   試行の選別        x8_StatTable/StatTable.mat の TrialTable（Go 試行、x8 の除外を当てたあと）
%   Fx・Fz2・キュー   x3_DataChecked/DataNN.mat から、m3_analyze_single_trial と同じ計算をやり直す
%                    （x4・x5 には Fx の波形はあるが、キューと接地の時刻が保存されていないため）
%   Onset の検出（m3 と同じ）
%     Fx   = Force1(:,1) + Force2(:,1) を 50 Hz（Prm.RT.FxFc）の 2 次 Butterworth で filtfilt
%     基準値 = キュー前 0.5 s の Fx の中央値
%     接地 = キュー後に Fz2 が「キュー前 0.5 s の中央値 + 50 N」を初めて超えた点
%     閾値 = 基準値 + 0.20 ×（キュー〜接地の Fx のピーク − 基準値）
%     Onset = キュー〜接地で、Fx が下から閾値を跨ぎ、20 ms 続けて超えた最初の点
%   抜き出した Onset が x8 の SwingOnsetForce と一致するかを、初回に確かめて表示する。
%
% 使い方：このフォルダで fx_onset_viewer を実行する。
%   初回は x3 を読むので時間がかかる。抜き出した波形は cache/ に保存し、2 回目からはそれを読む。
%   x3・x8 を作り直したとき、または WinMs を変えたときは cache/fx_onset_cache.mat を消してから実行する。
%
% 2026-10-29

%% 設定
WinMs = [-500, 1500] ;   % 抜き出す区間（キュー起点）[ms]

ConditionNameArray = {'free', 'simple', 'gonogo', 'gostop'} ;   % x4 の DataArray の列の並び
ConditionLabel     = {'Free', 'Simple', 'Go/No-go', 'Go/Stop'} ;
ConditionColor     = [0.40 0.40 0.40 ;    % free    灰
                      0.00 0.45 0.70 ;    % simple  青
                      0.90 0.62 0.00 ;    % gonogo  橙
                      0.80 0.20 0.20] ;   % gostop  赤
SubjectColor       = [0.000 0.447 0.698 ; 0.835 0.369 0.000 ; 0.000 0.620 0.451 ; 0.800 0.475 0.655 ; ...
                      0.902 0.624 0.000 ; 0.337 0.706 0.914 ; 0.941 0.894 0.259 ; 0.000 0.000 0.000 ; ...
                      0.500 0.500 0.500 ; 0.600 0.300 0.100] ;   % S01〜S10（x10_plot_by_condition と同じ）

scriptFolder   = fileparts(mfilename('fullpath')) ;
projectFolder  = fullfile(scriptFolder, '..', '..', '..', '..') ;   % Project002 のフォルダ
analysisFolder = fullfile(projectFolder, 'Experiments', 'Main experiments', '03_Analysis') ;
cacheFolder    = fullfile(scriptFolder, 'cache') ;
cachePath      = fullfile(cacheFolder, 'fx_onset_cache.mat') ;
outFolder      = fullfile(scriptFolder, 'output') ;

%% データ（キャッシュがあれば読む）
if exist(cachePath, 'file')
    load(cachePath, 'Tr', 'CacheWinMs') ;
    if ~isequal(CacheWinMs, WinMs)
        error('キャッシュの WinMs が設定と違います。%s を消してから実行してください。', cachePath) ;
    end
    fprintf('キャッシュを読みました：%d 試行\n', numel(Tr)) ;
else
    Tr = extractFx(analysisFolder, ConditionNameArray, WinMs) ;
    CacheWinMs = WinMs ;
    if ~exist(cacheFolder, 'dir'), mkdir(cacheFolder) ; end
    save(cachePath, 'Tr', 'CacheWinMs') ;
    fprintf('キャッシュを保存しました：%s\n', cachePath) ;
end

SubjectArray = unique([Tr.Subject]) ;
nCondition   = numel(ConditionNameArray) ;
tAxis        = (WinMs(1):WinMs(2))' ;   % キュー起点の時刻 [ms]（1 kHz なので 1 ms 刻み）
selTrial     = [] ;                     % クリックで選んだ試行

%% 画面を作る
fig = uifigure('Name', 'Fx onset viewer', 'Position', [80 40 1300 940]) ;
gl  = uigridlayout(fig, [1 2]) ;
gl.ColumnWidth = {240, '1x'} ;

% ---- 左：操作パネル ----
pl = uigridlayout(gl, [22 1]) ;
pl.RowHeight = {20, '1x', 25, 20, 22, 22, 22, 22, 20, 24, 20, 24, 20, 24, 20, 24, 22, 22, 22, 20, 60, 30} ;

uilabel(pl, 'Text', '被験者（Ctrl / ⌘ で複数）', 'FontWeight', 'bold') ;
subjItems = arrayfun(@(s) sprintf('S%02d', s), SubjectArray, 'UniformOutput', false) ;
lbSubject = uilistbox(pl, 'Items', subjItems, 'ItemsData', SubjectArray, 'Multiselect', 'on', ...
    'Value', SubjectArray(1), 'ValueChangedFcn', @(~,~) redraw()) ;
bl = uigridlayout(pl, [1 2], 'Padding', 0) ;
uibutton(bl, 'Text', '全員', 'ButtonPushedFcn', @(~,~) setSubjects(SubjectArray)) ;
uibutton(bl, 'Text', '1 人目だけ', 'ButtonPushedFcn', @(~,~) setSubjects(lbSubject.Value(1))) ;

uilabel(pl, 'Text', '条件', 'FontWeight', 'bold') ;
cbCondition = gobjects(1, nCondition) ;
for ic = 1:nCondition
    cbCondition(ic) = uicheckbox(pl, 'Text', ConditionLabel{ic}, 'Value', true, ...
        'FontColor', ConditionColor(ic,:), 'FontWeight', 'bold', 'ValueChangedFcn', @(~,~) redraw()) ;
end

uilabel(pl, 'Text', '試行の選び方', 'FontWeight', 'bold') ;
ddTrial = uidropdown(pl, 'Items', {'RT の除外のあと', 'すべての除外のあと（RT・top・床反力）'}, ...
    'ValueChangedFcn', @(~,~) redraw()) ;
uilabel(pl, 'Text', '色分け', 'FontWeight', 'bold') ;
ddColor = uidropdown(pl, 'Items', {'条件', '被験者'}, 'ValueChangedFcn', @(~,~) redraw()) ;
uilabel(pl, 'Text', '時間軸の 0', 'FontWeight', 'bold') ;
ddTime = uidropdown(pl, 'Items', {'キュー', 'Onset', '踏み込み足の接地'}, 'ValueChangedFcn', @(~,~) redraw()) ;
uilabel(pl, 'Text', '縦軸', 'FontWeight', 'bold') ;
ddY = uidropdown(pl, 'Items', {'そのまま (N)', '基準値を引く (N)', '基準値を引いて体重で割る (BW)'}, ...
    'ValueChangedFcn', @(~,~) redraw()) ;
cbThr      = uicheckbox(pl, 'Text', '閾値を描く（破線 = 探索窓）', 'Value', true, 'ValueChangedFcn', @(~,~) redraw()) ;
cbMean     = uicheckbox(pl, 'Text', '色ごとの平均を太線で重ねる', 'ValueChangedFcn', @(~,~) redraw()) ;
cbMeanOnly = uicheckbox(pl, 'Text', '平均だけを描く（試行を隠す）', 'ValueChangedFcn', @(~,~) redraw()) ;
uilabel(pl, 'Text', 'クリックした試行', 'FontWeight', 'bold') ;
lblInfo = uilabel(pl, 'Text', '線をクリックすると、ここに試行の情報が出る', 'WordWrap', 'on', 'VerticalAlignment', 'top') ;
uibutton(pl, 'Text', '図を保存（PNG）', 'ButtonPushedFcn', @(~,~) saveFigure()) ;

% ---- 右：上 Fx、下 Fz2 ----
gr = uigridlayout(gl, [2 1]) ;
gr.RowHeight = {'3x', '2x'} ;
axFx = uiaxes(gr) ;
axFz = uiaxes(gr) ;

redraw() ;

%% 入れ子関数（画面の操作で呼ばれる）
    function setSubjects(s)
        lbSubject.Value = s ;
        redraw() ;
    end

    function redraw()
        cla(axFx) ; hold(axFx, 'on') ; grid(axFx, 'on') ;
        cla(axFz) ; hold(axFz, 'on') ; grid(axFz, 'on') ;
        idx = selectedTrials() ;
        byCond = ddColor.Value == "条件" ;

        % 色のグループ（条件 または 被験者）
        if byCond
            groupOf = arrayfun(@(k) find(strcmp(ConditionNameArray, Tr(k).Condition)), idx) ;
            groups  = find(arrayfun(@(c) c.Value, cbCondition)) ;
            gLabel  = @(g) ConditionLabel{g} ;
            gColor  = @(g) ConditionColor(g,:) ;
        else
            groupOf = [Tr(idx).Subject] ;
            groups  = lbSubject.Value ;
            gLabel  = @(g) sprintf('S%02d', g) ;
            gColor  = @(g) SubjectColor(g,:) ;
        end

        hLeg = gobjects(0) ; hLegFz = gobjects(0) ; legText = {} ;
        for g = groups(:)'
            kk  = idx(groupOf == g) ;
            col = gColor(g) ;
            if isempty(kk)
                hLeg(end+1)   = plot(axFx, NaN, NaN, '-', 'Color', col) ; %#ok<AGROW>
                hLegFz(end+1) = plot(axFz, NaN, NaN, '-', 'Color', col) ; %#ok<AGROW>
                legText{end+1} = sprintf('%s（0 試行）', gLabel(g)) ; %#ok<AGROW>
                continue
            end
            [FxA, FzA, t0] = alignedWaves(kk) ;   % 列 = 試行
            h = gobjects(1) ;
            if ~cbMeanOnly.Value
                for j = 1:numel(kk)
                    k = kk(j) ;
                    t = tAxis - t0(j) ;
                    h = plot(axFx, t, FxA(:,j), '-', 'Color', [col 0.45], 'LineWidth', 0.8, ...
                        'ButtonDownFcn', @(~,~) pickTrial(k)) ;
                    plot(axFz, t, FzA(:,j), '-', 'Color', [col 0.45], 'LineWidth', 0.8, ...
                        'ButtonDownFcn', @(~,~) pickTrial(k)) ;
                    % 印：● Onset、▼ 接地
                    iOn = Tr(k).IOnset - WinMs(1) + 1 ;
                    iFC = Tr(k).IFC    - WinMs(1) + 1 ;
                    plot(axFx, t(iOn), FxA(iOn,j), 'o', 'MarkerSize', 5, 'MarkerFaceColor', col, 'MarkerEdgeColor', 'k') ;
                    if iFC <= numel(t)
                        plot(axFx, t(iFC), FxA(iFC,j), 'v', 'MarkerSize', 5, 'MarkerFaceColor', col, 'MarkerEdgeColor', 'k') ;
                        plot(axFz, t(iFC), FzA(iFC,j), 'v', 'MarkerSize', 5, 'MarkerFaceColor', col, 'MarkerEdgeColor', 'k') ;
                    end
                    % 閾値：探索窓（キュー → 接地）の長さの破線
                    if cbThr.Value
                        plot(axFx, [0, Tr(k).IFC] - t0(j), thrValue(k) * [1 1], '--', 'Color', col, 'LineWidth', 0.8) ;
                    end
                end
            end
            if cbMean.Value || cbMeanOnly.Value
                [tm, FxM, FzM] = meanWaves(FxA, FzA, t0) ;
                h = plot(axFx, tm, FxM, '-', 'Color', col, 'LineWidth', 2.5) ;
                plot(axFz, tm, FzM, '-', 'Color', col, 'LineWidth', 2.5) ;
                % 平均だけのときは、閾値と探索窓も平均で描く
                if cbThr.Value && cbMeanOnly.Value
                    plot(axFx, [mean(-t0), mean([Tr(kk).IFC] - t0)], mean(thrValue(kk)) * [1 1], '--', ...
                        'Color', col, 'LineWidth', 2) ;
                end
            end
            hLeg(end+1)   = h ; %#ok<AGROW>
            hLegFz(end+1) = plot(axFz, NaN, NaN, '-', 'Color', col, 'LineWidth', 1.5) ; %#ok<AGROW>
            legText{end+1} = sprintf('%s（%d 試行）', gLabel(g), numel(kk)) ; %#ok<AGROW>
        end

        % 選んだ試行を黒の太線で
        if ~isempty(selTrial) && ismember(selTrial, idx)
            [FxA, FzA, t0] = alignedWaves(selTrial) ;
            plot(axFx, tAxis - t0, FxA, '-', 'Color', 'k', 'LineWidth', 2) ;
            plot(axFz, tAxis - t0, FzA, '-', 'Color', 'k', 'LineWidth', 2) ;
            if cbThr.Value
                plot(axFx, [0, Tr(selTrial).IFC] - t0, thrValue(selTrial) * [1 1], '--', 'Color', 'k', 'LineWidth', 1.5) ;
            end
        end

        xline(axFx, 0, '-', 'Color', [0.3 0.3 0.3]) ;
        xline(axFz, 0, '-', 'Color', [0.3 0.3 0.3]) ;
        xlabel(axFz, sprintf('%s からの時間 (ms)', ddTime.Value)) ;
        [yUnit, yNote] = yAxisText() ;
        ylabel(axFx, ['Fx：前後方向の合成床反力 ' yUnit]) ;
        ylabel(axFz, ['Fz2：踏み込み足の鉛直床反力 ' yUnit]) ;
        title(axFx, {sprintf('Fx（%s、%s）', ddTrial.Value, yNote), ...
            '● Onset　▼ 踏み込み足の接地（Onset の探索窓の終わり）　破線 閾値（キュー → 接地）'}, 'FontWeight', 'normal') ;
        title(axFz, 'Fz2（踏み込み足）', 'FontWeight', 'normal') ;
        xlim(axFx, WinMs) ; xlim(axFz, WinMs) ;
        % 上下に同じ凡例を置く（上下の軸の横幅がそろう）
        if ~isempty(hLeg)
            legend(axFx, hLeg,   legText, 'Location', 'northeastoutside') ;
            legend(axFz, hLegFz, legText, 'Location', 'northeastoutside') ;
        else
            legend(axFx, 'off') ;  legend(axFz, 'off') ;
        end
    end

    function idx = selectedTrials()
        % 選んだ被験者・条件・試行の選び方に合う試行の番号（Tr の添字）
        condOn  = ConditionNameArray(arrayfun(@(c) c.Value, cbCondition)) ;
        isSubj  = ismember([Tr.Subject], lbSubject.Value) ;
        isCond  = ismember({Tr.Condition}, condOn) ;
        if ddTrial.Value == "RT の除外のあと"
            isKeep = true(1, numel(Tr)) ;
        else
            isKeep = [Tr.KeepAll] ;
        end
        idx = find(isSubj & isCond & isKeep) ;
    end

    function [FxA, FzA, t0] = alignedWaves(kk)
        % 縦軸の設定に合わせた波形（列 = 試行）と、時間軸の 0 にする時刻 t0 [ms]
        FxA = [Tr(kk).Fx] ;
        FzA = [Tr(kk).Fz2] ;
        switch ddY.Value
            case '基準値を引く (N)'
                FxA = FxA - [Tr(kk).FxBase] ;
                FzA = FzA - [Tr(kk).Fz2Base] ;
            case '基準値を引いて体重で割る (BW)'
                FxA = (FxA - [Tr(kk).FxBase])  ./ [Tr(kk).BW] ;
                FzA = (FzA - [Tr(kk).Fz2Base]) ./ [Tr(kk).BW] ;
        end
        switch ddTime.Value
            case 'キュー',           t0 = zeros(1, numel(kk)) ;
            case 'Onset',            t0 = [Tr(kk).IOnset] ;
            case '踏み込み足の接地', t0 = [Tr(kk).IFC] ;
        end
    end

    function [tm, FxM, FzM] = meanWaves(FxA, FzA, t0)
        % 時間軸の 0 をそろえてから平均する（そろえたあと、全試行の抜き出し区間に入る範囲だけ）
        tm  = ((WinMs(1) - min(t0)) : (WinMs(2) - max(t0)))' ;
        FxS = NaN(numel(tm), size(FxA, 2)) ;  FzS = FxS ;
        for j = 1:size(FxA, 2)
            ii = tm + t0(j) - WinMs(1) + 1 ;
            FxS(:,j) = FxA(ii, j) ;
            FzS(:,j) = FzA(ii, j) ;
        end
        FxM = mean(FxS, 2, 'omitnan') ;   % 記録の外（NaN）は除いて平均する
        FzM = mean(FzS, 2, 'omitnan') ;
    end

    function v = thrValue(kk)
        % 閾値を、縦軸の設定に合わせて変換する（行ベクトル）
        v = [Tr(kk).FxThr] ;
        switch ddY.Value
            case '基準値を引く (N)',              v = v - [Tr(kk).FxBase] ;
            case '基準値を引いて体重で割る (BW)', v = (v - [Tr(kk).FxBase]) ./ [Tr(kk).BW] ;
        end
    end

    function [yUnit, yNote] = yAxisText()
        switch ddY.Value
            case 'そのまま (N)',     yUnit = '(N)' ;  yNote = 'そのまま' ;
            case '基準値を引く (N)', yUnit = '(N)' ;  yNote = 'キュー前 0.5 s の中央値を引く' ;
            otherwise,               yUnit = '(BW)' ; yNote = '基準値を引いて体重で割る' ;
        end
    end

    function pickTrial(k)
        selTrial = k ;
        lblInfo.Text = sprintf(['S%02d　%s　Trial %d\n' 'RT %.0f ms　接地 %.0f ms（キューから）\n' ...
            '基準値 %.1f N　閾値 %.1f N'], Tr(k).Subject, Tr(k).Condition, Tr(k).Trial, ...
            Tr(k).IOnset, Tr(k).IFC, Tr(k).FxBase, Tr(k).FxThr) ;
        redraw() ;
    end

    function saveFigure()
        if ~exist(outFolder, 'dir'), mkdir(outFolder) ; end
        base = sprintf('fx_onset_%s', datestr(now, 'yyyymmdd_HHMMSS')) ; %#ok<TNOW1,DATST>
        exportapp(fig, fullfile(outFolder, [base '.png'])) ;
        uialert(fig, sprintf('%s.png に保存しました', fullfile(outFolder, base)), '保存', 'Icon', 'success') ;
    end

end


%% ローカル関数
function Tr = extractFx(analysisFolder, ConditionNameArray, WinMs)
% x8 で RT が残った Go 試行について、x3 から Fx・Fz2 を m3 と同じ手順で計算し、キュー起点で抜き出す

addpath(analysisFolder) ;   % parameters.m
Prm = parameters ;

load(fullfile(analysisFolder, 'x8_StatTable', 'StatTable.mat'), 'TrialTable') ;
T = TrialTable(TrialTable.IsGo & ~isnan(TrialTable.RTForce_ms), :) ;   % RT の除外のあと
% すべての除外のあと：top・床反力の指標も x8 で残っている試行
T.KeepAll = ~isnan(T.PeakVelTop) & ~isnan(T.MT_ms) & ~isnan(T.PeakFz2_BW) ;

Tr = struct('Subject', {}, 'Condition', {}, 'Trial', {}, 'Fx', {}, 'Fz2', {}, 'FxBase', {}, 'FxThr', {}, ...
    'Fz2Base', {}, 'IOnset', {}, 'IFC', {}, 'BW', {}, 'KeepAll', {}) ;
nMismatch = 0 ;

for iSubject = unique(T.Subject)'
    fprintf('S%02d の x3 を読み込み中...\n', iSubject) ;
    S  = load(fullfile(analysisFolder, 'x3_DataChecked', sprintf('Data%02d.mat', iSubject)), 'DataArray') ;
    Ts = T(T.Subject == iSubject, :) ;

    for r = 1:height(Ts)
        iCondition = find(strcmp(ConditionNameArray, Ts.Condition(r))) ;
        Data = S.DataArray(Ts.Trial(r), iCondition) ;
        fsA  = Data.AnalogFs ;

        % キュー（Go 試行は正のパルスが先）
        tCue = find(Data.LEDData(:,2) > Prm.Cue.GoThresholdV, 1, 'first') ;

        % m3 と同じ前処理：末尾の NaN を切り、50 Hz でローパス
        lastValid = find(~any(isnan(Data.Force1), 2) & ~any(isnan(Data.Force2), 2), 1, 'last') ;
        [bR, aR] = butter(2, Prm.RT.FxFc/(fsA/2)) ;
        F1f = filtfilt(bR, aR, Data.Force1(1:lastValid, :)) ;
        F2f = filtfilt(bR, aR, Data.Force2(1:lastValid, :)) ;
        fx  = F1f(:,1) + F2f(:,1) ;
        fz2 = F2f(:,3) ;

        nBase   = round(Prm.RT.BaseSec * fsA) ;
        fxBase  = median(fx( max(1, tCue-nBase) : tCue-1)) ;
        fz2Base = median(fz2(max(1, tCue-nBase) : tCue-1)) ;
        tFC     = find(fz2(tCue:end) > fz2Base + Prm.RT.FootContactN, 1, 'first') + tCue - 1 ;
        fxThr   = fxBase + Prm.RT.FxRatio * max(fx(tCue:tFC) - fxBase) ;

        % x8 の Onset と一致するか（一致しなければ注意を出す。描く Onset は x8 の値）
        tOnset = Ts.SwingOnsetForce(r) ;
        isOver = fx > fxThr ;
        nDur   = round(Prm.RT.DurMs/1000 * fsA) ;
        tCheck = NaN ;
        for k = tCue+1 : (tFC - nDur + 1)
            if ~isOver(k-1) && all(isOver(k : k+nDur-1)), tCheck = k ; break, end
        end
        if tCheck ~= tOnset
            nMismatch = nMismatch + 1 ;
            fprintf(2, '  （注意）S%02d %s Trial %d：計算し直した Onset %g と x8 の %g が違います\n', ...
                iSubject, Ts.Condition(r), Ts.Trial(r), tCheck, tOnset) ;
        end

        % キュー起点で抜き出す（記録の外は NaN）
        ii    = tCue + (WinMs(1):WinMs(2))' ;
        isIn  = ii >= 1 & ii <= numel(fx) ;
        fxW   = NaN(numel(ii), 1) ;  fxW(isIn)  = fx(ii(isIn)) ;
        fz2W  = NaN(numel(ii), 1) ;  fz2W(isIn) = fz2(ii(isIn)) ;

        Tr(end+1).Subject = iSubject ; %#ok<AGROW>
        Tr(end).Condition = char(Ts.Condition(r)) ;
        Tr(end).Trial     = Ts.Trial(r) ;
        Tr(end).Fx        = fxW ;
        Tr(end).Fz2       = fz2W ;
        Tr(end).FxBase    = fxBase ;
        Tr(end).FxThr     = fxThr ;
        Tr(end).Fz2Base   = fz2Base ;
        Tr(end).IOnset    = (tOnset - tCue) / fsA * 1000 ;   % キューからの時刻 [ms]（= RT）
        Tr(end).IFC       = (tFC    - tCue) / fsA * 1000 ;   % キューからの時刻 [ms]
        Tr(end).BW        = Ts.BWest_N(r) ;
        Tr(end).KeepAll   = Ts.KeepAll(r) ;
    end
    clear S
end
fprintf('Onset の照合：%d 試行中 %d 試行が x8 と違う\n', numel(Tr), nMismatch) ;
end