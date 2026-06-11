% スイング開始の定義：バット長軸の角速度 > 300 deg/s

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

% マーカー一覧を表示する
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

% bottom → top の方向ベクトル
v_long = r_top - r_bottom;

% ノルム（大きさ）の計算
v_long_norm = sum(v_long.^2, 2).^0.5;

% 単位ベクトル（正規化）
e_long = v_long_norm;