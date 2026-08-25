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

%% m3_analyze_single_trial: RT 検出（後ろ足 Fz1）
Prm.RT.FzK     = 10 ;    % 閾値 = ベースライン SD の何倍か（≒ 15%BW）
Prm.RT.DurMs   = 30 ;    % 閾値超えの持続時間 [ms]
Prm.RT.BaseSec = 0.5 ;   % ベースライン窓（キュー直前）[s]
Prm.RT.WinSec  = 2.0 ;   % 探索窓（キュー起点）[s]
Prm.RT.FloorMs = 150 ;   % 生理的下限。目視照合の基準（強制 NaN 化はしない）

%% x7_3 / x7_4: 床反力の体重正規化に用いるベースラインの妥当性チェック
%  静止時の Fz1+Fz2 は体重にほぼ一致するはずである。大きく外れる試行は
%  プレートに正しく乗っていない計測不良なので、正規化すると異常値になる。
Prm.GRF.BWTolerance = 0.2 ;   % 被験者中央値からの許容ずれ（±20%）
Prm.GRF.WinSec = 2.0 ;   % ピーク Fz の探索窓（キュー起点）[s]

%% m3 / x4: RT 算出（2方式を併記する）
%  方式Hand = Nasu et al. (2020) 準拠。手部（骨盤基準）の投手方向速度が
%             「全試行の平均ピーク速度の10%」を超えた時点を動作開始とする。
%  方式Force = 後ろ足 Fz1 が平常時から 10SD 逸脱し 30 ms 持続した時点（既存）。
Prm.RT.HandMarkerNames   = {'first', 'second', 'third'} ;
Prm.RT.PelvisMarkerNames = {'RASIS', 'LASIS', 'RPSIS', 'LPSIS'} ;  % 骨盤
Prm.RT.HandThrRatio      = 0.10 ;      % 平均ピーク速度に対する閾値の比
Prm.RT.PrimaryMethod     = 'Force' ;   % Result.RT に入れる方式（'Force' / 'Hand'）

%% top マーカーの品質チェック（x5 / x8 で不良試行を選別する）
%  バット先端の実測ピークは 27〜35 m/s。250 Hz では 1 フレーム 110〜140 mm に相当する。
%  50 m/s 相当（200 mm/frame）を超える変位はスイングでは起こりえず、
%  マーカーの飛び・ラベル入れ替わりを意味する。
Prm.QC.TopStepMaxMm = 200 ;

