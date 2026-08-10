function Iout = removeIsolatedPuncta(I,opts)
%DETECTPLAQUES Detects individual plaques within an individual STORMRegion

arguments
    I (:,:) {mustBeNumeric(I)}
    opts.MinPunctaPerCluster (1,1) double = 15
    opts.DebugOutput (1,1) logical = false
    opts.DisplayOutput (1,1) logical = false
end

debugOutput = opts.DebugOutput || opts.DisplayOutput;

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
% % grow to cover puncta
%punctaMask = matlabx.image.mask.growSeedMask(I,seedMask,"Threshold",0);
% select full watershed components containing isolated-puncta seeds
punctaMask = desmostorm.analysis.image.selectWatershedSeedLabels(I, ...
    seedMask, ...
    "Threshold",0);

% initialize output image
Iout = I;
% remove isolated puncta by setting their intensity to zero
Iout(punctaMask) = 0;

if debugOutput

    imgCell1 = {I,seedMask,punctaMask,Iout};
    names1 = ["Input","Remove Seeds","Remove Mask","Output"];
    img1 = matlabx.image.Image5D.fromComponents(imgCell1,"Names",names1);

    imgCell2 = {I,Iout};
    names2 = ["Input","Output"];
    img2 = matlabx.image.Image5D.fromComponents(imgCell2,"Names",names2);


    ax1 = matlabx.app.quickshow(img1,"Title","removeIsolatedPuncta Results");
    %ax1.ComponentColorMode = 'luts';
    ax1.ComponentColormaps{1} = turbo;
    ax1.ComponentColormaps{4} = turbo;


    ax2 = matlabx.app.quickshow(img2,"Title","removeIsolatedPuncta Results");
    %ax2.ComponentColorMode = 'luts';
    ax2.ComponentColormaps{1} = turbo;
    ax2.ComponentColormaps{2} = turbo;

    clustData.plot(ax2.getAxes());

    T = clustData.exportClusterMetrics;
    desmostorm.Log.DEBUG(sprintf( ...
        "removeIsolatedPuncta: %d seed point(s), %d cluster(s), %d isolated point(s).", ...
        size(seedPts,1), ...
        height(T), ...
        size(isolatedPts,1)));
end


end
