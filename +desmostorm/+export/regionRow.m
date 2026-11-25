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

function row = regionRow(region)
%REGIONROW Build one region measurement row for export.

arguments
    region (1,1) desmostorm.model.STORMRegion
end

% Physical calibration used to convert pixel measurements.
ps = region.PixelSize;
% Linescan ROI geometry used for the current region.
ROI = region.ROI;
% Analyzed profiles in the parent image’s source channel order.
L = region.LinescanResults;
proj = region.Project;

row = struct();

row.ProjectName = string(proj.Name);
row.ImageName = string(region.Parent.Name);
row.RegionName = string(region.Name);
row.PixelSize = ps.stringDisplay;

row.LabelID = string(region.LabelID);
row.LabelSource = string(region.LabelSource);
row.Score = sprintf('%.2f',region.Score);

row.ROISource = string(region.ROISource);
row.RegionCenter = string(sprintf('(%.1f, %.1f)',region.Center(1),region.Center(2)));
row.RegionWidth_px = region.BoxSize;
row.RegionHeight_px = region.BoxSize;
row.RegionWidth_phys = ps.px2phys(region.BoxSize);
row.RegionHeight_phys = ps.px2phys(region.BoxSize);

row.ROICenter = string(sprintf('(%.1f, %.1f)',ROI.CenterX,ROI.CenterY));
row.ROIWidth_px = ROI.Width;
row.ROIHeight_px = ROI.Height;
row.ROIWidth_phys = ps.px2phys(ROI.Width);
row.ROIHeight_phys = ps.px2phys(ROI.Height);
row.ROIRotationAngle = round(ROI.RotationAngle,2);

% Number of channels to process.
nChannels = numel(proj.Channels);
% Number of results available in source order.
nResults = length(L);

% Process each source channel in its original component order.
for i = 1:nChannels
    leftPeakFWHM_px = NaN;
    leftPeakLocation_px = NaN;
    rightPeakFWHM_px = NaN;
    rightPeakLocation_px = NaN;
    peakDistance_px = NaN;

    % Source channel index.
    c = region.Parent.sourceChannelIndex(i);
    if ~isempty(c) && c <= nResults
        if L(c).hasLeftPeak
            leftPeakFWHM_px = round(L(c).LeftPeakWidth,2);
            leftPeakLocation_px = round(L(c).LeftPeakLocation,2);
        end

        if L(c).hasRightPeak
            rightPeakFWHM_px = round(L(c).RightPeakWidth,2);
            rightPeakLocation_px = round(L(c).RightPeakLocation,2);
        end

        if L(c).hasCentralPeakPair
            peakDistance_px = round(L(c).CentralPeakPairDistance,2);
        end
    end

    row.(sprintf('PeakDistance_px__C%i_',i)) = peakDistance_px;
    row.(sprintf('LeftPeakFWHM_px__C%i_',i)) = leftPeakFWHM_px;
    row.(sprintf('RightPeakFWHM_px__C%i_',i)) = rightPeakFWHM_px;
    row.(sprintf('LeftPeakLocation_px__C%i_',i)) = leftPeakLocation_px;
    row.(sprintf('RightPeakLocation_px__C%i_',i)) = rightPeakLocation_px;

    row.(sprintf('PeakDistance_C%i_',i)) = ps.px2phys(peakDistance_px);
    row.(sprintf('LeftPeakFWHM_C%i_',i)) = ps.px2phys(leftPeakFWHM_px);
    row.(sprintf('RightPeakFWHM_C%i_',i)) = ps.px2phys(rightPeakFWHM_px);
    row.(sprintf('LeftPeakLocation_C%i_',i)) = ps.px2phys(leftPeakLocation_px);
    row.(sprintf('RightPeakLocation_C%i_',i)) = ps.px2phys(rightPeakLocation_px);
end

end
