% run_main_experiment.m
% 本番用・統合実験スクリプト
% 白LEDをワインドアップ開始合図とし、マイクロジッター後に緑/赤LEDでストライク/ボールを提示する。

%% ===== 1. 設定セクション =====
disp('--- 反応時間課題バットスイング実験 本番用スクリプト ---');

csv_file = '../3.1_プロトコールCSV設計/protocol_sample.csv'; % 本番用CSVへのパスに変更可能
device_id = "Dev1";
ch_g       = "ao0";          % ao0：緑LED（Go / ストライク）
ch_r       = "ao1";          % ao1：赤LED（No-Go / ボール）
ch_w       = "port0/line0";  % port0/line0 (DIO)：白LED（投球始動） + Qualisysトリガ並列

isi_offset = 3.0;        % ISIに加算するオフセット（マクロジッター・ピッチャー構え待機）
fp_base    = 1.5;        % フォアピリオド（モーション時間）のベース
fp_jitter_range = 0.2;   % マイクロジッターのブレ幅 (±0.2秒)

%% ===== 2. CSV読み込みと時間計算 =====
if ~isfile(csv_file)
    error('CSVファイルが見つかりません: %s\nパスを確認してください。', csv_file);
end

opts = detectImportOptions(csv_file);
opts = setvartype(opts, {'condition','trial_type','stimulus_color','response_required','notes'}, 'string');
protocol_tbl = readtable(csv_file, opts);

run_trials = height(protocol_tbl);

% --- QTM推奨Capture Timeの計算 ---
total_isi = sum(protocol_tbl.isi_sec) + (isi_offset * run_trials);
total_fp  = fp_base * run_trials;
total_led = sum(protocol_tbl.led_duration_sec);
total_time = 5.0 + total_isi + total_fp + total_led; % 初期待機5秒を加算
qtm_capture_time = ceil(total_time) + 10; % 10秒のバッファを追加

fprintf('\n【読み込み完了】総試行数: %d 試行\n', run_trials);
fprintf('==============================================\n');
fprintf('【重要】Qualisys (QTM) の設定確認\n');
fprintf('  Project Options -> Processing -> Calculate 6DOF を両方ON\n');
fprintf('  Capture time を【 %d 秒 】以上に設定してください。\n', qtm_capture_time);
fprintf('==============================================\n\n');

%% ===== 3. DAQセットアップ =====
disp('DAQのセットアップ中...');
try
    dq = daq("ni");
    addoutput(dq, device_id, ch_g, "Voltage");   % CH1: ao0 (緑)
    addoutput(dq, device_id, ch_r, "Voltage");   % CH2: ao1 (赤)
    addoutput(dq, device_id, ch_w, "Digital");   % CH3: port0/line0 (白・DIO)
    
    % 初期化: すべてOFF
    write(dq, [0.0, 0.0, 0]);
    disp('DAQのセットアップ完了。');
catch ME
    warning('DAQの初期化に失敗しました。ハードウェアが接続されているか確認してください。');
    rethrow(ME);
end

%% ===== 4. QTMトリガ待機 =====
disp('');
disp('==============================================');
disp('【実験手順】');
disp('  1. QTM側で Capture を選択し Start ボタンを押す');
disp('  2. ステータスが "Waiting for trigger" になったことを確認');
disp('  3. 打者に「開始します」と声かけ');
disp('==============================================');
input('準備ができたら Enter を押して実験を開始してください...', 's');

disp('Qualisysに同期トリガを送信します...');
% 白LED（DIO）のみ1を出力。これがQTMトリガとなる。
write(dq, [0.0, 0.0, 1]);
pause(0.05);
write(dq, [0.0, 0.0, 0]);
disp('トリガ送信完了。QTMの録画が開始されました。');

fprintf('\n=== 実験開始（5秒後に最初の試行の待機に入ります） ===\n');
for t = 5:-1:1
    fprintf('  %d...\n', t);
    pause(1);
end

%% ===== 5. 試行ループ（刺激呈示） =====
try
    for i = 1:run_trials
        condition = protocol_tbl.condition(i);
        color    = protocol_tbl.stimulus_color(i);
        isi_time = protocol_tbl.isi_sec(i) + isi_offset;
        led_dur  = protocol_tbl.led_duration_sec(i);
        v_on     = protocol_tbl.voltage_on(i);
        
        % フォアピリオド（マイクロジッター計算）
        % -fp_jitter_range から +fp_jitter_range の乱数
        jitter = (rand() * 2 * fp_jitter_range) - fp_jitter_range;
        fp_time = fp_base + jitter;

        % 緑/赤の電圧を決定
        v_g = 0.0;
        v_r = 0.0;
        if v_on > 0 && condition ~= "no_stimulus"
            % simple_reactionのCSV上の色は"white"ですが、本実験では緑(Go)を点灯させます
            if strcmp(color, "green") || strcmp(color, "white")
                v_g = v_on;
            elseif strcmp(color, "red")
                v_r = v_on;
            end
        end

        fprintf('Trial %d/%d [%s]: [Wait] %.1fs -> [Wind-up] %.2fs -> [Release] %s (%.2fs)\n', ...
                i, run_trials, condition, isi_time, fp_time, upper(color), led_dur);

        % --- [1] ISI待機（マクロジッター・構え待機） ---
        t_start_isi = tic;
        while toc(t_start_isi) < isi_time
            pause(0.001);
        end

        % --- [2] 白LED点灯（ワインドアップ開始） ---
        % 自己ペーススイング(no_stimulus)の時は白LEDを点灯させない
        if condition ~= "no_stimulus"
            write(dq, [0.0, 0.0, 1]);
        end

        % --- [3] フォアピリオド待機（マイクロジッター） ---
        t_start_fp = tic;
        while toc(t_start_fp) < fp_time
            pause(0.001);
        end

        % --- [4] 緑/赤LED点灯 & 白LED消灯（リリース） ---
        write(dq, [v_g, v_r, 0]);

        % --- [5] 点灯時間待機 ---
        t_start_led = tic;
        while toc(t_start_led) < led_dur
            pause(0.001);
        end

        % --- [6] 全LED消灯 ---
        write(dq, [0.0, 0.0, 0]);
    end

    disp('実験が正常に完了しました。全LEDを消灯しました。');

catch ME
    disp('エラーまたは中断が発生しました。デバイスを安全な状態に戻します。');
    if exist('dq', 'var')
        write(dq, [0.0, 0.0, 0]);
    end
    rethrow(ME);
end

write(dq, [0.0, 0.0, 0]);
disp('QTMの録画を手動で停止、または自動停止を待ってください。');
