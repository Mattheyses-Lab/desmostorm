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

function launch()
%LAUNCH  Launches the desmostorm GUI

    % --- perform setup actions if necessary ---

    requiredVersion = desmostorm.Info.RequiredSetupVersion;
    currentVersion = desmostorm.Preferences.get("SetupVersion","0.0.0");
    
    if desmostorm.Version.compare(currentVersion,requiredVersion) < 0
        desmostorm.setup.run();
        desmostorm.Preferences.set("SetupVersion",requiredVersion);
    end

    % Reuse the existing app window if DesmoSTORM is already open.
    if desmostorm.app.hasMainFigure()
        desmostorm.app.focusMainFigure();
        return
    end

    % start the GUI
    desmostorm.app.GUI;

end
