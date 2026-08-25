function pkg = loadClassifierPackage(filename)
%LOADCLASSIFIERPACKAGE Load a desmostorm classifier package MAT-file.
%
% Packages are saved as a single variable named ClassifierPackage. Keeping that
% variable name fixed makes it possible to validate user-selected MAT-files
% before downstream code assumes network/package fields exist.

    arguments
        filename {mustBeTextScalar}
    end
    
    % Load only the expected variable so large MAT-files do not pull unrelated
    % data into memory.
    S = load(filename, 'ClassifierPackage');
    
    if ~isfield(S, 'ClassifierPackage')
        error("loadClassifierPackage:MissingVariable", ...
            "File does not contain variable 'ClassifierPackage'.");
    end
    
    pkg = S.ClassifierPackage;

    % If the package includes materialized patches, attach the patch root to
    % table metadata so patchDatastore can resolve relative patch filenames in
    % future package formats. Current packages store absolute patch filenames,
    % so this is mostly a compatibility hook.
    if isfield(pkg,"PatchStore") && isstruct(pkg.PatchStore) && ...
            isfield(pkg.PatchStore,"Root") && isfield(pkg,"PatchTable") && ...
            istable(pkg.PatchTable)
        pkg.PatchTable.Properties.UserData.PatchRoot = string(pkg.PatchStore.Root);
    end
    
end
