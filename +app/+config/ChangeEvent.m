classdef (ConstructOnLoad) ChangeEvent < event.EventData
% event data class for settings changed events
    properties
        Domain   string   % "Analysis" | "Display" | "IO"
        Name     string   % e.g., "BoxSize", "ColormapName"
        OldValue
        NewValue
    end
    methods
        function this = ChangeEvent(domain, name, oldv, newv)
            this.Domain = string(domain);
            this.Name   = string(name);
            this.OldValue = oldv;
            this.NewValue = newv;
        end
    end
end