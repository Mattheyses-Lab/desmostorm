function pkg = loadClassifierPackage(filename)
%loadClassifierPackage Load classifier package from MAT-file.

    arguments
        filename {mustBeTextScalar}
    end
    
    S = load(filename, 'ClassifierPackage');
    
    if ~isfield(S, 'ClassifierPackage')
        error("loadClassifierPackage:MissingVariable", ...
            "File does not contain variable 'ClassifierPackage'.");
    end
    
    pkg = S.ClassifierPackage;
    
end