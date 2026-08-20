function plot_rt_detection(Data, Result, 0pt)

% plot_rt_detection  1試行の RT 検出結果を3段のパネルで描く
%
%   上段：手部の投手方向速度（Nasu 方式）
%         波形 VelHandX ／ 閾値線 Result.ThrVelHandX ／ 縦線 SwingOnsetHand・TPeakVelHandX
%   中段：後ろ足の鉛直床反力（床反力方式）
%         波形 Fz1Filt ／ 閾値線 Fz1BaseMean ± FzK*Fz1BaseSD（上下2本）
%         ／ 縦線 SwingOnsetForce
%   下段：LED 信号（ch1 = ready, ch2 = cue）
%
%   3段とも横軸はキューを 0 とする秒で共通。linkaxes で連動させる。
%
%   Nasu 方式の閾値は Result.ThrVelHandX から読む（段取り STEP 1-3 案B）。
%   全試行から算出する量だが、x4 が全要素に同じ値を入れているため
%   1試行分の Result だけで閾値線を引ける。引数で受け渡す必要はない。