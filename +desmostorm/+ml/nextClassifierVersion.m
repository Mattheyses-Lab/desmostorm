function [nextVersion, stem] = nextClassifierVersion(saveDir, baseName)
%nextClassifierVersion Determine next available version number for a base name.
%
% Example:
%   classifier_myModel_v001.mat
%   classifier_myModel_v002.mat

    arguments
        saveDir {mustBeTextScalar}
        baseName {mustBeTextScalar}
    end
    
    stem = matlab.lang.makeValidName(string(baseName), 'ReplacementStyle', 'delete');
    stem = regexprep(stem, "^x", ""); % optional cleanup if makeValidName prepends x
    if strlength(stem) == 0
        error("nextClassifierVersion:BadBaseName", "Base name must contain at least one valid character.");
    end
    
    files = dir(fullfile(saveDir, sprintf("classifier_%s_v*.mat", stem)));
    
    versions = 0;
    for i = 1:numel(files)
        tok = regexp(files(i).name, "_v(\d+)\.mat$", "tokens", "once");
        if ~isempty(tok)
            versions(end+1) = str2double(tok{1}); %#ok<AGROW>
        end
    end
    
    nextVersion = max(versions) + 1;
end