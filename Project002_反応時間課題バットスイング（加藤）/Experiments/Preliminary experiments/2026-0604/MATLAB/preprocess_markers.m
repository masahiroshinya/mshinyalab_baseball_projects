% ---- 1試行分のマーカーをフィルタして返すローカル関数（スクリプト末尾に配置）----
% ※ MATLABのスクリプト内ローカル関数として定義する（R2016b以降）
function M = preprocess_markers(Data, fc)
fs = Data.FrameRate ;
[b, a] = butter(2, fc/(fs/2)) ;

% NaN補間（filtfiltの前に必須）
fields = fieldnames(Data.Markers) ;
for i = 1:numel(fields)
    x = Data.Markers.(fields{i}) ;
    t = (1:size(x,1))' ;
    for col = 1:size(x,2)
        nanIdx = isnan(x(:,col)) ;
        if any(nanIdx) && any(~nanIdx)
            x(nanIdx,col) = interp1(t(~nanIdx), x(~nanIdx,col), t(nanIdx), 'linear', 'extrap') ;
        end
    end
    Data.Markers.(fields{i}) = x ;
end
M = filt_all_fields(b, a, Data.Markers) ;
end