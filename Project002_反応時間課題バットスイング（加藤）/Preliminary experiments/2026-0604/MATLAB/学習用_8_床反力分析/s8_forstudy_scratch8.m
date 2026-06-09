clear
close all
clc

folderName = 'x1_RawData/2026-0604_予備実験';
fileName   = 'S01_free0001';

Data = load_qualisys_mat(folderName, fileName);

% サンプリング周波数の確認
fprintf('=== サンプリング周波数 ===\n');
fprintf('マーカー　: %d Hz\n', Data.FrameRate);
fprintf('アナログ（GRF）：%d Hz\n', Data.Analog.Frequency);
fprintf('\n');

% Force1・Force2のサイズ確認
fprintf('=== データサイズの確認 ===\n');
fprintf('Force1のサイズ　：%d行 × %d列\n', size(Data.Force1, 1), size(Data.Force1, 2));
fprintf('Force2のサイズ　：%d行 × %d列\n', size(Data.Force2, 1), size(Data.Force2, 2));
fprintf('\n');

% 垂直分力（Fz）を取り出す
% Force1(:,3) → Fz (3列目 = 垂直方向)
Fz1 = Data.Force1(:, 3);
Fz2 = Data.Force2(:, 3);

fprintf('=== 垂直分力（Fz）の確認 ===\n');
fprintf('Fz1 の最大値：%6.1f N\n', max(Fz1));
fprintf('Fz1 の最小値：%6.1f N\n', min(Fz1));
fprintf('Fz2 の最大値：%6.1f N\n', max(Fz2));
fprintf('Fz2 の最小値：%6.1f N\n', min(Fz2));

% 時間軸を作成する（試行開始を t=0 とする）
nAnalog  = length(Fz1);
fsAnalog = Data.Analog.Frequency;
tAnalog  = [1:nAnalog] / fsAnalog;

% Fzをプロットする
figure(1)

subplot(2, 1, 1)
plot(tAnalog, Fz1)
xlabel('Time [s] (試行開始からの経過時間)')
ylabel('Fz1[N]')
title('垂直分力 - プレート1')
grid on

subplot(2, 1, 2)
plot(tAnalog, Fz2)
xlabel('Time [s] (試行開始からの経過時間)')
ylabel('Fz2[N]')
title('垂直分力 - プレート2')
grid on

% LEDタイミングを取得する
led = Data.LEDData(:, 2);

tCueAnalog = find(abs(led) > 2, 1, 'first');

if isempty(tCueAnalog)
      fprintf('LEDタイミングが検出されませんでした\n');
else
    fprintf('=== LEDタイミング ===\n');
    fprintf('LED 点灯サンプル番号：%d\n', tCueAnalog);
    fprintf('LED 点灯時刻（試行開始から）：%.3f s\n', tCueAnalog / fsAnalog);
end

