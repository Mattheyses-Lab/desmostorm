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

function score = scorePairDistance(pairDist,roiHeight)
%SCOREPAIRDISTANCE Favor separations plausible for two plaques in the ROI.

lower = max(10,0.20 * roiHeight);
target = 0.50 * roiHeight;
upper = 0.75 * roiHeight;

if pairDist < lower
    score = max(0,pairDist / lower);
elseif pairDist <= target
    score = pairDist / target;
elseif pairDist <= upper
    score = 1;
else
    score = max(0,1 - (pairDist - upper) / upper);
end
end
