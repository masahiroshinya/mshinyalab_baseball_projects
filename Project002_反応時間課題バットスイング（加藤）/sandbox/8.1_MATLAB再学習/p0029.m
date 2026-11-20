T0=clock;
while etime(clock,T0)<5
    X=fix(rand.*10000);
    if X==2010
        X, break
    end
end
