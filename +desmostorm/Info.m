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

classdef Info
    properties (Constant)
        Name    string = "desmostorm"   % name of the app
        Version string = "1.1.1"        % application version, major.minor.patch

        % Setup version is intentionally separate from app version. Bump this
        % only when launch should rerun setup work such as path setup, matlabx
        % setup, UI calibration, or preference/settings migration checks.
        RequiredSetupVersion string = "1.1.0"

        % Settings schema version describes the shape/meaning of saved settings
        % files. Schema migration should preserve user intent whenever possible:
        % add missing fields, rename old fields, or normalize old layouts.
        SettingsSchemaVersion string = "1.1.0"

        % Factory defaults version describes the generation of default app
        % settings. Bump this when early-development defaults should be pushed
        % into the app-level settings file. This is more opinionated than schema
        % migration and is not applied to settings embedded in project files.
        FactoryDefaultsVersion string = "1.1.0"
    end
end
