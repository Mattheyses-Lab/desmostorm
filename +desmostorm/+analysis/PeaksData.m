classdef PeaksData

    % input data
    properties
        Signal (:,1) double  % signal values
        Location (:,1) double  % signal value location vector (distance/time/etc)
    end

    % processed input
    properties
        SignalNorm   (:,1) double
        SignalSmooth (:,1) double
    end

    % analysis settings
    properties
        Normalize               (1,1) logical
        Smooth                  (1,1) logical
        MinPeakDistance         (1,1) double
        MinPeakHeight           (1,1) double
        MinPeakHeightMode       (1,:) char
        MinPeakProminence       (1,1) double
        MinPeakProminenceMode   (1,:) char
        PeakSmoothing           (1,1) double
        WidthReference          (1,:) char
        DistanceScale           (1,1) double
        DistanceUnit            (1,:) char
        RecomputeWidths         (1,1) logical % T/F - whether to recompute widths from findpeaks() to match FWHM annotations
    end

    % primary output measurements
    properties
        PeakValues      (:,1) double = []
        PeakLocations   (:,1) double = []
        PeakWidths      (:,1) double = []
        PeakProminences (:,1) double = []
        PeakDistances   (:,1) double = []
    end

    % additional collected outputs for central peak pair (if it exists)
    properties
        % CentralPeakPairValues      (:,1) double = []
        % CentralPeakPairLocations   (:,1) double = []
        % CentralPeakPairWidths      (:,1) double = []
        % CentralPeakPairProminences (:,1) double = []
        CentralPeakPairDistance    (:,1) double = []

        LeftPeakIdx         (:,1) double = []
        LeftPeakValue       (:,1) double = []
        LeftPeakLocation    (:,1) double = []
        LeftPeakWidth       (:,1) double = []
        LeftPeakProminence  (:,1) double = []

        RightPeakIdx         (:,1) double = []
        RightPeakValue       (:,1) double = []
        RightPeakLocation    (:,1) double = []
        RightPeakWidth       (:,1) double = []
        RightPeakProminence  (:,1) double = []
    end

    % analysis geometry derived from detected peaks
    properties
        PeakGeometry struct = desmostorm.analysis.PeaksData.emptyPeakGeometry()
    end

    % output structs
    properties(Dependent)
        OutputRaw       struct
        OutputScaled    struct
    end

    % other derived outputs
    properties(Dependent)
        nPeaks              (1,1) double
        hasCentralPeakPair  (1,1) logical
        hasLeftPeak         (1,1) logical
        hasRightPeak        (1,1) logical
    end


    methods
        function obj = PeaksData(Signal,Location,opts)
            arguments
                Signal                      (:,1) double
                Location                    (:,1) double
                opts.Normalize              (1,1) logical   = true
                opts.Smooth                 (1,1) logical   = true
                opts.MinPeakDistance        (1,1) double    = 0
                opts.MinPeakHeight          (1,1) double    = 0
                opts.MinPeakHeightMode      (1,:) char {ismember(opts.MinPeakHeightMode,{'absolute','relative'})} = 'relative'
                opts.MinPeakProminence      (1,1) double    = 0
                opts.MinPeakProminenceMode  (1,:) char {ismember(opts.MinPeakProminenceMode,{'absolute','relative'})} = 'relative'
                opts.PeakSmoothing          (1,1) double    = 15
                opts.WidthReference         (1,:) char      = 'halfheight'
                opts.DistanceScale          (1,1) double    = 1
                opts.DistanceUnit           (1,:) char      = 'px'
                opts.RecomputeWidths        (1,1) logical   = true
            end
            % collect inputs
            obj.Signal = Signal;
            obj.Location = Location;
            obj.Normalize = opts.Normalize;
            obj.Smooth = opts.Smooth;
            obj.MinPeakDistance = opts.MinPeakDistance;
            obj.MinPeakHeight = opts.MinPeakHeight;
            obj.MinPeakHeightMode = opts.MinPeakHeightMode;
            obj.MinPeakProminence = opts.MinPeakProminence;
            obj.MinPeakProminenceMode = opts.MinPeakProminenceMode;
            obj.PeakSmoothing = opts.PeakSmoothing;
            obj.WidthReference = opts.WidthReference;
            obj.DistanceScale = opts.DistanceScale;
            obj.DistanceUnit = opts.DistanceUnit;
            obj.RecomputeWidths = opts.RecomputeWidths;
            % process the data
            obj = obj.process();
        end

        function obj = process(obj)
            % --- SMOOTH AND NORMALIZE THE RAW INPUT SIGNAL ---
            % normalize the raw signal if required (use the raw signal if ~obj.Normalize)
            if obj.Normalize
                obj.SignalNorm = desmostorm.analysis.PeaksData.normalizeSignal(obj.Signal);
            else
                obj.SignalNorm = obj.Signal;
            end
            % smooth the normalized signal if required (use the normalized signal if ~obj.Smooth)
            if obj.Smooth
                obj.SignalSmooth = desmostorm.analysis.PeaksData.smooth(obj.SignalNorm,obj.PeakSmoothing);
            else
                obj.SignalSmooth = obj.SignalNorm;
            end
            % --- DETECT PEAKS USING findpeaks() ---
            out = desmostorm.analysis.PeaksData.detect(obj.SignalSmooth, ...
                obj.Location, ...
                obj.MinPeakDistance, ...
                obj.MinPeakHeight, ...
                obj.MinPeakProminence, ...
                obj.WidthReference, ...
                'MinPeakHeightMode', obj.MinPeakHeightMode, ...
                'MinPeakProminenceMode', obj.MinPeakProminenceMode);
            obj.PeakValues = out.PeakValues;
            obj.PeakLocations = out.PeakLocations;
            obj.PeakWidths = out.PeakWidths;
            obj.PeakProminences = out.PeakProminences;
            obj.PeakDistances = out.PeakDistances;
            % --- GET ANALYSIS GEOMETRY FOR PEAK WIDTHS/BORDERS ---
            geom = desmostorm.analysis.PeaksData.getPeakGeometry( ...
                obj.SignalSmooth, ...
                obj.Location, ...
                obj.PeakValues, ...
                obj.PeakLocations, ...
                obj.PeakProminences, ...
                "WidthReference",obj.WidthReference);
            obj.PeakGeometry = geom;
            % if required, replace PeakWidths from findpeaks() with those measured directly from the FWHM lines
            if obj.RecomputeWidths && ~isempty(geom)
                obj.PeakWidths = reshape([geom.Width],[],1);
            end

            % --- COLLECT OUTPUT STATS FOR CENTRAL PEAK PAIR ---
            out = obj.getCentralPeakPairStats();
            obj.LeftPeakIdx             = out.LeftPeakIdx;
            obj.LeftPeakValue           = out.LeftPeakValue;
            obj.LeftPeakLocation        = out.LeftPeakLocation;
            obj.LeftPeakWidth           = out.LeftPeakWidth;
            obj.LeftPeakProminence      = out.LeftPeakProminence;
            obj.RightPeakIdx            = out.RightPeakIdx;
            obj.RightPeakValue          = out.RightPeakValue;
            obj.RightPeakLocation       = out.RightPeakLocation;
            obj.RightPeakWidth          = out.RightPeakWidth;
            obj.RightPeakProminence     = out.RightPeakProminence;
            obj.CentralPeakPairDistance = out.CentralPeakPairDistance;
        end


        function [h,ax] = plot(obj,opts)
            arguments
                obj         (1,1) desmostorm.analysis.PeaksData
                opts.Parent (:,1) matlab.ui.control.UIAxes = matlab.ui.control.UIAxes.empty()
            end

            if isempty(opts.Parent)
                pos = matlabx.UICal.centeredFigOuterPosition(750,350);
                fig = uifigure(...
                    "WindowStyle","alwaysontop",...
                    "Units","pixels",...
                    "OuterPosition",pos,...
                    "Theme","light",...
                    "Color",[1 1 1]);
                ax = uiaxes(fig,"Units","normalized","OuterPosition",[0 0 1 1]);
            else
                ax = opts.Parent;
            end
            h = widgets.PeaksPlot(ax,obj);
        end

    end


    %% extra analysis helpers
    methods

        function out = getCentralPeakPairStats(obj)

            % initialize struct
            out = struct(...
                'LeftPeakIdx',              [], ...
                'LeftPeakValue',            [], ...
                'LeftPeakLocation',         [], ...
                'LeftPeakWidth',            [], ...
                'LeftPeakProminence',       [], ...
                'RightPeakIdx',             [], ...
                'RightPeakValue',           [], ...
                'RightPeakLocation',        [], ...
                'RightPeakWidth',           [], ...
                'RightPeakProminence',      [], ...
                'CentralPeakPairDistance',  []);

            % make sure we have at least 1 peak
            if obj.nPeaks == 0, return; end

            % convert peak locations to idxs
            locs = obj.PeakLocations;
            locs = arrayfun(@(loc) find(obj.Location==loc,1),locs);

            % convert location vector to idxs
            nSamples = numel(obj.Location);
            %Xidx = 1:nSamples;

            % find central peak pair, first peak to the left and right of the signal midpoint
            midIdx = nSamples/2;

            % first peak moving left from the middle of the signal
            %peakIdx1 = find(locs<midIdx,1,"last");
            leftPeakIdx = find(locs<midIdx,1,"last");

            % first peak moving right from the middle of the signal
            % peakIdx2 = find(locs>midIdx,1,"first");
            rightPeakIdx = find(locs>midIdx,1,"first");

            % assign left peak stats
            if ~isempty(leftPeakIdx)
                out.LeftPeakIdx             = leftPeakIdx;
                out.LeftPeakValue           = obj.PeakValues(leftPeakIdx);
                out.LeftPeakLocation        = obj.PeakLocations(leftPeakIdx);
                out.LeftPeakWidth           = obj.PeakWidths(leftPeakIdx);
                out.LeftPeakProminence      = obj.PeakProminences(leftPeakIdx);

            end

            % assign right peak stats
            if ~isempty(rightPeakIdx)
                out.RightPeakIdx            = rightPeakIdx;
                out.RightPeakValue          = obj.PeakValues(rightPeakIdx);
                out.RightPeakLocation       = obj.PeakLocations(rightPeakIdx);
                out.RightPeakWidth          = obj.PeakWidths(rightPeakIdx);
                out.RightPeakProminence     = obj.PeakProminences(rightPeakIdx);
            end

            % get central peak pair distance if possible
            if ~isempty(leftPeakIdx) && ~isempty(rightPeakIdx)
                out.CentralPeakPairDistance = obj.PeakDistances(leftPeakIdx);
            end

        end

    end




    %% derived getters
    methods

        % package unscaled output
        function out = get.OutputRaw(obj)
            out.Location = obj.Location;
            out.Signal = obj.Signal;
            out.SignalNorm = obj.SignalNorm;
            out.SignalSmooth = obj.SignalSmooth;
            out.PeakValues = obj.PeakValues;
            out.PeakLocations = obj.PeakLocations;
            out.PeakWidths = obj.PeakWidths;
            out.PeakProminences = obj.PeakProminences;
            out.PeakDistances = obj.PeakDistances;
            out.PeakGeometry = obj.PeakGeometry;
        end

        % package scaled output (multiplied by obj.DistanceScale)
        function out = get.OutputScaled(obj)
            out = obj.OutputRaw;
            out.Location = out.Location*obj.DistanceScale;
            out.PeakLocations = out.PeakLocations*obj.DistanceScale;
            out.PeakWidths = out.PeakWidths*obj.DistanceScale;
            out.PeakDistances = out.PeakDistances*obj.DistanceScale;
            out.PeakGeometry = desmostorm.analysis.PeaksData.scalePeakGeometry( ...
                out.PeakGeometry, ...
                obj.DistanceScale);
        end

        % number of peaks
        function n = get.nPeaks(obj)
            n = numel(obj.PeakLocations);
        end


        function tf = get.hasCentralPeakPair(obj)
            tf = obj.hasLeftPeak && obj.hasRightPeak;
        end

        function tf = get.hasLeftPeak(obj)
            tf = ~isempty(obj.LeftPeakIdx);
        end

        function tf = get.hasRightPeak(obj)
            tf = ~isempty(obj.RightPeakIdx);
        end

    end



    methods(Static)

      function out = detect(Signal, Location, MinPeakDistance, MinPeakHeight, MinPeakProminence, WidthReference, opts)
            arguments
                Signal                      (:,1) double
                Location                    (:,1) double
                MinPeakDistance             (1,1) double
                MinPeakHeight               (1,1) double
                MinPeakProminence           (1,1) double
                WidthReference              (1,:) char = 'halfheight'
                opts.MinPeakHeightMode      (1,:) char {ismember(opts.MinPeakHeightMode,{'absolute','relative'})} = 'relative'
                opts.MinPeakProminenceMode  (1,:) char {ismember(opts.MinPeakProminenceMode,{'absolute','relative'})} = 'relative'
            end

            % recalculate MinPeakHeight and MinPeakProminence in terms of the Signal values if applicable
            if strcmp(opts.MinPeakHeightMode,'relative')
                MinPeakHeight = MinPeakHeight * max(Signal);
            end

            if strcmp(opts.MinPeakProminenceMode,'relative')
                MinPeakProminence = MinPeakProminence * max(Signal);
            end

            % make sure signal has at least two more elements than the value of MinPeakDistance
            if length(Signal) > (MinPeakDistance+1)
                % 4th output is prominence for each peak, may use in future
                [PeakValues,PeakLocations,PeakWidths,PeakProminences] = findpeaks(...
                    Signal,Location,...
                    'MinPeakHeight',MinPeakHeight,...
                    'MinPeakDistance',MinPeakDistance,...
                    'WidthReference',WidthReference,...
                    'MinPeakProminence',MinPeakProminence); % set higher to pick up fewer small peaks

                if numel(PeakLocations) > 1
                    PeakDistances = diff(PeakLocations);
                else
                    PeakDistances = NaN;
                end
            else
                PeakValues = [];
                PeakLocations = [];
                PeakWidths = [];
                PeakProminences = [];
                PeakDistances = [];
            end

            % collect output
            out = struct(...
                'PeakValues',       PeakValues, ...
                'PeakLocations',    PeakLocations, ...
                'PeakWidths',       PeakWidths, ...
                'PeakProminences',  PeakProminences, ...
                'PeakDistances',    PeakDistances);

        end


        % rescale to [0,1]
        function out = normalizeSignal(Signal)
            out = rescale(Signal);
        end

        % smooth with moving average filter
        function out = smooth(Signal,span)
            out = smooth(Signal,span);
        end

        function geom = getPeakGeometry(y,x,pks,locs,proms,opts)
            arguments
                y (:,1) double
                x (:,1) double
                pks (:,1) double
                locs (:,1) double
                proms (:,1) double
                opts.WidthReference (1,:) char = 'halfheight'
            end

            geom = desmostorm.analysis.PeaksData.emptyPeakGeometry();
            if isempty(locs)
                return
            end

            peakIdx = desmostorm.analysis.PeaksData.getPeakIndices(x,locs);
            borderIdx = desmostorm.analysis.PeaksData.getPeakBorderIndices(y,peakIdx);
            widths = desmostorm.analysis.PeaksData.getPeakWidthIntersections( ...
                y, ...
                x, ...
                peakIdx, ...
                pks, ...
                proms, ...
                borderIdx(1:end-1), ...
                borderIdx(2:end), ...
                "WidthReference",opts.WidthReference);

            nPeaks = numel(peakIdx);
            geom = repmat(desmostorm.analysis.PeaksData.blankPeakGeometry(),nPeaks,1);

            for i = 1:nPeaks
                geom(i).PeakIndex = peakIdx(i);
                geom(i).PeakLocation = x(peakIdx(i));
                geom(i).PeakValue = pks(i);
                geom(i).PeakProminence = proms(i);
                geom(i).LeftBorderIndex = borderIdx(i);
                geom(i).RightBorderIndex = borderIdx(i+1);
                geom(i).LeftBorderLocation = x(borderIdx(i));
                geom(i).RightBorderLocation = x(borderIdx(i+1));
                geom(i).LeftBorderValue = y(borderIdx(i));
                geom(i).RightBorderValue = y(borderIdx(i+1));
                geom(i).WidthHeight = widths.WidthHeight(i);
                geom(i).LeftWidthLocation = widths.LeftWidthLocation(i);
                geom(i).RightWidthLocation = widths.RightWidthLocation(i);
                geom(i).Width = widths.Width(i);
            end
        end

        function peakIdx = getPeakIndices(x,locs)
            arguments
                x (:,1) double
                locs (:,1) double
            end

            peakIdx = arrayfun(@(loc) find(x==loc,1),locs);
            peakIdx = reshape(peakIdx,[],1);
        end

        function borderIdx = getPeakBorderIndices(y,peakIdx)
            arguments
                y (:,1) double
                peakIdx (:,1) double
            end

            nPeaks = numel(peakIdx);
            nSamples = numel(y);

            if nPeaks == 0
                borderIdx = zeros(0,1);
                return
            end

            borderIdx = zeros(nPeaks+1,1);
            borderIdx(1) = 1;
            borderIdx(end) = nSamples;

            for i = 1:nPeaks-1
                segmentIdx = peakIdx(i):peakIdx(i+1);
                [~,minIdx] = min(y(segmentIdx));
                borderIdx(i+1) = segmentIdx(minIdx);
            end
        end

        function out = getPeakWidthIntersections(y,x,peakIdx,pks,proms,leftBorderIdx,rightBorderIdx,opts)
            arguments
                y (:,1) double
                x (:,1) double
                peakIdx (:,1) double
                pks (:,1) double
                proms (:,1) double
                leftBorderIdx (:,1) double
                rightBorderIdx (:,1) double
                opts.WidthReference (1,:) char = 'halfheight'
            end

            nPeaks = numel(peakIdx);

            leftWidthLocation = nan(nPeaks,1);
            rightWidthLocation = nan(nPeaks,1);
            widthHeight = nan(nPeaks,1);
            width = nan(nPeaks,1);

            for i = 1:nPeaks
                switch opts.WidthReference
                    case 'halfheight'
                        halfHeight = pks(i)/2;
                    case 'halfprom'
                        halfHeight = proms(i)/2;
                end

                leftBorder = leftBorderIdx(i);
                rightBorder = rightBorderIdx(i);

                idxL = find(y(leftBorder:peakIdx(i)) <= halfHeight,1,'last');
                idxL = idxL + leftBorder - 1;
                idxL = max(idxL,leftBorder);

                if isempty(idxL) || idxL == leftBorder
                    xL = x(leftBorder);
                else
                    xL = interp1(y(idxL:idxL+1),x(idxL:idxL+1),halfHeight,'linear');
                end

                idxR = find(y(peakIdx(i):rightBorder) <= halfHeight,1,'first');
                idxR = idxR + peakIdx(i) - 1;
                idxR = min(idxR,rightBorder);

                if isempty(idxR) || idxR == rightBorder
                    xR = x(rightBorder);
                else
                    xR = interp1(y(idxR-1:idxR),x(idxR-1:idxR),halfHeight,'linear');
                end

                leftWidthLocation(i) = xL;
                rightWidthLocation(i) = xR;
                widthHeight(i) = halfHeight;
                width(i) = xR - xL;
            end

            out = struct( ...
                "LeftWidthLocation",leftWidthLocation, ...
                "RightWidthLocation",rightWidthLocation, ...
                "WidthHeight",widthHeight, ...
                "Width",width);
        end

        function geom = emptyPeakGeometry()
            geom = repmat(desmostorm.analysis.PeaksData.blankPeakGeometry(),0,1);
        end

        function geom = blankPeakGeometry()
            geom = struct( ...
                "PeakIndex",NaN, ...
                "PeakLocation",NaN, ...
                "PeakValue",NaN, ...
                "PeakProminence",NaN, ...
                "LeftBorderIndex",NaN, ...
                "RightBorderIndex",NaN, ...
                "LeftBorderLocation",NaN, ...
                "RightBorderLocation",NaN, ...
                "LeftBorderValue",NaN, ...
                "RightBorderValue",NaN, ...
                "WidthHeight",NaN, ...
                "LeftWidthLocation",NaN, ...
                "RightWidthLocation",NaN, ...
                "Width",NaN);
        end

        function geom = scalePeakGeometry(geom,scale)
            arguments
                geom struct
                scale (1,1) double
            end

            if isempty(geom)
                return
            end

            distanceFields = { ...
                "PeakLocation", ...
                "LeftBorderLocation", ...
                "RightBorderLocation", ...
                "LeftWidthLocation", ...
                "RightWidthLocation", ...
                "Width"};

            for f = 1:numel(distanceFields)
                name = distanceFields{f};
                for i = 1:numel(geom)
                    geom(i).(name) = geom(i).(name)*scale;
                end
            end
        end

        % generate random noisy peaks for testing
        function [Location,Signal,data] = generateRandomGaussPeaks(opts)
            %GENERATERANDOMGAUSSPEAKS  Random smooth peaks + noise
            %
            %   [Location,Signal,data] = generateRandomGaussPeaks("N",N,"nPeaks",nPeaks,"noiseSigma",noiseSigma)
            %
            %   INPUTS (name-value pairs)
            %       N           – number of points (must be odd)
            %       nPeaks      – number of peaks to generate
            %       noiseSigma  – amplitude of additive noise
            %
            %   OUTPUTS
            %       Location    – integer vector centered at 0
            %       Signal      – noisy signal with smooth underlying peaks
            %       data        – struct holding inputs, randomized peak parameters (Height, Width, etc.),
            %                     and some outputs
            %

            arguments
                opts.N          (1,1) double = 2*randi([250 750]) + 1
                opts.nPeaks     (1,1) double = randi([3 10])
                opts.noiseSigma (1,1) double = 0.1 + 0.4*rand
            end

            N = opts.N;
            nPeaks = opts.nPeaks;
            noiseSigma = opts.noiseSigma;  

            % Ensure odd N
            if mod(N,2)==0
                error('N must be odd so that Location can be symmetric around 0.');
            end

            % Location centered at 0
            halfRange = (N-1)/2;
            Location = -halfRange:halfRange;
            loc = (Location - min(Location)) / (max(Location) - min(Location));   % normalized coordinate [0,1]

            % ---- RANDOMIZE PEAK PARAMETERS ----

            % Peak positions: uniform in [0.05, 0.95] so they aren't on the edges
            Positions = 0.05 + 0.90*rand(1, nPeaks);
            % Peak heights: between 1 and 4 (tunable)
            Heights = 1 + 3*rand(1, nPeaks);
            % Peak widths: between 1% and 10% of the full domain
            Widths = (0.01 + 0.09*rand(1, nPeaks));

            % ---- BUILD GAUSSIAN PEAKS ----

            % % Vectorized: Gauss(i,:) = Hgt(i)*exp(-((x - Pos(i))/Wdt(i)).^2)
            % Gauss = Heights(:) .* exp(-((loc - Positions(:))./Widths(:)).^2);
            % cleanSignal = sum(Gauss, 1);
            % 
            % % ---- ADD NOISE ----
            % Signal = cleanSignal + noiseSigma * randn(size(cleanSignal));
            % 
            % % normalize such that all(Signal(:)>=0)
            % Signal = Signal - min(Signal);

            % generate gaussians
            GaussRaw = Heights(:) .* exp(-((loc - Positions(:))./Widths(:)).^2);

            % add noise
            GaussNoise = GaussRaw + noiseSigma * randn(size(GaussRaw));

            % sum individual signals
            Signal = sum(GaussNoise, 1);

            % normalize such that all(Signal(:)>=0)
            Signal = Signal - min(Signal);

            [sortedPositions,sortIdx] = sort(Positions,"ascend");
            sortedPositionsIdx = max(min(round(sortedPositions*N),N),1);
            sortedLocations = Location(sortedPositionsIdx);
            sortedHeights = Heights(sortIdx);
            sortedWidths = Widths(sortIdx);

            data = struct(...
                "N_Points",N,...
                "N_Peaks",nPeaks,...
                "NoiseSigma",noiseSigma,...
                "Peak_Locations",sortedLocations,...
                "Peak_Heights",sortedHeights,...
                "Peak_Widths",sortedWidths,...
                "Gauss_Raw",GaussRaw,...
                "Gauss_Noise",GaussNoise);

        end

    end

end
