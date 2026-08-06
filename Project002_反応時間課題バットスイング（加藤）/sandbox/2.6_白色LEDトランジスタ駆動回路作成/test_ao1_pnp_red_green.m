% test_ao1_green_red.m（案）
% AO1チャネルから +5V / 0V / -5V を順に出力し、緑・赤LEDの動作を確認する

dq = daq("ni");
addoutput(dq, "Dev1", "ao1", "Voltage");

% --- ① +5V：Go cue → 緑が点灯するはず ---
disp('AO1から +5V を出力します（5秒間）→ 【緑】が点灯・【赤】は消灯のはず');
write(dq, 5);
pause(5);

% --- ② 0V：待機 → 両方消灯するはず ---
disp('AO1を 0V に戻します（3秒間）→ 【緑・赤とも消灯】のはず');
write(dq, 0);
pause(3);

% --- ③ -5V：No-Go cue → 赤が点灯するはず ---
disp('AO1から -5V を出力します（5秒間）→ 【赤】が点灯・【緑】は消灯のはず');
write(dq, -5);
pause(5);

% --- 終了 ---
write(dq, 0);
disp('テスト完了');