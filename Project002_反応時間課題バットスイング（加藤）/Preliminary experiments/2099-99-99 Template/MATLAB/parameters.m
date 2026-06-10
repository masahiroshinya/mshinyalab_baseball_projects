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


