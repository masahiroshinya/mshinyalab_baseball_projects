function sendQTMTrigger(dq)
% sendQTMTrigger - QTMへのSync Triggerパルスを送信する関数
%
% 使い方:
%   sendQTMTrigger(dq)
%
% 引数:
%   dq : daq オブジェクト（ao0 チャンネルが追加済みであること）
%
% 解説:
%   ao0 チャンネルに 0V → 5V → 0V のパルスを送信する。
%   QTMは立ち上がりエッジ（Positive edge）を検出し、計測を開始する。
%   パルス幅は50ms（QTMの最小遅延20msに余裕を持たせた値）。

    disp('【sendQTMTrigger】トリガ送信を開始します...');

    % 5V に立ち上げる（立ち上がりエッジでQTMがトリガを認識）
    write(dq, 5);

    % パルス幅 50ms を確保
    pause(0.05);

    % 0V に戻す（パルス終了）
    write(dq, 0);

    disp('【sendQTMTrigger】トリガ送信完了（QTMが20ms後に計測開始）。');
end
