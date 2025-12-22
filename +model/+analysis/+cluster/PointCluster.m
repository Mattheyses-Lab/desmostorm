classdef PointCluster < handle

    properties
        % the group of clusters to which this cluster belongs
        Master (1,1) model.analysis.cluster.PointClusters

        Points (:,2) double
        Centroid (1,2) double
        Distances (:,1) double

        % alpha shape representing convex hull of the cluster points
        Shape (:,1)
    end

    properties (Dependent)
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

        % ---- NEW: PCA / ellipse features ----
        Cov2 (2,2) double              % covariance of centered points
        EigVals (1,2) double           % [lambda1 lambda2], lambda1 >= lambda2
        EigVecs (2,2) double           % eigenvectors corresponding to EigVals
        Anisotropy (1,1) double        % lambda1/lambda2
        Eccentricity (1,1) double      % sqrt(1 - lambda2/lambda1)

        % ---- NEW: distance distribution ----
        DistTailRatio (1,1) double     % q90/q50 of point-to-centroid distances

        % ---- NEW: nearest-neighbor dispersion ----
        NearestNeighborDistances (:,1) double % per-point NND within cluster
        NNMedian (1,1) double
        NNDispersion (1,1) double      % mad(NND)/median(NND)

        % ---- NEW: shape compactness ----
        Compactness (1,1) double       % 4*pi*A/P^2 (dimensionless)

        % ---- NEW: density ----
        PointDensity (1,1) double      % nPoints / HullArea

    end


    methods

        function obj = PointCluster(master,points,centroid,distances)
            obj.Master = master;
            obj.Points = points;
            obj.Centroid = centroid;
            obj.Distances = distances;
            obj.Shape = alphaShape(obj.Points,Inf,"HoleThreshold",1);
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

        function updateCentroid(obj)
            % calculate centroid coordinates
            if isempty(obj.Points) % no points -> no centroid -> delete cluster
                obj.delete();
                return
            else % calculate centroid as geometric mean of point positions
                obj.Centroid = mean(obj.Points, 1);
            end
            % Update distances after centroid change
            obj.updateDistances();
            % Update shape after centroid change
            obj.updateShape();
        end

        function updateDistances(obj)
            obj.Distances = sqrt(sum((obj.Points - obj.Centroid).^2, 2));
        end

        function updateShape(obj)
            obj.Shape = alphaShape(obj.Points,Inf,"HoleThreshold",1);
        end

        function removeOutliers(obj)
            % % outlier threshold - 1.5x standard deviation
            % threshold = obj.DistanceSD * 3;
            % % get outlier idxs
            % outlierIndices = obj.Distances > threshold;
            % % Remove outliers
            % obj.Points(outlierIndices, :) = [];
            % % Update centroid after removal
            % obj.updateCentroid();


            % --- method 2: point-to-point distances

            n = obj.nPoints;

            % pairwise distances (small clusters only; keep simple for now)
            D = pdist2(obj.Points, obj.Points);
            D(1:n+1:end) = NaN; % ignore self-distance

            % mean point-to-point distance for each point
            Dmean_point = mean(D,2,'omitmissing');

            % mean point-to-point distance across all points
            Dmean_cluster = mean(Dmean_point,1);

            % find outlier indices
            badIdx = Dmean_point > (Dmean_cluster + 2.5*std(Dmean_point));

            % Remove outliers
            obj.Points(badIdx, :) = [];
            % Update centroid after removal
            obj.updateCentroid();




        end


        function removeIsolatedPointsNND(obj, k)
            %REMOVEISOLATEDPOINTSNND Remove points that are locally isolated based on
            % nearest-neighbor distance (NND) outliers.
            %
            % k: threshold multiplier on MAD (typical 2 to 3). Default = 2.5
            arguments
                obj
                k (1,1) double {mustBeGreaterThanOrEqual(k,2)} = 2
            end

            % 
            % if nargin < 2 || isempty(k)
            %     k = 2.5;
            % end

            n = obj.nPoints;
            if n < 3
                return
            end

            % Pairwise distances
            dnn = obj.NearestNeighborDistances;


            % --- method 1 ---
            % % Robust threshold: median + k*MAD
            % d0 = median(dnn, 'omitnan');
            % s  = mad(dnn, 1);                   % median absolute deviation (robust)
            % thr = d0 + k*s;
            % 
            % % Remove isolated points
            % badIdx = dnn > thr;
            % obj.Points(badIdx,:) = [];
            % obj.updateCentroid();
            % 
            % % run again until we stop removing points
            % if numel(find(badIdx)) > 0
            %     obj.removeIsolatedPointsNND(k);
            % end



            % --- method 2 ---

            minSupport = 4;
            rFactor = 4;


            D = pdist2(obj.Points, obj.Points);
            D(1:n+1:end) = inf;
        
            % Use typical within-plaque spacing: median 1-NN distance
            d1 = min(D, [], 2);
            r  = rFactor * median(d1, 'omitnan');
        
            % Neighbor support count within radius r
            support = sum(D <= r, 2);
        
            badIdx = support < minSupport;
            obj.Points(badIdx,:) = [];
            obj.updateCentroid();

        end







    end


    methods

        function delete(obj)
            % notify master we deleted a cluster
            notify(obj.Master,'ClusterDeleted');
        end

    end


end
