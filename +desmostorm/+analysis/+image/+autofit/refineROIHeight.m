% DesmoSTORM - MATLAB app for desmosomal plaque protein analysis.
% Copyright (C) 2026 William Dean
%
% This program is free software; you can redistribute it and/or modify it
% under the terms of the GNU General Public License as published by the Free
% Software Foundation; either version 2 of the License, or (at your option)
% any later version.
%
% This program is distributed in the hope that it will be useful, but WITHOUT
% ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
% FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
% details.
%
% You should have received a copy of the GNU General Public License along
% with this program; if not, see <https://www.gnu.org/licenses/>.

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
