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

function peaksData = analyzeROIWidthProfile(I,ROI,config)
%ANALYZEROIWIDTHPROFILE Run peak analysis on the rectified width profile.

linescanData = desmostorm.analysis.profile.measure2D(I, ...
    ROI.CenterX, ...
    ROI.CenterY, ...
    ROI.Width, ...
    ROI.Height, ...
    ROI.RotationAngle, ...
    'Interp','linear');

peaksData = desmostorm.analysis.image.autofit.makePeaksData( ...
    linescanData.WidthProfile(:), ...
    linescanData.WidthDist(:), ...
    config);
end
