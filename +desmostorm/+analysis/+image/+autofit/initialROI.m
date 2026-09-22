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

function ROI = initialROI(H,W,opts)
%INITIALROI Build the centered starting ROI used for angle scoring.
%
% The default fraction keeps the square ROI large enough to contain typical
% plaque pairs while leaving room for a full rotation inside the region crop.

arguments
    H (1,1) double {mustBePositive}
    W (1,1) double {mustBePositive}
    opts.SizeFraction (1,1) double {mustBeGreaterThan(opts.SizeFraction,0),mustBeLessThanOrEqual(opts.SizeFraction,1)} = 0.70
end

side = opts.SizeFraction * min(H,W);

ROI = struct();
ROI.Height = side;
ROI.Width = side;
ROI.CenterX = (W / 2) + 0.5;
ROI.CenterY = (H / 2) + 0.5;
ROI.RotationAngle = 0;
end
