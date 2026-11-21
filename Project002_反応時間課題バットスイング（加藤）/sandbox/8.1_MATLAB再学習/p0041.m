figure
X=0:pi/100:2*pi;
Y=sin(X);
plot(X,Y)

figure
X=0:pi./100:(2.*pi).^0.5;
Y=sin(X.^2);
plot(X,Y)