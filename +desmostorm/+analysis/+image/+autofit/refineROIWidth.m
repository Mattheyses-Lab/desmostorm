function [ROI,info] = refineROIWidth(I,ROI,config)
%REFINEROIWIDTH Fit left/right ROI edges from the rectified width profile.

info = struct( ...
    "Succeeded",false, ...
    "LeftMinIdx",NaN, ...
    "RightMinIdx",NaN, ...
    "Method","profile-bounds");

peaksData = desmostorm.analysis.image.autofit.analyzeROIWidthProfile(I,ROI,config);
if peaksData.nPeaks == 0
    return
end

X = peaksData.Location;
[leftMinIdx,rightMinIdx,bounds] = ...
    desmostorm.analysis.image.autofit.findProfileObjectBounds( ...
    peaksData,"Mode","allpeaks");

dWLeft = X(1) - X(leftMinIdx);
ROI = desmostorm.analysis.image.autofit.shiftLeftEdge(ROI,dWLeft);

dWRight = X(rightMinIdx) - X(end);
ROI = desmostorm.analysis.image.autofit.shiftRightEdge(ROI,dWRight);

info.Succeeded = true;
info.LeftMinIdx = leftMinIdx;
info.RightMinIdx = rightMinIdx;
info.Bounds = bounds;
end
