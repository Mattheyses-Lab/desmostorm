classdef PointCluster < handle

    properties
        % the group of clusters to which this cluster belongs
        Master (:,1) model.analysis.cluster.PointClusters = model.analysis.cluster.PointClusters.empty()
        % index of this cluster in the master
        Index (1,1) = NaN
        % cluster centroid coordinates (x,y)
        Centroid (1,2) double
        % point to centroid distances
        Distances (:,1) double
        % alpha shape representing convex hull of the cluster points
        Shape (:,1)
    end

    properties (Access=private)
        % private backing for Points
        Points_ (:,2) double
    end

    properties (Dependent)
        % points comprising the cluster (has private backing Points_)
        Points (:,2) double

        % number of points in the cluster
        nPoints (1,1) double
        % standard deviation of point to centroid distances
        DistanceSD (1,1) double
        % area of the convex hull
        HullArea (1,1) double
        % perimeter of the convex hull
        HullPerimeter (1,1) double
        % coordinates of the hull boundary
        Hull (:,2) double

        % ---- PCA / ellipse features ----
        Cov2 (2,2) double              % covariance of centered points
        EigVals (1,2) double           % [lambda1 lambda2], lambda1 >= lambda2
        EigVecs (2,2) double           % eigenvectors corresponding to EigVals
        Anisotropy (1,1) double        % lambda1/lambda2
        Eccentricity (1,1) double      % sqrt(1 - lambda2/lambda1)

        % ---- distance distribution ----
        DistTailRatio (1,1) double     % q90/q50 of point-to-centroid distances

        % ---- nearest-neighbor dispersion ----
        NearestNeighborDistances (:,1) double % per-point NND within cluster
        NNMedian (1,1) double
        NNDispersion (1,1) double      % mad(NND)/median(NND)
        Compactness (1,1) double       % 4*pi*A/P^2 (dimensionless)

        % ---- density ----
        PointDensity (1,1) double      % nPoints / HullArea
    end


    %% constructor, Set/Get for Points, updating
    methods

        function obj = PointCluster(master,points,idx)
            obj.Master = master;
            obj.Index = idx;
            obj.Points = points;
        end

        function pts = get.Points(obj)
            pts = obj.Points_;
        end

        function set.Points(obj,pts)
            obj.Points_ = pts;
            obj.update();
        end

        function update(obj)
            % calculate centroid coordinates
            if isempty(obj.Points) % no points -> delete cluster
                obj.delete();
                return
            end
            % update centroid, distances, and shape
            obj.updateCentroid();
            obj.updateDistances();
            obj.updateShape();
        end

        function updateCentroid(obj)
            obj.Centroid = mean(obj.Points, 1); % geometric mean of point positions
        end

        function updateDistances(obj)
            obj.Distances = sqrt(sum((obj.Points - obj.Centroid).^2, 2));
        end

        function updateShape(obj)
            obj.Shape = alphaShape(obj.Points,Inf,"HoleThreshold",1);
        end

        function setIndex(obj,idx)
            obj.Index = idx;
        end

    end


    %% derived getters
    methods

        function val = get.nPoints(obj)
            val = size(obj.Points,1);
        end

        function val = get.DistanceSD(obj)
            val = std(obj.Distances);
        end

        function val = get.HullArea(obj)
            val = obj.Shape.area();
        end

        function val = get.HullPerimeter(obj)
            val = obj.Shape.perimeter();
        end

        function val = get.Hull(obj)
            [~,val] = obj.Shape.boundaryFacets;
        end

        % -------- NEW: PCA / ellipse features --------

        function C = get.Cov2(obj)
            if obj.nPoints < 2
                C = nan(2,2);
                return
            end
            X = obj.Points - mean(obj.Points,1);
            % Use normalization by (N-1) to match cov() default
            C = (X.'*X) / max(obj.nPoints-1,1);
        end

        function val = get.EigVals(obj)
            if any(isnan(obj.Cov2(:)))
                val = [NaN NaN];
                return
            end
            s = eig(obj.Cov2);
            s = sort(s,'descend');
            if numel(s) < 2
                val = [NaN NaN];
            else
                val = s(:).';
            end
        end

        function V = get.EigVecs(obj)
            if any(isnan(obj.Cov2(:)))
                V = nan(2,2);
                return
            end
            [V,D] = eig(obj.Cov2);
            [~,idx] = sort(diag(D),'descend');
            V = V(:,idx);
        end

        function val = get.Anisotropy(obj)
            l = obj.EigVals;
            if any(isnan(l)) || l(2) <= 0
                val = NaN;
                return
            end
            val = l(1) / l(2);
        end

        function val = get.Eccentricity(obj)
            l = obj.EigVals;
            if any(isnan(l)) || l(1) <= 0 || l(2) < 0
                val = NaN;
                return
            end
            % clamp to [0,1] numerically
            r = max(min(l(2)/l(1),1),0);
            val = sqrt(1 - r);
        end

        % -------- NEW: distance distribution --------

        function val = get.DistTailRatio(obj)
            if isempty(obj.Distances)
                val = NaN;
                return
            end
            d = obj.Distances(:);
            q50 = prctile(d,50);
            q90 = prctile(d,90);
            if q50 <= 0
                val = NaN;
            else
                val = q90 / q50;
            end
        end

        % -------- NEW: nearest-neighbor dispersion --------

        function dnn = get.NearestNeighborDistances(obj)
            n = obj.nPoints;
            if n < 2
                dnn = NaN(0,1);
                return
            end
            % pairwise distances (small clusters only; keep simple for now)
            D = pdist2(obj.Points, obj.Points);
            D(1:n+1:end) = inf; % ignore self-distance
            dnn = min(D,[],2);
        end

        function val = get.NNMedian(obj)
            dnn = obj.NearestNeighborDistances;
            if isempty(dnn) || all(isnan(dnn))
                val = NaN;
            else
                val = median(dnn,'omitnan');
            end
        end

        function val = get.NNDispersion(obj)
            dnn = obj.NearestNeighborDistances;
            if isempty(dnn) || all(isnan(dnn))
                val = NaN;
                return
            end
            m = median(dnn,'omitnan');
            if m <= 0 || isnan(m)
                val = NaN;
                return
            end
            val = mad(dnn,1) / m; % normalized MAD (scale-free)
        end

        % -------- NEW: shape compactness --------

        function val = get.Compactness(obj)
            A = obj.HullArea;
            P = obj.HullPerimeter;
            if isempty(A) || isempty(P) || P <= 0
                val = NaN;
                return
            end
            val = (4*pi*A) / (P^2);
        end

        % -------- NEW: density --------

        function val = get.PointDensity(obj)
            A = obj.HullArea;
            if isempty(A) || A <= 0
                val = NaN;
                return
            end
            val = obj.nPoints / A;
        end

    end

    %% processing and point refinement
    methods

        function removeOutliersNNDistance(obj)
            %REMOVEOUTLIERSNNDISTANCE Remove points whose NN distance
            % > 2.5 std deviations away from median NN distance

            % number of points
            n = obj.nPoints;
            % pairwise distances (small clusters only; keep simple for now)
            D = pdist2(obj.Points, obj.Points);
            D(1:n+1:end) = NaN; % ignore self-distance
            % distance to NN for each point
            DNN = min(D, [], 2, "omitmissing");
            % median NN distance across all points
            DNN_med = median(DNN, "omitmissing");
            % find outlier indices
            badIdx = DNN > (DNN_med + 2.5*std(DNN));
            % Remove outliers
            obj.Points(badIdx, :) = [];
        end

        function removeIsolatedPointsNNSupport(obj, minSupport, rFactor)
            %REMOVEISOLATEDPOINTSNND Remove points or point groups that are locally isolated 
            % based on the number of nearby supporting points within defined radius (DBSCAN lite)
            arguments
                obj
                minSupport (1,1) double {mustBeGreaterThanOrEqual(minSupport,1)} = 4
                rFactor (1,1) double {mustBeGreaterThanOrEqual(rFactor,1)} = 4
            end

            % check inputs
            if ~isvalid(obj), return; end

            n = obj.nPoints;
            if n < 3, return; end

            % all point-to-point distances
            D = pdist2(obj.Points, obj.Points);
            D(1:n+1:end) = NaN;
            % distance to NN for each point
            d1 = min(D, [], 2, "omitmissing");
            % multiply by rFactor to define support radius, r
            r  = rFactor * median(d1, "omitmissing");
            % count neighbor supporting points within radius
            support = sum(D <= r, 2);
            % idxs to points with too few neighbors
            badIdx = support < minSupport;
            % delete bad points
            obj.Points(badIdx,:) = [];
        end

        function removeOutliersDBSCAN(obj)
            % points to cluster
            pts = obj.Points;
            % number of points
            n = obj.nPoints;
            if n < 3, return; end


            fprintf('DBSCAN (cluster %i)\n',obj.Index);
            fprintf('Number of points: %i\n',obj.nPoints);

            % minimum neighbor points
            minPts = 3;

            % all point-to-point distances
            D = pdist2(pts, pts);
            
            % find optimal epsilon value
            epsilon = model.analysis.cluster.chooseDbscanEpsilonKnee(pts,minPts,"SmoothFrac",0.01);
            fprintf('Optimal epsilon: %f\n',epsilon);

            % cluster with DBSCAN (Density-based spatial clustering of applications with noise)
            clusterIdxs = dbscan(D,epsilon,5,"Distance","precomputed");
            % number of noise points rejected (outliers)
            nOutliers = numel(find(clusterIdxs==-1));
            % remove outliers
            obj.Points(clusterIdxs==-1,:) = [];

            fprintf('Removed %i outliers\n',nOutliers);
        end

    end

    %% teardown
    methods
        function delete(obj)
            % create event data payload to carry cluster index
            evt = model.analysis.cluster.ClusterDeletedEvent(obj.Index);
            % notify master we deleted a cluster
            notify(obj.Master,'ClusterDeleted',evt);
        end
    end

end
