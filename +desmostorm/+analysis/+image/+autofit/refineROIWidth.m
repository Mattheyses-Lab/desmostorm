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
