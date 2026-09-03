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
