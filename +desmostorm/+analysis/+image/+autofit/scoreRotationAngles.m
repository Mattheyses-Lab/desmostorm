function T = scoreRotationAngles(I,ROI,config,thetas)
%SCOREROTATIONANGLES Score each candidate angle for a two-plaque profile.
%
% The score is intentionally interpretable rather than clever. A strong angle
% should produce a central left/right peak pair with a deep valley between the
% peaks, balanced peak heights, a plausible peak separation, and a pair center
% near the middle of the scan.

n = numel(thetas);
Theta = reshape(thetas,[],1);
Score = zeros(n,1);
NPeaks = zeros(n,1);
HasCentralPair = false(n,1);
PairDistance = nan(n,1);
PairCenter = nan(n,1);
PeakBalance = nan(n,1);
ValleyDepth = nan(n,1);
ProminenceScore = nan(n,1);
CenterScore = nan(n,1);
DistanceScore = nan(n,1);
CountScore = nan(n,1);

for i = 1:n
    peaksData = desmostorm.analysis.image.autofit.analyzeROIHeightProfile( ...
        I,ROI,config,thetas(i));
    metrics = desmostorm.analysis.image.autofit.scorePeaksData(peaksData,ROI);

    Score(i) = metrics.Score;
    NPeaks(i) = metrics.NPeaks;
    HasCentralPair(i) = metrics.HasCentralPair;
    PairDistance(i) = metrics.PairDistance;
    PairCenter(i) = metrics.PairCenter;
    PeakBalance(i) = metrics.PeakBalance;
    ValleyDepth(i) = metrics.ValleyDepth;
    ProminenceScore(i) = metrics.ProminenceScore;
    CenterScore(i) = metrics.CenterScore;
    DistanceScore(i) = metrics.DistanceScore;
    CountScore(i) = metrics.CountScore;
end

% Neighbor agreement matters; a good angle should live on a small plateau,
% not be a one-degree accident.
SmoothedScore = smoothdata(Score,"movmean",5);

T = table( ...
    Theta, ...
    Score, ...
    SmoothedScore, ...
    NPeaks, ...
    HasCentralPair, ...
    PairDistance, ...
    PairCenter, ...
    PeakBalance, ...
    ValleyDepth, ...
    ProminenceScore, ...
    CenterScore, ...
    DistanceScore, ...
    CountScore);
end
