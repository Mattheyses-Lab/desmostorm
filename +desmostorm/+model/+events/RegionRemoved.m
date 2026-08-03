classdef (ConstructOnLoad) RegionRemoved < event.EventData
%REGIONREMOVED Event data for region deletion.

    properties
        ImageID string
        RegionID string
        RegionName string
    end

    methods
        function this = RegionRemoved(imageID, regionID, regionName)
            this.ImageID = string(imageID);
            this.RegionID = string(regionID);
            this.RegionName = string(regionName);
        end
    end

end
