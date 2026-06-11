% スイング開始�?�定義?��バ�?ト長軸の角�?�度 > 300 deg/s

clear
close all
clc

iSubject   = 1;
iCondition = 3;
iTrial     = 1;

dataFilePath = sprintf('x3_DataChecked/Data%02d', iSubject);
load(dataFilePath)

Data = DataArray(iTrial, iCondition);

Prm = parameters;
fs  = Data.FrameRate;
fprintf('サンプリング周波数: %d Hz\n', fs);

% マ�?�カー�?覧を表示する
disp('=== Data.Markers のフィールド名 ===')
disp(fieldnames(Data.Markers))

fc = Prm.Fc;
[b, a] = butter(2, fc / (fs / 2));

% NaNをスプラインで補完してからフィルタリング
fields = fieldnames(Data.Markers);
for i = 1:numel(fields)
     f = fields{i};
     x = Data.Markers.(f);
     t = (1:size(x,1))';
     for col = 1:size(x,2)
          nanIdx = isnan(x(:,col));
          if any(nanIdx) && any(~nanIdx)
               x(nanIdx, col) = interp1(t(~nanIdx), x(~nanIdx, col), t(nanIdx), 'linear', 'extrap');
          end
     end
     Data.Markers.(f) = x;
end

M = filt_all_fields(b, a, Data.Markers);

r_bottom = M.bottom;
r_top    = M.top;

% bottom �? top の方向�?�クトル
v_long = r_top - r_bottom;

% ノル�??��大きさ?���?�計�?
v_long_norm = sum(v_long.^2, 2).^0.5;

% 単位�?�クトル?��正規化?�?
e_long = v_long ./ v_long_norm;

% 単位�?�クトルの時間微�?
de_long = diff3p(e_long, 1/fs);

% �?フレー�?での大きさ?���? 角�?�度の近似値?�?
omega_rad = sum(de_long.^2, 2).^0.5;

% ラジアン/�? �? 度/�? に変換
omega_deg = omega_rad * (180 / pi);

led        = Data.LEDData(:, 2);
tCueAnalog = find(abs(led) > 2, 1, 'first');
tCueMarker = round(tCueAnalog / Data.AnalogFs * fs);

if isempty(tCueAnalog)
     error('LEDタイミングが見つかりませんでした')
end

if led(tCueAnalog) > 0
     cueText = 'Go';
else
     cueText = 'NoGo';
end

fprintf('キュー種�?: %s\n', cueText);
fprintf('LEDフレー�?: %d フレー�?目\n', tCueMarker);

THRESHOLD_OMEGA = 300;

nFrames    = length(omega_deg);
searchRange = tCueMarker : nFrames;

idxAbove = find(omega_deg(searchRange) > THRESHOLD_OMEGA, 1 ,'first');

if isempty(idxAbove)
     tSwingOnset = NaN;
     fprintf('スイング開始が検�?�されませんでした\n');
else
     tSwingOnset = searchRange(1) + idxAbove -1;
     fprintf('スイング開�?: %d フレー�?目\n', tSwingOnset);
end
