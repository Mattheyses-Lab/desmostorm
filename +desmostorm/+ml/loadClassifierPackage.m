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
    
end
