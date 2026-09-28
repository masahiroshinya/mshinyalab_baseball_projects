function Prm = parameters()

% parameters for MATLAB analysis


%% x1_import_data: interp_nan_spline

Prm.MaxNumNans = 10 ;

% error code
Prm.ErrorCode.HasLongNan = 1 ;
Prm.ErrorText.HasLongNan = sprintf('has long nan: more than %d samples of nan', Prm.MaxNumNans) ;

% 条件ごとに試行数が異なる場合、DataArray の余った要素に入れるコード
Prm.ErrorCode.NoData = 3 ;
Prm.ErrorText.NoData = 'no data: padded element (trial does not exist)' ;


%% x3_analyze_single_trial: Filter
Prm.Fc = 30 ;

%% m3_analyze_single_trial: キュー判定（LED ch2）
%  緑LED = 正電圧（Go）、赤LED = 負電圧（NoGo / Stop）
Prm.Cue.GoThresholdV  =  2 ;   % Go 判定の電圧閾値 [V]
Prm.Cue.NegThresholdV = -1 ;   % NoGo / Stop 判定の電圧閾値 [V]

%  go/stop 課題は必ず go cue が先に出て、その後に go か stop が提示される。
%  go cue から下記の窓の中に負のパルスがあれば stop 試行と判定する。
%  （実験スクリプト: first_go 0.1 s + go_to_branch_off 0.25 s → 分岐は 0.35 s 後）
Prm.Cue.StopWinSec = 1.0 ;

Prm.CueCode.Go   = 1 ;
Prm.CueCode.NoGo = 2 ;
Prm.CueCode.Stop = 3 ;

% error code
Prm.ErrorCode.LEDTimingNotDetected = 2 ;
Prm.ErrorText.LEDTimingNotDetected = 'LED illumination was not detected' ;

%% m3_analyze_single_trial: RT 検出（前後方向の合成床反力 Fx）
%  sandbox/5.6_プロット 00_技術説明 §3 で検証した方式（2026-09-28 本番へ移植）。
%  Fx = Force1(:,1) + Force2(:,1) が
%    閾値 = キュー前の中央値 + 0.20 ×（キュー → 踏み込み足接地 の窓内ピーク − 中央値）
%  を 20 ms 続けて超えた最初の時点を動作開始とする。
Prm.RT.FxFc         = 50 ;    % Fx のローパス遮断周波数 [Hz]（sandbox の検証値）
Prm.RT.BaseSec      = 0.5 ;   % ベースライン窓（キュー直前）[s]
Prm.RT.FxRatio      = 0.20 ;  % 閾値 = ベース + 比率 ×（窓内ピーク − ベース）
Prm.RT.DurMs        = 20 ;    % 閾値超えの持続時間 [ms]
Prm.RT.FootContactN = 50 ;    % 踏み込み足の接地とみなす Fz2 [N]
Prm.RT.MinWinMs     = 50 ;    % キュー → 接地 がこれ未満なら探索窓が短すぎる [ms]
Prm.RT.WinSec       = 2.0 ;   % 解析窓（キュー起点）[s]。s_check_top_* が使う
Prm.RT.FloorMs      = 150 ;   % 生理的下限。目視照合の基準（強制 NaN 化はしない）

%% x7_3 / x7_4: 床反力の体重正規化に用いるベースラインの妥当性チェック
%  静止時の Fz1+Fz2 は体重にほぼ一致するはずである。大きく外れる試行は
%  プレートに正しく乗っていない計測不良なので、正規化すると異常値になる。
Prm.GRF.BWTolerance = 0.2 ;   % 被験者中央値からの許容ずれ（±20%）
Prm.GRF.WinSec = 2.0 ;   % ピーク Fz の探索窓（キュー起点）[s]

%% top マーカーの品質チェック（x5 / x8 で不良試行を選別する）
%  バット先端の実測ピークは 27〜35 m/s。250 Hz では 1 フレーム 110〜140 mm に相当する。
%  50 m/s 相当（200 mm/frame）を超える変位はスイングでは起こりえず、
%  マーカーの飛び・ラベル入れ替わりを意味する。
Prm.QC.TopStepMaxMm = 200 ;


%% 除外基準（2026-09-10 決定：top マーカーと床反力の2つに限定する）
%  データ品質による除外はこの2つだけとし、判定は x8 のフラグ列に集約する。
%  ★ Prm.MaxNumNans（=10）は interp_nan_spline が「補間してよい長さ」であり、
%    ここの MaxNanRunTop は「指標として信用できる長さ」。意味が違うので分ける。
%  詳細は技術説明 §10。
%  ★ 判定範囲は「解析窓内（cue 後 0〜2 s）」に確定した（§10.8 の実行結果）。
%    記録全体で判定すると、構えやスイング後に top が落ちただけの試行まで落ち、
%    n_PeakVelTop が最小 1 になる条件が3つ出て分散分析に使えなくなる。
%  ★ 窓内に「残っている」NaN が判定対象。x2 の interp_nan_spline が
%    Prm.MaxNumNans 以下の欠損を埋めた後に残るのは、それを超える連続欠損
%    （と記録端の欠損）だけなので、実効的な閾値は Prm.MaxNumNans である。
Prm.Excl.TopMarkerName  = 'top' ;   % 欠損を判定するマーカー
Prm.Excl.WinSec         = 2.0 ;     % 判定に使う解析窓の長さ（cue 起点）[s]
Prm.Excl.MaxNanRunTop   = 10 ;      % 記録全体の最長連続NaN。参考情報の閾値のみ
Prm.Excl.BWTailSec      = 0.5 ;     % 体重推定に使う記録末端の長さ [s]
Prm.Excl.BWOutlierRatio = 0.7 ;     % 末端値が中央値のこの比率未満なら体重推定から除く
