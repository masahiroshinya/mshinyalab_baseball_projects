close all
clear

y = rand(10,1) ;

figure(2)
plot(y,'r') 

figHandle = figure(3)
axHandle = axes ;
h = plot(y)
hold on

[a,b] = max(y)

h2 = plot(b,a, 'bo')

yline(a)
xline(b)


