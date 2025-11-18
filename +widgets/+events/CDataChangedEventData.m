classdef (ConstructOnLoad) CDataChangedEventData < event.EventData
    % event.EventData subclass used by widgets.ImageAxes to deliver CDataChanged event payload to widgets.tools obects

    properties
        oldCData
        newCData
    end

    methods
        function data = CDataChangedEventData(oldCData,newCData)
            data.oldCData = oldCData;
            data.newCData = newCData;
        end
    end

end