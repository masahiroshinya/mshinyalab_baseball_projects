function [Avr,Var]=AvrAndVar6(X,Y)
% AvrAndVar6 Average and Variance of X or [X Y]
% Avr and Var are respectively
% the average and the variance of a given vector X or [X Y].
if nargin==1
    N=length(X);
    Z=X;
else
    N=length(X)+length(Y);
    Z=[X Y];
end
Avr=sum(Z)./N;           % Average
Var=sum(Z.^2)./N-Avr.^2; % Variance