function t = time_from_cue(idx, idxZero, fs)

% time_from_cue サンプル番号を、基準点を 0 とする時刻 [s] に変換する
%
% t = time_from_cue(idx, idxZero, fs)
%
% idx     : サンプル（またはフレーム）番号。ベクトルでもスカラーでも良い。
% idxZero : 時刻 0 とするサンプル番号（通常はキュー）。
% fs      : idx と idxZero が属する系統のサンプリング関数　[Hz]
% t       : 秒。idx と同じ大きさ。
% 
% ※ idx・idxZero・fs は必ず同じ系統（マーカー系 or アナログ系）で揃えること。
%     マーカーのフレーム番号にアナログの fs を渡すと、4倍ずれた図が
%     エラーを出さずに描かれる（技術説明 §5.3）。
%
%   idxZero が NaN のときは、試行先頭を 0 とする絶対時間を返す。
%   これにより、LED 未検出の試行でも図が描ける（要件 R5）。

if isnan(idxZero)
    idxZero = 1;
end

t = (idx(:) - idxZero / fs);