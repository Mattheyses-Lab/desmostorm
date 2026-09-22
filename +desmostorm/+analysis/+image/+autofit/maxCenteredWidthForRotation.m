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

function width = maxCenteredWidthForRotation(W,H,theta,height)
%MAXCENTEREDWIDTHFORROTATION Largest centered width that fits the crop.

safety = 0.98;
c = abs(cosd(theta));
s = abs(sind(theta));

candidates = inf(1,2);
if c > eps
    candidates(1) = (W - s * height) / c;
end
if s > eps
    candidates(2) = (H - c * height) / s;
end

width = safety * min(candidates);
if isempty(width) || isnan(width) || width <= 0 || isinf(width)
    width = safety * W;
end
width = max(1,width);
end
