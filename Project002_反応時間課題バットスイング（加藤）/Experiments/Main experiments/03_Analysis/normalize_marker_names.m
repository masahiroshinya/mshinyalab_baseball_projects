function Markers = normalize_marker_names(Markers)

% normalize_marker_names
%
% QTM 側のラベル揺れを吸収し、マーカー名を全被験者で統一する。
%
% 背景:
%   S01・S02 の計測では手部マーカーが Firtst / Second / Third というラベルで
%   記録されている（Firtst は First の綴りミス）。S03 以降の計測でラベルが
%   first / second / third に修正されたため、被験者間で名前が食い違っている。
%   MATLAB の構造体フィールドは大文字小文字を区別するので、そのままでは
%   下流の解析（parameters.m の HandMarkerNames）が片方でしか動かない。
%
%   命名の統一先は小文字とする。綴りが正しく、バットのマーカー（top, knob,
%   grip, barrel, bottom）とも表記が揃うため。
%
% 入力:
%   Markers ... load_qualisys_mat が返す Markers 構造体
%               （フィールド名 = マーカー名、値 = [nFrame x 3] の座標）
% 出力:
%   Markers ... 名前を統一した Markers 構造体
%
% 備考:
%   欠けているマーカーは何もせず素通りさせる。マーカーが揃っていない試行が
%   あるのは既知（骨盤4点は 300 試行中 232 試行しか揃っていない）で、
%   その扱いは m3 側で判定する。ここでは名前だけを面倒を見る。

% 旧ラベル（統一前） → 新ラベル（統一後）
AliasArray = { ...
    'Firtst', 'first'  ; ...
    'Second', 'second' ; ...
    'Third',  'third'  } ;

for iAlias = 1:size(AliasArray, 1)

    oldName = AliasArray{iAlias, 1} ;
    newName = AliasArray{iAlias, 2} ;

    if ~isfield(Markers, oldName)
        continue
    end

    % 両方あるのは想定外。黙って上書きすると原因不明の解析結果になるため止める。
    if isfield(Markers, newName)
        error('normalize_marker_names:DuplicateLabel', ...
            'マーカー %s と %s が同じ試行に存在します。QTM 側のラベルを確認してください。', ...
            oldName, newName) ;
    end

    Markers.(newName) = Markers.(oldName) ;
    Markers = rmfield(Markers, oldName) ;

end

end
