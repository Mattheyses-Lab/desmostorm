function T = mergePatchTables(Told, Tnew, opts)
%mergePatchTables Merge old and new patch tables, with new rows taking precedence.
%
% Duplicate identity is based on:
%   imageFilename + centerX + centerY
%
% If the same patch appears in both tables, the row in Tnew wins.

    arguments
        Told table
        Tnew table
        opts.CenterPrecision (1,1) double {mustBePositive} = 3
    end
    
    if isempty(Told)
        T = Tnew;
        return
    end
    if isempty(Tnew)
        T = Told;
        return
    end
    
    % Ensure common required vars exist
    req = ["imageFilename","centerX","centerY","label"];
    for v = req
        if ~ismember(v, string(Told.Properties.VariableNames))
            error("mergePatchTables:MissingVar", "Told is missing variable '%s'.", v);
        end
        if ~ismember(v, string(Tnew.Properties.VariableNames))
            error("mergePatchTables:MissingVar", "Tnew is missing variable '%s'.", v);
        end
    end
    
    % Normalize types
    Told.imageFilename = string(Told.imageFilename);
    Tnew.imageFilename = string(Tnew.imageFilename);
    
    if ~iscategorical(Told.label), Told.label = categorical(Told.label); end
    if ~iscategorical(Tnew.label), Tnew.label = categorical(Tnew.label); end
    
    % Union categories
    allCats = union(categories(Told.label), categories(Tnew.label));
    Told.label = categorical(string(Told.label), allCats);
    Tnew.label = categorical(string(Tnew.label), allCats);
    
    % Add missing columns as empty/NaN if needed so vertical concat works cleanly
    allVars = union(string(Told.Properties.VariableNames), string(Tnew.Properties.VariableNames));
    
    for v = allVars
        if ~ismember(v, string(Told.Properties.VariableNames))
            Told.(v) = defaultColumnLike(Tnew.(v), height(Told));
        end
        if ~ismember(v, string(Tnew.Properties.VariableNames))
            Tnew.(v) = defaultColumnLike(Told.(v), height(Tnew));
        end
    end
    
    % Match column order
    Tnew = Tnew(:, Told.Properties.VariableNames);
    
    % Build keys
    oldKey = makePatchKeys(Told, opts.CenterPrecision);
    newKey = makePatchKeys(Tnew, opts.CenterPrecision);
    
    % Remove old rows that are overridden by new rows
    keepOld = ~ismember(oldKey, newKey);
    T = [Told(keepOld,:); Tnew];
    
end

function key = makePatchKeys(T, prec)
    fmt = "%." + string(prec) + "f";
    n = height(T);
    key = strings(n,1);
    
    for i = 1:n
        key(i) = T.imageFilename(i) + "|" + ...
            compose(fmt, T.centerX(i)) + "|" + ...
            compose(fmt, T.centerY(i));
    end
end

function col = defaultColumnLike(exampleCol, n)
    if isstring(exampleCol)
        col = strings(n,1);
    elseif iscategorical(exampleCol)
        col = categorical(strings(n,1), categories(exampleCol));
    elseif isnumeric(exampleCol)
        col = nan(n, size(exampleCol,2));
    elseif islogical(exampleCol)
        col = false(n, size(exampleCol,2));
    else
        col = cell(n,1);
    end
end