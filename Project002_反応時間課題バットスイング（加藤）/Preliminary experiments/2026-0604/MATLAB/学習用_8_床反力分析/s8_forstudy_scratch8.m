clear
close all
clc

folderName = '../../2026-0604/x1_RawData/2026-0604予備実験';
filrName   = 'S01_free0001';

Data = load_qualisys_mat(folderName, filename);

fprintf('=== サンプリング周波数 ===\n');
fprintf('マーカー　: %d Hz\n', Data.FrameRate);
fprintf('アナログ（GRF）：%d Hz\n', Data.AnalogFs);
fprintf('\n');

