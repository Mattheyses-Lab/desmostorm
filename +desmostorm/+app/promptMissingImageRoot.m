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

function searchRoot = promptMissingImageRoot(missingNames, projectFolder)
%PROMPTMISSINGIMAGEROOT Ask the user where missing project images live.

arguments
    missingNames (:,1) string
    projectFolder (1,1) string = ""
end

searchRoot = "";
fig = desmostorm.app.focusMainFigure();

if isempty(fig)
    return
end

msg = "Locate missing image files (" + numel(missingNames) + " missing):";
desmostorm.Log.WARN(msg);
for i = 1:numel(missingNames)
    desmostorm.Log.WARN("Missing image file: " + missingNames(i));
end

selection = uiconfirm(fig, ...
    [msg; ""; missingNames], ...
    'Image files missing', ...
    "Options", ["Locate", "Cancel"], ...
    "DefaultOption", 1, ...
    "CancelOption", 2, ...
    "Icon", "warning");

switch selection
    case "Locate"
        wasVisible = fig.Visible;
        fig.Visible = "off";
        cleanupFig = onCleanup(@() restoreFigureVisibility(fig, wasVisible));
        selectedRoot = uigetdir(projectFolder, msg);
    otherwise
        return
end

if isequal(selectedRoot, 0)
    return
end

searchRoot = string(selectedRoot);

end

function restoreFigureVisibility(fig, visibleState)
    if ~isempty(fig) && isvalid(fig)
        fig.Visible = visibleState;
        desmostorm.app.focusMainFigure();
    end
end
