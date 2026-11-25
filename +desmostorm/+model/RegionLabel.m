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

classdef RegionLabel < handle
%RegionLabel  Defines a user label (name/hotkey/color) for region annotation.

    properties
        % Stable identifier used to look up this record.
        ID (1,1) string = ""
        % Display name shown in the application.
        Name (1,1) string = ""
        % Keyboard shortcut used to select this label.
        Hotkey (1,1) string = ""   % e.g. "1", "a", "q"
        % RGB color for.
        Color (1,3) double = [1 1 1]
        % Time when this record was created.
        CreatedAt datetime = datetime('now')
    end

    methods
        function obj = RegionLabel(name, opts)
        %REGIONLABEL Initialize a named label with a color and optional shortcut.
            arguments
                name (1,1) string = ""
                opts.ID (1,1) string = ""
                opts.Hotkey (1,1) string = ""
                opts.Color (1,3) double = [1 1 1]
            end

            obj.Name = name;

            if strlength(opts.ID) > 0
                obj.ID = opts.ID;
            else
                obj.ID = matlabx.utils.text.uniqueID();
            end

            obj.Hotkey = lower(string(opts.Hotkey));
            obj.Color  = opts.Color;
        end

        function tf = hasHotkey(obj)
        %HASHOTKEY Check whether hotkey is present.
            tf = strlength(obj.Hotkey) > 0;
        end
    end

end