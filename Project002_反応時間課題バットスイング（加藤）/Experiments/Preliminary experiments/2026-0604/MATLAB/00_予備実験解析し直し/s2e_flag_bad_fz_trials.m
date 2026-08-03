% s2e_flag_bad_fz_trials.m
% 目的：床反力のベースラインが体重にならない（＝きちんと計測できていない）試行を
%       特定し、除外マスク FzExclude を作る。
% カレントは 2026-0604/MATLAB にすること。

clear; close all; clc

iSubject = 1 ;
fprintf('===== Subject %02d：床反力ベースライン点検 =====\n', iSubject) ;

load(sprintf('x3_DataChecked/Data%02d', iSubject))
load(sprintf('x4_SingleTrialAnalysisResults/SingleTrialAnalysisResults%02d', iSubject))

ConditionNameArray = {'free','simple','gonogo'} ;
nCondition = numel(ConditionNameArray) ;
nTrial     = size(SingleTrialResultArray, 1) ;
BASE_SEC   = 0.5 ;
TOL        = 0.20 ;   % 体重からのずれ許容（±20%）

baseTot = nan(nTrial, nCondition) ;

for c = 1:nCondition
    for t = 1:nTrial
        D = DataArray(t,c) ; R = SingleTrialResultArray(t,c) ;
        if ~isfield(D,'Force1') || isempty(D.Force1), continue, end
        if isnan(R.TCueMarker) || isnan(D.AnalogFs),  continue, end
        fsA   = D.AnalogFs ;
        tCueA = round(R.TCueMarker / D.FrameRate * fsA) ;
        if tCueA < round(BASE_SEC*fsA)+1, continue, end
        b = tCueA-round(BASE_SEC*fsA) : tCueA-1 ;
        Fz1 = D.Force1(:,3) ; Fz2 = D.Force2(:,3) ;
        if any(isnan(Fz1(b))) || any(isnan(Fz2(b))), continue, end
        baseTot(t,c) = mean(Fz1(b)) + mean(Fz2(b)) ;
    end
end

% ---- 体重の基準：全試行の中央値（正常試行が多数派なので頑健）----
BW = median(baseTot(:), 'omitnan') ;
fprintf('推定体重 BW = %.0f N\n\n', BW) ;

% ---- 除外マスク：体重±TOL から外れた試行、または計測できなかった試行 ----
FzExclude = abs(baseTot - BW) > TOL*BW | isnan(baseTot) ;

% ---- 結果表示 ----
fprintf('%-8s %s\n', '条件', '各試行の baseline合計Fz [N]（*=除外）') ;
for c = 1:nCondition
    fprintf('%-8s', ConditionNameArray{c}) ;
    for t = 1:nTrial
        mark = ' ' ; if FzExclude(t,c), mark = '*' ; end
        fprintf(' %4.0f%s', baseTot(t,c), mark) ;
    end
    fprintf('   → 除外 %d / %d 試行\n', sum(FzExclude(:,c)), nTrial) ;
end

fprintf('\n除外した(試行,条件):\n') ;
[tt, cc] = find(FzExclude) ;
for k = 1:numel(tt)
    fprintf('  Trial %2d  %s\n', tt(k), ConditionNameArray{cc(k)}) ;
end

% ---- マスクを保存（後段のRTコードが読めるように）----
save(sprintf('x5_SingleTrialAnalysisResultsChecked/FzExclude%02d.mat', iSubject), 'FzExclude', 'BW') ;
fprintf('\nFzExclude%02d.mat を保存しました。\n', iSubject) ;
