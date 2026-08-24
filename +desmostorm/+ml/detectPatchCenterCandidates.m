function [centers,clustData] = detectPatchCenterCandidates(I,opts)
%DETECTPATCHCENTERCANDIDATES Find candidate classifier patch centers.
%
% This is a deliberately small first pass for proposal acceleration. It uses
% puncta detections and a fixed point-clustering refinement recipe to identify
% object-rich areas, then returns either cluster centroids or a coarse set of
% sample points inside each cluster hull.

arguments
    I (:,:) {mustBeNumeric}
    opts.Mode (1,1) string {mustBeMember(opts.Mode,["ClusterCentroid","ClusterArea"])} = "ClusterCentroid"
    opts.AreaSampleStride (1,1) double {mustBePositive} = 96
    opts.InitialMinPointsPerCluster (1,1) double {mustBeGreaterThanOrEqual(opts.InitialMinPointsPerCluster,3)} = 3
    opts.SupportMinNeighbors (1,1) double {mustBeGreaterThanOrEqual(opts.SupportMinNeighbors,1)} = 4
    opts.SupportRadiusFactor (1,1) double {mustBeGreaterThanOrEqual(opts.SupportRadiusFactor,1)} = 4
    opts.DistanceSigmaFactor (1,1) double {mustBePositive} = 2.5
    opts.FinalMinPointsPerCluster (1,1) double {mustBeGreaterThanOrEqual(opts.FinalMinPointsPerCluster,1)} = 5
end

% Detect puncta-level points that act as the raw evidence for candidate plaque
% locations. The cluster recipe below tries to reject sparse/noisy detections
% before candidate centers are emitted for classifier scoring.
[points,~] = matlabx.image.measure.detectPuncta(I);
desmostorm.Log.DEBUG(sprintf( ...
    "Detected %d puncta candidate(s) for cluster-guided proposal generation.", ...
    size(points,1)));

% Start permissively so candidate objects are not lost before refinement.
clustData = matlabx.analysis.cluster.PointClusters(points, ...
    "MinPointsPerCluster",opts.InitialMinPointsPerCluster);

% First remove points that lack enough local neighbor support, then rebuild
% clusters from the surviving clustered points.
clustData.refinePoints( ...
    "Method","nnSupport", ...
    "MinSupport",opts.SupportMinNeighbors, ...
    "RadiusFactor",opts.SupportRadiusFactor, ...
    "StageName","SupportRefinedPoints");
clustData.recluster();

% Then remove distance outliers from each cluster and rebuild once more. This
% pass helps keep nearby junk from pulling centroids away from plausible plaque
% centers.
clustData.refinePoints( ...
    "Method","nnDistance", ...
    "SigmaFactor",opts.DistanceSigmaFactor, ...
    "StageName","DistanceRefinedPoints");
clustData.recluster();

% Finally discard clusters that are still too small to be plausible proposal
% sources after point-level cleanup.
clustData.filterByProperty( ...
    "nPoints", ...
    [opts.FinalMinPointsPerCluster Inf], ...
    "Reason","FinalMinPointsPerCluster", ...
    "StageName","FilteredPatchCandidates");

desmostorm.Log.DEBUG(sprintf( ...
    "Cluster-guided proposal generation found %d cluster(s).", ...
    clustData.nClusters));

switch opts.Mode
    case "ClusterCentroid"
        centers = clustData.Centroids;
    case "ClusterArea"
        centers = sampleClusterHullCenters(clustData,opts.AreaSampleStride);
end

end

function centers = sampleClusterHullCenters(clustData,stride)
%SAMPLECLUSTERHULLCENTERS Sample candidate centers inside cluster hulls.
% Each cluster contributes a stride-spaced local grid clipped to its convex
% hull. The centroid is retained as a fallback for small or degenerate hulls.
    centers = zeros(0,2);
    for i = 1:clustData.nClusters
        ck = clustData.Clusters(i);
        hull = ck.Hull;
        if size(hull,1) < 3
            centers = [centers; ck.Centroid]; %#ok<AGROW>
            continue
        end

        x0 = min(hull(:,1)); x1 = max(hull(:,1));
        y0 = min(hull(:,2)); y1 = max(hull(:,2));
        xs = centeredGrid(x0,x1,stride,ck.Centroid(1));
        ys = centeredGrid(y0,y1,stride,ck.Centroid(2));
        [XX,YY] = meshgrid(xs,ys);
        pts = [XX(:) YY(:)];
        in = inpolygon(pts(:,1),pts(:,2),hull(:,1),hull(:,2));
        pts = pts(in,:);

        if isempty(pts)
            pts = ck.Centroid;
        elseif ~any(all(abs(pts - ck.Centroid) < eps,2))
            pts = [ck.Centroid; pts]; %#ok<AGROW>
        end

        centers = [centers; pts]; %#ok<AGROW>
    end

    if ~isempty(centers)
        centers = unique(round(centers,3),"rows","stable");
    end
end

function vals = centeredGrid(lo,hi,stride,anchor)
%CENTEREDGRID Build a stride-spaced vector guaranteed to include anchor.
    vals = anchor;
    vals = [fliplr(anchor-stride:-stride:lo), vals, anchor+stride:stride:hi];
    vals = vals(vals >= lo & vals <= hi);
end
