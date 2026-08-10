function Iout = removeEdgeClusters(I,opts)
%REMOVEEDGECLUSTERS Remove unclustered puncta and clusters near image edges.
%
% This is an autofit-oriented cleanup step. It keeps the implementation close
% to removeIsolatedPuncta, but broadens the seed selection: unclustered points
% are still removed, and any cluster whose centroid is close to the image edge
% is also marked for removal.

arguments
    I (:,:) {mustBeNumeric(I)}
    opts.MinPunctaPerCluster (1,1) double = 15
    opts.EdgeDistanceFraction (1,1) double {mustBeGreaterThanOrEqual(opts.EdgeDistanceFraction,0),mustBeLessThanOrEqual(opts.EdgeDistanceFraction,1)} = 0.5
    opts.DebugOutput (1,1) logical = false
    opts.DisplayOutput (1,1) logical = false
end

debugOutput = opts.DebugOutput || opts.DisplayOutput;
[H,W] = size(I);

% Locate puncta and cluster them using the same default behavior as
% removeIsolatedPuncta. Keeping these steps parallel makes it easier to tune or
% merge the preprocessing flow later.
[seedPts,~] = matlabx.image.measure.findPuncta(I);
clustData = desmostorm.analysis.cluster.PointClusters(seedPts, ...
    "MinPointsPerCluster",opts.MinPunctaPerCluster, ...
    "RefinePoints",false, ...
    "Recluster",true, ...
    "RefineClusters",false);

isolatedPts = clustData.UnclusteredPoints;
edgeClusterIdx = findEdgeClusterIdx(clustData,W,H,opts.EdgeDistanceFraction);
edgePts = collectClusterPoints(clustData,edgeClusterIdx);

removeSeedPts = [isolatedPts; edgePts];
seedMask = matlabx.image.mask.fromPoints(removeSeedPts,size(I));
removeMask = desmostorm.analysis.image.selectWatershedSeedLabels(I, ...
    seedMask, ...
    "Threshold",0);

Iout = I;
Iout(removeMask) = 0;

if debugOutput
    imgCell = {I,seedMask,removeMask,Iout};
    names = ["Input","Remove Seeds","Remove Mask","Output"];
    img = matlabx.image.Image5D.fromComponents(imgCell,"Names",names);

    imgCell2 = {I,Iout};
    names2 = ["Input","Output"];
    img2 = matlabx.image.Image5D.fromComponents(imgCell2,"Names",names2);

    ax = matlabx.app.quickshow(img,"Title","removeEdgeClusters Results");
    ax.ComponentColormaps{1} = turbo;
    ax.ComponentColormaps{4} = turbo;

    ax2 = matlabx.app.quickshow(img2,"Title","removeEdgeClusters Results");
    ax2.ComponentColormaps{1} = turbo;
    ax2.ComponentColormaps{2} = turbo;


    clustData.plot(ax2.getAxes());

    desmostorm.Log.DEBUG(sprintf( ...
        "removeEdgeClusters: %d seed point(s), %d cluster(s), %d edge cluster(s), %d removal seed point(s).", ...
        size(seedPts,1), ...
        clustData.nClusters, ...
        numel(edgeClusterIdx), ...
        size(removeSeedPts,1)));
end

end

function idx = findEdgeClusterIdx(clustData,W,H,fraction)
%FINDEDGECLUSTERIDX Identify clusters whose centroids are far from center.
    idx = zeros(0,1);
    if clustData.nClusters == 0
        return
    end

    centroids = clustData.Centroids;
    imageCenter = [(W / 2) + 0.5, (H / 2) + 0.5];

    % Pixel centers span roughly (W-1)/2 and (H-1)/2 pixels from image center
    % to image edge. Using that half-span makes fraction=0.5 mean "outside the
    % central half-width/height", which matches the intent of removing junk
    % near image edges.
    xThreshold = fraction * max((W - 1) / 2,1);
    yThreshold = fraction * max((H - 1) / 2,1);

    isEdge = ...
        abs(centroids(:,1) - imageCenter(1)) >= xThreshold | ...
        abs(centroids(:,2) - imageCenter(2)) >= yThreshold;

    idx = find(isEdge);
end

function pts = collectClusterPoints(clustData,idx)
%COLLECTCLUSTERPOINTS Concatenate all points owned by selected clusters.
    pts = zeros(0,2);
    if isempty(idx)
        return
    end

    pts = vertcat(clustData.Clusters(idx).Points);
end
