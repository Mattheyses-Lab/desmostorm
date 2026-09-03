function [ROI,info] = refineROIHeight(I,ROI,config)
%REFINEROIHEIGHT Fit top/bottom ROI edges around the central peak pair.

info = struct( ...
    "Succeeded",false, ...
    "LeftMinIdx",NaN, ...
    "RightMinIdx",NaN, ...
    "Method","central-peak-pair-bounds");

peaksData = desmostorm.analysis.image.autofit.analyzeROIHeightProfile( ...
    I,ROI,config,ROI.RotationAngle);
if ~peaksData.hasCentralPeakPair
    return
end

X = peaksData.Location;
[leftMinIdx,rightMinIdx,bounds] = ...
    desmostorm.analysis.image.autofit.findProfileObjectBounds( ...
    peaksData,"Mode","centralpair");

dHTop = X(1) - X(leftMinIdx);
ROI = desmostorm.analysis.image.autofit.shiftTopEdge(ROI,dHTop);

dHBottom = X(rightMinIdx) - X(end);
ROI = desmostorm.analysis.image.autofit.shiftBottomEdge(ROI,dHBottom);

info.Succeeded = true;
info.LeftMinIdx = leftMinIdx;
info.RightMinIdx = rightMinIdx;
info.Bounds = bounds;
end
