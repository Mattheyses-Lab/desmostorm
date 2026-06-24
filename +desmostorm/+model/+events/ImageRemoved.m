classdef (ConstructOnLoad) ImageRemoved < event.EventData
% event data class for ImageRemoved events
    properties
        ImageID string
    end
    methods
        function this = ImageRemoved(imageID)
            this.ImageID = imageID;
        end
    end
end