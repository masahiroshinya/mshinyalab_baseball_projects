% s_count_excluded.m
%
% 目的:
%   除外基準①（top の欠損）で何試行が落ちるかを、被験者×条件ごとに数える。
%   判定範囲を変えたときの影響を比べられるよう、記録全体・解析窓内・ピーク近傍の
%   3つを並記する。技術説明 §10.4・§10.6・§10.8。
%
% 前提:
%   x4 まで実行済みであること（cue 位置とピーク位置が必要なため）。
%
% 備考:
%   x1〜x9 の解析ワークフローには含まれない診断用スクリプト（§9.1 と同じ扱い）。
%   採用している判定範囲は解析窓内（Prm.Excl.WinSec）。§9.4 のとおり「欠損が
%   あること自体は不良の証拠にならない」ため、記録全体では指標に無害な欠損で
%   試行を捨ててしまう。
%
%   ★ 併せて「ピークが解析窓の中にあるか」も数える。PeakVelTop は
%     max(netVelTop) で試行全体から取っており探索窓を持たない（§9.3）ため、
%     窓の外にピークがある試行では判定と指標の範囲が食い違う。

clear
clc

Prm = parameters ;
ConditionNameArray = {'free', 'simple', 'gonogo', 'gostop'} ;
PEAK_WIN_SEC = 0.1 ;   % 「ピーク近傍」の半幅（比較用）

fprintf('除外基準①の判定範囲: 解析窓内（cue 後 0〜%.1f s）\n\n', Prm.Excl.WinSec) ;
fprintf('%-3s %-8s %6s | %8s %8s %10s | %10s\n', ...
    'S', '条件', 'Go試行', '記録全体', '窓内★', 'ピーク近傍', 'ピーク窓外') ;

nGoAll = 0 ; nBadAll = zeros(1,3) ; nPeakOutAll = 0 ;

for iSubject = 1:5

    f3 = sprintf('x3_DataChecked/Data%02d', iSubject) ;
    f4 = sprintf('x4_SingleTrialAnalysisResults/SingleTrialAnalysisResults%02d', iSubject) ;
    if ~exist([f3 '.mat'], 'file') || ~exist([f4 '.mat'], 'file')
        fprintf('S%02d: 中間ファイルが見つかりません。スキップします。\n', iSubject) ;
        continue
    end
    load(f3)   % → DataArray
    load(f4)   % → SingleTrialResultArray

    for iCondition = 1:numel(ConditionNameArray)

        nGo = 0 ; nBad = zeros(1,3) ; nPeakOut = 0 ;

        for iTrial = 1:size(DataArray, 1)

            Data   = DataArray(iTrial, iCondition) ;
            Result = SingleTrialResultArray(iTrial, iCondition) ;

            if isequal(Data.ErrorCode, Prm.ErrorCode.NoData), continue, end
            if ~strcmp(Result.CueText, 'Go'), continue, end   % Go 試行だけ数える
            nGo = nGo + 1 ;

            if ~isfield(Data.Markers, Prm.Excl.TopMarkerName)
                nBad = nBad + 1 ;
                continue
            end

            % ★ x3_DataChecked の Markers はまだ m3 の linear/extrap を通って
            %   いないので、残っている NaN が「埋めるべきでなかった欠損」である。
            isNanTop = any(isnan(Data.Markers.(Prm.Excl.TopMarkerName)), 2) ;
            fs       = Data.FrameRate ;
            nFrame   = numel(isNanTop) ;

            % (a) 記録全体
            if Data.MaxNanRunTop > Prm.Excl.MaxNanRunTop, nBad(1) = nBad(1) + 1 ; end

            % (b) 解析窓内（採用している判定。m3 が Result.IsBadTop に入れている）
            if Result.IsBadTop, nBad(2) = nBad(2) + 1 ; end

            % (c) ピーク近傍（比較用）
            ip = Result.TPeakVelTop ;
            if ~isnan(ip)
                w = max(1, ip - round(PEAK_WIN_SEC*fs)) : ...
                    min(ip + round(PEAK_WIN_SEC*fs), nFrame) ;
                if any(isNanTop(w)), nBad(3) = nBad(3) + 1 ; end
            end

            % ピークが解析窓の外にあるか（判定範囲と指標範囲の食い違い）
            tc = Result.TCueMarker ;
            if ~isnan(tc) && ~isnan(ip)
                if ip < tc || ip > tc + round(Prm.Excl.WinSec*fs)
                    nPeakOut = nPeakOut + 1 ;
                end
            end

        end

        if nGo == 0, continue, end

        fprintf('%3d %-8s %6d | %8d %8d %10d | %10d\n', ...
            iSubject, ConditionNameArray{iCondition}, nGo, ...
            nBad(1), nBad(2), nBad(3), nPeakOut) ;

        nGoAll      = nGoAll      + nGo ;
        nBadAll     = nBadAll     + nBad ;
        nPeakOutAll = nPeakOutAll + nPeakOut ;
    end

    fprintf('\n') ;
    clear DataArray SingleTrialResultArray

end

fprintf('=== Go 試行 %d 本のうち不良と判定される数 ===\n', nGoAll) ;
fprintf('  記録全体     : %3d （残り %3d）\n', nBadAll(1), nGoAll-nBadAll(1)) ;
fprintf('  解析窓内 ★  : %3d （残り %3d）  ← 採用\n', nBadAll(2), nGoAll-nBadAll(2)) ;
fprintf('  ピーク±%.1fs : %3d （残り %3d）\n', PEAK_WIN_SEC, nBadAll(3), nGoAll-nBadAll(3)) ;
fprintf('\nピークが解析窓の外にある試行: %d 本', nPeakOutAll) ;
if nPeakOutAll == 0
    fprintf('（判定範囲と指標範囲の食い違いは実測では生じていない）\n') ;
else
    fprintf(' ★ PeakVelTop に探索窓を付けるか検討すること（§9.3）\n') ;
end
