X=0:pi./100:2.*pi;

Y1=sin(X);
subplot(2,3,1);
plot(X,Y1);

Y2=sin(2.*X);
subplot(2,3,3);
plot(X,Y2);

Y3=sin(3.*X);
subplot(2,3,5);
plot(X,Y3);

Y4=sin(4.*X);
subplot(2,3,6);
plot(X,Y4);