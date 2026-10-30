function top_trajectory_3d()
% top_trajectory_3d.m
%
% バット先端（top マーカー）の軌道を 3 次元で描き、被験者ごとに条件を出し入れして見比べるツール。
% 打席の左右で軌道の向きが逆になるので、被験者は 1 名ずつ選ぶ（被験者をまたいで重ねない）。
%
% データ：
%   試行の選別と時刻   x8_StatTable/StatTable.mat の TrialTable
%                      （Go 試行で、x8 の除外で PeakVelTop が NaN になっていない試行）
%   top の座標         x3_DataChecked/DataNN.mat の DataArray(Trial, 条件).Markers.top
%                      （m3_analyze_single_trial と同じ前処理：NaN の線形補間 → 30 Hz 2 次 Butterworth の filtfilt）
%   描く区間           スイング開始（SwingOnsetForce）〜 合成速度のピーク（TPeakVelTop）＋ PostSec
%   StrictSubjects     の被験者は、x8 の除外基準（top・onset・RT・床反力）のどれかに引っかかった試行を、
%                      目視で残した（Mark = k）ものも含めて外す（撮れていない試行が多いため）
%
% 使い方：このフォルダで top_trajectory_3d を実行する。
%   初回は x3 の .mat を読むので時間がかかる。抜き出した軌道は cache/ に保存し、2 回目からはそれを読む。
%   x3・x8 を作り直したときは cache/top_trajectory_cache.mat を消してから実行する。
%
% 2026-10-28

%% 設定
PostSec = 0.10 ;   % ピーク速度の後に描く長さ [s]（フォロースルーの入り口まで）
StrictSubjects = [3 4] ;   % 除外基準に引っかかった試行を、目視の判断に関係なく外す被験者

ConditionNameArray = {'free', 'simple', 'gonogo', 'gostop'} ;   % x4 の DataArray の列の並び
ConditionLabel     = {'Free', 'Simple', 'Go/No-go', 'Go/Stop'} ;
ConditionColor     = [0.40 0.40 0.40 ;    % free    灰
                      0.00 0.45 0.70 ;    % simple  青
                      0.90 0.62 0.00 ;    % gonogo  橙
                      0.80 0.20 0.20] ;   % gostop  赤

scriptFolder   = fileparts(mfilename('fullpath')) ;
projectFolder  = fullfile(scriptFolder, '..', '..', '..', '..') ;   % Project002 のフォルダ
analysisFolder = fullfile(projectFolder, 'Experiments', 'Main experiments', '03_Analysis') ;
cacheFolder    = fullfile(scriptFolder, 'cache') ;
cachePath      = fullfile(cacheFolder, 'top_trajectory_cache.mat') ;
outFolder      = fullfile(scriptFolder, 'output') ;

%% データ：軌道を抜き出す（キャッシュがあれば読む）
if exist(cachePath, 'file')
    load(cachePath, 'Traj', 'CachePostSec') ;
    if CachePostSec ~= PostSec
        error('キャッシュの PostSec（%g s）が設定（%g s）と違います。%s を消してから実行してください。', ...
            CachePostSec, PostSec, cachePath) ;
    end
    if ~isfield(Traj, 'IsFlagged')
        error('キャッシュが古い版のものです。%s を消してから実行してください。', cachePath) ;
    end
    fprintf('キャッシュを読みました：%d 試行\n', numel(Traj)) ;
else
    Traj = extractTrajectories(analysisFolder, ConditionNameArray, PostSec) ;
    CachePostSec = PostSec ;
    if ~exist(cacheFolder, 'dir'), mkdir(cacheFolder) ; end
    save(cachePath, 'Traj', 'CachePostSec') ;
    fprintf('キャッシュを保存しました：%s\n', cachePath) ;
end

isOut = [Traj.IsFlagged] & ismember([Traj.Subject], StrictSubjects) ;
for s = StrictSubjects
    fprintf('S%02d：除外基準に引っかかった %d 試行を外します\n', s, sum(isOut & [Traj.Subject] == s)) ;
end
Traj = Traj(~isOut) ;

SubjectArray = unique([Traj.Subject]) ;
nCondition   = numel(ConditionNameArray) ;

%% 画面を作る
fig = uifigure('Name', 'top marker 3D trajectory', 'Position', [100 100 1150 700]) ;
gl  = uigridlayout(fig, [1 2]) ;
gl.ColumnWidth = {230, '1x'} ;

% ---- 左：操作パネル ----
pl = uigridlayout(gl, [12 1]) ;
pl.RowHeight = {20, '1x', 20, 22, 22, 22, 22, 20, 22, 22, 22, 30} ;

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

uilabel(pl, 'Text', '表示', 'FontWeight', 'bold') ;
cbAlign = uicheckbox(pl, 'Text', 'Onset の位置を原点にそろえる', 'Value', false, ...
    'ValueChangedFcn', @(~,~) redraw()) ;
cbMean  = uicheckbox(pl, 'Text', '条件平均を太線で重ねる', 'Value', false, ...
    'ValueChangedFcn', @(~,~) redraw()) ;
cbMeanOnly = uicheckbox(pl, 'Text', '平均だけを描く（試行を隠す）', 'Value', false, ...
    'ValueChangedFcn', @(~,~) redraw()) ;
uibutton(pl, 'Text', '図を保存（PNG・PDF）', 'ButtonPushedFcn', @(~,~) saveFigure()) ;

% ---- 右：3 次元の軸 ----
ax = uiaxes(gl) ;
view(ax, 3) ;
grid(ax, 'on') ;
hold(ax, 'on') ;
rotate3d(ax, 'on') ;

redraw() ;

%% 入れ子関数（画面の操作で呼ばれる）
    function redraw()
        [az, el] = view(ax) ;   % 回した視点を保つ
        cla(ax) ;
        selSubject = lbSubject.Value ;
        legendHandle = gobjects(0) ;
        legendText   = {} ;
        nShown       = zeros(1, nCondition) ;

        for jc = 1:nCondition
            if ~cbCondition(jc).Value, continue, end
            isSel = [Traj.Subject] == selSubject & strcmp({Traj.Condition}, ConditionNameArray{jc}) ;
            idx = find(isSel) ;
            col = ConditionColor(jc,:) ;
            if isempty(idx)   % 試行がない条件も、凡例に 0 試行と出す
                legendHandle(end+1) = plot3(ax, NaN, NaN, NaN, '-', 'Color', col) ; %#ok<AGROW>
                legendText{end+1}   = sprintf('%s（0 試行）', ConditionLabel{jc}) ; %#ok<AGROW>
                continue
            end
            if ~cbMeanOnly.Value
                for k = idx
                    P = shapeTrajectory(k) ;
                    h = plot3(ax, P(:,1), P(:,2), P(:,3), '-', 'Color', [col 0.35], 'LineWidth', 0.8) ;
                    plot3(ax, P(Traj(k).IPeak,1), P(Traj(k).IPeak,2), P(Traj(k).IPeak,3), 'o', ...
                        'MarkerSize', 4, 'MarkerFaceColor', col, 'MarkerEdgeColor', 'none') ;
                end
            end
            nShown(jc) = numel(idx) ;

            if cbMean.Value || cbMeanOnly.Value
                Pm = meanTrajectory(idx) ;
                h = plot3(ax, Pm(:,1), Pm(:,2), Pm(:,3), '-', 'Color', col, 'LineWidth', 3) ;
                if cbMeanOnly.Value   % 平均の終点 = ピーク速度（時間正規化の 100%）
                    plot3(ax, Pm(end,1), Pm(end,2), Pm(end,3), 'o', ...
                        'MarkerSize', 7, 'MarkerFaceColor', col, 'MarkerEdgeColor', 'none') ;
                end
            end
            legendHandle(end+1) = h ; %#ok<AGROW>
            legendText{end+1}   = sprintf('%s（%d 試行）', ConditionLabel{jc}, nShown(jc)) ; %#ok<AGROW>
        end

        axis(ax, 'equal') ;
        xlabel(ax, 'X：投手方向 (m)') ;
        ylabel(ax, 'Y (m)') ;
        zlabel(ax, 'Z：鉛直 (m)') ;
        if cbMeanOnly.Value
            subTitle = '線：条件平均（Onset → ピーク速度を 0〜100% に正規化）、点：ピーク速度' ;
        else
            subTitle = sprintf('線：Onset → ピーク速度 + %.2f s、点：ピーク速度', PostSec) ;
        end
        title(ax, {sprintf('被験者 S%02d', selSubject), subTitle}, 'FontWeight', 'normal') ;
        if ~isempty(legendHandle)
            legend(ax, legendHandle, legendText, 'Location', 'northeastoutside') ;
        else
            legend(ax, 'off') ;
        end
        view(ax, az, el) ;
    end

    function P = shapeTrajectory(k)
        % 表示の設定（原点をそろえるか）に合わせて 1 試行の軌道を変換する
        P = Traj(k).XYZ ;
        if cbAlign.Value, P = P - P(1,:) ; end
    end

    function Pm = meanTrajectory(idx)
        % Onset 〜 ピーク速度を 101 点に時間正規化して平均する（ピーク後の部分は使わない）
        nPoint = 101 ;
        P3 = zeros(nPoint, 3, numel(idx)) ;
        for j = 1:numel(idx)
            Q = shapeTrajectory(idx(j)) ;
            Q = Q(1:Traj(idx(j)).IPeak, :) ;
            P3(:,:,j) = interp1(linspace(0, 1, size(Q,1)), Q, linspace(0, 1, nPoint)) ;
        end
        Pm = mean(P3, 3) ;
    end

    function saveFigure()
        if ~exist(outFolder, 'dir'), mkdir(outFolder) ; end
        base = sprintf('top_trajectory_S%02d_%s', lbSubject.Value, datestr(now, 'yyyymmdd_HHMMSS')) ; %#ok<TNOW1,DATST>
        exportgraphics(ax, fullfile(outFolder, [base '.png']), 'Resolution', 300) ;
        exportgraphics(ax, fullfile(outFolder, [base '.pdf']), 'ContentType', 'vector') ;
        uialert(fig, sprintf('%s に保存しました', fullfile(outFolder, base)), '保存', 'Icon', 'success') ;
    end

end


%% ローカル関数
function Traj = extractTrajectories(analysisFolder, ConditionNameArray, PostSec)
% x8 で残った Go 試行について、x3 の top 座標から Onset 〜 ピーク速度 + PostSec を抜き出す

addpath(analysisFolder) ;   % parameters.m
Prm = parameters ;

load(fullfile(analysisFolder, 'x8_StatTable', 'StatTable.mat'), 'TrialTable') ;
T = TrialTable(TrialTable.IsGo & ~isnan(TrialTable.PeakVelTop) & ~isnan(TrialTable.SwingOnsetForce), :) ;

% x8 の除外基準のどれかに引っかかった試行（目視で残した Mark = k の試行も true）
T.IsFlagged = T.IsBadTop | T.IsBadOnset | T.IsShortRT | T.IsBadGRF | T.ExclTop | T.ExclRT | T.ExclGRF ;

Traj = struct('Subject', {}, 'Condition', {}, 'Trial', {}, 'XYZ', {}, 'IPeak', {}, 'IsFlagged', {}) ;

for iSubject = unique(T.Subject)'
    fprintf('S%02d の x3 を読み込み中...\n', iSubject) ;
    S = load(fullfile(analysisFolder, 'x3_DataChecked', sprintf('Data%02d.mat', iSubject)), 'DataArray') ;
    Ts = T(T.Subject == iSubject, :) ;

    for r = 1:height(Ts)
        iCondition = find(strcmp(ConditionNameArray, Ts.Condition(r))) ;
        Data = S.DataArray(Ts.Trial(r), iCondition) ;
        fs   = Data.FrameRate ;

        % m3_analyze_single_trial と同じ前処理（NaN の線形補間 → filtfilt）
        x = Data.Markers.(Prm.Excl.TopMarkerName) ;
        t = (1:size(x,1))' ;
        for col = 1:3
            nanIdx = isnan(x(:,col)) ;
            if any(nanIdx) && any(~nanIdx)
                x(nanIdx,col) = interp1(t(~nanIdx), x(~nanIdx,col), t(nanIdx), 'linear', 'extrap') ;
            end
        end
        [b, a] = butter(2, Prm.Fc/(fs/2)) ;
        x = filtfilt(b, a, x) / 1000 ;   % [m]

        % 区間：Onset（アナログのサンプル番号 → マーカーのフレーム番号）〜 ピーク速度 + PostSec
        iOnset = max(1, round(Ts.SwingOnsetForce(r) / Data.AnalogFs * fs)) ;
        iPeak  = Ts.TPeakVelTop(r) ;
        iEnd   = min(size(x,1), iPeak + round(PostSec * fs)) ;
        if iPeak <= iOnset
            fprintf(2, '  （注意）S%02d %s Trial %d：ピーク速度が Onset より前なので飛ばします\n', ...
                iSubject, Ts.Condition(r), Ts.Trial(r)) ;
            continue
        end

        Traj(end+1).Subject = iSubject ; %#ok<AGROW>
        Traj(end).Condition = char(Ts.Condition(r)) ;
        Traj(end).Trial     = Ts.Trial(r) ;
        Traj(end).XYZ       = x(iOnset:iEnd, :) ;
        Traj(end).IPeak     = iPeak - iOnset + 1 ;   % 抜き出した区間の中でのピークの位置
        Traj(end).IsFlagged = Ts.IsFlagged(r) ;
    end
    clear S
end
end