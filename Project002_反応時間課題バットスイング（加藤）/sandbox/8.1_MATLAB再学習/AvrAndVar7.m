function [Avr,Var]=AvrAndVar7(varargin)
% AvrAndVar7 Average and Variance of X1,X2,...
% Avr And Var are respectively
% the average and the variance of a given vectors X1,X2,...
Z=[];
for I=1:length(varargin)
    Z=[Z varargin{I}];
end
N=length(Z);
Avr=sum(Z)./N;           % Average
Var=sum(Z.^2)./N-Avr.^2; % Variance