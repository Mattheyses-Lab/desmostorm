function metrics = scorePeaksData(peaksData,ROI)
%SCOREPEAKSDATA Convert peak measurements into one angle score.

metrics = struct( ...
    "Score",0, ...
    "NPeaks",peaksData.nPeaks, ...
    "HasCentralPair",peaksData.hasCentralPeakPair, ...
    "PairDistance",NaN, ...
    "PairCenter",NaN, ...
    "PeakBalance",NaN, ...
    "ValleyDepth",NaN, ...
    "ProminenceScore",NaN, ...
    "CenterScore",NaN, ...
    "DistanceScore",NaN, ...
    "CountScore",NaN);

if ~peaksData.hasCentralPeakPair
    return
end

leftLoc = peaksData.LeftPeakLocation;
rightLoc = peaksData.RightPeakLocation;
leftVal = peaksData.LeftPeakValue;
rightVal = peaksData.RightPeakValue;
leftProm = peaksData.LeftPeakProminence;
rightProm = peaksData.RightPeakProminence;

pairDist = rightLoc - leftLoc;
pairCenter = mean([leftLoc rightLoc]);
scanHalfWidth = max(abs(peaksData.Location));

p1 = desmostorm.analysis.image.autofit.nearestIndex(peaksData.Location,leftLoc);
p2 = desmostorm.analysis.image.autofit.nearestIndex(peaksData.Location,rightLoc);
valley = min(peaksData.SignalSmooth(p1:p2));
peakMean = mean([leftVal rightVal]);

peakBalance = min([leftVal rightVal]) / max([leftVal rightVal] + eps);
valleyDepth = max(0,(peakMean - valley) / (peakMean + eps));
prominenceScore = min(1,mean([leftProm rightProm]));
centerScore = 1 - min(1,abs(pairCenter) / max(scanHalfWidth,eps));
distanceScore = desmostorm.analysis.image.autofit.scorePairDistance(pairDist,ROI.Height);
countScore = double(peaksData.nPeaks == 2) + 0.75 * double(peaksData.nPeaks > 2);

metrics.PairDistance = pairDist;
metrics.PairCenter = pairCenter;
metrics.PeakBalance = peakBalance;
metrics.ValleyDepth = valleyDepth;
metrics.ProminenceScore = prominenceScore;
metrics.CenterScore = centerScore;
metrics.DistanceScore = distanceScore;
metrics.CountScore = countScore;

metrics.Score = ...
    3.0 * valleyDepth + ...
    2.0 * prominenceScore + ...
    2.0 * peakBalance + ...
    2.0 * centerScore + ...
    2.5 * distanceScore + ...
    0.5 * countScore;
end
