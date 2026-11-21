X=1:5;
Y=[X;X.^2]
Fid=fopen('p0057.txt','wt');
fprintf(Fid,'%2d%5d\n',Y);
fclose(Fid);
