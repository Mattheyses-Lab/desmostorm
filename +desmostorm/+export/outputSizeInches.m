function inches = outputSizeInches(sizeValue,units,resolution)
%OUTPUTSIZEINCHES Convert export dimensions to physical dimensions.
    switch string(units)
        case "inches"
            inches = sizeValue;
        case "centimeters"
            inches = sizeValue / 2.54;
        case "points"
            inches = sizeValue / 72;
        case "pixels"
            inches = sizeValue / resolution;
    end
end
