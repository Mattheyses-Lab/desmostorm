function [ROI,diagnostics] = autofitRegionROI(I,config,opts)
%AUTOFITREGIONROI Estimate a rectangular linescan ROI for one region image.
%
% The current experimental strategy is intentionally modular:
%   1. preprocess image for fitting
%   2. score candidate rotation angles using the height-profile linescan
%   3. choose a stable high-scoring angle
%   4. refine ROI height from the central peak pair
%   5. expand width to the largest centered width allowed by the chosen angle
%   6. refine ROI width from the rectified width profile
%
% The extent-refinement pieces are deliberately written as small helpers. This
% area is still experimental, and clustering/masking may eventually replace
% some of the profile-bound heuristics below.

arguments
    I
    config
    opts.DebugOutput (1,1) logical = desmostorm.Preferences.get( ...
        "AnalysisDebugOutput", desmostorm.runtime.isDeveloperMode())
    opts.ShowPlots = []
end

diagnostics = struct();
debugOutput = opts.DebugOutput;
if ~isempty(opts.ShowPlots)
    % Backward-compatible alias for the old development option. New code
    % should use DebugOutput because diagnostics may include tables, plots,
    % logs, or other non-plot output.
    debugOutput = logical(opts.ShowPlots);
end

if isempty(I)
    ROI = [];
    return
end

I = double(I);
[H,W] = size(I,[1 2]);

% Start from a centered ROI that can rotate freely inside the region crop.
% This makes angle scoring less dependent on the user-selected box size than
% the old half-box initial extent.
ROI = initialROI(H,W);

% Cleanup currently removes sparse DBSCAN noise points and edge junk. These
% are useful for profile stability, but should remain swappable preprocessing
% steps while the autofit path is still experimental.
[Ifit,diagnostics.Preprocess] = preprocessForAutofit(I,debugOutput);

% Keep the sweep broad for now. We can later narrow this using a cluster/mask
% orientation prior once enough bad cases have been examined.
thetas = -90:1:89;

angleScores = scoreRotationAngles(Ifit,ROI,config,thetas);
diagnostics.AngleScores = angleScores;

[theta,choice] = chooseRotationAngle(angleScores);
diagnostics.AngleChoice = choice;

if isnan(theta)
    diagnostics.AngleChoice = choice;
    desmostorm.Log.WARN("Auto-fit ROI failed to converge: no suitable rotation angle found.");
    if debugOutput
        ROI.RotationAngle = NaN;
        showAutofitDebugOutput(I,Ifit,ROI,diagnostics);
    end
    ROI = [];
    return
end

ROI.RotationAngle = theta;

% Refine height first: the plaque pair is usually best resolved along this
% axis, and a cleaner height gives the width profile a better average.
[ROI,diagnostics.HeightRefinement] = refineROIHeight(Ifit,ROI,config);

% Width is the axis most likely to exceed the initial fitting ROI. Reset it to
% the largest centered width that still fits at the chosen angle/refined height,
% then refine inward from that generous starting point.
ROI.Width = maxCenteredWidthForRotation(W,H,ROI.RotationAngle,ROI.Height);
[ROI,diagnostics.WidthRefinement] = refineROIWidth(Ifit,ROI,config);

if debugOutput
    showAutofitDebugOutput(I,Ifit,ROI,diagnostics);
end

end

function ROI = initialROI(H,W)
%INITIALROI Build the centered starting ROI used for angle scoring.
    side = 0.70 * min(H,W);

    ROI = struct();
    ROI.Height = side;
    ROI.Width = side;
    ROI.CenterX = (W / 2) + 0.5;
    ROI.CenterY = (H / 2) + 0.5;
    ROI.RotationAngle = 0;
end

function [Iout,info] = preprocessForAutofit(I,debugOutput)
%PREPROCESSFORAUTOFIT Return the image used by angle/extent fitting.
%
% This helper is intentionally small so alternative cleanup approaches
% (foreground masks, morphology, cluster-guided filtering) can be swapped in
% without disturbing the fitting code.
    info = struct( ...
        "Methods",["removeIsolatedPuncta","removeEdgeClusters"]);

    Iout = desmostorm.analysis.image.removeIsolatedPuncta(I, ...
        "DebugOutput",debugOutput);

    Iout = desmostorm.analysis.image.removeEdgeClusters(Iout, ...
        "DebugOutput",debugOutput);
end

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

    for i = 1:n
        theta = thetas(i);
        peaksData = analyzeROIHeightProfile(I,ROI,config,theta);
        metrics = scorePeaksData(peaksData,ROI);

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
    end

    % Neighbor agreement matters; a good angle should live on a small plateau,
    % not be a one-degree accident. Five samples keeps the old one-degree sweep
    % responsive while damping jagged peak calls.
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
        DistanceScore);
end

function peaksData = analyzeROIHeightProfile(I,ROI,config,theta)
%ANALYZEROIHEIGHTPROFILE Run the rectangular linescan and peak analysis.
    linescanData = desmostorm.analysis.profile.measure2D(I, ...
        ROI.CenterX, ...
        ROI.CenterY, ...
        ROI.Width, ...
        ROI.Height, ...
        theta, ...
        'Interp','linear');

    peaksData = makeAutofitPeaksData( ...
        linescanData.HeightProfile, ...
        linescanData.HeightDist, ...
        config);
end

function peaksData = analyzeROIWidthProfile(I,ROI,config)
%ANALYZEROIWIDTHPROFILE Run peak analysis on the rectified width profile.
    linescanData = desmostorm.analysis.profile.measure2D(I, ...
        ROI.CenterX, ...
        ROI.CenterY, ...
        ROI.Width, ...
        ROI.Height, ...
        ROI.RotationAngle, ...
        'Interp','linear');

    peaksData = makeAutofitPeaksData( ...
        linescanData.WidthProfile(:), ...
        linescanData.WidthDist(:), ...
        config);
end

function peaksData = makeAutofitPeaksData(signal,location,config)
%MAKEAUTOFITPEAKSDATA Construct PeaksData with autofit-safe smoothing flags.
    smoothPeaks = config.PeakSmoothing > 0;
    peakSmoothing = max(1,config.PeakSmoothing);

    peaksData = desmostorm.analysis.PeaksData( ...
        signal, ...
        location, ...
        "MinPeakDistance",config.MinPeakDistance, ...
        "MinPeakHeight",config.MinPeakHeight, ...
        "PeakSmoothing",peakSmoothing, ...
        "Smooth",smoothPeaks, ...
        "MinPeakHeightMode",'absolute', ...
        "MinPeakProminenceMode",'absolute');
end

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
        "DistanceScore",NaN);

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

    p1 = nearestIndex(peaksData.Location,leftLoc);
    p2 = nearestIndex(peaksData.Location,rightLoc);
    valley = min(peaksData.SignalSmooth(p1:p2));
    peakMean = mean([leftVal rightVal]);

    peakBalance = min([leftVal rightVal]) / max([leftVal rightVal] + eps);
    valleyDepth = max(0,(peakMean - valley) / (peakMean + eps));
    prominenceScore = min(1,mean([leftProm rightProm]));
    centerScore = 1 - min(1,abs(pairCenter) / max(scanHalfWidth,eps));
    distanceScore = scorePairDistance(pairDist,ROI.Height);
    countScore = double(peaksData.nPeaks == 2) + 0.75*double(peaksData.nPeaks > 2);

    metrics.PairDistance = pairDist;
    metrics.PairCenter = pairCenter;
    metrics.PeakBalance = peakBalance;
    metrics.ValleyDepth = valleyDepth;
    metrics.ProminenceScore = prominenceScore;
    metrics.CenterScore = centerScore;
    metrics.DistanceScore = distanceScore;

    metrics.Score = ...
        3.0*valleyDepth + ...
        2.0*prominenceScore + ...
        2.0*peakBalance + ...
        2.0*centerScore + ...
        2.5*distanceScore + ...
        0.5*countScore;
end

function score = scorePairDistance(pairDist,roiHeight)
%SCOREPAIRDISTANCE Favor separations plausible for two plaques in the ROI.
    lower = max(10,0.20*roiHeight);
    target = 0.50*roiHeight;
    upper = 0.75*roiHeight;

    if pairDist < lower
        score = max(0,pairDist/lower);
    elseif pairDist <= target
        score = pairDist / target;
    elseif pairDist <= upper
        score = 1;
    else
        score = max(0,1 - (pairDist - upper)/upper);
    end
end

function [theta,choice] = chooseRotationAngle(T)
%CHOOSEROTATIONANGLE Choose the center of the best high-score plateau.
    theta = NaN;
    choice = struct( ...
        "Method","score-plateau", ...
        "ScoreThreshold",NaN, ...
        "SelectedThetaIdx",NaN, ...
        "SelectedTheta",NaN);

    if isempty(T) || all(T.SmoothedScore <= 0)
        choice.Method = "failed-empty-score";
        return
    end

    valid = T.HasCentralPair & T.SmoothedScore > 0;
    if ~any(valid)
        choice.Method = "failed-no-central-pair";
        return
    end

    maxScore = max(T.SmoothedScore(valid));
    threshold = 0.80 * maxScore;
    mask = valid & T.SmoothedScore >= threshold;

    % If there is a clean two-peak plateau, prefer it over profiles with
    % extra peaks. Extra peaks are often peripheral puncta or bridge signal
    % that should not dominate angle selection.
    cleanMask = mask & T.NPeaks == 2;
    if any(cleanMask)
        mask = cleanMask;
    end

    runIdx = longestCircularTrueRun(mask);

    if isempty(runIdx)
        [~,idx] = max(T.SmoothedScore);
    else
        idx = runIdx(ceil(numel(runIdx)/2));
    end

    theta = T.Theta(idx);
    choice.ScoreThreshold = threshold;
    choice.SelectedThetaIdx = idx;
    choice.SelectedTheta = theta;
end

function idx = longestCircularTrueRun(mask)
%LONGESTCIRCULARTRUERUN Return indices for the longest true run with wrap.
    mask = reshape(logical(mask),1,[]);
    n = numel(mask);
    idx = [];

    if n == 0 || ~any(mask)
        return
    end

    if all(mask)
        idx = 1:n;
        return
    end

    doubled = [mask mask];
    bestStart = 1;
    bestLen = 0;
    currentStart = 1;
    currentLen = 0;

    for i = 1:numel(doubled)
        if doubled(i)
            if currentLen == 0
                currentStart = i;
            end
            currentLen = currentLen + 1;
            if currentLen > bestLen && currentLen <= n
                bestLen = currentLen;
                bestStart = currentStart;
            end
        else
            currentLen = 0;
        end
    end

    idx = mod((bestStart:bestStart+bestLen-1)-1,n) + 1;
end

function [ROI,info] = refineROIHeight(I,ROI,config)
%REFINEROIHEIGHT Fit top/bottom ROI edges around the central peak pair.
    info = struct( ...
        "Succeeded",false, ...
        "LeftMinIdx",NaN, ...
        "RightMinIdx",NaN, ...
        "Method","central-peak-pair-bounds");

    peaksData = analyzeROIHeightProfile(I,ROI,config,ROI.RotationAngle);
    if ~peaksData.hasCentralPeakPair
        return
    end

    X = peaksData.Location;
    [leftMinIdx,rightMinIdx,bounds] = findProfileObjectBounds( ...
        peaksData, ...
        "Mode","centralpair");

    dHTop = X(1) - X(leftMinIdx);
    ROI = shiftTopEdge(ROI,dHTop);

    dHBottom = X(rightMinIdx) - X(end);
    ROI = shiftBottomEdge(ROI,dHBottom);

    info.Succeeded = true;
    info.LeftMinIdx = leftMinIdx;
    info.RightMinIdx = rightMinIdx;
    info.Bounds = bounds;
end

function [ROI,info] = refineROIWidth(I,ROI,config)
%REFINEROIWIDTH Fit left/right ROI edges from the rectified width profile.
    info = struct( ...
        "Succeeded",false, ...
        "LeftMinIdx",NaN, ...
        "RightMinIdx",NaN, ...
        "Method","profile-bounds");

    peaksData = analyzeROIWidthProfile(I,ROI,config);
    if peaksData.nPeaks == 0
        return
    end

    X = peaksData.Location;
    [leftMinIdx,rightMinIdx,bounds] = findProfileObjectBounds( ...
        peaksData, ...
        "Mode","allpeaks");

    dWLeft = X(1) - X(leftMinIdx);
    ROI = shiftLeftEdge(ROI,dWLeft);

    dWRight = X(rightMinIdx) - X(end);
    ROI = shiftRightEdge(ROI,dWRight);

    info.Succeeded = true;
    info.LeftMinIdx = leftMinIdx;
    info.RightMinIdx = rightMinIdx;
    info.Bounds = bounds;
end

function [leftIdx,rightIdx,info] = findProfileObjectBounds(peaksData,opts)
%FINDPROFILEOBJECTBOUNDS Choose stable outer bounds around profile signal.
%
% This intentionally avoids using the nearest local minimum to a peak. Instead
% it protects the detected peak support, then searches outward for sustained
% low-signal runs. That prevents small dips near a plaque center from pulling
% the ROI edge inward and shifting the ROI center.
    arguments
        peaksData (1,1) desmostorm.analysis.PeaksData
        opts.Mode (1,:) char {mustBeMember(opts.Mode,{'centralpair','allpeaks'})} = 'centralpair'
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
        case 'centralpair'
            if peaksData.hasCentralPeakPair && numel(geom) >= max([peaksData.LeftPeakIdx peaksData.RightPeakIdx])
                selectedGeom = geom([peaksData.LeftPeakIdx peaksData.RightPeakIdx]);
            else
                selectedGeom = geom;
            end

        case 'allpeaks'
            if isempty(peaksData.PeakValues)
                selectedGeom = geom;
            else
                keep = peaksData.PeakValues >= 0.25*max(peaksData.PeakValues);
                selectedGeom = geom(keep);
            end
    end

    if isempty(selectedGeom)
        [~,centerIdx] = max(peaksData.Signal);
        leftIdx = centerIdx;
        rightIdx = centerIdx;
        return
    end

    % Use width intersections as the protected support. Peak borders can be
    % scan edges for the outermost peaks, which would prevent any outward
    % boundary search and leave the ROI at its initial extent.
    leftLocs = [selectedGeom.LeftWidthLocation];
    rightLocs = [selectedGeom.RightWidthLocation];

    leftLoc = min(leftLocs,[],"all","omitnan");
    rightLoc = max(rightLocs,[],"all","omitnan");

    if isnan(leftLoc), leftLoc = min([selectedGeom.PeakLocation]); end
    if isnan(rightLoc), rightLoc = max([selectedGeom.PeakLocation]); end

    leftIdx = nearestIndex(X,leftLoc);
    rightIdx = nearestIndex(X,rightLoc);
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
    span = max(7,round(0.05*n));
    if mod(span,2) == 0
        span = span + 1;
    end
    span = min(span,max(1,n));
end

function runLength = autofitBoundaryRunLength(n)
%AUTOFITBOUNDARYRUNLENGTH Number of consecutive low samples required.
    runLength = max(4,round(0.03*n));
end

function threshold = autofitBoundaryThreshold(Y,leftSupportIdx,rightSupportIdx)
%AUTOFITBOUNDARYTHRESHOLD Low-signal cutoff for object boundary detection.
    supportSignal = Y(leftSupportIdx:rightSupportIdx);
    peakLevel = max(supportSignal,[],"omitnan");
    threshold = max(0.08,0.18*peakLevel);
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

function ROIout = shiftTopEdge(ROI,d)
%SHIFTTOPEDGE Move the ROI top edge in local-height coordinates.
    dC = d / 2;
    ROIout = ROI;
    ROIout.Height = max(1,ROI.Height + d);
    ROIout.CenterX = ROI.CenterX + cosd(90 + ROI.RotationAngle)*dC;
    ROIout.CenterY = ROI.CenterY - sind(90 + ROI.RotationAngle)*dC;
end

function ROIout = shiftBottomEdge(ROI,d)
%SHIFTBOTTOMEDGE Move the ROI bottom edge in local-height coordinates.
    dC = d / 2;
    ROIout = ROI;
    ROIout.Height = max(1,ROI.Height + d);
    ROIout.CenterX = ROI.CenterX - cosd(90 + ROI.RotationAngle)*dC;
    ROIout.CenterY = ROI.CenterY + sind(90 + ROI.RotationAngle)*dC;
end

function ROIout = shiftLeftEdge(ROI,d)
%SHIFTLEFTEDGE Move the ROI left edge in local-width coordinates.
    dC = d / 2;
    ROIout = ROI;
    ROIout.Width = max(1,ROI.Width + d);
    ROIout.CenterX = ROI.CenterX - cosd(ROI.RotationAngle)*dC;
    ROIout.CenterY = ROI.CenterY + sind(ROI.RotationAngle)*dC;
end

function ROIout = shiftRightEdge(ROI,d)
%SHIFTRIGHTEDGE Move the ROI right edge in local-width coordinates.
    dC = d / 2;
    ROIout = ROI;
    ROIout.Width = max(1,ROI.Width + d);
    ROIout.CenterX = ROI.CenterX + cosd(ROI.RotationAngle)*dC;
    ROIout.CenterY = ROI.CenterY - sind(ROI.RotationAngle)*dC;
end

function width = maxCenteredWidthForRotation(W,H,theta,height)
%MAXCENTEREDWIDTHFORROTATION Largest centered width that fits the crop.
    safety = 0.98;
    c = abs(cosd(theta));
    s = abs(sind(theta));

    candidates = inf(1,2);
    if c > eps
        candidates(1) = (W - s*height) / c;
    end
    if s > eps
        candidates(2) = (H - c*height) / s;
    end

    width = safety * min(candidates);
    if isempty(width) || isnan(width) || width <= 0 || isinf(width)
        width = safety * W;
    end
    width = max(1,width);
end

function idx = nearestIndex(x,value)
%NEARESTINDEX Robust index lookup for floating-point location vectors.
    [~,idx] = min(abs(x - value));
end

function showAutofitDebugOutput(Iraw,Ifit,ROI,diagnostics)
%SHOWAUTOFITDEBUGOUTPUT Display final analysis diagnostics.
%
% This intentionally does not animate the angle sweep. The complete angle
% table is stored in diagnostics.AngleScores; the figure only summarizes the
% final selected ROI and the score landscape.

    T = diagnostics.AngleScores;
    choice = diagnostics.AngleChoice;

    desmostorm.Log.DEBUG(sprintf( ...
        "Auto-fit ROI debug: selected theta %.2f using %s.", ...
        ROI.RotationAngle, ...
        choice.Method));

    fig = uifigure( ...
        "WindowStyle","alwaysontop", ...
        "OuterPosition",matlabx.UICal.centeredFigOuterPosition(1100,500), ...
        "Name","Auto-fit ROI diagnostics");
    layout = uigridlayout(fig,[1 2], ...
        "ColumnWidth",{"1.2x","1x"}, ...
        "RowHeight",{"1x"});

    img = matlabx.image.Image5D.fromComponents( ...
        {Iraw,Ifit}, ...
        "Names",["Raw","Preprocessed"]);

    imageAx = matlabx.ui.axes.ImageAxes(layout, ...
        "Name","Auto-fit image", ...
        "ToolBelt",{'DrawRectangle'}, ...
        "ImageData",img, ...
        "Colormap",turbo);
    imageAx.ComponentColormaps{1} = turbo;
    imageAx.ComponentColormaps{2} = turbo;
    imageAx.Tools.DrawRectangle.RotationAngleMode = 'half-circle';
    if ~isnan(ROI.RotationAngle)
        imageAx.Tools.DrawRectangle.setROIPosition(ROI);
    end

    scoreAx = uiaxes(layout);
    scoreAx.NextPlot = "add";
    plot(scoreAx,T.Theta,T.Score, ...
        "LineStyle","-", ...
        "Color",[0.45 0.45 0.45], ...
        "LineWidth",1);
    plot(scoreAx,T.Theta,T.SmoothedScore, ...
        "LineStyle","-", ...
        "Color",[0.05 0.25 0.85], ...
        "LineWidth",2);
    if ~isnan(choice.SelectedTheta)
        xline(scoreAx,choice.SelectedTheta, ...
            "Color",[0.85 0.15 0.10], ...
            "LineWidth",1.5);
    end
    scoreAx.NextPlot = "replace";
    scoreAx.XGrid = "on";
    scoreAx.YGrid = "on";
    scoreAx.XLabel.String = "Rotation angle (deg)";
    scoreAx.YLabel.String = "Score";
    if isnan(choice.SelectedTheta)
        scoreAx.Title.String = sprintf("Auto-fit failed (%s)",choice.Method);
        legendLabels = {"Raw score","Smoothed score"};
    else
        scoreAx.Title.String = sprintf("Selected %.1f deg (%s)",choice.SelectedTheta,choice.Method);
        legendLabels = {"Raw score","Smoothed score","Selected angle"};
    end
    lgd = legend(scoreAx);
    lgd.String = legendLabels;
    lgd.Location = "best";
end
