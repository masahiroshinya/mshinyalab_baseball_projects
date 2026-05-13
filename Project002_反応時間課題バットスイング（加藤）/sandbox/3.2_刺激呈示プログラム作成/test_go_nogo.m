% test_go_nogo.m
% Go-No Go課題テスト用スクリプト
% ao0：緑LED（Go刺激）+ Qualisys Syncトリガ（並列接続）
% ao1：赤LED（No-Go刺激）

%% ===== 1. 設定セクション =====
disp('--- Go-No Go課題テスト 初期設定 ---');

csv_file = '../3.1_プロトコールCSV設計/protocol_sample.csv';
device_id = "Dev1";
ch_g       = "ao0";    % ao0：緑LED（Go）+ Qualisysトリガ（並列）
ch_r       = "ao1";    % ao1：赤LED（No-Go）
isi_offset = 5.0;      % ISIに加算するオフセット（秒）

%% ===== 2. CSV読み込み =====
if ~isfile(csv_file)
    error('CSVファイルが見つかりません: %s\nパスを確認してください。', csv_file);
end

opts = detectImportOptions(csv_file);
opts = setvartype(opts, {'condition','trial_type','stimulus_color','response_required','notes'}, 'string');
protocol_tbl = readtable(csv_file, opts);

test_tbl = protocol_tbl(101:107, :);   % go_nogo 練習 7試行
fprintf('Trial 101〜107（Go-No Go 練習 7試行）を実行します。\n');
fprintf('ISIオフセット: +%.1f秒　初回待機: 5秒\n\n', isi_offset);

%% ===== 3. DAQセットアップ =====
disp('DAQのセットアップ中...');
try
    dq = daq("ni");
    addoutput(dq, device_id, ch_g, "Voltage");   % ao0：緑LED
    addoutput(dq, device_id, ch_r, "Voltage");   % ao1：赤LED
    write(dq, [0.0, 0.0]);
    disp('DAQのセットアップ完了。');
catch ME
    warning('DAQの初期化に失敗しました。ハードウェアが接続されているか確認してください。');
    rethrow(ME);
end

%% ===== 4. QTM準備確認 & トリガ送信 =====
disp('');
disp('==============================================');
disp('【重要】QTM側の操作をしてください:');
disp('  1. Capture メニュー → Capture を選択');
disp('  2. Start ボタンを押す');
disp('  3. ステータスバーに "Waiting for trigger" と表示されたら準備完了');
disp('==============================================');
input('準備ができたら Enter を押してください...', 's');

disp('Qualisysにトリガを送信します...');
write(dq, [5.0, 0.0]);   % ao0のみ5V（QTMトリガ）、ao1は0V
pause(0.05);
write(dq, [0.0, 0.0]);
disp('トリガ送信完了。QTMが20ms後に録画を開始します。');

fprintf('\n=== テスト開始（5秒後にスタートします） ===\n');
for t = 5:-1:1
    fprintf('  %d...\n', t);
    pause(1);
end

%% ===== 5. 試行ループ（刺激呈示） =====
run_trials = height(test_tbl);

try
    for i = 1:run_trials
        color    = test_tbl.stimulus_color(i);
        isi_time = test_tbl.isi_sec(i) + isi_offset;
        led_dur  = test_tbl.led_duration_sec(i);
        v_on     = test_tbl.voltage_on(i);

        % 色に応じた電圧配列 [ao0（緑）, ao1（赤）] を決定
        volt_out = [0.0, 0.0];
        if v_on > 0
            if strcmp(color, "green")
                volt_out = [v_on, 0.0];   % Go：緑のみ点灯
            elseif strcmp(color, "red")
                volt_out = [0.0, v_on];   % No-Go：赤のみ点灯
            end
        end

        fprintf('Trial %d/%d: color=%s (%s), ISI=%.2fs, Dur=%.3fs\n', ...
                i, run_trials, color, test_tbl.response_required(i), isi_time, led_dur);

        % ISI待機
        t_start_isi = tic;
        while toc(t_start_isi) < isi_time
            pause(0.001);
        end

        % LED点灯
        write(dq, volt_out);

        % 点灯時間待機
        t_start_led = tic;
        while toc(t_start_led) < led_dur
            pause(0.001);
        end

        % LED消灯
        write(dq, [0.0, 0.0]);
    end

    disp('テストが正常に完了しました。全LEDを消灯しました。');

catch ME
    disp('エラーまたは中断が発生しました。デバイスを安全な状態に戻します。');
    if exist('dq', 'var')
        write(dq, [0.0, 0.0]);
    end
    rethrow(ME);
end

write(dq, [0.0, 0.0]);
disp('QTMの録画を手動で停止してください。');
