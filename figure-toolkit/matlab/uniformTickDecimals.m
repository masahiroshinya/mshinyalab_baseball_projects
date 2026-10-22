function nDecimals = uniformTickDecimals(ruler)
% 目盛りの値に小数があるとき、全目盛りの小数点以下の桁数を揃える（例：0, 0.5, 1 → 0.0, 0.5, 1.0）
%
% 右揃えの縦軸の目盛りで小数点の位置を揃えるため。目盛りの文字を手で指定している場合（TickLabelsMode が manual）は変えない。
% 入力：ruler ... 軸のルーラー（例：ax.YAxis）
% 出力：nDecimals ... 揃えた小数点以下の桁数（小数がなければ 0 で、書式は変えない）

nDecimals = 0 ;
if strcmp(ruler.TickLabelsMode, 'manual')
    return
end
maxDecimals = 6 ; % 調べる桁数の上限
for value = ruler.TickValues
    for iDecimal = 0:maxDecimals
        scaled = value*10^iDecimal ;
        if abs(scaled - round(scaled)) < 1e-9*max(1, abs(scaled))
            break
        end
    end
    nDecimals = max(nDecimals, iDecimal) ;
end
if nDecimals > 0
    ruler.TickLabelFormat = sprintf('%%.%df', nDecimals) ;
end
end
