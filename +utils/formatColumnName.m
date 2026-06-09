function out = formatColumnName(in)
    % mapping rules
    key_value_pairs = { ...
        'ProjectName',          'Project Name';...
        'ImageName',            'Image Name';...
        'RegionName',           'Region Name';...
        'RegionID',             'Region ID';...
        'PixelSize',            'Pixel Size';...
        'RegionCenter',         'Region Center (x, y)';...
        'RegionWidth_px',       'Region Width (px)';...
        'RegionHeight_px',      'Region Height (px)';...
        'RegionWidth_phys',     'Region Width';...
        'RegionHeight_phys',    'Region Height';...
        'ROICenter',            'ROI Center (x, y)';...
        'ROIWidth_px',          'ROI Width (px)';...
        'ROIHeight_px',         'ROI Height (px)';...
        'ROIWidth_phys',        'ROI Width';...
        'ROIHeight_phys',       'ROI Height';...
        'ROIRotationAngle',     'ROI Rotation Angle (°)'...
        };

    map = containers.Map(key_value_pairs(:,1),key_value_pairs(:,2));

    if isKey(map, in)
        out = map(in);
    else
        % try to auto format
        out = autoFormat(in);
    end


    function str2 = autoFormat(str)

        % Convert underscores into alternating parentheses
        parenOpen = true;
        str2 = strings(1,0);
        
        for k = 1:numel(str)
            if str(k) == '_'
                if parenOpen
                    str2(end+1) = " (";
                else
                    str2(end+1) = ") ";
                end
                parenOpen = ~parenOpen;
            else
                str2(end+1) = string(str(k));
            end
        end
        
        str2 = char(join(str2,""));
        
        % Add spaces between lowercase-to-uppercase transitions
        str2 = regexprep(str2, '([a-z])([A-Z])', '$1 $2');
        
        % Add spaces between letters and numbers in either direction
        str2 = regexprep(str2, '([A-Za-z])([0-9])', '$1 $2');
        str2 = regexprep(str2, '([0-9])([A-Za-z])', '$1 $2');
        
        % Clean up repeated spaces
        str2 = regexprep(str2, '\s+', ' ');
        str2 = strtrim(str2);

    end

end