% s2f_sweep_fz1_threshold.m
% 目的：Fz1（後ろ足）で動作開始を取るときの k（SD倍数）と持続窓を振り、
%       150ms未満の誤検出が消える最小の組み合わせを探す。
% カレントは 2026-0604/MATLAB にすること。

clear; close all; clc

iSubject = 2 ;
load(sprintf('x3_DataChecked/Data%02d', iSubject))
load(sprintf('x4_SingleTrialAnalysisResults/SingleTrialAnalysisResults%02d', iSubject))
load(sprintf('x5_SingleTrialAnalysisResultsChecked/FzExclude%02d', iSubject))   % FzExclude

ConditionNameArray = {'free','simple','gonogo'} ;
CondList = [2 3] ;          % RT対象：simple, gonogo のみ（freeは参考値なので除く）
BASE_SEC = 0.5 ;
WIN_SEC  = 2.0 ;
FLOOR_MS = 150 ;            % 生理的下限

kList   = [5 6 7 8 10] ;
durList = [0 20 30 50] ;   % 持続窓 [ms]（0=持続条件なし）

fprintf('===== Subject %02d：Fz1閾値スイープ（Go試行）=====\n', iSubject) ;
fprintf('各セル = 「%d ms未満の検出数 / 検出できた試行数」（%dms未満=誤検出）\n\n', FLOOR_MS, FLOOR_MS) ;
fprintf('%6s', 'k\dur') ; fprintf('%12s', string(durList)+"ms") ; fprintf('\n') ;

for ik = 1:numel(kList)
    fprintf('%6d', kList(ik)) ;
    for id = 1:numel(durList)
        nUnder = 0 ; nDetect = 0 ;
        for c = CondList
            for t = 1:size(SingleTrialResultArray,1)
                if FzExclude(t,c), continue, end
                D = DataArray(t,c) ; R = SingleTrialResultArray(t,c) ;
                if ~isfield(D,'Force1') || isempty(D.Force1), continue, end
                if isnan(R.TCueMarker) || isnan(D.AnalogFs), continue, end
                if ~strcmp(R.CueText,'Go'), continue, end

                fsA   = D.AnalogFs ;
                tCueA = round(R.TCueMarker / D.FrameRate * fsA) ;
                if tCueA < round(BASE_SEC*fsA)+1, continue, end
                b = tCueA-round(BASE_SEC*fsA) : tCueA-1 ;
                w = tCueA : min(tCueA+round(WIN_SEC*fsA), size(D.Force1,1)) ;

                Fz1 = D.Force1(:,3) ;
                if any(isnan(Fz1(b))) || any(isnan(Fz1(w))), continue, end
                mu = mean(Fz1(b)) ; sd = std(Fz1(b)) ;

                over  = abs(Fz1(w)-mu) > kList(ik)*sd ;
                holdN = max(1, round(durList(id)/1000*fsA)) ;
                idx   = firstSustained(over, holdN) ;
                if isempty(idx), continue, end

                RT = (idx-1)/fsA*1000 ;
                nDetect = nDetect + 1 ;
                if RT < FLOOR_MS, nUnder = nUnder + 1 ; end
            end
        end
        fprintf('%12s', sprintf('%d/%d', nUnder, nDetect)) ;
    end
    fprintf('\n') ;
end

% ---- 閾値超えが holdN サンプル連続した最初の位置を返す ----
function idx = firstSustained(over, holdN)
idx = [] ;
d = diff([0; over(:); 0]) ;
starts = find(d==1) ; ends = find(d==-1)-1 ;
run = find((ends-starts+1) >= holdN, 1, 'first') ;
if ~isempty(run), idx = starts(run) ; end
end
