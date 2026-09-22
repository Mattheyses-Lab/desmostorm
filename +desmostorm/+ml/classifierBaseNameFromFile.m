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
