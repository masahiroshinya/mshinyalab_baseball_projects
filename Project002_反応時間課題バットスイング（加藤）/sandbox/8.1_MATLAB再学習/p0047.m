X=0:pi/100:2*pi;
plot(X,sin(X),X,sin(2.*X))
title('sin(X) and sin(2X)');
xlabel('x')
ylabel('y')

text(2.5,0.7,'y=sin(x)')
text(1.8,0,'y=sin(2x)')