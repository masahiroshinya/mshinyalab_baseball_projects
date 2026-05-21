function Data_filt = filt_all_fields(b,a,Data)

% filt_all_fields
%
% filt_all_fields(b,a,Data)  applies filtfilt(b,a,Xi)  
%   where Data is a structure which has fields of X1, X2,..., Xi,... Xn
%     and b & a are the filter parameters.    
% 
% Data may be Markers structure or Force structure obtained by using Qualysis
%
% Example:
% fc = 10 ; fs = 100 ; order = 2 ;
% [b,a] = butter(order, fc/(fs/2), 'low') ;
% Markers_filt = filt_all_fields(b,a,Markers) ;
%
% Last edited by SHINYA, 2017-08-02

%%
Data_filt = Data ;
Fields = fieldnames(Data) ;
nFields = length(Fields) ;
for iField = 1:nFields
    field = Fields{iField} ;
    Data_filt.(field) = filtfilt(b, a, Data.(field)) ;
end




