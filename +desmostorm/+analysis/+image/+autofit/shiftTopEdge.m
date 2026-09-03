function ROIout = shiftTopEdge(ROI,d)
%SHIFTTOPEDGE Move the ROI top edge in local-height coordinates.

dC = d / 2;
ROIout = ROI;
ROIout.Height = max(1,ROI.Height + d);
ROIout.CenterX = ROI.CenterX + cosd(90 + ROI.RotationAngle) * dC;
ROIout.CenterY = ROI.CenterY - sind(90 + ROI.RotationAngle) * dC;
end
