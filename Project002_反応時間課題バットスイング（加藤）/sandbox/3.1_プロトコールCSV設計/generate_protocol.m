%% generate_protocol.m
% 反応時間課題バットスイング実験 プロトコールCSV生成スクリプト
% 参照: 段取り.md

%% ===== 設定セクション =====

% --- ブロック・試行数 ---
% 練習試行数
n_practice_no_stim = 10;
n_practice_simple  = 10;
n_practice_gonogo  = 15;

% 本試行数
n_main_no_stim = 30;
n_main_simple  = 50;
n_main_gonogo  = 80;

% --- 実験条件 ---
% ラテン方格法等で順番を変える場合、ここの並び順を変更する
% 推奨順序の例: (1) no_stimulus -> simple_reaction -> go_nogo
condition_order = {'no_stimulus', 'simple_reaction', 'go_nogo'};

% --- Go-NoGo 比率 ---
go_ratio = 0.70;    % Go試行の割合（残り 0.30 が No-Go）

% --- タイミングパラメータ ---
isi_min_sec      = 3.0;     % ISI最小値 [秒]
isi_max_sec      = 6.0;     % ISI最大値 [秒]（一様乱数で生成）
led_duration_sec = 0.150;   % LED点灯継続時間 [秒]
voltage_on       = 5.0;     % DAQ制御信号電圧 [V]（基盤側が電流制御）

% --- 乱数シード（再現性のため固定） ---
rng_seed = 42;

% --- 出力ファイル名 ---
output_filename = sprintf('protocol_%s.csv', datestr(now, 'yyyymmdd'));

%% ===== 処理セクション =====
rng(rng_seed); % 乱数シードの固定

% データ格納用配列の初期化
protocol_data = {};
trial_id = 1;
block_id = 1;

for c = 1:length(condition_order)
    current_cond = condition_order{c};
    
    % --- 条件ごとの試行数を設定 ---
    if strcmp(current_cond, 'no_stimulus')
        n_practice = n_practice_no_stim;
        n_main = n_main_no_stim;
    elseif strcmp(current_cond, 'simple_reaction')
        n_practice = n_practice_simple;
        n_main = n_main_simple;
    elseif strcmp(current_cond, 'go_nogo')
        n_practice = n_practice_gonogo;
        n_main = n_main_gonogo;
    else
        error('未定義の条件が含まれています: %s', current_cond);
    end
    
    phases = {'practice', 'main'};
    n_trials_array = [n_practice, n_main];
    
    for p = 1:2
        phase_type = phases{p};
        n_trials = n_trials_array(p);
        
        if n_trials == 0
            continue; % 試行数0の場合はスキップ
        end
        
        % Go-NoGo条件の場合の刺激配列を事前生成し、シャッフル
        if strcmp(current_cond, 'go_nogo')
            n_go = round(n_trials * go_ratio);
            n_nogo = n_trials - n_go;
            stim_array = [repmat({'go'}, 1, n_go), repmat({'nogo'}, 1, n_nogo)];
            stim_array = stim_array(randperm(n_trials)); % シャッフル
        end
        
        for t = 1:n_trials
            % 各カラムの初期値
            stimulus_color = '';
            response_required = '';
            current_led_duration = led_duration_sec;
            current_voltage = voltage_on;
            notes = '';
            
            % 条件に応じたパラメータ設定
            if strcmp(current_cond, 'no_stimulus')
                stimulus_color = 'none';
                response_required = 'n/a';
                current_led_duration = 0.000;
                current_voltage = 0.0;
                if t == 1
                    notes = sprintf('%s: %s', phase_type, current_cond);
                end
                
            elseif strcmp(current_cond, 'simple_reaction')
                stimulus_color = 'white';
                response_required = 'go';
                if t == 1
                    notes = sprintf('%s: %s', phase_type, current_cond);
                end
                
            elseif strcmp(current_cond, 'go_nogo')
                if strcmp(stim_array{t}, 'go')
                    stimulus_color = 'green';
                    response_required = 'go';
                else
                    stimulus_color = 'red';
                    response_required = 'nogo';
                end
                if t == 1
                    notes = sprintf('%s: %s', phase_type, current_cond);
                end
            end
            
            % ISI生成 (一様乱数)
            isi_sec = isi_min_sec + (isi_max_sec - isi_min_sec) * rand();
            
            % 1行分のデータ追加
            protocol_data(end+1, :) = { ...
                trial_id, ...
                block_id, ...
                t, ...
                current_cond, ...
                phase_type, ...
                stimulus_color, ...
                response_required, ...
                round(isi_sec, 3), ...
                current_led_duration, ...
                current_voltage, ...
                notes ...
            };
            
            trial_id = trial_id + 1;
        end
        
        block_id = block_id + 1; % フェーズごとにブロックをインクリメント
    end
end

%% ===== テーブル作成とバリデーション =====
var_names = {'trial_id', 'block_id', 'trial_in_block', 'condition', 'trial_type', ...
             'stimulus_color', 'response_required', 'isi_sec', 'led_duration_sec', ...
             'voltage_on', 'notes'};
T = cell2table(protocol_data, 'VariableNames', var_names);

% --- バリデーション実行 ---
fprintf('--- バリデーションチェック開始 ---\n');

% 1. 必須カラムの存在確認 (VariableNamesで定義済なので実質パス)
assert(isequal(T.Properties.VariableNames, var_names), 'カラム名が一致しません。');

% 2. trial_id の連番確認
assert(all(T.trial_id == (1:height(T))'), 'trial_id が連番になっていません。');

% 3. condition の値確認
valid_conds = {'no_stimulus', 'simple_reaction', 'go_nogo'};
assert(all(ismember(T.condition, valid_conds)), '不正な condition が含まれています。');

% 4. trial_type の値確認
valid_types = {'practice', 'main'};
assert(all(ismember(T.trial_type, valid_types)), '不正な trial_type が含まれています。');

% 5. stimulus_color の値確認
valid_colors = {'none', 'white', 'green', 'red'};
assert(all(ismember(T.stimulus_color, valid_colors)), '不正な stimulus_color が含まれています。');

% 6. response_required の値確認
valid_resps = {'n/a', 'go', 'nogo'};
assert(all(ismember(T.response_required, valid_resps)), '不正な response_required が含まれています。');

% 7. condition と stimulus_color の整合性確認
for i = 1:height(T)
    c = T.condition{i};
    sc = T.stimulus_color{i};
    if strcmp(c, 'no_stimulus') && ~strcmp(sc, 'none')
        warning('行 %d: no_stimulus なのに stimulus_color が %s です。', i, sc);
    end
    if strcmp(c, 'simple_reaction') && ~strcmp(sc, 'white')
        warning('行 %d: simple_reaction なのに stimulus_color が %s です。', i, sc);
    end
    if strcmp(c, 'go_nogo') && ~(strcmp(sc, 'green') || strcmp(sc, 'red'))
        warning('行 %d: go_nogo なのに stimulus_color が %s です。', i, sc);
    end
end

% 8. isi_sec の範囲確認
invalid_isi = T.isi_sec < isi_min_sec | T.isi_sec > isi_max_sec;
if any(invalid_isi)
    warning('%d 行の isi_sec が設定範囲（%f〜%f）外です。', sum(invalid_isi), isi_min_sec, isi_max_sec);
end

% 9. led_duration_sec の値確認
idx_nostim = strcmp(T.condition, 'no_stimulus');
if any(T.led_duration_sec(idx_nostim) ~= 0.0)
    warning('no_stimulus 条件で led_duration_sec が 0.0 でない行があります。');
end
if any(T.led_duration_sec(~idx_nostim) ~= led_duration_sec)
    warning('刺激あり条件で led_duration_sec が設定値 (%f) でない行があります。', led_duration_sec);
end

% 10. voltage_on の範囲確認
assert(all(T.voltage_on >= 0.0 & T.voltage_on <= 10.0), 'voltage_on が 0〜10V の範囲外の行があります。');
if any(T.voltage_on(idx_nostim) ~= 0.0)
    error('no_stimulus 条件で voltage_on が 0.0 でない行があります。');
end

fprintf('--- バリデーションチェック完了（問題なし） ---\n\n');

%% ===== CSV書き出し =====
writetable(T, output_filename);
fprintf('プロトコールを作成しました: %s\n', output_filename);
fprintf('総試行数: %d\n', height(T));
for c = 1:length(valid_conds)
    cond = valid_conds{c};
    fprintf('  - %s: %d 試行\n', cond, sum(strcmp(T.condition, cond)));
end
