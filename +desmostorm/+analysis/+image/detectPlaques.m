function [seedPoints,seedMask] = detectPlaques(I,opts)
%DETECTPLAQUES Detects individual plaques within an individual STORMRegion

    arguments
        % image to detect plaques in
        I

        % size of the box representing each region (so we can make sure all regions are within image bounds)
        opts.BoxSize (1,1) double = 300
        % whether to preprocess input image prior to SURF detection
        opts.Preprocess (1,1) logical = true
        % whether to show SURF detection and cluster results
        opts.DisplayClusterOutput (1,1) logical = false

        opts.MergeClusters (1,1) logical = true
    end

    %% fix input

    % convert to double if needed
    if ~isa(I,"double"), I = im2double(I); end

    % normalize to [0 1]
    I = rescale(I);

    % store size
    sz = size(I);

    %% preprocess image for blob detection - TESTING

    if opts.Preprocess
        I = matlabx.image.process.suppressHotPuncta(I);
    end

    %% start by detecting puncta
    points = matlabx.image.measure.findPuncta(I);

    %% use DBSCAN to coalesce puncta locations into clusters
    clustData = desmostorm.analysis.cluster.PointClusters(points,...
        "MinPointsPerCluster",15,...
        "MaxClusterConvexHullArea",Inf,...
        "MaxEccentricity",0.98,...
        "RefinePoints",false,...
        "Recluster",true,...
        "RefineClusters",false);

    % merge nearby clusters
    if opts.MergeClusters
        clustData.mergeClustersByDistance(opts.BoxSize/3);
    end

    %% filter clusters

    % filter by property
    clustData.filterByProperty('nPoints',[6 Inf]);

    %% keep cluster closest to image center

    % cluster centroid locations
    C = clustData.Centroids;

    % make sure non-empty
    if isempty(C)
        seedPoints = [];
        seedMask = [];
        return
    end

    if clustData.nClusters > 1
        % center of image
        imageCenter = size(I)./2 + 0.5;
        % distance of each cluster centroid to image center
        clustDistToCenter = pdist2(imageCenter,C);
        % find idx of cluster closest to center
        [~,minIdx] = min(clustDistToCenter,[],"all");
        % get all other cluster idxs
        badIdx = setdiff(1:clustData.nClusters,minIdx);
        % delete them
        clustData.deleteClustersByIdx(badIdx);
    end

    %% display intermediate cluster output if requested

    if opts.DisplayClusterOutput

        fH = uifigure("WindowStyle","alwaysontop",...
            "Position",[200 200 700 700],...
            "Visible","off");
    
        ax = matlabx.ui.axes.ImageAxes(fH,...
            "Units","normalized",...
            "Position",[0 0 1 1],...
            "CData",I,...
            "ToolBelt",{'Zoom'},...
            "Colormap",turbo);
    
        clustData.plot(ax.getAxes());
    
        movegui(fH,"north");
    
        fH.Visible = "on";

        T = clustData.exportClusterMetrics;
        disp(T);

    end

    % extract final points
    seedPoints = clustData.Points;

    % build seed mask
    % preallocate mask
    seedMask = false(sz);
    % convert points to linear px idxs
    idx = sub2ind(sz, round(seedPoints(:,2)), round(seedPoints(:,1)));
    % add to mask
    seedMask(idx) = true;


end
