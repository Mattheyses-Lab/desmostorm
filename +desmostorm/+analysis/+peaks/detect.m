function out = detect(Y, X, MinPeakDistance, MinPeakHeight)
    arguments
        Y (:,1) double
        X (:,1) double
        MinPeakDistance (1,1) double
        MinPeakHeight (1,1) double
    end
    
    if length(Y) >= MinPeakDistance
        % 4th output is prominence for each peak, may use in future
        [PeakValues,PeakLocations,PeakWidths,~] = findpeaks(...
            Y,X,...
            'MinPeakHeight',MinPeakHeight,...
            'MinPeakDistance',MinPeakDistance,...
            'WidthReference','halfheight',...
            'MinPeakProminence',0.1); % so we do not pick up tiny peaks
    else
        PeakValues = NaN;
        PeakLocations = NaN;
        PeakWidths = NaN;
    end

    % collect output
    out = struct(...
        'PeakValues',       PeakValues, ...
        'PeakLocations',    PeakLocations, ...
        'PeakWidths',       PeakWidths);

end