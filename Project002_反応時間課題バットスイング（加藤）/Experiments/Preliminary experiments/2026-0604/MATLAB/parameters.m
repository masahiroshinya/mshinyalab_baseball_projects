function Prm = parameters()

% parameters for MATLAB analysis


%% x1_import_data: interp_nan_spline

Prm.MaxNumNans = 10 ;

% error code
Prm.ErrorCode.HasLongNan = 1 ;
Prm.ErrorText.HasLongNan = sprintf('has long nan: more than %d samples of nan', Prm.MaxNumNans) ;


%% x3_analyze_single_trial: Filter
Prm.Fc = 30 ;

% error code
Prm.ErrorCode.LEDTimingNotDetected = 2 ;
Prm.ErrorText.LEDTimingNotDetected = 'LED illumination was not detected' ;

%% m3_analyze_single_trial: RT 検出（後ろ足 Fz1）
Prm.RT.FzK     = 10 ;    % 閾値 = ベースライン SD の何倍か（≒ 15%BW）
Prm.RT.DurMs   = 30 ;    % 閾値超えの持続時間 [ms]
Prm.RT.BaseSec = 0.5 ;   % ベースライン窓（キュー直前）[s]
Prm.RT.WinSec  = 2.0 ;   % 探索窓（キュー起点）[s]
Prm.RT.FloorMs = 150 ;   % 生理的下限。目視照合の基準（強制 NaN 化はしない）



