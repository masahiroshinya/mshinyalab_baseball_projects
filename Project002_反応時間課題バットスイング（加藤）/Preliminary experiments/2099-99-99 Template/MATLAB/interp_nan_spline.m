function [Data_interp, HasLongNan] = interp_nan_spline(Data, maxNumNans)

% interp_nan_spline
%
% Data_interp = interp_nan_spline(Data, maxNumNans)
%   interpolates consecutive NaN sequences of length <= maxNumNans
%   using spline interpolation.
%   NaN runs longer than maxNumNans, or at the signal edges, are left as NaN.
%
%   Data is a structure where each field is an [nFrames x nDim] matrix,
%   compatible with Markers structures from Qualisys.
%
% Example:
% maxNumNans = 10 ;
% Markers_interp = interp_nan_spline(Markers, maxNumNans) ;
% Markers_filt   = filt_all_fields(b, a, Markers_interp) ;

Data_interp = Data ;
fields = fieldnames(Data) ;

for iField = 1:length(fields)
    hasLongNan  = false ;
    x = Data.(fields{iField}) ;
    [~, nDim] = size(x) ;

    for iDim = 1:nDim
        v = x(:, iDim) ;
        nanIdx   = find(isnan(v)) ;
        knownIdx = find(~isnan(v)) ;

        if isempty(nanIdx) || length(knownIdx) < 2
            continue
        end

        breaks = [0; find(diff(nanIdx) > 1); length(nanIdx)] ;

        for iRun = 1:length(breaks)-1
            runStart = nanIdx(breaks(iRun) + 1) ;
            runEnd   = nanIdx(breaks(iRun+1)) ;
            runLen   = runEnd - runStart + 1 ;

            hasKnownBefore = any(knownIdx < runStart) ;
            hasKnownAfter  = any(knownIdx > runEnd) ;

            if runLen <= maxNumNans && hasKnownBefore && hasKnownAfter
                v(runStart:runEnd) = interp1(knownIdx, v(knownIdx), runStart:runEnd, 'spline') ;
            elseif runLen > maxNumNans
                hasLongNan = true ;
            end
        end

        x(:, iDim) = v ;
    end

    Data_interp.(fields{iField}) = x ;
    HasLongNan.(fields{iField}) = hasLongNan ;
end
