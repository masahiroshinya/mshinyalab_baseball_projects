% HookTime の説明図に使う 1 試行（S05・Simple・Trial 12）のマーカーと時点を JSON に書き出す
%
% 試行の選び方：Fig.1 と同じ向き（右打者を正面から見て、投手側が右）で描くため、骨盤のマーカーが右打者の向き
%   （RASIS が LASIS より捕手側）の S05・S08 から選んだ。S05 の Simple で、x3 の top・knob・骨盤に欠損のない 7 試行のうち、
%   ①②③ の時間が S05 の平均（334・153・67 ms）に最も近い Trial 12（304・152・68 ms）。S08 はフック局面が 119 ms と短いので使わない。
% 時点：x5 の TPeakVelTop（ピーク速度のフレーム）から、AccelTime・LoopTime・HookTime を 4 ms（250 Hz）ずつさかのぼる。
%   x8 の局面分けと同じ定義（m3_analyze_single_trial.m）。
%
% 実行：このフォルダで matlab -batch "run('export_s05_simple12.m')"（2026-11-03）

thisFolder = fileparts(mfilename('fullpath')) ;
analysisFolder = fullfile(thisFolder, '..', '..', '..', '..', '..', 'Experiments', 'Main experiments', '03_Analysis') ;
S = load(fullfile(analysisFolder, 'x3_DataChecked', 'Data05.mat')) ;
d = S.DataArray(12, 2) ; % 行 = 試行、列 = 条件（2：simple）
R = load(fullfile(analysisFolder, 'x5_SingleTrialAnalysisResultsChecked', 'SingleTrialAnalysisResults05.mat')) ;
f = fieldnames(R) ;
r = R.(f{1})(12, 2) ;
O = struct('subject', 5, 'cond', d.ConditionName, 'trial', d.TrialNumber, 'fs', d.FrameRate, ...
    'tpeak', r.TPeakVelTop, 'hook', r.HookTime, 'loop', r.LoopTime, 'accel', r.AccelTime, ...
    'tcue', r.TCueMarker, 'rt', r.RTForce, 'peakvel', r.PeakVelTop) ;
markerNames = {'bottom', 'grip', 'knob', 'barrel', 'top', 'RASIS', 'RPSIS', 'LPSIS', 'LASIS'} ; % バットは握り側の端から bottom・grip・knob・barrel・top
for i = 1:numel(markerNames)
    O.(markerNames{i}) = d.Markers.(markerNames{i}) ;
end
fid = fopen(fullfile(thisFolder, 's05_simple12.json'), 'w') ;
fprintf(fid, '%s', jsonencode(O)) ;
fclose(fid) ;
