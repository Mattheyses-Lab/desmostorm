function Iout = removeIsolatedPuncta(I,opts)
%DETECTPLAQUES Detects individual plaques within an individual STORMRegion

arguments
    I (:,:) {mustBeNumeric(I)}
    opts.MinPunctaPerCluster (1,1) double = 15
    opts.DisplayOutput (1,1) logical = false
end

% locate puncta
[seedPts,~] = matlabx.image.measure.findPuncta(I);

% use DBSCAN to coalesce puncta locations into clusters
clustData = desmostorm.analysis.cluster.PointClusters(seedPts,...
    "MinPointsPerCluster",opts.MinPunctaPerCluster,...
    "RefinePoints",false,...
    "Recluster",true,...
    "RefineClusters",false);

% keep only isolated (unclustered) points
isolatedPts = clustData.UnclusteredPoints;

% make seed mask
seedMask = matlabx.image.mask.fromPoints(isolatedPts,size(I));
% grow to cover puncta
punctaMask = matlabx.image.mask.growSeedMask(I,seedMask,"Threshold",0);

% initialize output image
Iout = I;
% remove isolated puncta by setting their intensity to zero
Iout(punctaMask) = 0;

if opts.DisplayOutput

    imgCell = {I,Iout};
    names = ["Input","Output"];

    img = matlabx.image.Image5D.fromComponents(imgCell,"Names",names);


    ax = matlabx.app.quickshow(img);

    clustData.plot(ax.getAxes());

    T = clustData.exportClusterMetrics;
    disp(T);
end


end