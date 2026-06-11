classdef (ConstructOnLoad) ImageAdded < event.EventData
% event data class for ImageAdded events
    properties
        ImageID string
    end
    methods
        function this = ImageAdded(imageID)
            this.ImageID = imageID;
        end
    end
end