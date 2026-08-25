% s_check_top_quality_detail.m
%
% 目的:
%   s_check_top_outliers で見つかった top マーカーの不良を、原因まで掘り下げる。
%     (1) ジャンプ試行で、飛んだ先が他のバットマーカーの位置と一致するか
%         → 一致すれば QTM のラベル入れ替わりと確定できる
%     (2) 欠損試行のうち、ピーク近傍に欠損が重なっているものだけを抽出する
%         → 窓内に欠損があっても、ピークから離れていれば実害はない
%
% 入力:
%   x3_DataChecked/Data<ID>.mat
%   x5_SingleTrialAnalysisResultsChecked/SingleTrialAnalysisResults<ID>.mat

clear
close all
clc

% -----------------------------------------------------------------------
% 設定
% -----------------------------------------------------------------------
subjects           = 1:5 ;
ConditionNameArray = {'free', 'simple', 'gonogo', 'gostop'} ;
BatMarkerArray     = {'knob', 'grip', 'barrel', 'bottom'} ;   % top と比較する相手

STEP_MAX_MM   = 200 ;    % ジャンプとみなすフレーム間変位 [mm]
PEAK_WIN_SEC  = 0.10 ;   % ピークの「近傍」とみなす前後の時間 [s]
MATCH_TOL_MM  = 100 ;    % 飛び先が他マーカーと一致したとみなす距離 [mm]

Prm    = parameters ;
winSec = Prm.RT.WinSec ;

Jump = table() ;   % ジャンプ試行の詳細
Gap  = table() ;   % 欠損試行の詳細

% -----------------------------------------------------------------------
% 被験者ループ
% -----------------------------------------------------------------------
for iSubject = subjects

    dataPath   = sprintf('x3_DataChecked/Data%02d', iSubject) ;
    resultPath = sprintf('x5_SingleTrialAnalysisResultsChecked/SingleTrialAnalysisResults%02d', iSubject) ;

    if ~exist([dataPath '.mat'], 'file') || ~exist([resultPath '.mat'], 'file')
        fprintf('S%02d: 中間ファイルが見つかりません。スキップします。\n', iSubject) ;
        continue
    end

    load(dataPath)      % → DataArray
    load(resultPath)    % → SingleTrialResultArray

    nTrial     = size(SingleTrialResultArray, 1) ;
    nCondition = min(size(SingleTrialResultArray, 2), numel(ConditionNameArray)) ;

    for iCondition = 1:nCondition
        for iTrial = 1:nTrial

            R = SingleTrialResultArray(iTrial, iCondition) ;
            D = DataArray(iTrial, iCondition) ;

            if isempty(R.NetVelTop), continue, end

            fs      = D.FrameRate ;
            posTop  = D.Markers.top ;
            nFrame  = size(posTop, 1) ;
            condName = string(ConditionNameArray{iCondition}) ;

            % max は NaN を無視するので、そのまま最大変位の位置を取れる
            step = sqrt(sum(diff(posTop).^2, 2)) ;
            [stepMax, iStep] = max(step) ;

            % ===============================================================
            % (1) ジャンプ試行の詳細
            % ===============================================================
            if ~isnan(stepMax) && stepMax > STEP_MAX_MM

                iAfter = iStep + 1 ;   % 飛んだ直後のフレーム

                if isnan(R.TCueMarker)
                    tJump = NaN ;
                else
                    tJump = (iAfter - R.TCueMarker) / fs ;
                end

                % 飛んだ先が、他のバットマーカーの位置と一致するか
                nearestName = "(不明)" ;
                nearestDist = Inf ;
                for iMarker = 1:numel(BatMarkerArray)
                    name = BatMarkerArray{iMarker} ;
                    if ~isfield(D.Markers, name), continue, end
                    p = D.Markers.(name)(iAfter, :) ;
                    if any(isnan(p)), continue, end
                    dist = norm(posTop(iAfter, :) - p) ;
                    if dist < nearestDist
                        nearestDist = dist ;
                        nearestName = string(name) ;
                    end
                end

                % バットの長さ（top ↔ knob の距離の中央値）。ジャンプ量との比較用
                if isfield(D.Markers, 'knob')
                    dTopKnob = sqrt(sum((posTop - D.Markers.knob).^2, 2)) ;
                    batLen   = median(dTopKnob(~isnan(dTopKnob))) ;
                else
                    batLen = NaN ;
                end

                isLabelSwap = (nearestDist < MATCH_TOL_MM) ;

                Jump = [Jump ; table(iSubject, condName, iTrial, ...
                    stepMax, tJump, batLen, nearestName, nearestDist, isLabelSwap, ...
                    'VariableNames', {'Subject', 'Condition', 'Trial', ...
                    'StepMax_mm', 'tJump_s', 'BatLen_mm', ...
                    'NearestMarker', 'NearestDist_mm', 'IsLabelSwap'})] ; %#ok<AGROW>
            end

            % ===============================================================
            % (2) 欠損の詳細
            % ===============================================================
            isNanFrame = any(isnan(posTop), 2) ;

            if ~any(isNanFrame) || isnan(R.TCueMarker)
                continue
            end

            % 解析窓（cue 後 0〜2 秒）内の欠損
            w         = R.TCueMarker : min(R.TCueMarker + round(winSec*fs), nFrame) ;
            nNanInWin = sum(isNanFrame(w)) ;

            if nNanInWin == 0, continue, end

            % 最長の連続欠損 [ms]
            d      = diff([0 ; double(isNanFrame(:)) ; 0]) ;
            runLen = find(d == -1) - find(d == 1) ;
            maxRunMs = max(runLen) / fs * 1000 ;

            % ピーク近傍（±PEAK_WIN_SEC）に欠損が重なっているか
            halfWin = round(PEAK_WIN_SEC * fs) ;
            pw = max(1, R.TPeakVelTop - halfWin) : min(nFrame, R.TPeakVelTop + halfWin) ;
            nNanNearPeak = sum(isNanFrame(pw)) ;

            Gap = [Gap ; table(iSubject, condName, iTrial, string(R.CueText), ...
                R.PeakVelTop, nNanInWin, maxRunMs, nNanNearPeak, ...
                (nNanNearPeak > 0), ...
                'VariableNames', {'Subject', 'Condition', 'Trial', 'CueText', ...
                'PeakVelTop', 'nNanInWin', 'MaxGap_ms', 'nNanNearPeak', ...
                'IsBadPeak'})] ; %#ok<AGROW>

        end % iTrial
    end % iCondition
end % iSubject

% -----------------------------------------------------------------------
% 表A：ジャンプの正体
% -----------------------------------------------------------------------
fprintf('=== 表A: ジャンプ試行の詳細（閾値 %d mm/frame）===\n', STEP_MAX_MM) ;
fprintf('  NearestMarker  = 飛んだ直後の top に最も近いバットマーカー\n') ;
fprintf('  IsLabelSwap    = その距離が %d mm 未満（＝ラベル入れ替わりと判定）\n\n', MATCH_TOL_MM) ;
if isempty(Jump)
    fprintf('  なし\n') ;
else
    disp(Jump)
    fprintf('ラベル入れ替わりと判定: %d / %d 試行\n', sum(Jump.IsLabelSwap), height(Jump)) ;
end

% -----------------------------------------------------------------------
% 表B：欠損の影響範囲
% -----------------------------------------------------------------------
fprintf('\n=== 表B: 解析窓に欠損がある試行の内訳 ===\n') ;
fprintf('       窓内に欠損   うちピーク近傍(±%.2f s)にも欠損\n', PEAK_WIN_SEC) ;
if isempty(Gap)
    fprintf('  なし\n') ;
else
    for iSubject = subjects
        mask = (Gap.Subject == iSubject) ;
        if ~any(mask), continue, end
        fprintf('S%02d        %3d                %3d\n', ...
            iSubject, sum(mask), sum(Gap.IsBadPeak(mask))) ;
    end
    fprintf('計         %3d                %3d\n', height(Gap), sum(Gap.IsBadPeak)) ;
end

% -----------------------------------------------------------------------
% 表C：ピーク近傍に欠損がある試行の一覧（本当に危ない試行）
% -----------------------------------------------------------------------
fprintf('\n=== 表C: ピーク近傍に欠損がある試行 ===\n') ;
if ~isempty(Gap) && any(Gap.IsBadPeak)
    Bad = sortrows(Gap(Gap.IsBadPeak, :), {'Subject', 'Condition', 'Trial'}) ;
    disp(Bad)
else
    fprintf('  なし\n') ;
end
