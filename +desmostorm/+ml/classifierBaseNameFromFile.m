function stem = classifierBaseNameFromFile(classifierFile)
%CLASSIFIERBASENAMEFROMFILE Extract the base model name from a package file.
%
% Classifier packages are versioned as classifier_<base>_v###.mat. Continued
% training uses this helper to keep writing new versions under the same base
% name.
%
% Example
% -------
%   classifier_myModel_v003.mat -> myModel

    arguments
        classifierFile {mustBeTextScalar}
    end
    
    [~, name, ~] = fileparts(string(classifierFile));
    
    % Require the expected package naming convention so versioning stays
    % predictable and accidental input files fail early.
    tok = regexp(name, "^classifier_(.+)_v\d+$", "tokens", "once");
    if isempty(tok)
        error("classifierBaseNameFromFile:BadName", ...
            "Classifier file name does not match expected pattern: %s", name);
    end
    
    stem = string(tok{1});
    
end
