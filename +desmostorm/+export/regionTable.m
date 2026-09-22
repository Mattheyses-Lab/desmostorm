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

function T = regionTable(project)
%REGIONTABLE Build project region measurements table for export.

arguments
    project (1,1) desmostorm.model.STORMProject
end

imgs = project.ImageArray;
if isempty(imgs)
    T = table();
    return
end

parts = arrayfun(@(img) desmostorm.export.imageRegionTable(img), ...
    imgs, 'UniformOutput', false);
parts = parts(~cellfun(@isempty, parts));

if isempty(parts)
    T = table();
else
    T = vertcat(parts{:});
end

end
