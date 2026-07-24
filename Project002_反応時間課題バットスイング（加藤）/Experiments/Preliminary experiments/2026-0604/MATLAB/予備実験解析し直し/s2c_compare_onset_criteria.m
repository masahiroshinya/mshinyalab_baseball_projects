% s2c_compare_onset_criteria.m
%
% 目的：逆探索の「さかのぼり基準」を3案で比較する。
%   案B-1: ベースライン + 3SD
%   案B-2: ピーク速度の 3%
%   案B-3: ピーク速度の 1%
%   参考:  案A（単一閾値 1.0 m/s、さかのぼりなし）

clear; close all; clc

iSubject = 2 ;
load(sprintf('x3_DataChecked/Data%02d', iSubject))
load(sprintf('x4_SingleTrialAnalysisResults/SingleTrialAnalysisResults%02d', iSubject))

ConditionNameArray = {'free', 'simple', 'gonogo'} ;
ANCHOR     = 1.0 ;    % [m/s] 「確実にスイング」と言えるアンカー閾値
WINDOW_SEC = 2.0 ;
nTrial     = size(SingleTrialResultArray, 1) ;

for iCondition = 1:3
    fprintf('\n===== %s =====\n', ConditionNameArray{iCondition}) ;
    fprintf('Trial  CueText   案A(1.0)  案B-1(base+3SD)  案B-2(3%%peak)  案B-3(1%%peak)\n') ;

    for iTrial = 1:nTrial
        Result = SingleTrialResultArray(iTrial, iCondition) ;
        v  = Result.NetVelTop ;
        if isempty(v) || isnan(Result.TCueMarker), continue, end
        fs = DataArray(iTrial, iCondition).FrameRate ;

        win       = Result.TCueMarker : min(Result.TCueMarker+round(WINDOW_SEC*fs), length(v)) ;
        baseRange = max(1, Result.TCueMarker-round(0.5*fs)) : Result.TCueMarker-1 ;

        % ---- アンカー：確実にスイングと言える点。無ければ全案NaN（NoGo棄却）----
        idxAnchor = find(v(win) > ANCHOR, 1, 'first') ;
        if isempty(idxAnchor)
            fprintf('%5d  %-8s  %8s  %15s  %13s  %13s   ← アンカー無し（棄却）\n', ...
                iTrial, Result.CueText, 'NaN', 'NaN', 'NaN', 'NaN') ;
            continue
        end

        peakVel = max(v(win)) ;
        rt = nan(1,4) ;
        rt(1) = (idxAnchor-1) / fs * 1000 ;                       % 案A

        % ---- 逆探索：アンカーから過去にさかのぼる ----
        %  win(1):win(idxAnchor) の区間で、基準を下回る「最後」の点を探す
        segment = v(win(1):win(idxAnchor)) ;
        levelList = [mean(v(baseRange)) + 3*std(v(baseRange)), ...
            0.03 * peakVel, ...
            0.01 * peakVel] ;

        for k = 1:3
            idxOnset = find(segment < levelList(k), 1, 'last') ;
            if ~isempty(idxOnset)
                rt(k+1) = (idxOnset-1) / fs * 1000 ;
            end
        end

        fprintf('%5d  %-8s  %8.1f  %15.1f  %13.1f  %13.1f\n', ...
            iTrial, Result.CueText, rt(1), rt(2), rt(3), rt(4)) ;
    end
end
