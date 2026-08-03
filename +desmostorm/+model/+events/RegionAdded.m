classdef (ConstructOnLoad) RegionAdded < event.EventData
%REGIONADDED Event data for region creation.

    properties
        ImageID string
        RegionID string
        RegionName string
    end

    methods
        function this = RegionAdded(imageID, regionID, regionName)
            this.ImageID = string(imageID);
            this.RegionID = string(regionID);
            this.RegionName = string(regionName);
        end
    end

end
