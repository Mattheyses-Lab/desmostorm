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
