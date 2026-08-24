function row = regionRow(region)
%REGIONROW Build one region measurement row for export.

arguments
    region (1,1) desmostorm.model.STORMRegion
end

ps = region.PixelSize;
ROI = region.ROI;
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

nChannels = proj.MaxSizeC;
nResults = length(L);

for i = 1:nChannels
    leftPeakFWHM_px = NaN;
    leftPeakLocation_px = NaN;
    rightPeakFWHM_px = NaN;
    rightPeakLocation_px = NaN;
    peakDistance_px = NaN;

    if i <= nResults
        if L(i).hasLeftPeak
            leftPeakFWHM_px = round(L(i).LeftPeakWidth,2);
            leftPeakLocation_px = round(L(i).LeftPeakLocation,2);
        end

        if L(i).hasRightPeak
            rightPeakFWHM_px = round(L(i).RightPeakWidth,2);
            rightPeakLocation_px = round(L(i).RightPeakLocation,2);
        end

        if L(i).hasCentralPeakPair
            peakDistance_px = round(L(i).CentralPeakPairDistance,2);
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
