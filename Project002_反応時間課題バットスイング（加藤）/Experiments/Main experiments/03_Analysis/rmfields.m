function s = rmfields(s, FieldArray)

% rmfields - 構造体フィールドの一括削除
%
% この MATLAB 関数 は、指定したフィールドを構造体配列 s から削除します。
% 
% 例.
% FieldArray = {'Name', 'Height', 'Weight'} ;
% s = rmfield(s, FieldArray)
%
% 2017-10-23 SHINYA


nField = length(FieldArray) ;
for iField = 1:nField
    s = rmfield(s, FieldArray{iField}) ;
end
