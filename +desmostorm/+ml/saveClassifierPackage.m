function saveClassifierPackage(filename, pkg)
%SAVECLASSIFIERPACKAGE Save a classifier package as a MAT-file.

    arguments
        filename {mustBeTextScalar}
        pkg struct
    end
    
    % Use a fixed variable name so loadClassifierPackage can validate files
    % without relying on arbitrary workspace variable names.
    ClassifierPackage = pkg;
    save(filename, 'ClassifierPackage', '-v7.3');

end
