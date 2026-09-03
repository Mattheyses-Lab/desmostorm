function [leftIdx,rightIdx,info] = findProfileObjectBounds(peaksData,opts)
%FINDPROFILEOBJECTBOUNDS Choose stable outer bounds around profile signal.
%
% This intentionally avoids using the nearest local minimum to a peak. Instead
% it protects the detected peak support, then searches outward for sustained
% low-signal runs. That prevents small dips near a plaque center from pulling
% the ROI edge inward and shifting the ROI center.

arguments
    peaksData (1,1) desmostorm.analysis.PeaksData
    opts.Mode (1,1) string {mustBeMember(opts.Mode,["centralpair","allpeaks"])} = "centralpair"
end

X = peaksData.Location;
Y = normalizeProfileForBounds(peaksData.Signal);
smoothSpan = autofitBoundsSmoothingSpan(numel(Y));
Y = desmostorm.analysis.PeaksData.smooth(Y,smoothSpan);

[supportLeftIdx,supportRightIdx] = protectedSupportIndices(peaksData,opts.Mode);
threshold = autofitBoundaryThreshold(Y,supportLeftIdx,supportRightIdx);
runLength = autofitBoundaryRunLength(numel(Y));

leftIdx = findSustainedLowRunLeft(Y,supportLeftIdx,threshold,runLength);
rightIdx = findSustainedLowRunRight(Y,supportRightIdx,threshold,runLength);

info = struct( ...
    "SupportLeftIdx",supportLeftIdx, ...
    "SupportRightIdx",supportRightIdx, ...
    "SupportLeftLocation",X(supportLeftIdx), ...
    "SupportRightLocation",X(supportRightIdx), ...
    "BoundaryThreshold",threshold, ...
    "RunLength",runLength, ...
    "BoundsSmoothing",smoothSpan);
end

function [leftIdx,rightIdx] = protectedSupportIndices(peaksData,mode)
%PROTECTEDSUPPORTINDICES Return profile indices the boundary search may not cross.
geom = peaksData.PeakGeometry;
X = peaksData.Location;

switch mode
    case "centralpair"
        if peaksData.hasCentralPeakPair && ...
                numel(geom) >= max([peaksData.LeftPeakIdx peaksData.RightPeakIdx])
            selectedGeom = geom([peaksData.LeftPeakIdx peaksData.RightPeakIdx]);
        else
            selectedGeom = geom;
        end

    case "allpeaks"
        if isempty(peaksData.PeakValues)
            selectedGeom = geom;
        else
            keep = peaksData.PeakValues >= 0.25 * max(peaksData.PeakValues);
            selectedGeom = geom(keep);
        end
end

if isempty(selectedGeom)
    [~,centerIdx] = max(peaksData.Signal);
    leftIdx = centerIdx;
    rightIdx = centerIdx;
    return
end

% Use width intersections as the protected support. Peak borders can be scan
% edges for the outermost peaks, which would prevent any outward boundary
% search and leave the ROI at its initial extent.
leftLocs = [selectedGeom.LeftWidthLocation];
rightLocs = [selectedGeom.RightWidthLocation];

leftLoc = min(leftLocs,[],"all","omitnan");
rightLoc = max(rightLocs,[],"all","omitnan");

if isnan(leftLoc), leftLoc = min([selectedGeom.PeakLocation]); end
if isnan(rightLoc), rightLoc = max([selectedGeom.PeakLocation]); end

leftIdx = desmostorm.analysis.image.autofit.nearestIndex(X,leftLoc);
rightIdx = desmostorm.analysis.image.autofit.nearestIndex(X,rightLoc);
end

function y = normalizeProfileForBounds(y)
%NORMALIZEPROFILEFORBOUNDS Normalize while preserving an all-zero profile.
y = y(:);
y = y - min(y,[],"omitnan");
maxVal = max(y,[],"omitnan");
if maxVal > 0
    y = y ./ maxVal;
end
end

function span = autofitBoundsSmoothingSpan(n)
%AUTOFITBOUNDSSMOOTHINGSPAN Use stronger smoothing for geometry fitting.
%
% This is intentionally independent of config.PeakSmoothing. PeakSmoothing is
% a measurement setting; bounds smoothing is an autofit robustness setting.
span = max(7,round(0.05 * n));
if mod(span,2) == 0
    span = span + 1;
end
span = min(span,max(1,n));
end

function runLength = autofitBoundaryRunLength(n)
%AUTOFITBOUNDARYRUNLENGTH Number of consecutive low samples required.
runLength = max(4,round(0.03 * n));
end

function threshold = autofitBoundaryThreshold(Y,leftSupportIdx,rightSupportIdx)
%AUTOFITBOUNDARYTHRESHOLD Low-signal cutoff for object boundary detection.
supportSignal = Y(leftSupportIdx:rightSupportIdx);
peakLevel = max(supportSignal,[],"omitnan");
threshold = max(0.08,0.18 * peakLevel);
threshold = min(threshold,0.25);
end

function idx = findSustainedLowRunLeft(Y,startIdx,threshold,runLength)
%FINDSUSTAINEDLOWRUNLEFT Find the closest sustained low run left of support.
searchIdx = 1:max(1,startIdx-1);
low = Y(searchIdx) <= threshold;
idx = lastRunEnd(searchIdx,low,runLength);
end

function idx = findSustainedLowRunRight(Y,startIdx,threshold,runLength)
%FINDSUSTAINEDLOWRUNRIGHT Find the closest sustained low run right of support.
searchIdx = min(numel(Y),startIdx+1):numel(Y);
low = Y(searchIdx) <= threshold;
idx = firstRunStart(searchIdx,low,runLength);
end

function idx = lastRunEnd(searchIdx,mask,runLength)
%LASTRUNEND Return the last index of the last true run of sufficient length.
idx = searchIdx(1);
if isempty(searchIdx) || ~any(mask)
    return
end

d = diff([false reshape(mask,1,[]) false]);
starts = find(d == 1);
stops = find(d == -1) - 1;
valid = find((stops - starts + 1) >= runLength,1,"last");
if ~isempty(valid)
    idx = searchIdx(stops(valid));
end
end

function idx = firstRunStart(searchIdx,mask,runLength)
%FIRSTRUNSTART Return the first index of the first true run of sufficient length.
idx = searchIdx(end);
if isempty(searchIdx) || ~any(mask)
    return
end

d = diff([false reshape(mask,1,[]) false]);
starts = find(d == 1);
stops = find(d == -1) - 1;
valid = find((stops - starts + 1) >= runLength,1,"first");
if ~isempty(valid)
    idx = searchIdx(starts(valid));
end
end
