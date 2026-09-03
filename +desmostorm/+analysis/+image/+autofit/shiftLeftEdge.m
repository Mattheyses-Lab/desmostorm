function ROIout = shiftLeftEdge(ROI,d)
%SHIFTLEFTEDGE Move the ROI left edge in local-width coordinates.

dC = d / 2;
ROIout = ROI;
ROIout.Width = max(1,ROI.Width + d);
ROIout.CenterX = ROI.CenterX - cosd(ROI.RotationAngle) * dC;
ROIout.CenterY = ROI.CenterY + sind(ROI.RotationAngle) * dC;
end
