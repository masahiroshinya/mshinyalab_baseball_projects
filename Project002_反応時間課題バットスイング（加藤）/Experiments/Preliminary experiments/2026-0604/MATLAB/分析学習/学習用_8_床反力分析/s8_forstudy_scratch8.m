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
xlabel('Time [s]（試行開始からの経過時間）')
ylabel('Fz1[N]')
title('垂直分力 - プレート1')
grid on

subplot(2, 1, 2)
plot(tAnalog, Fz2)
xlabel('Time [s]（試行開始からの経過時間）')
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

% LED基準の時間軸を作成する
% t = 0 が点灯、t < 0 が点灯前、t > 0 が点灯後
tFromLED = ([1 : nAnalog] - tCueAnalog) / fsAnalog;

% LED基準のFzをプロットする
figure(2)
plotTimeRange = [-1, 3];

subplot(2, 1, 1)
plot(tFromLED, Fz1)
set(gca, 'xlim', plotTimeRange)
xlabel('Time from LED[s]')
ylabel('Fz1[N]')
title('垂直分力 プレート1（LED点灯を t=0 として表示）')
lineplot(0, 'v', 'r-')
grid on

subplot(2, 1, 2)
plot(tFromLED, Fz2)
set(gca, 'xlim', plotTimeRange)
xlabel('Time from LED[s]')
ylabel('Fz2[N]')
title('垂直分力 プレート2（LED点灯を t=0 として表示）')
lineplot(0, 'v', 'r-')
grid on

% 静止期のサンプル範囲を決める
% 録画開始からLED点灯直前までを静止期とする（プロトコールの定義：LED点灯まで静止）
staticStart = 1;
staticEnd   = tCueAnalog - 1;

% 静止期のFzから体重を推定する
meanFz1_static = mean(Fz1(staticStart:staticEnd));
meanFz2_static = mean(Fz2(staticStart:staticEnd));
bodyWeight_N   = meanFz1_static + meanFz2_static;

fprintf('=== 体重の推定 ===\n');
fprintf('プレート1 Fz（静止期平均）：%.1f N\n', meanFz1_static);
fprintf('プレート2 Fz（静止期平均）：%.1f N\n', meanFz2_static);
fprintf('推定体重：%.1f N（約 %.1f kg）\n', bodyWeight_N, bodyWeight_N / 9.81);

% 垂直分力を体重で正規化する
Fz1_BW = Fz1 / bodyWeight_N;
Fz2_BW = Fz2 / bodyWeight_N;

% 正規化済み Fz を重ねてプロット
figure(3)
plotTimeRange = [-1, 3];

plot(tFromLED, Fz1_BW, 'b-', 'LineWidth', 1.2);
hold on
plot(tFromLED, Fz2_BW, 'r-', 'LineWidth', 1.2);
set(gca, 'xlim', plotTimeRange);
set(gca, 'ylim', [-0.1, 1.4]);
xlabel('Time from LED[s]')
ylabel('Vertical Force[BW]')
title('垂直分力の体重移動パターン（正規化済み）')
legend('プレート1（青）', 'プレート2（赤）', 'Location', 'northwest')
lineplot(0, 'v', 'k--')
grid on

% 合計値（Fz1 + Fz2）を確認する
FzTotal_BW = Fz1_BW + Fz2_BW;
figure(4)
plot(tFromLED, FzTotal_BW, 'k-')
set(gca, 'xlim', plotTimeRange)
xlabel('Time from LED[s]')
ylabel('Total Fz[BW]')
title('垂直分力の合計（プレート1 + プレート2）')
lineplot(0, 'v', 'r--')
grid on

% 前後方向分力（Fy）を取り出して正規化する
Fy1 = Data.Force1(:, 2);
Fy2 = Data.Force2(:, 2);

Fy1_BW = Fy1 / bodyWeight_N;
Fy2_BW = Fy2 / bodyWeight_N;

% Fz と Fy を上下に並べてプロットする
figure(5)
plotTimeRange = [-1, 3];

subplot(2, 1, 1)
plot(tFromLED, Fz1_BW, 'b-');
hold on
plot(tFromLED, Fz2_BW, 'r-');
set(gca, 'xlim', plotTimeRange)
xlabel('Time from LED[s]')
ylabel('Fz[BW]')
title('垂直分力（Fz）')
legend('プレート1', 'プレート2', 'Location', 'northwest')
lineplot(0, 'v', 'k--');
grid on

subplot(2, 1, 2)
plot(tFromLED, Fy1_BW, 'b-');
hold on
plot(tFromLED, Fy2_BW, 'r-');
set(gca, 'xlim', plotTimeRange)
xlabel('Time from LED[s]')
ylabel('Fy[BW]')
title('前後方向分力（Fy）')
legend('プレート1', 'プレート2', 'Location', 'northwest')
lineplot(0, 'v', 'k--');
grid on