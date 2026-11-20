function AvrAndVar5
% AvrAndVar：Average and Variance of a vector X
% AVR and VAR are respectively
% the average and the variance of a given vector X.
% Notice that X, AVR and VAR are grobal variables.
global X AVR VAR
N=length(X);
AVR=sum(X)./N;           % Average
VAR=sum(X.^2)./N-AVR.^2; % Variance