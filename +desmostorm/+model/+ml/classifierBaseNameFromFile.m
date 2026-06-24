function stem = classifierBaseNameFromFile(classifierFile)
%classifierBaseNameFromFile Extract base model name from classifier filename.
%
% classifier_myModel_v003.mat -> myModel

    arguments
        classifierFile {mustBeTextScalar}
    end
    
    [~, name, ~] = fileparts(string(classifierFile));
    
    tok = regexp(name, "^classifier_(.+)_v\d+$", "tokens", "once");
    if isempty(tok)
        error("classifierBaseNameFromFile:BadName", ...
            "Classifier file name does not match expected pattern: %s", name);
    end
    
    stem = string(tok{1});
    
end