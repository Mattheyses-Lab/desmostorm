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

function peaksData = makePeaksData(signal,location,config)
%MAKEPEAKSDATA Construct PeaksData with autofit-safe smoothing flags.
%
% Peak detection uses the app's configured measurement thresholds, while the
% later boundary search applies its own extra smoothing so ROI geometry fitting
% can be hardened independently from final peak measurement settings.

smoothPeaks = config.PeakSmoothing > 0;
peakSmoothing = max(1,config.PeakSmoothing);

peaksData = desmostorm.analysis.PeaksData( ...
    signal, ...
    location, ...
    "MinPeakDistance",config.MinPeakDistance, ...
    "MinPeakHeight",config.MinPeakHeight, ...
    "PeakSmoothing",peakSmoothing, ...
    "Smooth",smoothPeaks, ...
    "MinPeakHeightMode",'absolute', ...
    "MinPeakProminenceMode",'absolute');
end
