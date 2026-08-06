% test_all_leds.m（案）
% 白（AO0 -5V）・緑（AO1 +5V）・赤（AO1 -5V）の3色をまとめて確認する

dq = daq("ni");
addoutput(dq, "Dev1", {'ao0', 'ao1'}, "Voltage");

% 初期化：両チャネルとも0V（全消灯）
write(dq, [0, 0]);
disp('--- 3色LED動作確認 ---');
pause(1);

% --- ① AO0 = -5V：Ready cue → 白のみ点灯 ---
disp('① AO0 = -5V  → 【白】のみ点灯するはず');
write(dq, [-5, 0]);
pause(4);
write(dq, [0, 0]);
pause(1);

% --- ② AO0 = +5V：Qualisysトリガー → 全消灯 ---
disp('② AO0 = +5V  → 【全消灯】のはず（トリガー送出時に誤点灯しない）');
write(dq, [5, 0]);
pause(4);
write(dq, [0, 0]);
pause(1);

% --- ③ AO1 = +5V：Go cue → 緑のみ点灯 ---
disp('③ AO1 = +5V  → 【緑】のみ点灯するはず');
write(dq, [0, 5]);
pause(4);
write(dq, [0, 0]);
pause(1);

% --- ④ AO1 = -5V：No-Go cue → 赤のみ点灯 ---
disp('④ AO1 = -5V  → 【赤】のみ点灯するはず');
write(dq, [0, -5]);
pause(4);
write(dq, [0, 0]);
pause(1);

% --- ⑤ 本番相当のシーケンス（トリガー → Ready(白) → Go(緑)）---
disp('⑤ 本番相当：トリガー → 白 → 緑 の順に提示します');
write(dq, [5, 0]);    pause(0.1);   % Qualisysトリガー（白は光らない）
write(dq, [0, 0]);    pause(1.0);   % 待機
write(dq, [-5, 0]);   pause(0.5);   % Ready cue（白）
write(dq, [0, 0]);    pause(1.0);   % フォアピリオド
write(dq, [0, 5]);    pause(0.5);   % Go cue（緑）
write(dq, [0, 0]);

disp('テスト完了');
