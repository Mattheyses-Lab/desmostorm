classdef RegionLabel < handle
%RegionLabel  Defines a user label (name/hotkey/color) for region annotation.

    properties
        ID (1,1) string = ""
        Name (1,1) string = ""
        Hotkey (1,1) string = ""   % e.g. "1", "a", "q"
        Color (1,3) double = [1 1 1]
    end

    properties (SetAccess=private)
        CreatedAt datetime = datetime('now')
    end

    methods
        function obj = RegionLabel(name, opts)
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
                obj.ID = utils.uniqueID();
            end

            obj.Hotkey = lower(string(opts.Hotkey));
            obj.Color  = opts.Color;
        end

        function tf = hasHotkey(obj)
            tf = strlength(obj.Hotkey) > 0;
        end
    end

end