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
