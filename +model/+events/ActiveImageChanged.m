classdef (ConstructOnLoad) ActiveImageChanged < event.EventData
% event data class for ActiveImageChanged events
    properties
        NewID string
        OldID string
    end
    methods
        function this = ActiveImageChanged(newID,oldID)
            this.NewID = newID;
            this.OldID = oldID;
        end
    end
end