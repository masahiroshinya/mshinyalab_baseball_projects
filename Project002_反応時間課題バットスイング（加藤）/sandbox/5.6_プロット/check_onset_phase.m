% check_onset_phase.m
%
% free と simple で、検出された動作開始（onset）が身体運動の同じ局面を
% 捉えているかを目視で確かめる。
%
% 考え方:
%   同じ局面を捉えているなら、onset を時刻 0 にそろえた波形は条件間で重なるはず。
%   重ならなければ、onset が条件によって違う意味を持っていることになる。
%   比較のためキュー基準の図も並べて描く。
%
%   free は自己ペース条件なのでキュー基準では揃わなくて当然だが、
%   onset 基準でも揃わないなら、RT だけでなく MT・Slope も条件間で
%   比較できないことになる（技術説明.md §5 の課題）。
%
% 検出方式は untitled.m と同一（Fx 基準・比率 0.20・持続 20 ms）。
%
% 2026-08-26

clear
close all
clc

%% ---- 1. 設定 ----
AnalysisDir = fullfile('..', '..', 'Experiments', 'Main experiments', '03_Analysis') ;

SubjectList   = 1:5 ;
ConditionList = [1 2] ;                    % 1=free, 2=simple
ConditionName = {'free', 'simple'} ;

Prm.CueGoThresholdV  =  2 ;
Prm.CueNegThresholdV = -1 ;
Prm.ForceFc          = 50 ;
Prm.FootContactN     = 50 ;
Prm.BaseSec          = 0.5 ;
Prm.RatioFx          = 0.20 ;
Prm.DurMs            = 20 ;

WinSec  = [-0.5, 1.0] ;                    % 重ね描きの窓 [s]
GridFs  = 1000 ;                           % 共通の時間グリッド [Hz]
tGrid   = (WinSec(1) : 1/GridFs : WinSec(2))' ;

%% ---- 2. 全試行を処理して波形を集める ----
Trace = struct('cond',{},'subject',{},'trial',{}, ...
               'fxCue',{},'fxOnset',{},'velCue',{},'velOnset',{}, ...
               'velNorm',{},'fxNorm',{}, ...
               'rt',{},'mt',{},'peakVel',{},'velAtOnset',{},'fxAtOnset',{}) ;

% 正規化時間のグリッド：0 = onset、1 = 最大速度の時点
pGrid = (-0.3 : 0.01 : 1.3)' ;

for iSubject = SubjectList
    S = load( fullfile(AnalysisDir, 'x3_DataChecked', sprintf('Data%02d.mat', iSubject)) ) ;
    DataArray = S.DataArray ;

    for iCondition = ConditionList
        for iTrial = 1:size(DataArray, 1)

            Data = DataArray(iTrial, iCondition) ;
            if isempty(Data.ErrorCode) || isequal(Data.ErrorCode, 3), continue ; end

            fs       = Data.FrameRate ;
            analogFs = Data.AnalogFs ;
            ledData  = Data.LEDData ;
            force1   = Data.Force1 ;
            force2   = Data.Force2 ;
            top      = Data.Markers.top ;

            % 末尾 NaN を落とす
            isBad     = any(isnan(ledData),2) | any(isnan(force1),2) | any(isnan(force2),2) ;
            lastValid = find(~isBad, 1, 'last') ;
            if isempty(lastValid) || lastValid < 100, continue ; end
            ledData = ledData(1:lastValid,:) ;
            force1  = force1( 1:lastValid,:) ;
            force2  = force2( 1:lastValid,:) ;
            nAnalog = lastValid ;

            % キュー
            tGoStim = find(ledData(:,2) > Prm.CueGoThresholdV, 1, 'first') ;
            if isempty(tGoStim), continue ; end       % NoGo 試行

            % 床反力
            [b,a]  = butter(2, Prm.ForceFc/(analogFs/2), 'low') ;
            force1 = filtfilt(b,a,force1) ;
            force2 = filtfilt(b,a,force2) ;
            fx     = force1(:,1) + force2(:,1) ;

            tFootContact = find(force2(tGoStim:nAnalog,3) > Prm.FootContactN, 1, 'first') ;
            if isempty(tFootContact), continue ; end
            tFootContact = tFootContact + tGoStim - 1 ;
            if tFootContact - tGoStim < 50, continue ; end

            % RT 検出（untitled.m と同一）
            nDur   = round(Prm.DurMs/1000 * analogFs) ;
            iBase  = max(1, tGoStim - round(Prm.BaseSec*analogFs)) : tGoStim-1 ;
            baseFx = median( fx(iBase) ) ;
            peakFx = max( fx(tGoStim:tFootContact) - baseFx ) ;
            if peakFx <= 0, continue ; end

            thresholdFx = baseFx + peakFx * Prm.RatioFx ;
            isOver      = fx > thresholdFx ;
            tOnsetFx    = NaN ;
            for k = tGoStim+1 : (tFootContact - nDur + 1)
                if ~isOver(k-1) && all( isOver(k : k+nDur-1) )
                    tOnsetFx = k ; break
                end
            end
            if isnan(tOnsetFx), continue ; end

            % バット先端速度
            topVelNorm = sum( diff3p(top, 1/fs).^2, 2 ).^0.5 / 1000 ;   % [m/s]
            iGoFrame   = max(1, round(tGoStim/(analogFs/fs))) ;
            [peakVel, iRel] = max( topVelNorm(iGoFrame:end) ) ;
            iPeakFrame = iRel + iGoFrame - 1 ;

            % 妥当性フィルタ（untitled.m の集計と同じ基準）
            rt = (tOnsetFx - tGoStim)/analogFs*1000 ;
            mt = ((iPeakFrame-1)/fs - (tOnsetFx-1)/analogFs)*1000 ;
            if peakVel <= 5 || peakVel >= 40 || mt <= 0 || rt < 100 || rt >= 600, continue ; end

            % 共通グリッドへ載せ替える（アナログ 1000 Hz、マーカー 250 Hz）
            tA = ((1:nAnalog)' - 1)/analogFs ;
            tM = ((1:numel(topVelNorm))' - 1)/fs ;

            resample = @(tSrc, ySrc, tZero) interp1(tSrc - tZero, ySrc, tGrid, 'linear', NaN) ;

            iOnsetFrame = (tOnsetFx-1)/analogFs ;    % 秒に直してから引く

            % 時間を MT で正規化して載せ替える（0 = onset、1 = 最大速度）
            pM = (tM - iOnsetFrame) / (mt/1000) ;
            pA = (tA - iOnsetFrame) / (mt/1000) ;

            Trace(end+1) = struct( ...
                'cond', iCondition, 'subject', iSubject, 'trial', iTrial, ...
                'fxCue',    resample(tA, fx,         (tGoStim-1)/analogFs), ...
                'fxOnset',  resample(tA, fx,         iOnsetFrame), ...
                'velCue',   resample(tM, topVelNorm, (tGoStim-1)/analogFs), ...
                'velOnset', resample(tM, topVelNorm, iOnsetFrame), ...
                'velNorm', interp1(pM, topVelNorm/peakVel,        pGrid, 'linear', NaN), ...
                'fxNorm',  interp1(pA, (fx-baseFx)/peakFx,        pGrid, 'linear', NaN), ...
                'rt', rt, 'mt', mt, 'peakVel', peakVel, ...
                'velAtOnset', interp1(tM, topVelNorm, iOnsetFrame, 'linear', NaN), ...
                'fxAtOnset',  (fx(tOnsetFx) - baseFx) / peakFx ) ;
        end
    end
end

fprintf('集計対象：%d 試行（free %d、simple %d）\n\n', numel(Trace), ...
    sum([Trace.cond]==1), sum([Trace.cond]==2)) ;

%% ---- 3. 定量的な確認：onset 時点でどこまで動いているか ----
fprintf('=== onset 時点の状態（中央値）===\n') ;
fprintf('%-8s %5s %12s %14s %12s %12s\n', ...
    '条件','n','RT [ms]','onset時の速度','ピーク比 [%]','MT [ms]') ;
fprintf('%s\n', repmat('-',1,68)) ;
for c = ConditionList
    k = [Trace.cond] == c ;
    velAt = [Trace(k).velAtOnset] ;
    pkv   = [Trace(k).peakVel] ;
    fprintf('%-8s %5d %12.1f %12.2f m/s %11.1f%% %12.1f\n', ...
        ConditionName{c}, sum(k), median([Trace(k).rt]), ...
        median(velAt), median(velAt./pkv*100), median([Trace(k).mt])) ;
end
fprintf('\n※ ピーク比 = onset 時点の速度 ÷ その試行の最大速度。\n') ;
fprintf('   同じ局面を捉えているなら、条件間でこの値が揃うはず。\n\n') ;

%% ---- 4. 作図 ----
Col = [0.165 0.471 0.839 ;    % free   （青）
       0.922 0.408 0.204] ;   % simple （橙）
SURF = [0.988 0.988 0.984] ; INK = [0.043 0.043 0.043] ;

figure('Color', SURF, 'Position', [50 50 1400 900]) ;
tl = tiledlayout(2, 2, 'Padding','compact', 'TileSpacing','compact') ;

Field  = {'fxCue','fxOnset' ; 'velCue','velOnset'} ;
YLab   = {'F_x  [N]', 'Bat tip velocity [m/s]'} ;
ColTtl = {'キュー基準（t = 0 がキュー）', 'onset 基準（t = 0 が検出された動作開始）'} ;

for row = 1:2
  for col = 1:2
    ax = nexttile((row-1)*2 + col) ; hold(ax,'on') ;
    set(ax,'Color',SURF,'FontSize',12,'Box','off','TickDir','out', ...
           'YGrid','on','GridColor',[.9 .9 .89],'GridAlpha',1) ;

    hMedian = gobjects(1,2) ;
    for c = ConditionList
        k = find([Trace.cond] == c) ;
        M = nan(numel(tGrid), numel(k)) ;
        for i = 1:numel(k)
            M(:,i) = Trace(k(i)).(Field{row,col}) ;
        end
        % 個々の試行（薄く）
        plot(tGrid, M, '-', 'Color', [Col(c,:) 0.10], 'LineWidth', 0.5) ;
        % 条件の中央値（太く）
        hMedian(c) = plot(tGrid, median(M,2,'omitnan'), '-', ...
            'Color', Col(c,:), 'LineWidth', 2.5) ;
    end

    xline(0, 'k-', 'LineWidth', 1.5) ;
    if row == 1, yline(0, 'k:', 'LineWidth', 0.8) ; end
    xlim(WinSec) ;
    ylabel(YLab{row}) ;
    if row == 2, xlabel('Time [s]') ; end
    if row == 1, title(ColTtl{col}, 'FontSize', 13, 'Color', INK) ; end
    if row == 1 && col == 1
        legend(hMedian, ConditionName, 'Location','northwest', 'Box','off') ;
    end
    grid on
  end
end

title(tl, 'free と simple で、検出された動作開始は同じ局面を捉えているか', ...
    'FontSize', 16, 'FontWeight','bold', 'Color', INK) ;
subtitle(tl, ['細線 = 個々の試行、太線 = 条件の中央値    ' ...
    '右列で波形が重なれば、両条件で同じ局面を捉えていることになる'], ...
    'FontSize', 11.5, 'Color', [.32 .32 .31]) ;


%% ---- 5. 時間を MT で正規化して重ねる ----
%  onset を 0、最大速度の時点を 1 とする。
%  ここで重なれば「同じ局面を、違うテンポでたどっている」ことになる。
%  重ならなければ、onset が別の局面を指していることになる。

figure('Color', SURF, 'Position', [80 80 1400 560]) ;
tl2 = tiledlayout(1, 2, 'Padding','compact', 'TileSpacing','compact') ;

NField = {'velNorm', 'fxNorm'} ;
NYLab  = {'Bat tip velocity（最大速度で正規化）', 'F_x（ベースラインからピークで正規化）'} ;

for col = 1:2
    ax = nexttile(col) ; hold(ax,'on') ;
    set(ax,'Color',SURF,'FontSize',12,'Box','off','TickDir','out', ...
           'YGrid','on','GridColor',[.9 .9 .89],'GridAlpha',1) ;
    hM = gobjects(1,2) ;
    for c = ConditionList
        k = find([Trace.cond] == c) ;
        M = nan(numel(pGrid), numel(k)) ;
        for i = 1:numel(k), M(:,i) = Trace(k(i)).(NField{col}) ; end
        plot(pGrid, M, '-', 'Color', [Col(c,:) 0.10], 'LineWidth', 0.5) ;
        hM(c) = plot(pGrid, median(M,2,'omitnan'), '-', 'Color', Col(c,:), 'LineWidth', 2.5) ;
    end
    xline(0, 'k-',  'onset',  'LineWidth', 1.5, 'LabelOrientation','horizontal') ;
    xline(1, 'k--', 'peak',   'LineWidth', 1.2, 'LabelOrientation','horizontal') ;
    yline(Prm.RatioFx, 'k:', 'LineWidth', 0.8) ;
    xlim([-0.3 1.3]) ;
    xlabel('正規化時間（0 = onset、1 = 最大速度）') ;
    ylabel(NYLab{col}) ;
    if col == 1
        legend(hM, ConditionName, 'Location','northwest', 'Box','off') ;
    end
    grid on
end

title(tl2, '時間を MT で正規化すると重なるか（重なれば「同じ局面・違うテンポ」）', ...
    'FontSize', 16, 'FontWeight','bold', 'Color', INK) ;

%% ---- 6. 正規化波形の条件間のずれを数値で確認 ----
%  区間を分けて測る。onset 近傍（0〜0.5）が「同じ局面か」の判断に効く区間で、
%  0.7 以降は体重移動・前足接地による大きな負の振れが入るため、
%  peakFx（接地前の立ち上がり幅）での正規化が意味を持たなくなる。
Window = { 'onset近傍 (0〜0.5)', [0.0 0.5] ; ...
           '立ち上がり (0〜1.0)', [0.0 1.0] } ;

fprintf('=== 正規化時間での中央値波形のずれ（縦軸は 0〜1 に正規化済み）===\n') ;
fprintf('%-22s %-22s %10s %10s\n', '波形', '区間', '平均ずれ', '最大ずれ') ;
fprintf('%s\n', repmat('-',1,68)) ;
for col = 1:2
    Med = nan(numel(pGrid), 2) ;
    for c = ConditionList
        k = find([Trace.cond] == c) ;
        M = nan(numel(pGrid), numel(k)) ;
        for i = 1:numel(k), M(:,i) = Trace(k(i)).(NField{col}) ; end
        Med(:,c) = median(M, 2, 'omitnan') ;
    end
    for w = 1:size(Window,1)
        inWin = pGrid >= Window{w,2}(1) & pGrid <= Window{w,2}(2) ;
        d = abs(Med(inWin,1) - Med(inWin,2)) ;
        fprintf('%-22s %-22s %10.3f %10.3f\n', NField{col}, Window{w,1}, ...
            mean(d,'omitnan'), max(d)) ;
    end
end
fprintf('\n※ ずれが小さいほど、両条件が「同じ形の運動を、違うテンポでたどっている」ことを意味する。\n') ;
