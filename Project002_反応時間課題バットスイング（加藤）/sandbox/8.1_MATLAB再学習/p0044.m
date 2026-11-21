X=0:pi./100:2.*pi;
Y1=sin(X);
Y2=sin(2.*X);
Y3=sin(4.*X);
plot(X,Y1);
hold on
plot(X,Y2);
plot(X,Y3);
hold off