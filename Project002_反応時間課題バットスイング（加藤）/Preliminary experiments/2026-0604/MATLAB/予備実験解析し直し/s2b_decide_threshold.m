% s2b_decide_threshold.m
%
% 目的：スイング開始検出の閾値を決めるための3つの確認を一度に行う。
%   確認1: 全試行・全条件のベースライン統計
%   確認2: 閾値感度分析（閾値を変えるとRTがどれだけ動くか）
%   確認3: NoGo試行の最大速度（＝閾値の下限を決める制約）

clear; close all; clc

iSubject = 2 ;
load(sprintf('x3_DataChecked/Data%02d', iSubject))
load(sprintf('x4_SingleTrialAnalysisResults/SingleTrialAnalysisResults%02d', iSubject))

ConditionNameArray = {'free', 'simple', 'gonogo'} ;
nCondition    = length(ConditionNameArray) ;
nTrial        = size(SingleTrialResultArray, 1) ;
thresholdList = [0.3 0.5 0.75 1.0 1.5 2.0] ;   % [m/s] 候補
WINDOW_SEC    = 2.0 ;                          % 探索窓：キューから何秒か

%% ===== 確認1：ベースライン統計（全試行・全条件）=====
fprintf('===== 確認1：ベースライン（キュー前0.5秒）=====\n') ;
baseMean = nan(nTrial, nCondition) ;
baseMax  = nan(nTrial, nCondition) ;

for iCondition = 1:nCondition
    for iTrial = 1:nTrial
        Result = SingleTrialResultArray(iTrial, iCondition) ;
        v = Result.NetVelTop ;
        if isempty(v) || isnan(Result.TCueMarker), continue, end
        fs = DataArray(iTrial, iCondition).FrameRate ;
        baseRange = max(1, Result.TCueMarker-round(0.5*fs)) : Result.TCueMarker-1 ;
        if isempty(baseRange), continue, end
        baseMean(iTrial, iCondition) = mean(v(baseRange)) ;
        baseMax(iTrial, iCondition)  = max(v(baseRange)) ;
    end
    fprintf('%-7s: 平均 %.3f, 最大 %.3f, 最大の最大 %.3f m/s\n', ...
        ConditionNameArray{iCondition}, ...
        mean(baseMean(:,iCondition),'omitnan'), ...
        mean(baseMax(:,iCondition),'omitnan'), ...
        max(baseMax(:,iCondition),[],'omitnan')) ;
end

%% ===== 確認3：NoGo試行の最大速度（閾値の下限を決める）=====
fprintf('\n===== 確認3：NoGo試行のキュー後%.1f秒の最大速度 =====\n', WINDOW_SEC) ;
noGoPeak = [] ;
for iTrial = 1:nTrial
    Result = SingleTrialResultArray(iTrial, 3) ;
    if ~strcmp(Result.CueText, 'NoGo'), continue, end
    v = Result.NetVelTop ;
    if isempty(v) || isnan(Result.TCueMarker), continue, end
    fs  = DataArray(iTrial, 3).FrameRate ;
    win = Result.TCueMarker : min(Result.TCueMarker+round(WINDOW_SEC*fs), length(v)) ;
    p   = max(v(win)) ;
    noGoPeak(end+1) = p ; %#ok<SAGROW>
    fprintf('Trial %2d [NoGo]: 最大 %.3f m/s\n', iTrial, p) ;
end
if ~isempty(noGoPeak)
    fprintf('→ NoGo全体の最大 = %.3f m/s（閾値はこれより上でなければならない）\n', max(noGoPeak)) ;
end

%% ===== 確認2：閾値感度分析 =====
fprintf('\n===== 確認2：閾値感度分析（Go試行のみ）=====\n') ;
for iCondition = 1:nCondition
    RT = nan(nTrial, length(thresholdList)) ;
    for iTrial = 1:nTrial
        Result = SingleTrialResultArray(iTrial, iCondition) ;
        if ~strcmp(Result.CueText, 'Go'), continue, end
        v = Result.NetVelTop ;
        if isempty(v) || isnan(Result.TCueMarker), continue, end
        fs = DataArray(iTrial, iCondition).FrameRate ;
        searchRange = Result.TCueMarker : min(Result.TCueMarker+round(WINDOW_SEC*fs), length(v)) ;
        for iTh = 1:length(thresholdList)
            idx = find(v(searchRange) > thresholdList(iTh), 1, 'first') ;
            if ~isempty(idx)
                RT(iTrial, iTh) = (idx-1) / fs * 1000 ;
            end
        end
    end
    fprintf('\n--- %s ---\n', ConditionNameArray{iCondition}) ;
    fprintf('閾値[m/s] :') ; fprintf('%8.2f', thresholdList) ; fprintf('\n') ;
    fprintf('平均RT[ms]:') ; fprintf('%8.1f', mean(RT,1,'omitnan')) ; fprintf('\n') ;
    fprintf('0.5との差 :') ; fprintf('%8.1f', mean(RT,1,'omitnan') - mean(RT(:,2),1,'omitnan')) ; fprintf('\n') ;
    fprintf('検出できた試行数:') ; fprintf('%8d', sum(~isnan(RT),1)) ; fprintf('\n') ;
end
