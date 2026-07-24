% s3b_check_velocity_components.m
%
% 目的：バット先端速度を「合成速度（スカラー）」から「速度ベクトル（成分）」に
%       展開するにあたり、まず座標系の向きを実測で確認する。（01 論点5）
%
% なぜ最初に符号を確認するのか：
%   合成速度 sqrt(vx^2+vy^2+vz^2) は常に正なので、
%   軸の向きを取り違えていても表面化しなかった。
%   成分に展開した瞬間、符号の取り違えは Vx の正負を全部ひっくり返す。
%
%   先行資料（学習用_6/技術説明.md）には
%     「X軸方向の1次元速度（ホームベース方向 = 投手–捕手方向）」
%   とあるが、これは「X が投手–捕手の軸である」ことしか言っておらず、
%   +X がどちら向きかは書かれていない。しかも「ホームベース方向」という語は
%   素直に読むと投手方向とは逆になる。→ 実測で決める。
%
% 注意：
%   - カレントディレクトリを 2026-0604/MATLAB にして実行すること。
%   - Go 試行のみを見る（NoGo はスイングしない）。

clear; close all; clc

% -----------------------------------------------------------------------
% 設定
% -----------------------------------------------------------------------
iSubject   = 2 ;
iCondition = 2 ;   % 1=free, 2=simple, 3=gonogo
ConditionNameArray = {'free', 'simple', 'gonogo'} ;
condName   = ConditionNameArray{iCondition} ;

nShowTrial = 3 ;   % 波形を描く試行数

load(sprintf('x3_DataChecked/Data%02d', iSubject))
load(sprintf('x4_SingleTrialAnalysisResults/SingleTrialAnalysisResults%02d', iSubject))

Prm = parameters ;
nTrial = size(DataArray, 1) ;

fprintf('=== Subject %02d / %s ===\n\n', iSubject, condName) ;

% マーカーが何点あるか（骨盤マーカーの有無を確認する）
fprintf('--- 記録されているマーカー ---\n') ;
disp(fieldnames(DataArray(1, iCondition).Markers)) ;

% -----------------------------------------------------------------------
% 確認1：+X はどちら向きか（3つの独立した手がかりで判定する）
% -----------------------------------------------------------------------
fprintf('\n===== 確認1：+X の向き =====\n') ;
fprintf('手がかり1  : 構えでのバットの向き (top - bottom) の X 成分\n') ;
fprintf('             構えではバットは捕手側に倒れているので、\n') ;
fprintf('             +X が投手方向なら **負** になるはず。\n') ;
fprintf('手がかり2  : スイング中の top の X 座標の増減\n') ;
fprintf('             バット先端は捕手側から投手側へ回ってくるので、\n') ;
fprintf('             +X が投手方向なら 構え→ピーク時で **増加** するはず。\n') ;
fprintf('手がかり3  : ピーク速度時の Vx の符号\n') ;
fprintf('             インパクト付近でバット先端は投手方向に進むので、\n') ;
fprintf('             +X が投手方向なら **正** になるはず。\n\n') ;

fprintf('Trial  構えの(top-bottom)x   構えのtop_x   ピーク時のtop_x   差    ピーク時のVx\n') ;
fprintf('-----------------------------------------------------------------------------\n') ;

signCount = [0 0 0] ;   % 各手がかりが「+X = 投手方向」を支持した回数

for iTrial = 1:nTrial

    Data   = DataArray(iTrial, iCondition) ;
    Result = SingleTrialResultArray(iTrial, iCondition) ;

    if ~strcmp(Result.CueText, 'Go'),        continue, end
    if isempty(Result.NetVelTop),            continue, end
    if isnan(Result.TCueMarker),             continue, end

    fs = Data.FrameRate ;
    [b, a] = butter(2, Prm.Fc/(fs/2)) ;

    % NaN 補間 → フィルタ（m3 と同じ手順）
    M = struct() ;
    for f = {'top', 'bottom'}
        x = Data.Markers.(f{1}) ;
        t = (1:size(x,1))' ;
        for col = 1:size(x,2)
            nanIdx = isnan(x(:,col)) ;
            if any(nanIdx) && any(~nanIdx)
                x(nanIdx,col) = interp1(t(~nanIdx), x(~nanIdx,col), t(nanIdx), 'linear', 'extrap') ;
            end
        end
        M.(f{1}) = filtfilt(b, a, x) / 1000 ;   % [m]
    end

    velTop = diff3p(M.top, 1/fs) ;              % [m/s] N×3 のベクトル
    netVel = sum(velTop.^2, 2).^0.5 ;

    % 構え＝キュー直前 0.2 秒の平均
    baseRange = max(1, Result.TCueMarker-round(0.2*fs)) : Result.TCueMarker ;
    batVecX   = mean(M.top(baseRange,1) - M.bottom(baseRange,1)) ;   % 構えでのバットの向き
    topX_base = mean(M.top(baseRange,1)) ;

    [~, idxPeak] = max(netVel) ;
    topX_peak    = M.top(idxPeak, 1) ;
    vxAtPeak     = velTop(idxPeak, 1) ;

    fprintf('%4d %14.3f %14.3f %15.3f %8.3f %13.2f\n', ...
        iTrial, batVecX, topX_base, topX_peak, topX_peak - topX_base, vxAtPeak) ;

    signCount(1) = signCount(1) + (batVecX < 0) ;
    signCount(2) = signCount(2) + ((topX_peak - topX_base) > 0) ;
    signCount(3) = signCount(3) + (vxAtPeak > 0) ;
    nGo = sum(strcmp({SingleTrialResultArray(:,iCondition).CueText}, 'Go')) ;

end

fprintf('\n--- 判定（「+X = 投手方向」を支持した試行数）---\n') ;
fprintf('手がかり1（構えのバット向きが負）  : %d\n', signCount(1)) ;
fprintf('手がかり2（スイングで top_x が増加）: %d\n', signCount(2)) ;
fprintf('手がかり3（ピーク時 Vx が正）      : %d\n', signCount(3)) ;
fprintf('※ 3つとも大多数なら「+X = 投手方向」で確定。\n') ;
fprintf('※ 3つとも大多数が逆なら「+X = 捕手方向」。符号を反転して扱う。\n') ;
fprintf('※ 手がかりごとに割れる場合は、X が投手–捕手軸ではない可能性を疑う。\n') ;

% -----------------------------------------------------------------------
% 確認2：速度ベクトルの成分波形を見る
% -----------------------------------------------------------------------
fprintf('\n===== 確認2：成分波形（figure 1）=====\n') ;
fprintf('合成速度が捨てていた「向き」が見えるようにする。\n') ;

figure(1) ; clf
iShown = 0 ;

for iTrial = 1:nTrial

    Data   = DataArray(iTrial, iCondition) ;
    Result = SingleTrialResultArray(iTrial, iCondition) ;

    if ~strcmp(Result.CueText, 'Go'),  continue, end
    if isempty(Result.NetVelTop),      continue, end
    if isnan(Result.TCueMarker),       continue, end

    iShown = iShown + 1 ;
    if iShown > nShowTrial, break, end

    fs = Data.FrameRate ;
    [b, a] = butter(2, Prm.Fc/(fs/2)) ;

    x = Data.Markers.top ;
    t = (1:size(x,1))' ;
    for col = 1:size(x,2)
        nanIdx = isnan(x(:,col)) ;
        if any(nanIdx) && any(~nanIdx)
            x(nanIdx,col) = interp1(t(~nanIdx), x(~nanIdx,col), t(nanIdx), 'linear', 'extrap') ;
        end
    end
    posTop = filtfilt(b, a, x) / 1000 ;

    velTop = diff3p(posTop, 1/fs) ;
    netVel = sum(velTop.^2, 2).^0.5 ;

    tArray = ((1:size(velTop,1))' - Result.TCueMarker) / fs ;

    subplot(nShowTrial, 1, iShown)
    plot(tArray, velTop(:,1), 'r-', 'LineWidth', 1.2) ; hold on
    plot(tArray, velTop(:,2), 'g-', 'LineWidth', 1.0) ;
    plot(tArray, velTop(:,3), 'b-', 'LineWidth', 1.0) ;
    plot(tArray, netVel,      'k-', 'LineWidth', 1.4) ;
    yline(0, 'k:') ;
    hold off
    set(gca, 'XLim', [-0.5, 2.0]) ;
    xlabel('LED からの時間 (s)') ;
    ylabel('速度 (m/s)') ;
    title(sprintf('Trial %d  （黒=合成速度／赤=Vx／緑=Vy／青=Vz）', iTrial)) ;
    legend({'Vx', 'Vy', 'Vz', '|V|'}, 'Location', 'northwest') ;
    grid on

end

sgtitle(sprintf('Subject %02d / %s：速度ベクトルの成分', iSubject, condName)) ;

fprintf('\n見るポイント：\n') ;
fprintf('  ・合成速度（黒）は常に正。成分は正負に振れる。\n') ;
fprintf('  ・キュー前のベースラインで、合成速度は正の値に張り付くが\n') ;
fprintf('    成分は 0 のまわりで振動するはず（構えの揺れは往復運動のため）。\n') ;
fprintf('    → これが 00 の S02 ワッグル問題に効く可能性がある（要検証）。\n') ;
fprintf('  ・スイング中は Vx がどのタイミングで正のピークを取るかを見る。\n') ;
