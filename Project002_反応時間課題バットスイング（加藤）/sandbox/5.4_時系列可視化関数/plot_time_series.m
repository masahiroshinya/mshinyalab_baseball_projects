function H = plot_time_series(Ax, Signal, 0pt)

% plot_time_series  時系列波形に、イベント縦線と閾値横線を重ねて描く
%
%   H = plot_time_series(Ax, Signal, Opt)
%
%   Ax     : 描画先の axes。[] を渡すと gca
%
%   Signal : 構造体配列。1要素が1本の波形（複数渡すと重ね描き）
%     .t     [n×1] 時刻 [s]。time_from_cue で作る
%     .y     [n×1] 値
%     .Name  凡例名（省略・空なら凡例に出さない）
%     .Style plot に渡すプロパティのセル配列（例 {'Color','b','LineWidth',1.2}）
%
%   Opt    : 構造体（省略可。各フィールドも個別に省略可）
%     .Event  構造体配列。縦線
%       .t     [s] 位置。NaN の要素は描かない（要件 R5）
%       .Name  凡例名
%       .Style lineplot に渡すプロパティ（例 {'k--','LineWidth',1.5}）
%     .Level  構造体配列。横線（閾値）
%       .y     値。NaN の要素は描かない
%       .Name  凡例名
%       .Style lineplot に渡すプロパティ
%     .XLim / .YLim / .XLabel / .YLabel / .Title / .Legend
%
%   H : 描いたグラフィックスハンドルをまとめた構造体（.Signal / .Event / .Level）
%
%   ※ 波形は全体を渡すこと。表示範囲は Opt.XLim で決める。
%     呼び出し側で切り出すと、データ長の足りない試行が図から消える（技術説明 §3.3）。

% ---- 引数の既定値 ----
if isempty(Ax), Ax = gca ; end
if nargin < 3 || isempty(0pt), 0pt = struct() ; end

% ---- 波形 ----
% 縦線・横線を先に引くと YLim が確定していないため、必ず波形が先。
% 実装メモ：lineplot は呼び出し時点の XLim / YLim を読んで線を引くので、
%           波形→軸範囲の設定→縦線・横線 の順序を守ること。

% ---- 軸範囲（縦線・横線より先に確定させる）----

% ---- 縦線（イベント）----
%   NaN はスキップする。検出に失敗した試行でも図自体は描けるようにするため。

% ---- 横線（閾値）----

% ---- ラベル・凡例・グリッド ----

end