function scale = physicalStyleScale(screenInches,sizeValue,units,resolution,preserveAspectRatio)
%PHYSICALSTYLESCALE Compensate the rendered style for output scaling.
    ratio = desmostorm.export.outputSizeInches(sizeValue,units,resolution) ./ screenInches;
    if preserveAspectRatio == "on"
        scale = 1 / min(ratio);
    else
        scale = 1 / sqrt(prod(ratio));
    end
end
