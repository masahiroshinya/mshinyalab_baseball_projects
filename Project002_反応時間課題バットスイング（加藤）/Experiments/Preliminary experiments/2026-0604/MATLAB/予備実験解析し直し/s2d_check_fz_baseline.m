% s2d_check_fz_baseline.m
% 目的：RT検出信号をバット先端速度→床反力Fzへ移せるか判定する。
% Fzで同じ逆転が起きないかを、同じ土俵（ベースラインの静けさ vs 応答の大きさ）で測る。
% カレントは 2026-0604/MATLAB にすること（相対パス）。

clear; close all; clc

iSubject = 1 ;
fprintf('===== Subject %02d =====\n', iSubject) ;   % 被験者取り違え防止

load(sprintf('x3_DataChecked/Data%02d', iSubject))
load(sprintf('x4_SingleTrialAnalysisResults/SingleTrialAnalysisResults%02d', iSubject))

ConditionNameArray = {'free','simple','gonogo'} ;
nCondition = numel(ConditionNameArray) ;
nTrial     = size(SingleTrialResultArray, 1) ;
BASE_SEC = 0.5 ;   % ベースライン窓（キュー前）
WIN_SEC  = 2.0 ;   % 応答窓（キュー後）

% 検証するFz由来の信号。各窓で mean(base) を引いた「Δ（逸脱）」として評価する
sigNames = {'Fz1(軸足)','Fz2(踏込足)','|dFz1|+|dFz2|','Fz1+Fz2(合計)'} ;
nSig = numel(sigNames) ;

baseTot = nan(nTrial,nCondition) ;          % baseline合計Fz（体重整合性チェック用）
baseSD  = nan(nTrial,nCondition,nSig) ;     % baseline SD（＝雑音の大きさ）
respDev = nan(nTrial,nCondition,nSig) ;     % 応答の最大逸脱（＝信号の大きさ）
cueTxt  = strings(nTrial,nCondition) ;

for c = 1:nCondition
    for t = 1:nTrial
        D = DataArray(t,c) ; R = SingleTrialResultArray(t,c) ;

        % ---- ガード（x7_4と同じ思想）----
        if ~isfield(D,'Force1') || isempty(D.Force1), continue, end   % Force欠損
        if isnan(R.TCueMarker) || isnan(D.AnalogFs),  continue, end   % 取込失敗(S02 gonogo T1)

        % ---- マーカー基準のキュー(250Hz) → アナログのサンプル番号(1000Hz) ----
        fsA   = D.AnalogFs ;
        tCueA = round(R.TCueMarker / D.FrameRate * fsA) ;
        if tCueA < round(BASE_SEC*fsA)+1, continue, end
        b = tCueA-round(BASE_SEC*fsA) : tCueA-1 ;                     % ベースライン窓
        w = tCueA : min(tCueA+round(WIN_SEC*fsA), size(D.Force1,1)) ; % 応答窓

        Fz1 = D.Force1(:,3) ; Fz2 = D.Force2(:,3) ;
        if any(isnan(Fz1(b))) || any(isnan(Fz2(b))) || ...
                any(isnan(Fz1(w))) || any(isnan(Fz2(w))), continue, end

        m1 = mean(Fz1(b)) ; m2 = mean(Fz2(b)) ;
        baseTot(t,c) = m1 + m2 ;
        cueTxt(t,c)  = string(R.CueText) ;

        % 各信号の baseline SD と 応答の最大逸脱（Δ＝ベースライン平均からのずれ）
        sig   = { Fz1, Fz2, abs(Fz1-m1)+abs(Fz2-m2), Fz1+Fz2 } ;
        base0 = { m1,  m2,  0,                        m1+m2   } ;    % 各信号の基準
        for s = 1:nSig
            baseSD(t,c,s)  = std(sig{s}(b)) ;
            respDev(t,c,s) = max(abs(sig{s}(w) - base0{s})) ;
        end
    end
end

% ===== 整合性チェック：baseline合計Fzが体重スケールか =====
fprintf('\n--- baseline合計Fz [N]（体重にならない試行はFz解析に不適）---\n') ;
for c = 1:nCondition
    v  = baseTot(:,c) ; md = median(v,'omitnan') ;
    fprintf('%-7s: 中央値%.0f  範囲[%.0f, %.0f]  体重±20%%外れ試行=%d\n', ...
        ConditionNameArray{c}, md, min(v), max(v), sum(abs(v-md) > 0.2*md)) ;
end

% ===== 信号ごと：baseline SD / 応答逸脱 / 比R =====
for s = 1:nSig
    fprintf('\n===== 信号: %s =====\n', sigNames{s}) ;
    fprintf('%-7s %10s %12s %8s\n','条件','baseSD[N]','応答逸脱[N]','比R') ;
    for c = 1:nCondition
        sd = mean(baseSD(:,c,s),'omitnan') ; rd = mean(respDev(:,c,s),'omitnan') ;
        fprintf('%-7s %10.2f %12.1f %8.0f\n', ConditionNameArray{c}, sd, rd, rd/sd) ;
    end
end

% ===== 最重要：gonogo の Go vs NoGo（バット速度が破綻した箇所）=====
fprintf('\n===== gonogo：Go/NoGo別の応答最大逸脱 =====\n') ;
for s = 1:nSig
    goDev = respDev(cueTxt(:,3)=="Go",   3, s) ;
    ngDev = respDev(cueTxt(:,3)=="NoGo", 3, s) ;
    sdAll = mean(baseSD(:,3,s),'omitnan') ;
    ngMax = max(ngDev) ; if isempty(ngMax), ngMax = NaN ; end
    fprintf('%-13s: Go逸脱平均%.1f  NoGo逸脱最大%.1f  baseSD%.2f  → Go/SD=%.0f, NoGo/SD=%.0f\n', ...
        sigNames{s}, mean(goDev,'omitnan'), ngMax, sdAll, ...
        mean(goDev,'omitnan')/sdAll, ngMax/sdAll) ;
end
