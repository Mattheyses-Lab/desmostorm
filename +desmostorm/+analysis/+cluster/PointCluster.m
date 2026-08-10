classdef PointCluster < handle
%POINTCLUSTER Metrics and geometry for one 2-D point cluster.

    properties
        Master (:,1) desmostorm.analysis.cluster.PointClusters = desmostorm.analysis.cluster.PointClusters.empty()
        Index (1,1) double = NaN
        Centroid (1,2) double = [NaN NaN]
        Distances (:,1) double = zeros(0,1)
        Shape = []
    end

    properties (Access=private)
        Points_ (:,2) double = zeros(0,2)
    end

    properties (Dependent)
        Points (:,2) double
        nPoints (1,1) double
        DistanceSD (1,1) double
        HullArea (1,1) double
        HullPerimeter (1,1) double
        Hull (:,2) double

        Cov2 (2,2) double
        EigVals (1,2) double
        EigVecs (2,2) double
        Anisotropy (1,1) double
        Eccentricity (1,1) double

        DistTailRatio (1,1) double

        NearestNeighborDistances (:,1) double
        NNMedian (1,1) double
        NNDispersion (1,1) double
        Compactness (1,1) double

        PointDensity (1,1) double
    end

    methods
        function obj = PointCluster(master,points,idx)
            if nargin >= 1, obj.Master = master; end
            if nargin >= 2, obj.Points = points; end
            if nargin >= 3, obj.Index = idx; end
        end

        function pts = get.Points(obj)
            pts = obj.Points_;
        end

        function set.Points(obj,pts)
            obj.Points_ = pts;
            obj.update();
        end

        function update(obj)
            if isempty(obj.Points)
                obj.Centroid = [NaN NaN];
                obj.Distances = zeros(0,1);
                obj.Shape = [];
                return
            end

            obj.Centroid = mean(obj.Points,1);
            obj.Distances = sqrt(sum((obj.Points - obj.Centroid).^2,2));
            obj.updateShape();
        end

        function updateShape(obj)
            if obj.nPoints < 3 || size(unique(obj.Points,'rows'),1) < 3
                obj.Shape = [];
                return
            end

            obj.Shape = alphaShape(obj.Points,Inf,"HoleThreshold",1);
        end

        function setIndex(obj,idx)
            obj.Index = idx;
        end
    end

    methods
        function val = get.nPoints(obj)
            val = size(obj.Points,1);
        end

        function val = get.DistanceSD(obj)
            val = std(obj.Distances);
        end

        function val = get.HullArea(obj)
            if isempty(obj.Shape), val = NaN; return; end
            val = obj.Shape.area();
        end

        function val = get.HullPerimeter(obj)
            if isempty(obj.Shape), val = NaN; return; end
            val = obj.Shape.perimeter();
        end

        function val = get.Hull(obj)
            if isempty(obj.Shape), val = zeros(0,2); return; end
            [~,val] = obj.Shape.boundaryFacets();
        end

        function C = get.Cov2(obj)
            if obj.nPoints < 2
                C = nan(2,2);
                return
            end
            X = obj.Points - mean(obj.Points,1);
            C = (X.'*X) / max(obj.nPoints-1,1);
        end

        function val = get.EigVals(obj)
            if any(isnan(obj.Cov2(:)))
                val = [NaN NaN];
                return
            end
            val = sort(eig(obj.Cov2),'descend').';
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
            val = sqrt(1 - max(min(l(2)/l(1),1),0));
        end

        function val = get.DistTailRatio(obj)
            if isempty(obj.Distances)
                val = NaN;
                return
            end
            q50 = prctile(obj.Distances,50);
            q90 = prctile(obj.Distances,90);
            if q50 <= 0
                val = NaN;
            else
                val = q90 / q50;
            end
        end

        function dnn = get.NearestNeighborDistances(obj)
            n = obj.nPoints;
            if n < 2
                dnn = zeros(0,1);
                return
            end
            D = pdist2(obj.Points,obj.Points);
            D(1:n+1:end) = inf;
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
            val = mad(dnn,1) / m;
        end

        function val = get.Compactness(obj)
            A = obj.HullArea;
            P = obj.HullPerimeter;
            if isempty(A) || isempty(P) || isnan(A) || isnan(P) || P <= 0
                val = NaN;
                return
            end
            val = (4*pi*A) / (P^2);
        end

        function val = get.PointDensity(obj)
            A = obj.HullArea;
            if isempty(A) || isnan(A) || A <= 0
                val = NaN;
                return
            end
            val = obj.nPoints / A;
        end
    end

    methods
        function removeOutliersNNDistance(obj)
            n = obj.nPoints;
            if n < 3, return; end

            D = pdist2(obj.Points,obj.Points);
            D(1:n+1:end) = NaN;
            dnn = min(D,[],2,"omitmissing");
            dnnMed = median(dnn,"omitmissing");
            badIdx = dnn > (dnnMed + 2.5*std(dnn));
            obj.Points(badIdx,:) = [];
        end

        function removeIsolatedPointsNNSupport(obj,minSupport,rFactor)
            arguments
                obj
                minSupport (1,1) double {mustBeGreaterThanOrEqual(minSupport,1)} = 4
                rFactor (1,1) double {mustBeGreaterThanOrEqual(rFactor,1)} = 4
            end

            if ~isvalid(obj) || obj.nPoints < 3, return; end

            n = obj.nPoints;
            D = pdist2(obj.Points,obj.Points);
            D(1:n+1:end) = NaN;
            d1 = min(D,[],2,"omitmissing");
            r = rFactor * median(d1,"omitmissing");
            support = sum(D <= r,2);
            obj.Points(support < minSupport,:) = [];
        end

        function removeOutliersDBSCAN(obj,minPts)
            arguments
                obj
                minPts (1,1) double {mustBeGreaterThanOrEqual(minPts,3)} = 3
            end

            pts = obj.Points;
            if size(pts,1) < minPts + 1, return; end

            epsilon = desmostorm.analysis.cluster.chooseDbscanEpsilonKnee(pts,minPts,"SmoothFrac",0.01);
            if isnan(epsilon) || epsilon <= 0, return; end

            D = pdist2(pts,pts);
            labels = dbscan(D,epsilon,minPts,"Distance","precomputed");
            obj.Points(labels == -1,:) = [];
        end
    end

end
