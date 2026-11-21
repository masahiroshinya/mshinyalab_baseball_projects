N=10;
X=1:10;
Y=2.*X;
Z=3.*X;
[Avr Var]=AvrAndVar7(X);
Avr,Var
[Avr Var]=AvrAndVar7(X,Y);
Avr,Var
[Avr,Var]=AvrAndVar7(X,Y,Z);
Avr,Var