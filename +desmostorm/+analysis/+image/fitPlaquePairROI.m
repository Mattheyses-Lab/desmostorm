function [out, debug] = fitPlaquePairROI(I, opts)
%FITPLAQUEPAIRROI Fit an oriented rectangular ROI around the central plaque pair.
%
%   [Center, Width, Height, RotationAngle] = fitPlaquePairROI(I, seedPts)
%   uses a grayscale plaque-pair crop I and an Nx2 array of seed points
%   seedPts = [x y; ...] to identify the central plaque pair and fit a
%   rotated rectangle around it.
%
%   Outputs:
%       Center        - [cx cy]
%       Width         - extent parallel to plaques
%       Height        - extent perpendicular to plaques
%       RotationAngle - plaque direction angle in degrees CCW
%                       using image coordinates: x right, y down
%
%   [Center, Width, Height, RotationAngle, debug] = fitPlaquePairROI(...)
%   also returns a debug struct.
%
%   Assumptions:
%   - I is a single 2-D grayscale image containing one main plaque pair of
%     interest near the image center.
%   - seedPts are SURF/DBSCAN-derived points associated with the central pair.
%   - Nearby plaque fragments may intrude into the crop.
%
%   Strategy:
%   1) Threshold and clean image into connected components.
%   2) Score components by plaque-likeness + centrality + proximity to seedPts.
%   3) Keep the two best target components.
%   4) Estimate common plaque angle from those two components.
%   5) Fit a rotated bounding box to their union.
%   6) Shift/shrink box as needed so it stays within image bounds.
%
%   Options:
%       opts.Sigma               = 1.0
%       opts.MinArea             = 8
%       opts.MaxComponentsToTest = 12
%       opts.SeedInfluenceRadius = 12
%       opts.CenterSigma         = []      % default = 0.22*min(image size)
%       opts.PaddingParallel     = 4
%       opts.PaddingPerp         = 4
%       opts.FillHoles           = true
%       opts.PreferTwoComponents = true
%       opts.ShowDebug           = false
%
%   Notes:
%   - Width axis is parallel to plaques.
%   - Height axis is perpendicular to plaques.
%   - The returned angle follows image-coordinate convention:
%         0 deg   = right
%         +30 deg = up-right
%         -30 deg = down-right
    arguments
        I
        opts.Sigma (1,1) double = 1.0
        opts.MinArea (1,1) double = 8
        opts.MaxComponentsToTest (1,1) double = 12
        opts.SeedInfluenceRadius (1,1) double = 12
        opts.CenterSigma (1,1) double = NaN
        opts.PaddingParallel (1,1) double = 4
        opts.PaddingPerp (1,1) double = 4
        opts.FillHoles (1,1) logical = true
        opts.PreferTwoComponents (1,1) logical = true
        opts.ShowDebug (1,1) logical = false
    end
    
    if ~ismatrix(I)
        error('I must be a 2-D grayscale image.');
    end
    
    [nRows, nCols] = size(I);
    imageCenter = [(nCols+1)/2, (nRows+1)/2];
    
    if isnan(opts.CenterSigma)
        opts.CenterSigma = 0.22 * min(nRows, nCols);
    end
    
    %% Normalize image
    if ~isa(I,'double')
        I = im2double(I);
    end
    Inorm = rescale(I);
    
    
    % smooth image
    %Ismooth = imgaussfilt(Inorm, opts.Sigma);
    Ismooth = Inorm;
    
    
    
    
    %% Build initial mask
    
    % locate puncta maxima to get seeds for mask
    %[seedPts,seedMask] = matlabx.image.measure.findPuncta(Inorm);

    [seedPts,seedMask] = desmostorm.analysis.image.detectPlaques(Inorm);
    
    % Keep only in-bounds seed points
    if ~isempty(seedPts)
        keep = seedPts(:,1) >= 1 & seedPts(:,1) <= nCols & ...
               seedPts(:,2) >= 1 & seedPts(:,2) <= nRows;
        seedPts = seedPts(keep,:);
    end
    
    % dilate the seeds
    BW = imdilate(seedMask,strel('disk',1,0));
    
    % grow the dilated seeds with active contours (Chan-Vese method)
    BW = activecontour(Inorm,BW,100,'Chan-Vese','ContractionBias',-0.5);
    
    % fill holes in the mask
    BW = imfill(BW, 'holes');
    
    % TESTING BELOW
    
    % erode to separate components connected by a few pixels
    BW = imerode(BW,strel('disk',3,0));
    % remove smaller puncta
    BW = bwareaopen(BW,10,8);

    % END TESTING
    
    
    CC = bwconncomp(BW);
    if CC.NumObjects == 0
        [out, debug] = localFailResult('No components found.');
        debug.Inorm = Inorm;
        debug.Ismooth = Ismooth;
        debug.BW = BW;
        return
    end
    
    
    %% Measure components
    props = regionprops(CC, Ismooth, ...
        'Area','PixelIdxList','WeightedCentroid','MeanIntensity');
    
    nComp = numel(props);
    comp = repmat(localEmptyComponent(), nComp, 1);
    
    for k = 1:nComp
        idx = props(k).PixelIdxList;
        [yy, xx] = ind2sub([nRows, nCols], idx);
        XY = [xx(:), yy(:)];
    
        [theta, centroid, evals, majorLen, minorLen] = localPCAOrientation(XY);
    
        area = props(k).Area;
        elong = majorLen / max(minorLen, 1e-6);
        intensity = props(k).MeanIntensity;
    
        dCenter = norm(centroid - imageCenter);
        centerScore = exp(-(dCenter.^2) / (2*opts.CenterSigma^2));
    
        if isempty(seedPts)
            dSeed = dCenter;
            seedScore = centerScore;
            overlapScore = 0;
            nNearSeed = 0;
        else
            D = pdist2(XY, seedPts);
            minDistPix = min(D, [], 2);
            nNearSeed = sum(minDistPix <= opts.SeedInfluenceRadius);
            fracNearSeed = nNearSeed / size(XY,1);
            dSeed = min(vecnorm(seedPts - centroid, 2, 2));
            seedScore = exp(-(dSeed.^2) / (2*(opts.SeedInfluenceRadius*1.5)^2));
            overlapScore = fracNearSeed;
        end
    
        plaqueScore = area .* max(elong,1) .* max(intensity,eps);
    
        comp(k).PixelIdxList = idx;
        comp(k).XY = XY;
        comp(k).Area = area;
        comp(k).Centroid = centroid;
        comp(k).WeightedCentroid = props(k).WeightedCentroid;
        comp(k).MeanIntensity = intensity;
        comp(k).MajorAxisLength = majorLen;
        comp(k).MinorAxisLength = minorLen;
        comp(k).Elongation = elong;
        comp(k).Angle = theta;
        comp(k).EigVals = evals;
        comp(k).DistToCenter = dCenter;
        comp(k).CenterScore = centerScore;
        comp(k).DistToSeed = dSeed;
        comp(k).SeedScore = seedScore;
        comp(k).OverlapScore = overlapScore;
        comp(k).NumNearSeed = nNearSeed;
        comp(k).PlaqueScore = plaqueScore;
    
        % Strongly bias toward seed-overlapping and central components.
        comp(k).TotalScore = plaqueScore .* ...
            (0.20 + 1.80*centerScore) .* ...
            (0.20 + 2.20*seedScore + 3.00*overlapScore);
    end
    
    %% Keep only best few for pair selection
    [~, order] = sort([comp.TotalScore], 'descend');
    order = order(1:min(opts.MaxComponentsToTest, numel(order)));
    cand = comp(order);
    
    %% Pick target component set
    [selected, selectionMode] = localSelectTargetComponents(cand, imageCenter, seedPts, opts);
    
    if isempty(selected)
        [out, debug] = localFailResult('Could not select target plaque pair.');
        debug.Inorm = Inorm;
        debug.Ismooth = Ismooth;
        debug.BW = BW;
        debug.Threshold = t;
        debug.Components = comp;
        return
    end
    
    %% Common plaque direction
    if isscalar(selected)
        theta = selected(1).Angle;
    else
        angles = [selected.Angle];
        weights = [selected.Area] .* [selected.MajorAxisLength];
        theta = localAverageAxialAngle(angles, weights);
    end
    
    U = localAxisU(theta);
    V = localAxisV(theta);
    
    %% Fit rotated box to selected components
    allXY = vertcat(selected.XY);
    origin = mean(allXY, 1);
    
    XY0 = allXY - origin;
    u = XY0 * U(:);
    v = XY0 * V(:);
    
    umin = min(u);
    umax = max(u);
    vmin = min(v);
    vmax = max(v);
    
    Width = (umax - umin) + 2*opts.PaddingParallel;
    Height = (vmax - vmin) + 2*opts.PaddingPerp;
    
    u0 = (umin + umax)/2;
    v0 = (vmin + vmax)/2;
    Center = origin + u0*U + v0*V;
    
    %% Clamp to image by shifting inward, then shrinking if needed
    [Center, Width, Height, clampInfo] = localClampRotatedRectToImage( ...
        Center, Width, Height, theta, [nRows nCols]);
    
    RotationAngle = localWrapTo180(theta);
    
    
    %% Main output
    out = struct();
    out.CenterX         = Center(1);
    out.CenterY         = Center(2);
    out.Width           = Width;
    out.Height          = Height;
    out.RotationAngle   = RotationAngle;
    
    
    %% Debug
    debug = struct();
    debug.Inorm = Inorm;
    debug.Ismooth = Ismooth;
    %debug.Threshold = t;
    debug.BW = BW;
    debug.ImageCenter = imageCenter;
    debug.SeedPts = seedPts;
    debug.AllComponents = comp;
    debug.CandidateComponents = cand;
    debug.SelectedComponents = selected;
    debug.SelectionMode = selectionMode;
    debug.Origin = origin;
    debug.UAxis = U;
    debug.VAxis = V;
    debug.ProjectedU = u;
    debug.ProjectedV = v;
    debug.UMinMax = [umin umax];
    debug.VMinMax = [vmin vmax];
    debug.ClampInfo = clampInfo;
    
    if opts.ShowDebug
        figure('Color','w');
        imagesc(I); axis image ij; colormap turbo; hold on
    
        if ~isempty(seedPts)
            plot(seedPts(:,1), seedPts(:,2), 'wo', 'MarkerSize', 5, 'LineWidth', 1.2);
        end
    
        for k = 1:numel(cand)
            plot(cand(k).Centroid(1), cand(k).Centroid(2), 'cs', 'MarkerSize', 8, 'LineWidth', 1.2);
        end
    
        for k = 1:numel(selected)
            plot(selected(k).Centroid(1), selected(k).Centroid(2), 'go', 'MarkerSize', 10, 'LineWidth', 1.6);
        end
    
        localDrawRotRect(Center, Width, Height, RotationAngle, 'w-', 1.5);
    
        p1 = Center - 0.5*Width*U;
        p2 = Center + 0.5*Width*U;
        plot([p1(1) p2(1)], [p1(2) p2(2)], 'w--', 'LineWidth', 1.2);
    
        title(sprintf('Mode: %s | Angle %.1f | W %.1f | H %.1f', ...
            selectionMode, RotationAngle, Width, Height));
    end

%% failure helper
    function [S, debug] = localFailResult(msg)
        S = struct();
        S.CenterX         = NaN;
        S.CenterY         = NaN;
        S.Width           = NaN;
        S.Height          = NaN;
        S.RotationAngle   = NaN;
        debug = struct('Message', msg);
    end
end

%% ------------------------------------------------------------------------
function s = localEmptyComponent()
    s = struct( ...
        'PixelIdxList', [], ...
        'XY', [], ...
        'Area', [], ...
        'Centroid', [], ...
        'WeightedCentroid', [], ...
        'MeanIntensity', [], ...
        'MajorAxisLength', [], ...
        'MinorAxisLength', [], ...
        'Elongation', [], ...
        'Angle', [], ...
        'EigVals', [], ...
        'DistToCenter', [], ...
        'CenterScore', [], ...
        'DistToSeed', [], ...
        'SeedScore', [], ...
        'OverlapScore', [], ...
        'NumNearSeed', [], ...
        'PlaqueScore', [], ...
        'TotalScore', []);
end

function [theta, centroid, evals, majorLen, minorLen] = localPCAOrientation(XY)
    XY = double(XY);
    centroid = mean(XY, 1);
    X0 = XY - centroid;
    
    if size(X0,1) < 2 || all(abs(X0(:)) < eps)
        theta = 0;
        evals = [0 0];
        majorLen = 0;
        minorLen = 0;
        return
    end
    
    C = (X0' * X0) / max(size(X0,1)-1, 1);
    [V,D] = eig(C);
    [evals, idx] = sort(diag(D), 'descend');
    V = V(:,idx);
    
    dirMajor = V(:,1);
    theta = atan2d(-dirMajor(2), dirMajor(1));
    theta = localWrapTo180(theta);
    
    majorLen = 4 * sqrt(max(evals(1),0));
    minorLen = 4 * sqrt(max(evals(min(end,2)),0));
end

function theta = localAverageAxialAngle(anglesDeg, weights)
    a = deg2rad(2 * anglesDeg(:));
    w = weights(:);
    if isempty(w) || all(w == 0)
        w = ones(size(a));
    end
    c = sum(w .* cos(a));
    s = sum(w .* sin(a));
    theta = rad2deg(atan2(s,c)) / 2;
    theta = localWrapTo180(theta);
end

function U = localAxisU(theta)
    U = [cosd(theta), -sind(theta)];
end

function V = localAxisV(theta)
    V = [sind(theta), cosd(theta)];
end

function ang = localWrapTo180(ang)
    ang = mod(ang + 180, 360) - 180;
end

function [selected, mode] = localSelectTargetComponents(cand, imageCenter, seedPts, opts)
    selected = struct([]);
    mode = "none";
    
    if isempty(cand)
        return
    end
    
    if isscalar(cand)
        selected = cand(1);
        mode = "single";
        return
    end
    
    % Try all pairs and select the best one.
    bestPairScore = -inf;
    bestPair = [];
    
    for i = 1:numel(cand)-1
        for j = i+1:numel(cand)
            a = cand(i);
            b = cand(j);
    
            thetaPair = localAverageAxialAngle( ...
                [a.Angle b.Angle], ...
                [a.Area*a.MajorAxisLength, b.Area*b.MajorAxisLength]);
    
            U = localAxisU(thetaPair);
            V = localAxisV(thetaPair);
    
            ca = a.Centroid;
            cb = b.Centroid;
            d = cb - ca;
    
            sepParallel = abs(dot(d, U));
            sepPerp = abs(dot(d, V));
    
            angleDiff = localAxialAngleDifference(a.Angle, b.Angle);
    
            pairCentrality = exp(-((norm(ca-imageCenter)^2 + norm(cb-imageCenter)^2) / ...
                (2*(2*opts.CenterSigma)^2)));
    
            if isempty(seedPts)
                seedPairScore = pairCentrality;
            else
                dsa = min(vecnorm(seedPts - ca, 2, 2));
                dsb = min(vecnorm(seedPts - cb, 2, 2));
                seedPairScore = exp(-(dsa^2 + dsb^2) / (2*(2*opts.SeedInfluenceRadius)^2));
            end
    
            % Want plaques roughly parallel, with meaningful perpendicular separation.
            geomScore = ...
                exp(-(angleDiff^2) / (2*20^2)) .* ...
                exp(-(sepParallel^2) / (2*40^2)) .* ...
                (1 - exp(-(sepPerp^2) / (2*10^2)));
    
            plaqueStrength = sqrt(max(a.TotalScore,eps) * max(b.TotalScore,eps));
    
            pairScore = plaqueStrength .* (0.25 + 2.0*geomScore) .* ...
                (0.25 + 1.5*pairCentrality + 2.5*seedPairScore);
    
            if pairScore > bestPairScore
                bestPairScore = pairScore;
                bestPair = [i j];
            end
        end
    end
    
    if ~isempty(bestPair) && opts.PreferTwoComponents
        selected = cand(bestPair);
        mode = "pair";
        return
    end
    
    selected = cand(1);
    mode = "top-single";
end

function d = localAxialAngleDifference(a, b)
    d = abs(localWrapTo180(a - b));
    d = min(d, 180 - d);
end

function [Center, Width, Height, info] = localClampRotatedRectToImage(Center, Width, Height, theta, imageSize)
    nRows = imageSize(1);
    nCols = imageSize(2);
    
    U = localAxisU(theta);
    V = localAxisV(theta);
    
    % First try shifting center inward without changing size.
    corners = localRectCorners(Center, Width, Height, U, V);
    xmin = min(corners(:,1)); xmax = max(corners(:,1));
    ymin = min(corners(:,2)); ymax = max(corners(:,2));
    
    shiftX = 0;
    shiftY = 0;
    
    if xmin < 1,     shiftX = shiftX + (1 - xmin);     end
    if xmax > nCols, shiftX = shiftX - (xmax - nCols); end
    if ymin < 1,     shiftY = shiftY + (1 - ymin);     end
    if ymax > nRows, shiftY = shiftY - (ymax - nRows); end
    
    Center = Center + [shiftX shiftY];
    
    % Then shrink if still needed.
    corners = localRectCorners(Center, Width, Height, U, V);
    xmin = min(corners(:,1)); xmax = max(corners(:,1));
    ymin = min(corners(:,2)); ymax = max(corners(:,2));
    
    % Bounding box half-spans due to rotated rect
    halfSpanX = 0.5*(abs(Width*U(1)) + abs(Height*V(1)));
    halfSpanY = 0.5*(abs(Width*U(2)) + abs(Height*V(2)));
    
    maxHalfSpanX = min(Center(1)-1, nCols-Center(1));
    maxHalfSpanY = min(Center(2)-1, nRows-Center(2));
    
    scaleX = 1;
    scaleY = 1;
    
    if halfSpanX > maxHalfSpanX && halfSpanX > 0
        scaleX = maxHalfSpanX / halfSpanX;
    end
    if halfSpanY > maxHalfSpanY && halfSpanY > 0
        scaleY = maxHalfSpanY / halfSpanY;
    end
    
    scale = min([1, scaleX, scaleY]);
    if scale < 1
        Width = Width * scale;
        Height = Height * scale;
    end
    
    Width = max(Width, 1);
    Height = max(Height, 1);
    
    info = struct();
    info.ShiftApplied = [shiftX shiftY];
    info.ScaleApplied = scale;
    info.Corners = localRectCorners(Center, Width, Height, U, V);
end

function corners = localRectCorners(Center, Width, Height, U, V)
    du = 0.5 * Width * U;
    dv = 0.5 * Height * V;
    corners = [
        Center - du - dv
        Center + du - dv
        Center + du + dv
        Center - du + dv];
end

function localDrawRotRect(Center, Width, Height, Angle, lineSpec, lineWidth)
    if nargin < 5, lineSpec = 'w-'; end
    if nargin < 6, lineWidth = 1.5; end
    
    U = [cosd(Angle), -sind(Angle)];
    V = [sind(Angle),  cosd(Angle)];
    
    du = 0.5 * Width * U;
    dv = 0.5 * Height * V;
    
    c1 = Center - du - dv;
    c2 = Center + du - dv;
    c3 = Center + du + dv;
    c4 = Center - du + dv;
    
    X = [c1(1) c2(1) c3(1) c4(1) c1(1)];
    Y = [c1(2) c2(2) c3(2) c4(2) c1(2)];
    
    plot(X, Y, lineSpec, 'LineWidth', lineWidth);
end