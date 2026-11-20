T0=clock;
N=0;
while etime(clock,T0)<5
    X=fix(rand.*10000);
    if X~=2010
        continue
    else
        N=N+1;
    end
end
N