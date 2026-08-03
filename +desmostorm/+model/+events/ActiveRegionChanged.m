classdef (ConstructOnLoad) ActiveRegionChanged < event.EventData
%ACTIVEREGIONCHANGED Event data for active-region transitions.

    properties
        ImageID string
        NewID string
        OldID string
    end

    methods
        function this = ActiveRegionChanged(imageID, newID, oldID)
            this.ImageID = string(imageID);
            this.NewID = string(newID);
            this.OldID = string(oldID);
        end
    end

end
