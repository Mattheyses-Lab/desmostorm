classdef PointClusters < handle
%POINTCLUSTERS Cluster and summarize 2-D point detections.

    properties
        OriginalPoints (:,2) double = zeros(0,2)
        Labels (:,1) double = zeros(0,1)
        NoisePoints (:,2) double = zeros(0,2)
        Epsilon (1,1) double = NaN
        Verbose (1,1) logical = false
    end

    properties
        RefinePoints (1,1) logical = false
        Recluster (1,1) logical = false
        RefineClusters (1,1) logical = false

        MinPointsPerCluster (1,1) double = 3
        MaxClusterConvexHullArea (1,1) double = Inf
        MaxEccentricity (1,1) double = 0.98
        MinPointDensity (1,1) double = 0.001

        k (1,1) double = 2
    end

    properties
        Clusters (:,1) desmostorm.analysis.cluster.PointCluster = desmostorm.analysis.cluster.PointCluster.empty()
    end

    properties (Dependent)
        nPoints (1,1) double
        nClusters (1,1) double
        Points (:,2) double
        ClusterIdxs (:,1) double
        Centroids (:,2) double
        Distances (:,1) double
        UnclusteredPoints (:,2) double
        Summary table
    end

    events
        ClusterDeleted
    end

    methods
        function obj = PointClusters(coords,opts)
            arguments
                coords (:,2) double = zeros(0,2)

                opts.ClusterMethod (1,:) char {mustBeMember(opts.ClusterMethod,{'dbscan','kmeans'})} = 'dbscan'
                opts.Verbose (1,1) logical = false

                opts.RefinePoints (1,1) logical = false
                opts.Recluster (1,1) logical = true
                opts.RefineClusters (1,1) logical = false
                opts.MinPointsPerCluster (1,1) double = 3
                opts.MaxClusterConvexHullArea (1,1) double = Inf
                opts.MaxEccentricity (1,1) double = 1
                opts.MinPointDensity (1,1) double = 0.001

                opts.k (1,1) double {mustBeGreaterThanOrEqual(opts.k,2)} = 2
            end

            obj.Verbose = opts.Verbose;
            obj.RefinePoints = opts.RefinePoints;
            obj.Recluster = opts.Recluster;
            obj.RefineClusters = opts.RefineClusters;
            obj.MinPointsPerCluster = opts.MinPointsPerCluster;
            obj.MaxClusterConvexHullArea = opts.MaxClusterConvexHullArea;
            obj.MaxEccentricity = opts.MaxEccentricity;
            obj.MinPointDensity = opts.MinPointDensity;
            obj.k = opts.k;

            if isempty(coords)
                return
            end

            obj.OriginalPoints = coords;
            obj.cluster("ClusterMethod",opts.ClusterMethod);

            if obj.RefinePoints
                obj.refinePoints();
            end

            if obj.Recluster
                obj.recluster("ClusterMethod",opts.ClusterMethod);
            end

            if obj.RefineClusters
                obj.refineClusters();
            end
        end
    end

    methods
        function cluster(obj,opts)
            arguments
                obj (1,1) desmostorm.analysis.cluster.PointClusters
                opts.ClusterMethod (1,:) char {mustBeMember(opts.ClusterMethod,{'dbscan','kmeans'})} = 'dbscan'
            end

            obj.log("Building initial clusters...");
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
                pts (:,2) double
                minPts (1,1) double {mustBeGreaterThanOrEqual(minPts,3)} = 5
            end

            obj.clearClusters();
            obj.Labels = -1*ones(size(pts,1),1);
            obj.NoisePoints = pts;
            obj.Epsilon = NaN;

            if size(pts,1) < minPts + 1
                obj.log("DBSCAN skipped: not enough points.");
                return
            end

            epsilon = desmostorm.analysis.cluster.chooseDbscanEpsilonKnee(pts,minPts,"SmoothFrac",0.01);
            if isnan(epsilon) || epsilon <= 0
                obj.log("DBSCAN skipped: invalid epsilon.");
                return
            end

            D = pdist2(pts,pts);
            labels = dbscan(D,epsilon,minPts,"Distance","precomputed");
            obj.Epsilon = epsilon;
            obj.createClustersFromLabels(pts,labels);

            obj.log(sprintf( ...
                "DBSCAN: %d points grouped into %d cluster(s), %d noise point(s), epsilon %.4g.", ...
                size(pts,1),obj.nClusters,size(obj.NoisePoints,1),obj.Epsilon));
        end

        function kmeans(obj,pts,k)
            arguments
                obj (1,1) desmostorm.analysis.cluster.PointClusters
                pts (:,2) double
                k (1,1) double {mustBeGreaterThanOrEqual(k,2)} = 2
            end

            obj.clearClusters();
            obj.Labels = -1*ones(size(pts,1),1);
            obj.NoisePoints = zeros(0,2);
            obj.Epsilon = NaN;

            if size(pts,1) < k
                obj.NoisePoints = pts;
                obj.log("KMEANS skipped: not enough points.");
                return
            end

            labels = kmeans(pts,k,"Replicates",5);
            obj.createClustersFromLabels(pts,labels);
            obj.log(sprintf("KMEANS: %d points grouped into %d cluster(s).",size(pts,1),obj.nClusters));
        end

        function refinePoints(obj)
            obj.log("Refining points in each cluster...");

            for i = 1:obj.nClusters
                obj.Clusters(i).removeOutliersDBSCAN();
            end

            obj.removeEmptyClusters();
            obj.resetNumbering();
        end

        function refineClusters(obj)
            obj.deleteClustersByIdx(find([obj.Clusters(:).nPoints] < obj.MinPointsPerCluster));

            badIdx = find([obj.Clusters(:).HullArea] > obj.MaxClusterConvexHullArea);
            obj.deleteClustersByIdx(badIdx);

            badIdx = find([obj.Clusters(:).Eccentricity] > obj.MaxEccentricity);
            obj.deleteClustersByIdx(badIdx);

            badIdx = find([obj.Clusters(:).PointDensity] < obj.MinPointDensity);
            obj.deleteClustersByIdx(badIdx);
        end

        function recluster(obj,opts)
            arguments
                obj (1,1) desmostorm.analysis.cluster.PointClusters
                opts.ClusterMethod (1,:) char {mustBeMember(opts.ClusterMethod,{'dbscan','kmeans'})} = 'dbscan'
            end

            pts = obj.Points;
            if isempty(pts)
                obj.clearClusters();
                return
            end

            obj.log("Reclustering clustered points...");
            pts = pts(randperm(size(pts,1)),:);

            switch opts.ClusterMethod
                case 'dbscan'
                    obj.dbscan(pts,obj.MinPointsPerCluster);
                case 'kmeans'
                    obj.kmeans(pts,obj.k);
            end
        end

        function mergeClustersByDistance(obj,dist)
            arguments
                obj (1,1) desmostorm.analysis.cluster.PointClusters
                dist (1,1) double {mustBeNonnegative}
            end

            while obj.nClusters > 1
                centroids = obj.Centroids;
                D = pdist2(centroids,centroids);
                D(1:obj.nClusters+1:end) = NaN;
                [minVal,idx] = min(D,[],"all","omitnan");
                if isempty(minVal) || isnan(minVal) || minVal >= dist
                    break
                end

                [r,c] = ind2sub(size(D),idx);
                obj.mergeClustersByIdx([r c]);
            end
        end

        function filterByProperty(obj,prop,thresh)
            arguments
                obj (1,1) desmostorm.analysis.cluster.PointClusters
                prop (1,:) char {mustBeMember(prop,{'Eccentricity','nPoints','PointDensity','HullArea'})}
                thresh (1,2) double = [-Inf Inf]
            end

            if obj.nClusters == 0, return; end

            vals = [obj.Clusters(:).(prop)];
            badIdx = find(vals < thresh(1) | vals > thresh(2) | isnan(vals));
            obj.deleteClustersByIdx(badIdx);
        end
    end

    methods
        function createClustersFromLabels(obj,pts,labels)
            obj.clearClusters();
            obj.Labels = labels(:);
            obj.NoisePoints = pts(obj.Labels == -1,:);

            clusterIDs = unique(obj.Labels(obj.Labels > 0),'stable');
            for i = 1:numel(clusterIDs)
                obj.Clusters(i,1) = desmostorm.analysis.cluster.PointCluster( ...
                    obj, ...
                    pts(obj.Labels == clusterIDs(i),:), ...
                    i);
            end
        end

        function clearClusters(obj)
            if ~isempty(obj.Clusters)
                delete(obj.Clusters(isvalid(obj.Clusters)));
            end
            obj.Clusters = desmostorm.analysis.cluster.PointCluster.empty();
        end

        function deleteClustersByIdx(obj,idx)
            idx = obj.normalizeClusterIndex(idx);
            if isempty(idx), return; end

            dying = obj.Clusters(idx);
            obj.Clusters(idx) = [];
            delete(dying(isvalid(dying)));
            obj.resetNumbering();
        end

        function mergeClustersByIdx(obj,idx)
            idx = obj.normalizeClusterIndex(idx);
            if numel(idx) <= 1, return; end

            idx = sort(idx);
            mergedPoints = vertcat(obj.Clusters(idx).Points);
            dying = obj.Clusters(idx(2:end));
            obj.Clusters(idx(1)).Points = mergedPoints;
            obj.Clusters(idx(2:end)) = [];
            delete(dying(isvalid(dying)));
            obj.resetNumbering();
        end

        function resetNumbering(obj)
            obj.removeInvalidClusters();
            for i = 1:obj.nClusters
                obj.Clusters(i).setIndex(i);
            end
        end

        function removeEmptyClusters(obj)
            if isempty(obj.Clusters), return; end
            obj.deleteClustersByIdx(find([obj.Clusters(:).nPoints] == 0));
        end

        function removeInvalidClusters(obj)
            if isempty(obj.Clusters), return; end
            obj.Clusters = obj.Clusters(isvalid(obj.Clusters));
        end
    end

    methods
        function val = get.nPoints(obj)
            if isempty(obj.Clusters), val = 0; return; end
            val = sum([obj.Clusters(:).nPoints]);
        end

        function val = get.nClusters(obj)
            if isempty(obj.Clusters)
                val = 0;
            else
                val = numel(obj.Clusters(isvalid(obj.Clusters)));
            end
        end

        function val = get.Points(obj)
            if isempty(obj.Clusters), val = zeros(0,2); return; end
            val = vertcat(obj.Clusters(:).Points);
        end

        function val = get.ClusterIdxs(obj)
            if isempty(obj.Clusters), val = zeros(0,1); return; end

            val = zeros(obj.nPoints,1);
            ctr = 0;
            for i = 1:obj.nClusters
                nPts = obj.Clusters(i).nPoints;
                val(ctr+1:ctr+nPts) = i;
                ctr = ctr + nPts;
            end
        end

        function val = get.Centroids(obj)
            if isempty(obj.Clusters), val = zeros(0,2); return; end
            val = vertcat(obj.Clusters(:).Centroid);
        end

        function val = get.Distances(obj)
            if isempty(obj.Clusters), val = zeros(0,1); return; end
            val = vertcat(obj.Clusters(:).Distances);
        end

        function pts = get.UnclusteredPoints(obj)
            if isempty(obj.OriginalPoints)
                pts = zeros(0,2);
                return
            end

            clusteredPts = obj.Points;
            if isempty(clusteredPts)
                pts = obj.OriginalPoints;
                return
            end

            % "Unclustered" is the model-level ownership state: any original
            % detection point that is not currently owned by a live cluster.
            % This includes DBSCAN noise as well as points orphaned by cluster
            % deletion/refinement/reclustering.
            pts = setdiff(obj.OriginalPoints,clusteredPts,"rows","stable");
        end

        function T = get.Summary(obj)
            T = obj.exportClusterMetrics();
        end
    end

    methods
        function plot(obj,ax)
            hold(ax,"on")

            if ~isempty(obj.OriginalPoints)
                plot(ax,obj.OriginalPoints(:,1),obj.OriginalPoints(:,2), ...
                    "LineStyle","none", ...
                    "Marker","x", ...
                    "MarkerEdgeColor",[1 1 1], ...
                    "MarkerSize",3);
            end

            if obj.nClusters > 0
                colors = lines(obj.nClusters);
            else
                colors = zeros(0,3);
            end

            for i = 1:obj.nClusters
                XData = obj.Clusters(i).Points(:,1);
                YData = obj.Clusters(i).Points(:,2);
                hullPoints = obj.Clusters(i).Hull;

                if ~isempty(hullPoints)
                    patch(ax, ...
                        "XData",hullPoints(:,1), ...
                        "YData",hullPoints(:,2), ...
                        "FaceColor",colors(i,:), ...
                        "HitTest","off", ...
                        "PickableParts","none", ...
                        "FaceAlpha",0.25);
                end

                plot(ax,XData,YData, ...
                    "LineStyle","none", ...
                    "MarkerFaceColor",colors(i,:), ...
                    "Marker","o", ...
                    "MarkerEdgeColor",[1 1 1], ...
                    "MarkerSize",3);

                text("Parent",ax, ...
                    "Position",obj.Clusters(i).Centroid, ...
                    "String",sprintf('%i',i), ...
                    "BackgroundColor",[0 0 0 0.5], ...
                    "HorizontalAlignment","center", ...
                    "VerticalAlignment","middle");
            end

            if ~isempty(obj.NoisePoints)
                plot(ax,obj.NoisePoints(:,1),obj.NoisePoints(:,2), ...
                    "LineStyle","none", ...
                    "Marker",".", ...
                    "MarkerEdgeColor",[0.8 0.8 0.8], ...
                    "MarkerSize",8);
            end

            hold(ax,"off")
        end

        function T = exportClusterMetrics(obj)
            C = obj.Clusters;
            n = numel(C);

            ClusterID = (1:n).';
            N = nan(n,1);
            HullArea = nan(n,1);
            HullPerimeter = nan(n,1);
            PointDensity = nan(n,1);
            DistanceSD = nan(n,1);
            DistTailRatio = nan(n,1);
            Anisotropy = nan(n,1);
            Eccentricity = nan(n,1);
            Compactness = nan(n,1);
            NNMedian = nan(n,1);
            NNDispersion = nan(n,1);

            for i = 1:n
                ck = C(i);
                N(i) = ck.nPoints;
                HullArea(i) = ck.HullArea;
                HullPerimeter(i) = ck.HullPerimeter;
                PointDensity(i) = ck.PointDensity;
                DistanceSD(i) = ck.DistanceSD;
                DistTailRatio(i) = ck.DistTailRatio;
                Anisotropy(i) = ck.Anisotropy;
                Eccentricity(i) = ck.Eccentricity;
                Compactness(i) = ck.Compactness;
                NNMedian(i) = ck.NNMedian;
                NNDispersion(i) = ck.NNDispersion;
            end

            T = table( ...
                ClusterID, ...
                N, ...
                HullArea, ...
                HullPerimeter, ...
                PointDensity, ...
                DistanceSD, ...
                DistTailRatio, ...
                Anisotropy, ...
                Eccentricity, ...
                Compactness, ...
                NNMedian, ...
                NNDispersion);
        end
    end

    methods (Access=private)
        function idx = normalizeClusterIndex(obj,idx)
            if isempty(idx), idx = []; return; end

            if islogical(idx)
                idx = find(idx);
            end

            idx = unique(idx(:).');
            idx = idx(idx >= 1 & idx <= obj.nClusters);
        end

        function log(obj,msg)
            if obj.Verbose
                desmostorm.Log.DEBUG(msg);
            end
        end
    end

    methods
        function delete(obj)
            obj.clearClusters();
        end
    end

end
