function [out,clustData] = detectRegions(I,opts)
%DETECTREGIONS Detects regions of interest for new STORMRegion objects

    arguments
        % image to detect regions in
        I
        % maximum numeber of regions to detect
        opts.MaxNumRegions (1,1) double = 25

        % strongest feature threshold for SURF point detection | lower values -> more sensitive
        opts.MetricThreshold (1,1) double {mustBePositive(opts.MetricThreshold)} = 50
        % number of octaves | integer >= 1 | higher values -> larger blobs | recommended values between 1 and 4
        opts.NumOctaves (1,1) double {mustBeGreaterThanOrEqual(opts.NumOctaves,1)} = 3
        % number of scale levels per octave to compute | integer >= 3
        % higher values -> detect more blobs at finer scale increments | recommended values between 3 and 6
        opts.NumScaleLevels (1,1) double {mustBeGreaterThanOrEqual(opts.NumScaleLevels,3)} = 3

        % size of the box representing each region (so we can make sure all regions are within image bounds)
        opts.BoxSize (1,1) double = 300
        % whether to preprocess input image prior to SURF detection
        opts.Preprocess (1,1) logical = true
        % whether to show SURF detection and cluster results
        opts.DisplayClusterOutput (1,1) logical = true
    end

    %% fix input

    % convert to double if needed
    if ~isa(I,"double"), I = im2double(I); end

    % normalize to [0 1]
    I = rescale(I);

    %% preprocess image for blob detection - TESTING

    if opts.Preprocess
        %I = imlocalbrighten(I);
        I = utils.suppressHotPuncta(I);
    end

    %% start by detecting blobs using SURF
    points = model.analysis.image.detectBlobs(I,...
        "MetricThreshold",opts.MetricThreshold,...
        "NumOctaves",opts.NumOctaves,...
        "NumScaleLevels",opts.NumScaleLevels);

    %% use DBSCAN to coalesce SURF point locations into clusters
    clustData = model.analysis.cluster.PointClusters(points,...
        "MinPointsPerCluster",10,...
        "MaxClusterConvexHullArea",Inf,...
        "MaxEccentricity",0.98,...
        "RefinePoints",false,...
        "Recluster",true,...
        "RefineClusters",false);

    % merge nearby clusters
    clustData.mergeClustersByDistance(opts.BoxSize/3);

    % filter by property
    % --- nPoints
    clustData.filterByProperty('nPoints',[6 Inf]);
    % --- HullArea
    clustData.filterByProperty('HullArea',[opts.BoxSize*5 Inf]);

    %% display intermediate cluster output if requested

    if opts.DisplayClusterOutput

        fH = uifigure("WindowStyle","alwaysontop",...
            "Position",[200 200 700 700],...
            "Visible","off");
    
        ax = widgets.ImageAxes(fH,...
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









    %% remove bad centroids (too close too edge)



    % cluster centroid locations
    C = clustData.Centroids;

    % make sure non-empty
    if isempty(C)
        out = [];
        return
    end

    boxSize = opts.BoxSize;

    % snap center to pixel center if boxSize is odd, pixel edge if even
    if mod(boxSize,2)==1
        % Odd size: center must be at integer pixel centers
        C = round(C);
    else
        % Even size: center must be at half-integers (i.e. nearest .5)
        C = floor(C) + 0.5;
    end

    % locate centroids that would place boxes beyond the image limits
    half = boxSize/2;
    badIdx = C(:,1) < (0.5+half) | C(:,1) > (size(I,2)+0.5-half) | C(:,2) < (0.5+half) | C(:,2) > (size(I,1)+0.5-half);

    % Remove bad centroids
    C(badIdx,:) = [];
    
    % Store valid centers in output
    out = C;

end