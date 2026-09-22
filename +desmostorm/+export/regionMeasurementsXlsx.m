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

function regionMeasurementsXlsx(project, filename, opts)
%REGIONMEASUREMENTSXLSX Export project region measurements to XLSX.

arguments
    project (1,1) desmostorm.model.STORMProject
    filename {mustBeTextScalar}
    opts.ProgressDialog = matlab.ui.dialog.ProgressDialog.empty()
end

setProgressMessage(opts.ProgressDialog,'Building region measurement table...');
T = desmostorm.export.regionTable(project);

if isempty(T)
    warning('No regions to export.');
    return
end

desc = cellfun(@desmostorm.utils.formatColumnName, ...
    T.Properties.VariableNames, 'UniformOutput', false);
T.Properties.VariableNames = desc;

setProgressMessage(opts.ProgressDialog,'Writing region measurement file...');
writetable(T, filename, ...
    'WriteMode', 'replacefile', ...
    'WriteVariableNames', true);

end

function setProgressMessage(h,msg)
    if ~isempty(h) && isvalid(h)
        h.Message = msg;
        drawnow limitrate
    end
end
