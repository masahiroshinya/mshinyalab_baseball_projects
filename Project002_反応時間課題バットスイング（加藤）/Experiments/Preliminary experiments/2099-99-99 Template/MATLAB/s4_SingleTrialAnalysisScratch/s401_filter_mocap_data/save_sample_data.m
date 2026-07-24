% save_sample_data.m
% s41_plot_bat_picture の練習用サンプル�?ータを作�?��?�保存するスクリプト
%
% 【保存するデータ�?
%   Markers 構�??体�?Markers.top, Markers.bottom?���?�み
%
% 【選択した試行�??
%   被験�??: Subject 01
%   条件  : free?�?iCondition = 1?�?
%   試�?  : 第1試行�?iTrial = 1?�?
%   �?由  : free条件は常にスイングが発生するため�?�軌跡が�?ず描画できる
%
% 【実行方法�??
%   MATLABのカレントフォル�?�? MATLAB/ に設定してから実行すること
%
% ---------------------------------------------------------------

clear
clc

% --- �?ータ読み込み ---
iSubject   = 1 ;
iTrial     = 1 ;
iCondition = 1 ;  % 1 = free

dataFilePath = sprintf('../../x3_DataChecked/Data%02d', iSubject) ;  % s401_plot_bat_picture/ からの相対パス
load(dataFilePath, 'DataArray')

% --- 対象試行�?�確�? ---
Data = DataArray(iTrial, iCondition) ;

fprintf('被験�??: Subject %02d\n', iSubject) ;
fprintf('条件  : %s (iCondition = %d)\n', Data.ConditionName, iCondition) ;
fprintf('試�?  : iTrial = %d\n', iTrial) ;
fprintf('エラー: %s (ErrorCode = %d)\n', Data.ErrorText, Data.ErrorCode) ;

if Data.ErrorCode ~= 0
    warning('ErrorCode �? 0 ではありません。別の試行を選んでください�?') ;
end

% --- Markers �?け抽出して保�? ---
Markers = Data.Markers ;

saveFilePath = 'SampleData' ;
save(saveFilePath, 'Markers') ;

fprintf('\nSampleData.mat を保存しました: %s\n', saveFilePath) ;
fprintf('保存されたフィール�?:\n') ;
disp(fieldnames(Markers)) ;
