function Out=AvrAndVar(X)
% AvrAndVar：Average and Variance of a vector X
% Out=[Avr Var]; Avr and Var are respectively
% the average and the variance of a given vector X.
N=length(X);
Avr=sum(X)./N;           % Average
Var=sum(X.^2)./N-Avr.^2; % Variance
Out=[Avr Var];
