function [Avr,Var]=AvrAndVar4()
% AvrAndVar4：Average and Variance
% Avr and Ver are respectively
% the average and the variance of a generated vector X.
N=10;
X=1:N;
Avr=sum(X)./N;           % Average
Var=sum(X.^2)./N-Avr.^2; % Variance