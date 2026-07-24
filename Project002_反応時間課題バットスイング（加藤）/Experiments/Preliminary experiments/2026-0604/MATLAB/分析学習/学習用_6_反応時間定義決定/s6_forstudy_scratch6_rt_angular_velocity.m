iSubject   = 1 ;
iCondition = 3 ;  
iTrial = 5;

dataFilePath = sprintf('x3_DataChecked/Data%02d', iSubject) ;
load(dataFilePath)

Data = DataArray(iTrial, iCondition) ;

Prm = parameters ;
fs  = Data.FrameRate ;
fprintf('サンプリング周波数: %d Hz\n', fs) ;

fc = Prm.Fc;
[b, a] = butter(2, fc / (fs / 2));

% NaN補間（フィルタリング前の前処理）
fields = fieldnames(Data.Markers) ;
for i = 1:numel(fields)
    f = fields{i} ;
    x = Data.Markers.(f) ;          % [nFrames × 3]
    t = (1:size(x,1))' ;
    for col = 1:size(x,2)
        nanIdx = isnan(x(:,col)) ;
        if any(nanIdx) && any(~nanIdx)
            x(nanIdx,col) = interp1(t(~nanIdx), x(~nanIdx,col), t(nanIdx), 'linear', 'extrap') ;
        end
    end
    Data.Markers.(f) = x ;
end

M = filt_all_fields(b, a, Data.Markers);

r_bottom = M.bottom ;   % [nFrames × 3]  グリップ端の位置 [mm]
r_top    = M.top ;      % [nFrames × 3]  バット先端の位置 [mm]

% bottom → top の方向ベクトル
v_long = r_top - r_bottom ;                  % [nFrames × 3]

% ノルム（大きさ）の計算
v_long_norm = sum(v_long.^2, 2).^0.5 ;      % [nFrames × 1]

% 単位ベクトル（正規化）
e_long = v_long ./ v_long_norm ;             % [nFrames × 3]

% 単位ベクトルの時間微分（diff3p は3点中心差分法）
de_long = diff3p(e_long, 1/fs) ;        % [nFrames × 3]

% 各フレームでの大きさ（= 角速度の近似値）
omega_rad = sum(de_long.^2, 2).^0.5 ;  % [nFrames × 1]  [rad/s]

% ラジアン/秒 → 度/秒 に変換
omega_deg = omega_rad * (180 / pi) ;   % [nFrames × 1]  [deg/s]

led_go   = Data.LEDData(:, 2) ;          % Go信号（列2）
led_nogo = Data.LEDData(:, 1) ;          % NoGo信号（列1）

tCueGo   = find(led_go   > 2,  1, 'first') ;
tCueNoGo = find(led_nogo < -2, 1, 'first') ;

if ~isempty(tCueGo)
    tCueAnalog = tCueGo ;
    cueText    = 'Go' ;
elseif ~isempty(tCueNoGo)
    tCueAnalog = tCueNoGo ;
    cueText    = 'NoGo' ;
else
    error('LED タイミングが検出されませんでした') ;
end

tCueMarker = round(tCueAnalog / Data.AnalogFs * fs) ;
fprintf('キュー種類: %s\n', cueText) ;
fprintf('LED フレーム: %d フレーム目\n', tCueMarker) ;


fprintf('キュー種類: %s\n', cueText) ;
fprintf('LED フレーム: %d フレーム目\n', tCueMarker) ;

THRESHOLD_OMEGA = 300 ; 

nFrames     = length(omega_deg) ;
searchRange = tCueMarker : nFrames ;

idxAbove = find(omega_deg(searchRange) > THRESHOLD_OMEGA, 1, 'first') ;

if isempty(idxAbove)
    tSwingOnset = NaN ;
    fprintf('スイング開始が検出されませんでした\n') ;
else
    tSwingOnset = searchRange(1) + idxAbove - 1 ;
    fprintf('スイング開始: %d フレーム目\n', tSwingOnset) ;
end

if isnan(tSwingOnset)
    RT = NaN;
    fprintf('RT未検出（スイング未検出）\n');
else
    RT = (tSwingOnset - tCueMarker) / fs * 1000;
    fprintf('RT = %.1f ms (CueText: %s)\n', RT, cueText);
end

nFrames  = length(omega_deg);
tArray   = ([1:nFrames] - tCueMarker) / fs;
plotXLim = [-1, 3];

figure(1)
clf

% 上段：角速度の時系列
subplot(3, 1, [1 2])
plot(tArray, omega_deg, 'b-', 'LineWidth', 1.2)
hold on

% 閾値の横線
yline(THRESHOLD_OMEGA, 'r--', sprintf('%d deg/s', THRESHOLD_OMEGA));

% スイング開始の縦線
if ~isnan(tSwingOnset)
    tSO_sec = (tSwingOnset - tCueMarker) / fs;
    lineplot(tSO_sec, 'v', 'r-');
end

set(gca, 'xlim', plotXLim);
xlabel('LEDキューからの時間 (s)');
ylabel('角速度 (deg/s)');

if ~isnan(RT)
    title(sprintf('RT = %.1f ms [%s] | Shinya法（閾値 %d deg/s)', ...
        RT, cueText, THRESHOLD_OMEGA));
else
    title(sprintf('スイング未検出 [%s]', cueText));
end
grid on

% 下段：LED信号
subplot(3, 1, 3)
nAnalog      = size(Data.LEDData, 1);
tArrayAnalog = ([1:nAnalog] - tCueAnalog) / Data.AnalogFs;
plot(tArrayAnalog, Data.LEDData)
set(gca, 'xlim', plotXLim);
xlabel('LEDキューからの時間 (s)');
ylabel('LED信号 (V)');
grid on
