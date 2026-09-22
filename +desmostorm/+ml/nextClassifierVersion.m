% DesmoSTORM - MATLAB app for desmosomal plaque protein analysis.
% Copyright (C) 2026 William Dean
%
% This program is free software; you can redistribute it and/or modify it
% under the terms of the GNU General Public License as published by the Free
% Software Foundation; either version 2 of the License, or (at your option)
% any later version.
%
% This program is distributed in the hope that it will be useful, but WITHOUT
% ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
% FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
% details.
%
% You should have received a copy of the GNU General Public License along
% with this program; if not, see <https://www.gnu.org/licenses/>.

function [nextVersion, stem] = nextClassifierVersion(saveDir, baseName)
%NEXTCLASSIFIERVERSION Determine the next available classifier version number.
%
% Example:
%   classifier_myModel_v001.mat
%   classifier_myModel_v002.mat

    arguments
        saveDir {mustBeTextScalar}
        baseName {mustBeTextScalar}
    end
    
    % Normalize user-entered names to filename-safe stems while preserving the
    % readable base name as much as MATLAB allows.
    stem = matlab.lang.makeValidName(string(baseName), 'ReplacementStyle', 'delete');
    stem = regexprep(stem, "^x", ""); % optional cleanup if makeValidName prepends x
    if strlength(stem) == 0
        error("nextClassifierVersion:BadBaseName", "Base name must contain at least one valid character.");
    end
    
    % Scan existing packages for numeric version suffixes and append one.
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
