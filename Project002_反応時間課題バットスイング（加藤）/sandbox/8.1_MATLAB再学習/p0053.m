X=0:pi./100:2.*pi;
plot(X,sin(X),'LineWidth',3);
hold on
plot(X,sin(2.*X),'LineWidth',6);
hold off