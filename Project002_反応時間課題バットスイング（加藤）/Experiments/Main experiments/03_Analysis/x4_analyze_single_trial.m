% x4s_analyze_single_trial.m
%
% 目的:
%   x3_DataChecked/ のデータを読み込み、全被験者・全条件・全試行に対して
%   m3_analyze_single_trial() を実行し、結果を x4_SingleTrialAnalysisResults/ に保存する。
%   ワークフロー Step 4 に対応。

clear
close all
clc

% -----------------------------------------------------------------------
% 設定
% -----------------------------------------------------------------------
subjects           = 1 ;
ConditionNameArray = {'free', 'simple', 'gonogo', 'gostop'} ;
nCondition         = length(ConditionNameArray) ;

Prm = parameters ;   % 欠測試行（NoData）の判別に使う

% -----------------------------------------------------------------------
% 被験者ループ
% -----------------------------------------------------------------------
for iSubject = subjects

    fprintf('=== Subject %02d ===\n', iSubject) ;

    dataFilePath = sprintf('x3_DataChecked/Data%02d', iSubject) ;
    load(dataFilePath)

    nTrial = size(DataArray, 1) ;

    % 結果格納用の配列（事前確保）
    clear SingleTrialResultArray


    % ---------------------------------------------------------------
    % 条件ループ
    % ---------------------------------------------------------------
    for iCondition = 1:nCondition
        condName = ConditionNameArray{iCondition} ;
        fprintf('  条件: %s\n', condName) ;

        % -----------------------------------------------------------
        % 試行ループ
        % -----------------------------------------------------------
        for iTrial = 1:nTrial

            Data = DataArray(iTrial, iCondition) ;

            % 条件ごとの試行数の差を埋めた要素（実データなし）はスキップする
            if isequal(Data.ErrorCode, Prm.ErrorCode.NoData)
                SingleTrialResultArray(iTrial, iCondition) = makeEmptyResult() ;
                fprintf('    Trial %2d: データなし → スキップ\n', iTrial) ;
                continue
            end

            try
                Result = m3_analyze_single_trial(Data) ;
            catch ME
                fprintf('    Trial %2d: エラー "%s" → スキップ\n', iTrial, ME.message) ;
                Result = makeEmptyResult() ;
                SingleTrialResultArray(iTrial, iCondition) = Result ;
                continue
            end

            SingleTrialResultArray(iTrial, iCondition) = Result ;

            fprintf('    Trial %2d [%s]: RTForce = %.1f ms\n', ...
                iTrial, Result.CueText, Result.RTForce) ;


        end % iTrial
    end % iCondition

    % ---------------------------------------------------------------
    % 第2パス：Nasu 方式の閾値を確定し、手部 onset を検出する
    %   閾値 = その被験者の全スイング試行の平均ピーク速度 × 10%
    %   スイングしない NoGo / Stop 試行はピークの平均に含めない。
    %   条件ごとではなく全条件をまとめて平均する（条件差が閾値の差に
    %   吸収されるのを避けるため。Methods draft §2-4-1 の方針）。
    % ---------------------------------------------------------------
    ExcludedCueTextArray = {'NoGo', 'Stop'} ;

    PeakArray = nan(nTrial, nCondition) ;
    for iCondition = 1:nCondition
        for iTrial = 1:nTrial
            R = SingleTrialResultArray(iTrial, iCondition) ;
            if ismember(R.CueText, ExcludedCueTextArray), continue, end
            PeakArray(iTrial, iCondition) = R.PeakVelHandX ;
        end
    end

    meanPeak   = mean(PeakArray(:), 'omitnan') ;
    thrVelHand = Prm.RT.HandThrRatio * meanPeak ;
    fprintf('\n  Nasu 方式の閾値: 平均ピーク %.2f m/s × %.0f%% = %.3f m/s（n=%d 試行）\n', ...
        meanPeak, Prm.RT.HandThrRatio*100, thrVelHand, sum(~isnan(PeakArray(:)))) ;

    % Result.RT / SwingOnset は m3 では作らないので、ここで全要素に一括で追加する。
    % 構造体配列は要素ごとにフィールド集合が一致していないと代入できないため、
    % ループの中で新しいフィールドを足すとエラーになる。
    [SingleTrialResultArray.SwingOnset] = deal(NaN) ;
    [SingleTrialResultArray.RT]         = deal(NaN) ;

    for iCondition = 1:nCondition
        for iTrial = 1:nTrial

            R  = SingleTrialResultArray(iTrial, iCondition) ;
            fs = DataArray(iTrial, iCondition).FrameRate ;

            R = detectHandOnset(R, thrVelHand, fs) ;

            % 指定した方式を Result.RT / SwingOnset の別名にする（下流の互換のため）
            switch Prm.RT.PrimaryMethod
                case 'Hand'
                    R.SwingOnset = R.SwingOnsetHand ;
                    R.RT         = R.RTHand ;
                case 'Force'
                    R.SwingOnset = R.SwingOnsetForce ;
                    R.RT         = R.RTForce ;
                otherwise
                    error('Prm.RT.PrimaryMethod が不正です: %s', Prm.RT.PrimaryMethod) ;
            end

            SingleTrialResultArray(iTrial, iCondition) = R ;

            if ~isnan(R.RTHand) && ~isnan(R.RTForce)
                fprintf('    %-7s Trial %2d [%-4s]: 手部 %6.1f ms / 床反力 %6.1f ms （差 %+6.1f）\n', ...
                    ConditionNameArray{iCondition}, iTrial, R.CueText, ...
                    R.RTHand, R.RTForce, R.RTHand - R.RTForce) ;
            end

        end
    end


    % 保存
    resultFilePath = sprintf('x4_SingleTrialAnalysisResults/SingleTrialAnalysisResults%02d', iSubject) ;
    save(resultFilePath, 'SingleTrialResultArray') ;
    fprintf('  → 保存完了: %s.mat\n\n', resultFilePath) ;

    clear DataArray SingleTrialResultArray

end % iSubject

fprintf('=== 全被験者の処理が完了しました ===\n') ;


% -----------------------------------------------------------------------
% ローカル関数：エラー時の空の Result
% -----------------------------------------------------------------------
function Result = makeEmptyResult()
Result.NetVelTop       = [] ;
Result.VelTopX         = [] ;
Result.PeakVelTop      = NaN ;
Result.TPeakVelTop     = NaN ;
Result.PeakVelTopX     = NaN ;
Result.TPeakVelTopX    = NaN ;
Result.VelTopXAtPeak   = NaN ;
Result.VelHandX        = [] ;
Result.CueCode         = NaN ;
Result.CueText         = '' ;
Result.TCueMarker      = NaN ;
Result.PeakVelHandX    = NaN ;
Result.TPeakVelHandX   = NaN ;
Result.SwingOnsetHand  = NaN ;
Result.RTHand          = NaN ;
Result.Fz1BaseMean     = NaN ;
Result.Fz1BaseSD       = NaN ;
Result.SwingOnsetForce = NaN ;
Result.RTForce         = NaN ;
end


% -----------------------------------------------------------------------
% ローカル関数：手部 onset の検出（Nasu et al., 2020 準拠）
%   ピーク時刻から時間を遡り、閾値を下回った最後の点を動作開始とする。
%   前向きに探すと構え・ステップの小さな山を誤検出するため（技術説明 §2.3 手順9）。
% -----------------------------------------------------------------------
function Result = detectHandOnset(Result, thrVel, fs)
Result.SwingOnsetHand = NaN ;
Result.RTHand         = NaN ;

if isempty(Result.VelHandX) || isnan(Result.TPeakVelHandX) || isnan(Result.TCueMarker)
    return
end

v     = Result.VelHandX ;
idxOn = find(v(1:Result.TPeakVelHandX) <= thrVel, 1, 'last') ;
if isempty(idxOn)
    return
end

Result.SwingOnsetHand = idxOn ;                                    % フレーム番号
Result.RTHand         = (idxOn - Result.TCueMarker) / fs * 1000 ;  % [ms]
end





