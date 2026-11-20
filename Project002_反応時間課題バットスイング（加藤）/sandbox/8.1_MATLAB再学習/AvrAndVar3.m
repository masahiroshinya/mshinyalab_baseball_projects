function AvrAndVar3(X)
% AvrAndVar2：Average and Variance of a vector X
% Display Avr and Var of a given vector X.
N=length(X);
Avr=sum(X)./N;           % Average
Var=sum(X.^2)./N-Avr.^2; % Variance
S=sprintf('Average=%6.3f Variance=%6.3f', Avr,Var);
disp(S);