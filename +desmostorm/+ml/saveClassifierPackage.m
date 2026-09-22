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
