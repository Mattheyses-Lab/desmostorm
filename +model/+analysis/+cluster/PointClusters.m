classdef PointClusters < handle

    % input data
    properties

        % (X,Y) coordinates
        OriginalPoints (:,2) double

    end

    properties (Dependent)
        nPoints (1,1) double
    end

    % clustering input
    properties
        K (:,1) double
        MaxK (:,1) double
        KSelectionMode (1,:) char {mustBeMember(KSelectionMode,{'auto','manual'})} = 'auto'
        Replicates (1,1) double

        % whether to refine the points included in each cluster
        RefinePoints (1,1) logical = true

        % whether to refine the clusters
        RefineClusters (1,1) logical = true

        MinPointsPerCluster (1,1) = 3
        MaxClusterConvexHullArea (1,1) = Inf
        MaxEccentricity (1,1) = 0.98
        MinPointDensity (1,1) = 0.001
    end

    %% clustering output
    properties
        % Clusters (:,1) PointCluster = PointCluster.empty()
        Clusters (:,1)
    end

    properties (Dependent)
        nClusters (1,1)
        Points (:,2) double
        ClusterIdxs (:,1) double
        Centroids (:,2) double
        Distances (:,:) double
    end

    %% events/listeners
    events
        ClusterDeleted
    end

    properties
        L event.listener
    end


    methods

        function obj = PointClusters(coords,opts)
            arguments
                coords (:,2) = []
                opts.K (:,1) double {mustBeGreaterThanOrEqual(opts.K,1)} = []
                opts.MaxK (:,1) double = []
                opts.Replicates (1,1) double = 100

                opts.RefinePoints (1,1) logical = true
                opts.RefineClusters (1,1) logical = true
                opts.MinPointsPerCluster (1,1) double = 3
                opts.MaxClusterConvexHullArea (1,1) double = 100
                opts.MaxEccentricity (1,1) double = 1
            end

            if isempty(coords)
                return
            end

            obj.OriginalPoints = coords;
            obj.Replicates = opts.Replicates;
            obj.RefinePoints = opts.RefinePoints;
            obj.RefineClusters = opts.RefineClusters;
            obj.MinPointsPerCluster = opts.MinPointsPerCluster;
            obj.MaxClusterConvexHullArea = opts.MaxClusterConvexHullArea;
            obj.MaxEccentricity = opts.MaxEccentricity;


            if isempty(opts.MaxK)
                obj.MaxK = size(coords, 1); % Initialize MaxK to the number of points
            else
                obj.MaxK = min(opts.MaxK,size(coords, 1));
            end

            if isempty(opts.K)
                obj.KSelectionMode = 'auto';
            else
                obj.KSelectionMode = 'manual';
                obj.K = opts.K;
            end

            obj.L = addlistener(obj,'ClusterDeleted',@(~,~) obj.onClusterDeleted());


            obj.process();

            if obj.RefinePoints
                obj.refinePoints();
            end

            if obj.RefineClusters
                obj.refineClusters();
            end


        end

    end




    % processing
    methods

        function process(obj)

            % get auto K value if needed
            if isempty(obj.K)
                obj.K = obj.findOptimalK();
            end

            % Perform k-means clustering with the determined K
            [clusterIdxs, centroids, sums, distances] = ...
                kmeans(obj.OriginalPoints,obj.K,'Replicates',obj.Replicates,'Distance','sqeuclidean');

            % create a PointCluster object to hold the data for each cluster
            obj.Clusters = arrayfun(@(i) ...
                model.analysis.cluster.PointCluster(...
                    obj,...
                    obj.OriginalPoints(clusterIdxs==i, :),...
                    centroids(i,:),...
                    distances(clusterIdxs==i,i)),...
                1:obj.K, 'UniformOutput', true);

        end



        function k = findOptimalK(obj,opts)
            arguments
                obj (1,1) model.analysis.cluster.PointClusters
                opts.DisplayEvaluation (1,1) logical = false
            end

            % ClusterIdx = zeros(obj.nPoints,obj.MaxK);
            ClusterIdx = zeros(size(obj.OriginalPoints,1),obj.MaxK);

            pts = obj.OriginalPoints;
            nReplicates = obj.Replicates;

            % set up for parallel computing
            rng(1); % For reproducibility
            stream = RandStream('mlfg6331_64'); % Random number stream
            options = statset('UseParallel',1,'UseSubstreams',1,'Streams',stream);

            for k=1:obj.MaxK
                % run kmeans clustering with k clusters
                [idx,~,~,~] = kmeans(pts,k,...
                    'replicate',nReplicates,...
                    'Distance','sqeuclidean',...
                    'Options',options);
        
                % save the cluster indices for the current number of clusters
                ClusterIdx(:,k) = idx;
            end

            % evaluate clusters using the silhouette criterion
            ClusterEvalObj = evalclusters(obj.OriginalPoints,ClusterIdx,'silhouette','Distance','sqeuclidean');
            k = ClusterEvalObj.OptimalK;

            fprintf("Optimal K: %i\n",k);

            if opts.DisplayEvaluation
                f = uifigure(...
                    'Name','Cluster evaluation',...
                    'HandleVisibility','on',...
                    'WindowStyle','alwaysontop',...
                    'Visible','off');
                ax = uiaxes(f,...
                    "Units","normalized",...
                    "OuterPosition",[0 0 1 1]);
                plot(ax,ClusterEvalObj);
                movegui(f,"center");
                f.Visible = 'On';
            end

        end


        function refinePoints(obj)

            % % --- remove outlier points in each cluster ---
            % % call removeOutliers on each cluster
            % arrayfun(@(C) C.removeOutliers(),obj.Clusters);

            % --- remove isolated points in each cluster ---
            % call removeIsolatedPointsNND on each cluster
            arrayfun(@(C) C.removeIsolatedPointsNND(),obj.Clusters);

            % --- remove outlier points in each cluster ---
            % call removeOutliers on each cluster
            %arrayfun(@(C) C.removeOutliers(),obj.Clusters);

            
            
        end



        function refineClusters(obj)

            % --- remove clusters with too few points ---
            % idxs to bad clusters
            badIdx = find([obj.Clusters(:).nPoints]<obj.MinPointsPerCluster);
            % delete bad clusters
            obj.deleteClustersByIdx(badIdx);

            % --- remove clusters above hull area threshold ---
            % % idxs to bad clusters
            % badIdx = find([obj.Clusters(:).HullArea]>obj.MaxClusterConvexHullArea);
            % % delete bad clusters
            % obj.deleteClustersByIdx(badIdx);

            % --- remove clusters above eccentricity threshold ---
            % idxs to bad clusters
            badIdx = find([obj.Clusters(:).Eccentricity]>obj.MaxEccentricity);
            % delete bad clusters
            obj.deleteClustersByIdx(badIdx);


            % --- remove clusters below point density threshold ---
            % idxs to bad clusters
            badIdx = find([obj.Clusters(:).PointDensity]<obj.MinPointDensity);
            % delete bad clusters
            obj.deleteClustersByIdx(badIdx);


        end





    end


    %% cluster management (delete, reorder, etc.)
    methods


        function deleteClustersByIdx(obj,idx)
            % delete the cluster(s) specified by indices idx
            delete(obj.Clusters(idx));
        end


    end


    %% derived getters
    methods

        function val = get.nPoints(obj)
            %val = size(obj.OriginalPoints,1);

            % return 0 if no clusters
            if isempty(obj.Clusters), val = 0; return, end

            val = sum(obj.Clusters(:).nPoints,"all");
        end

        function val = get.nClusters(obj)
            val = numel(obj.Clusters(isvalid(obj.Clusters)));
        end

        function val = get.Points(obj)
            % return empty if no clusters
            if isempty(obj.Clusters), val = []; return, end
            % concatenate points from all clusters
            val = vertcat(obj.Clusters(:).Points);
        end

        function val = get.ClusterIdxs(obj)
            % return empty if no clusters
            if isempty(obj.Clusters), val = []; return, end
            % preallocate
            val = zeros(obj.nPoints);
            % count points as we iterate through loop
            ctr = 0;
            for i = 1:obj.nClusters
                % number of points in this cluster
                nPts = obj.Clusters(i).nPoints;
                % start and end idxs
                nStart = ctr+1;
                nEnd = ctr+nPts;
                % add the idx (i) for this cluster
                val(nStart:nEnd,:) = i;
                % update ctr to number of points we have indexed so far
                ctr = nEnd;
            end
        end

        function val = get.Centroids(obj)
            % return empty if no clusters
            if isempty(obj.Clusters), val = []; return, end
            % concatenate centroids from all clusters
            val = vertcat(obj.Clusters(:).Centroid);
        end

        function val = get.Distances(obj)
            % return empty if no clusters
            if isempty(obj.Clusters), val = []; return, end
            % concatenate point to centroid distances from all clusters
            val = horzcat(obj.Clusters(:).Distances);
        end

    end


    %% callbacks
    methods

        function onClusterDeleted(obj)
            % remove invalid handles
            obj.Clusters = obj.Clusters(isvalid(obj.Clusters));
        end

    end


    %% plotting
    methods

        function plot(obj,ax)

            hold(ax,"on")

            % plot the original points
            plot(ax,...
                obj.OriginalPoints(:,1),obj.OriginalPoints(:,2),...
                "LineStyle","none",...
                "MarkerFaceColor",[1 1 1],...
                "Marker","x",...
                "MarkerEdgeColor",[1 1 1],...
                "MarkerSize",3);

            colors = distinguishable_colors(obj.nClusters);

            for i = 1:obj.nClusters

                XData = obj.Clusters(i).Points(:,1);
                YData = obj.Clusters(i).Points(:,2);

                try
                    % get the hull boundary points
                    hullPoints = obj.Clusters(i).Hull;
                    % plot the convex hull of the points in cluster i
                    patch(ax,...
                        'XData',hullPoints(:,1),...
                        'YData',hullPoints(:,2),...
                        'FaceColor',colors(i,:),...
                        'HitTest','off',...
                        'PickableParts','none',...
                        'FaceAlpha',0.5);
                catch
                    warning('Not enough unique points to compute hull for cluster %i',i);
                end

                % plot the points in cluster i
                plot(ax,...
                    XData,YData,...
                    "LineStyle","none",...
                    "MarkerFaceColor",colors(i,:),...
                    "Marker","o",...
                    "MarkerEdgeColor",[1 1 1],...
                    "MarkerSize",3);

                % % plot the centroid for cluster i
                % plot(ax,obj.Clusters(i).Centroid(1),obj.Clusters(i).Centroid(2),...
                %     'MarkerSize',15,...
                %     'LineWidth',3,...
                %     'Marker','+',...
                %     'MarkerEdgeColor',[0 0 0]);

                text("Parent",ax,...
                    "Position",obj.Clusters(i).Centroid,...
                    "String",sprintf('%i',i),...
                    "BackgroundColor",[0 0 0 0.5],...
                    "HorizontalAlignment","center",...
                    "VerticalAlignment","middle");

            end

            hold(ax,"off")

        end


    end

    %% summaries

    methods

        function T = exportClusterMetrics(obj)
            %EXPORTCLUSTERMETRICS  Export per-cluster metrics as a table

            C = obj.Clusters;
            n = numel(C);

            % Preallocate (numeric columns default to NaN)
            ClusterID           = (1:n).';
            N                   = nan(n,1);
            HullArea            = nan(n,1);
            HullPerimeter       = nan(n,1);
            PointDensity        = nan(n,1);

            DistanceSD          = nan(n,1);
            DistTailRatio       = nan(n,1);

            Anisotropy          = nan(n,1);
            Eccentricity        = nan(n,1);
            Compactness         = nan(n,1);

            NNMedian            = nan(n,1);
            NNDispersion        = nan(n,1);

            for k = 1:n
                ck = C(k);

                N(k)             = ck.nPoints;
                HullArea(k)      = ck.HullArea;
                HullPerimeter(k) = ck.HullPerimeter;
                PointDensity(k)  = ck.PointDensity;

                DistanceSD(k)    = ck.DistanceSD;
                DistTailRatio(k) = ck.DistTailRatio;

                Anisotropy(k)    = ck.Anisotropy;
                Eccentricity(k)  = ck.Eccentricity;
                Compactness(k)   = ck.Compactness;

                NNMedian(k)      = ck.NNMedian;
                NNDispersion(k)  = ck.NNDispersion;

            end

            T = table( ...
                ClusterID, ...
                N, ...
                HullArea, HullPerimeter, PointDensity, ...
                DistanceSD, DistTailRatio, ...
                Anisotropy, Eccentricity, Compactness, ...
                NNMedian, NNDispersion ...
                );

        end


    end



    %% teardown

    methods


        function delete(obj)
            % remove listeners first
            if ~isempty(obj.L), delete(obj.L(isvalid(obj.L))); end
            % replace listener property with empty array of event.listener
            obj.L = event.listener.empty;

            % delete each cluster
            delete(obj.Clusters(:));

        end



    end




end