%% Extract_bottom_trials.m
%  topを使っている試行のうち、bottomも使える試行を抜き出す

clear
clc

% ① パスと設定
here    = fileparts(mfilename('fullpath')) ;
projDir = fullfile(here, '..', '..') ;
anaDir  = fullfile(projDir, 'Experiments', 'Main Experiments', '03_Analysis') ;
outDir  = fullfile(here, 'output') ;
if ~exist(outDir, 'dir'), mkdir(outDir) ;
end

addpath(anaDir) ;
Prm = parameters ;

ConditionOrder = {'free', 'simple', 'gonogo', 'gostop'} ;


% ② topを使っている試行を探す
S  = load(fullfile(anaDir, 'x8_StatTable', 'StatTable.mat'), 'TrialTable') ;
TT = S.TrialTable ;

TT.UseTop = ~( (TT.IsBadTop & ~TT.KeepTop) | TT.IsBadOnset | TT.ExclTop) ;

% ③ bottomの欠損を数える