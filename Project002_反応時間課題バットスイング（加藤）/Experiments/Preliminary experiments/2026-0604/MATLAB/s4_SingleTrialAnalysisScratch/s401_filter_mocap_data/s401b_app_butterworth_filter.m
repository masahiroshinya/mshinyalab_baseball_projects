function s401b_app_butterworth_filter()
% s401b_app_butterworth_filter
%
% 【学習目標 / Learning Goal】
%   バターワースフィルターのパラメータ（fc, order）が
%   フィルター特性に与える影響を対話的に確認する
%   Interactively explore how Butterworth filter parameters (fc, order)
%   affect the filter characteristics
%
% 【操作方法 / How to use】
%   スライダーで fc と order を変えると、グラフがリアルタイムに更新される
%   Move the sliders for fc and order to update the plots in real time
%
%   上のグラフ: フィルターの周波数応答（ゲイン特性）
%   Upper plot: Filter frequency response (gain characteristics)
%     - gain = 1.0: その周波数は通過する / that frequency passes through
%     - gain = 0.0: その周波数は除去される / that frequency is removed
%
%   下のグラフ: 合成信号（3 Hz 運動 + 50 Hz 正弦波ノイズ）へのフィルター適用結果
%   Lower plot: Filter applied to synthetic signal (3 Hz motion + 50 Hz sine noise)
%   ※ 50 Hz 正弦波はフィルター効果を分かりやすく示すための教材用ノイズ
%      The 50 Hz sine is a didactic noise for clearly visualizing filter effect
%
% 【実行方法 / How to run】
%   >> s401b_app_butterworth_filter
%   カレントフォルダを s401_filter_mocap_data/ に設定してから実行すること
%   Set MATLAB current folder to s401_filter_mocap_data/ before running
% -----------------------------------------------------------------------

% サンプリング周波数 / Sampling frequency [Hz]
fs = 200 ;

% --- 合成信号の作成 / Create synthetic signal ---
% 50 Hz 正弦波はスライダー操作時のフィルター効果を視覚的に確認しやすいため使用
% 50 Hz sine is used because it clearly shows the filter effect when moving sliders
duration = 3 ;
t = 0 : 1/fs : duration - 1/fs ;
signal = 100 * sin(2*pi*3*t) + 5 * sin(2*pi*50*t) ;

% --- UI の構築 / Build UI ---
% UI内のテキストは文字化け回避のため英語のみ
% UI text is in English only to avoid encoding issues
fig = uifigure( ...
    'Name',     'Butterworth Filter Explorer', ...
    'Position', [80 80 980 630]) ;

% コントロールパネル / Control panel
ctrl = uipanel(fig, ...
    'Title',    'Parameters', ...
    'Position', [10 10 200 610]) ;

% --- fc スライダー / fc slider ---
uilabel(ctrl, 'Position', [10 555 180 22], ...
    'Text', 'Cutoff frequency  fc [Hz]', 'FontWeight', 'bold') ;
lbl_fc = uilabel(ctrl, 'Position', [50 530 100 22], ...
    'Text', 'fc = 30 Hz', 'HorizontalAlignment', 'center') ;
sld_fc = uislider(ctrl, ...
    'Position',   [10 513 175 3], ...
    'Limits',     [1 90], ...
    'Value',      30, ...
    'MajorTicks', [1 15 30 45 60 75 90], ...
    'MinorTicks', []) ;

% --- order スライダー / order slider ---
uilabel(ctrl, 'Position', [10 455 180 22], ...
    'Text', 'Filter order', 'FontWeight', 'bold') ;
lbl_order = uilabel(ctrl, 'Position', [50 430 100 22], ...
    'Text', 'order = 2', 'HorizontalAlignment', 'center') ;
sld_order = uislider(ctrl, ...
    'Position',   [10 413 175 3], ...
    'Limits',     [1 8], ...
    'Value',      2, ...
    'MajorTicks', [1 2 3 4 5 6 7 8], ...
    'MinorTicks', []) ;

% --- fc の説明 / fc description (split into multiple labels, no WordWrap) ---
uilabel(ctrl, 'Position', [5 365 185 20], 'Text', 'About fc:', 'FontWeight', 'bold') ;
uilabel(ctrl, 'Position', [5 345 185 20], 'Text', 'Below fc  -> pass (gain ~ 1)') ;
uilabel(ctrl, 'Position', [5 325 185 20], 'Text', 'Above fc  -> attenuated (gain ~ 0)') ;
uilabel(ctrl, 'Position', [5 305 185 20], 'Text', 'Red line = fc in upper plot') ;

% --- order の説明 / order description ---
uilabel(ctrl, 'Position', [5 265 185 20], 'Text', 'About order:', 'FontWeight', 'bold') ;
uilabel(ctrl, 'Position', [5 245 185 20], 'Text', 'Higher -> steeper roll-off') ;
uilabel(ctrl, 'Position', [5 225 185 20], 'Text', 'Lower  -> gentler roll-off') ;
uilabel(ctrl, 'Position', [5 205 185 20], 'Text', 'Too high -> ringing artifacts') ;

% --- プロットエリア / Plot areas ---
ax1 = uiaxes(fig, 'Position', [230 340 730 270]) ;  % 周波数応答 / Freq response
ax2 = uiaxes(fig, 'Position', [230 30  730 290]) ;  % 信号 / Signal

% --- 初期プロット / Initial plot ---
updatePlot(30, 2) ;

% --- スライダーのコールバック / Slider callbacks ---
sld_fc.ValueChangedFcn    = @(~,~) onChange() ;
sld_order.ValueChangedFcn = @(~,~) onChange() ;


    % スライダー変更時の処理 / Handler called when a slider changes
    function onChange()
        fc_val    = round(sld_fc.Value) ;
        order_val = max(1, round(sld_order.Value)) ;
        lbl_fc.Text    = sprintf('fc = %d Hz', fc_val) ;
        lbl_order.Text = sprintf('order = %d', order_val) ;
        updatePlot(fc_val, order_val) ;
    end


    % グラフ更新 / Update plots with new filter parameters
    function updatePlot(fc_val, order_val)

        % バターワースフィルターの設計 / Design Butterworth filter
        % fc がナイキスト周波数以上にならないようにクリップする
        % Clip Wn to stay below the Nyquist frequency
        Wn = min(fc_val / (fs/2), 0.99) ;
        [b, a] = butter(order_val, Wn, 'low') ;

        % --- 周波数応答 / Frequency response ---
        % freqz() でフィルターのゲイン特性を計算する
        % Compute filter gain characteristics using freqz()
        [H, W] = freqz(b, a, 1024, fs) ;

        cla(ax1)
        plot(ax1, W, abs(H), 'b-', 'LineWidth', 2.5) ; hold(ax1, 'on')

        % カットオフ周波数の位置を示す赤破線 / Red dashed line at fc
        xline(ax1, fc_val,    'r--', 'LineWidth', 2) ;
        % -3 dB ライン（gain = 1/sqrt(2)）/ -3 dB line
        yline(ax1, 1/sqrt(2), 'k:',  'LineWidth', 1.5) ;
        % 合成信号の成分周波数 / Frequencies of the synthetic signal components
        xline(ax1, 3,  'b:', 'LineWidth', 1) ;   % 身体運動成分 / Motion component
        xline(ax1, 50, 'r:', 'LineWidth', 1) ;   % ノイズ成分 / Noise component

        ax1.XLim = [0 fs/2] ;
        ax1.YLim = [0 1.1] ;
        xlabel(ax1, 'Frequency [Hz]')
        ylabel(ax1, 'Gain')
        title(ax1, sprintf('Frequency Response   (fc = %d Hz,  order = %d)', fc_val, order_val))
        legend(ax1, ...
            'Filter response', ...
            sprintf('fc = %d Hz', fc_val), ...
            '-3 dB  (1/sqrt(2))', ...
            '3 Hz (motion)', ...
            '50 Hz (noise)', ...
            'Location', 'northeast')
        grid(ax1, 'on')

        % --- 信号へのフィルター適用 / Apply filter to signal ---
        % filtfilt() はゼロ位相フィルタリング（往復2回適用）
        % filtfilt() is zero-phase filtering (applied forward and backward)
        signal_filt = filtfilt(b, a, signal) ;

        cla(ax2)
        plot(ax2, t, signal,      'Color', [0.75 0.75 0.75], 'LineWidth', 1) ;
        hold(ax2, 'on')
        plot(ax2, t, signal_filt, 'b-', 'LineWidth', 1.5) ;

        ax2.XLim = [0 0.5] ;
        xlabel(ax2, 'Time [s]')
        ylabel(ax2, 'Amplitude [mm]')
        title(ax2, 'Synthetic signal (3 Hz motion + 50 Hz sine noise)  — Raw vs Filtered')
        legend(ax2, 'Raw (3 Hz + 50 Hz)', 'Filtered', 'Location', 'northeast')
        grid(ax2, 'on')

    end

end
