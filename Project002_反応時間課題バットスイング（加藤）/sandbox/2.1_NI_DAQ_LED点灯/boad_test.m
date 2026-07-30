% test_ao0_5v_5sec.m
% AO0チャネルから5Vを5秒間出力する刺激提示基盤テスト用スクリプト

% DataAcquisitionオブジェクトの作成
dq = daq("ni");

% アナログ出力チャンネルの追加（Dev1の ao0）
addoutput(dq, "Dev1", "ao0", "Voltage");

% 5Vを5秒間出力
disp('AO0から5Vを出力します（5秒間）');
write(dq, 5);   % 5Vを出力
pause(5);       % 5秒待機

% 出力を0Vに戻す
disp('出力を0Vに戻します');
write(dq, 0);

disp('テスト完了');
