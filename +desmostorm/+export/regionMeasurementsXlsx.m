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

desmostorm.runtime.updateProgress(opts.ProgressDialog,'Building region measurement table...');
% Table assembled from the current records.
T = desmostorm.export.regionTable(project);

if isempty(T)
    warning('No regions to export.');
    return
end

desc = cellfun(@desmostorm.utils.formatColumnName, ...
    T.Properties.VariableNames, 'UniformOutput', false);
T.Properties.VariableNames = desc;

desmostorm.runtime.updateProgress(opts.ProgressDialog,'Writing region measurement file...');
writetable(T, filename, ...
    'WriteMode', 'replacefile', ...
    'WriteVariableNames', true);

% Keep the existing measurement headers and identify their project channels.
channels = project.Channels;
indices = "C" + (1:numel(channels)).';
channelNames = reshape(string({channels.Name}),[],1);
channelIDs = reshape(string({channels.ID}),[],1);
writetable(table(indices,channelNames,channelIDs, ...
    'VariableNames',{'Channel','Name','ID'}),filename,'Sheet','Channels');

end
