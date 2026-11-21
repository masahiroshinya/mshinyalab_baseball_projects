X=0:pi./100:2.*pi;
plot(X,sin(X),'-');
hold on
plot(X,0.8.*sin(X),':');
plot(X,0.6.*sin(X),'--');
plot(X,0.4.*sin(X),'-.');
hold off