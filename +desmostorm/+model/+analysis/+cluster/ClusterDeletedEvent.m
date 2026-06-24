classdef (ConstructOnLoad) ClusterDeletedEvent < event.EventData
% event data class for cluster deleted events
    properties
        Index
    end
    methods
        function this = ClusterDeletedEvent(idx)
            this.Index = idx;
        end
    end
end