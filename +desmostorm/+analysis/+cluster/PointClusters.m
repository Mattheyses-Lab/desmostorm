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

        % whether to refine the points included in each cluster
        RefinePoints (1,1) logical = false
        % whether to recluster after refining points
        Recluster (1,1) logical = false
        % whether to refine the clusters after reclustering
        RefineClusters (1,1) logical = false

        MinPointsPerCluster (1,1) = 3
        MaxClusterConvexHullArea (1,1) = Inf
        MaxEccentricity (1,1) = 0.98
        MinPointDensity (1,1) = 0.001

        % kmeans only
        k (1,1) = 2
    end

    %% clustering output
    properties
        % Clusters (:,1) PointCluster = PointCluster.empty()
        Clusters (:,1) desmostorm.analysis.cluster.PointCluster = desmostorm.analysis.cluster.PointCluster.empty()
    end

    properties (Dependent)
        nClusters (1,1)
        Points (:,2) double
        ClusterIdxs (:,1) double
        Centroids (:,2) double
        Distances (:,:) double

        UnclusteredPoints (:,2) double
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

                opts.ClusterMethod (1,:) char {mustBeMember(opts.ClusterMethod,{'dbscan','kmeans'})} = 'dbscan'

                opts.RefinePoints (1,1) logical = false
                opts.Recluster (1,1) logical = true
                opts.RefineClusters (1,1) logical = false
                opts.MinPointsPerCluster (1,1) double = 3
                opts.MaxClusterConvexHullArea (1,1) double = inf
                opts.MaxEccentricity (1,1) double = 1

                opts.k (1,1) {mustBeGreaterThanOrEqual(opts.k,2)} = 2
            end

            if isempty(coords)
                return
            end

            obj.OriginalPoints = coords;
            obj.RefinePoints = opts.RefinePoints;
            obj.Recluster = opts.Recluster;
            obj.RefineClusters = opts.RefineClusters;
            obj.MinPointsPerCluster = opts.MinPointsPerCluster;
            obj.MaxClusterConvexHullArea = opts.MaxClusterConvexHullArea;
            obj.MaxEccentricity = opts.MaxEccentricity;

            obj.L = addlistener(obj,'ClusterDeleted',@(~,evt) obj.onClusterDeleted(evt));

            obj.cluster("ClusterMethod",opts.ClusterMethod);

            if obj.RefinePoints
                obj.refinePoints();
            end

            if obj.Recluster
                obj.recluster();
            end

            if obj.RefineClusters
                obj.refineClusters();
            end


        end

    end




    % processing
    methods

        function cluster(obj,opts)
            arguments
                obj (1,1) desmostorm.analysis.cluster.PointClusters
                opts.ClusterMethod (1,:) char {mustBeMember(opts.ClusterMethod,{'dbscan','kmeans'})} = 'dbscan'
            end

            fprintf('Building initial clusters...\n')

            switch opts.ClusterMethod
                case 'dbscan'
                    obj.dbscan(obj.OriginalPoints,obj.MinPointsPerCluster);
                case 'kmeans'
                    obj.kmeans(obj.OriginalPoints,obj.k);
            end

        end

        function dbscan(obj,pts,minPts)
            arguments
                obj (1,1) desmostorm.analysis.cluster.PointClusters
                % points to cluster
                pts (:,2) double
                % minimum number of neighbors required to form a core point in DBSCAN
                minPts (1,1) double {mustBeGreaterThanOrEqual(minPts,3)} = 5
            end

            fprintf('Clustering points using DBSCAN...\n');
            % number of points
            n = size(pts,1);
            % adjust minPts if needed
            minPts = max(minPts,3);
            % all point-to-point distances
            D = pdist2(pts, pts);
            % find optimal epsilon value
            epsilon = desmostorm.analysis.cluster.chooseDbscanEpsilonKnee(pts,minPts,"SmoothFrac",0.01);
            fprintf('DBSCAN: Optimal epsilon: %f\n',epsilon);
            % cluster with DBSCAN (Density-based spatial clustering of applications with noise)
            clusterIdxs = dbscan(D,epsilon,minPts,"Distance","precomputed");
            % number of clusters
            N = max(clusterIdxs);
            % number of noise points rejected (outliers)
            nOutliers = numel(find(clusterIdxs==-1));
            fprintf('DBSCAN: %i points grouped into %i clusters (%i outliers rejected)\n',n,N,nOutliers);
            % create a PointCluster object to hold the data for each cluster
            obj.Clusters = arrayfun(@(i) ...
                desmostorm.analysis.cluster.PointCluster(...
                    obj,...
                    pts(clusterIdxs==i, :),...
                    i),...
                    1:N, 'UniformOutput', true);
        end

        function kmeans(obj,pts,k)
            arguments
                obj (1,1) desmostorm.analysis.cluster.PointClusters
                % points to cluster
                pts (:,2) double
                % number of clusters
                k (1,1) double {mustBeGreaterThanOrEqual(k,2)} = 2
            end

            fprintf('Clustering points using kmeans...\n');
            % number of points
            n = size(pts,1);
            % cluster with kmeans
            [clusterIdxs, ~] = kmeans(pts, k, "Replicates", 5);
            % number of clusters
            N = max(clusterIdxs);
            fprintf('KMEANS: %i points grouped into %i clusters\n',n,N);
            % create a PointCluster object to hold the data for each cluster
            obj.Clusters = arrayfun(@(i) ...
                desmostorm.analysis.cluster.PointCluster(...
                    obj,...
                    pts(clusterIdxs==i, :),...
                    i),...
                    1:N, 'UniformOutput', true);
        end

        function refinePoints(obj)

            fprintf('Refining points in each cluster...\n')

            % --- remove outliers based on NN distance ---
            %arrayfun(@(C) C.removeOutliersNNDistance(),obj.Clusters);

            % --- remove isolated points in each cluster ---
            %arrayfun(@(C) C.removeIsolatedPointsNNSupport(),obj.Clusters);

            % --- remove outliers by running DBSCAN on each cluster ---
            arrayfun(@(C) C.removeOutliersDBSCAN(),obj.Clusters);

            % reset cluster idxs
            obj.resetNumbering();

        end



        function refineClusters(obj)

            % --- remove clusters with too few points ---
            % idxs to bad clusters
            badIdx = find([obj.Clusters(:).nPoints]<obj.MinPointsPerCluster);
            % output results
            if any(badIdx), fprintf('Deleting %i clusters: # points < MinPointsPerCluster...\n',numel(find(badIdx))); end
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
            % output results
            if any(badIdx), fprintf('Deleting %i clusters: Eccentricity < MaxEccentricity...\n',numel(find(badIdx))); end            
            % delete bad clusters
            obj.deleteClustersByIdx(badIdx);


            % --- remove clusters below point density threshold ---
            % idxs to bad clusters
            badIdx = find([obj.Clusters(:).PointDensity]<obj.MinPointDensity);
            % output results
            if any(badIdx), fprintf('Deleting %i clusters: PointDensity < MinPointDensity...\n',numel(find(badIdx))); end            
            % delete bad clusters
            obj.deleteClustersByIdx(badIdx);


        end



        function recluster(obj,opts)
            % recluster only those points currently in a cluster
            arguments
                obj (1,1) desmostorm.analysis.cluster.PointClusters
                opts.ClusterMethod (1,:) char {mustBeMember(opts.ClusterMethod,{'dbscan','kmeans'})} = 'dbscan'
            end

            fprintf('Reclustering...\n')
            % get points
            pts = obj.Points;
            % randomly shuffle the points
            pts = pts(randperm(size(pts,1)),:);
            % build new clusters
            switch opts.ClusterMethod
                case 'dbscan'
                    obj.dbscan(pts,obj.MinPointsPerCluster);
                case 'kmeans'
                    obj.kmeans(pts,obj.k);
            end

        end


        function mergeClustersByDistance(obj,dist)

            fprintf('Merging clusters with spacing < %d px...\n',dist)

            Nclose = 1;

            while Nclose > 0
                % number of clusters
                N = obj.nClusters;
                % centroids for each
                centroids = obj.Centroids(1:N,:);
                % all centroid to centroid distances
                D = pdist2(centroids, centroids);
                % ignore self-distance
                D(1:N+1:end) = NaN;
                % find all less than dist
                idx = find(D<dist);
                if isempty(idx)
                    break
                end
                % get the idx to the closest distance
                [~,minIdx] = min(D(idx));
                % get actual cluster idxs to merge (subarray idx of D)
                [r,c] = ind2sub([N N],idx(minIdx));
                % merge them
                obj.mergeClustersByIdx([r,c])
                % number of clusters that are too close (minus the one we just merged)
                Nclose = numel(idx);
            end

        end

    end

    %% cluster filtering

    methods

        function filterByProperty(obj,prop,thresh)
            %FILTERBYPROPERTY remove any clusters for which the value of property, prop, falls outside the range, thresh
            arguments
                obj (1,1) desmostorm.analysis.cluster.PointClusters
                % name of property to filter on
                prop (1,:) char {ismember(prop,{'Eccentricity','nPoints','PointDensity','HullArea'})}
                % minimum number of neighbors required to form a core point in DBSCAN
                thresh (1,2) double = [-Inf Inf]
            end

            % get all vals for each cluster
            vals = [obj.Clusters(:).(prop)];
            % idxs to bad clusters (outside thresh range)
            badIdx = find(vals<thresh(1) | vals>thresh(2));
            % output status
            if any(badIdx)
                fprintf('Deleting %i clusters: %s outside range [%d %d]...\n',numel(find(badIdx)),prop,thresh(1),thresh(2));
            end
            % delete bad clusters
            obj.deleteClustersByIdx(badIdx);
            % reset cluster idxs
            obj.resetNumbering();
        end




    end


    %% cluster management (delete, reorder, etc.)
    methods


        function deleteClustersByIdx(obj,idx)
            % delete the cluster(s) specified by indices idx
            delete(obj.Clusters(idx));
        end


        function mergeClustersByIdx(obj,idx)
            if numel(idx) <= 1
                return
            end
            % sort in ascending order
            idx = sort(idx);
            % add points of all clusters to first cluster
            obj.Clusters(idx(1)).Points = vertcat(obj.Clusters(idx).Points);
            % delete other clusters
            delete(obj.Clusters(idx(2:end)))

            % reset cluster idxs
            obj.resetNumbering();
        end

        function resetNumbering(obj)
            fprintf('Resetting cluster numbering...\n')
            arrayfun(@(i) obj.Clusters(i).setIndex(i),1:obj.nClusters);
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

        function pts = get.UnclusteredPoints(obj)
            A = obj.OriginalPoints;
            B = obj.Points;
            inB = ismember(A, B, 'rows');
            pts = A(~inB, :);
        end

    end


    %% callbacks
    methods

        function onClusterDeleted(obj,evt)
            fprintf('Deleted cluster %i\n',evt.Index);
            if isempty(obj.Clusters)
                return
            end
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

            for i = 1:n
                ck = C(i);

                N(i)             = ck.nPoints;
                HullArea(i)      = ck.HullArea;
                HullPerimeter(i) = ck.HullPerimeter;
                PointDensity(i)  = ck.PointDensity;

                DistanceSD(i)    = ck.DistanceSD;
                DistTailRatio(i) = ck.DistTailRatio;

                Anisotropy(i)    = ck.Anisotropy;
                Eccentricity(i)  = ck.Eccentricity;
                Compactness(i)   = ck.Compactness;

                NNMedian(i)      = ck.NNMedian;
                NNDispersion(i)  = ck.NNDispersion;

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