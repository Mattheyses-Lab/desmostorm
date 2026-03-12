function saveClassifierPackage(filename, pkg)
%saveClassifierPackage Save classifier package to MAT-file.

    arguments
        filename {mustBeTextScalar}
        pkg struct
    end
    
    ClassifierPackage = pkg;
    save(filename, 'ClassifierPackage', '-v7.3');

end