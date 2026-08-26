function dData = diff3p(data, h)

% diff3p    3点微分法
%
% dData = diff3p(data, h)
%
% 入力
% data: 微分前のデータ、縦方向が時系列となる2D array
% h:    サンプリング間隔（s）
%
% 出力
% dData: 微分後のデータ
%
% 参考：バイオメカニクス20講 pp. 166
% （2017-05-09, 進矢）


n = size(data,1) ;
dData(1,:) = (1/(2*h)) * (-3*data(1,:) + 4*data(2,:) - 1*data(3,:)) ;
dData(2:n-1,:) = (1/(2*h)) * (-data(1:n-2,:) + data(3:n,:)) ;
dData(n,:) = (1/(2*h)) * (1*data(n-2,:) - 4*data(n-1,:) + 3*data(n,:)) ;


