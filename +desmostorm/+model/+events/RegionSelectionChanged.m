classdef (ConstructOnLoad) RegionSelectionChanged < event.EventData
%REGIONSELECTIONCHANGED Event data for selected-region transitions.

    properties
        ImageID string
        NewIDs (:,1) string
        OldIDs (:,1) string
    end

    methods
        function this = RegionSelectionChanged(imageID, newIDs, oldIDs)
            this.ImageID = string(imageID);
            this.NewIDs = string(newIDs(:));
            this.OldIDs = string(oldIDs(:));
        end
    end

end
