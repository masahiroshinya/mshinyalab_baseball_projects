A=[1 2 3 4; 5 6 7 8; 9 10 11 12];
S=0;
for I=1:3
    for J=1:4
        S=S+A(I,J);
    end
end
S