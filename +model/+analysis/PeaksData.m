classdef PeaksData

    % input data
    properties
        Y (:,1) double  % signal values
        X (:,1) double  % signal value location vector (distance/time/etc)
    end

    % processed input
    properties
        YNorm   (:,1) double
        YSmooth (:,1) double
    end

    % analysis settings
    properties
        Normalize           (1,1) logical
        Smooth              (1,1) logical
        MinPeakDistance     (1,1) double
        MinPeakHeight       (1,1) double
        MinPeakProminence   (1,1) double
        PeakSmoothing       (1,1) double
        WidthReference      (1,:) char
        DistanceScale       (1,1) double
        DistanceUnit        (1,:) char
        RecomputeWidths     (1,1) logical   % T/F - whether to recompute widths from findpeaks() to match FWHM annotations
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

    % plot annotation coordinates
    properties
        BorderLineXY        (2,:) double = [NaN; NaN]
        VerticalLineXY      (2,:) double = [NaN; NaN]
        WidthLineXY         (2,:) double = [NaN; NaN]
        PeakToPeakLineXY    (2,:) double = [NaN; NaN]
        WidthLabelXY        (:,2) = [NaN NaN]
        PeakToPeakLabelXY   (:,2) = [NaN NaN]
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
        function obj = PeaksData(Y,X,opts)
            arguments
                Y                       (:,1) double
                X                       (:,1) double
                opts.Normalize          (1,1) logical   = true
                opts.Smooth             (1,1) logical   = true
                opts.MinPeakDistance    (1,1) double    = 0
                opts.MinPeakHeight      (1,1) double    = -Inf
                opts.MinPeakProminence  (1,1) double    = 0
                opts.PeakSmoothing      (1,1) double    = 15
                opts.WidthReference     (1,:) char      = 'halfheight'
                opts.DistanceScale      (1,1) double    = 1
                opts.DistanceUnit       (1,:) char      = 'px'
                opts.RecomputeWidths    (1,1) logical   = true
            end
            % collect inputs
            obj.Y = Y;
            obj.X = X;
            obj.Normalize = opts.Normalize;
            obj.Smooth = opts.Smooth;
            obj.MinPeakDistance = opts.MinPeakDistance;
            obj.MinPeakHeight = opts.MinPeakHeight;
            obj.MinPeakProminence = opts.MinPeakProminence;
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
                obj.YNorm = model.analysis.PeaksData.normalizeSignal(obj.Y);
            else
                obj.YNorm = obj.Y;
            end
            % smooth the normalized signal if required (use the normalized signal if ~obj.Smooth)
            if obj.Smooth
                obj.YSmooth = model.analysis.PeaksData.smooth(obj.YNorm,obj.PeakSmoothing);
            else
                obj.YSmooth = obj.YNorm;
            end
            % --- DETECT PEAKS USING findpeaks() ---
            out = model.analysis.PeaksData.detect(obj.YSmooth, ...
                obj.X, ...
                obj.MinPeakDistance, ...
                obj.MinPeakHeight, ...
                obj.MinPeakProminence, ...
                obj.WidthReference);
            obj.PeakValues = out.PeakValues;
            obj.PeakLocations = out.PeakLocations;
            obj.PeakWidths = out.PeakWidths;
            obj.PeakProminences = out.PeakProminences;
            obj.PeakDistances = out.PeakDistances;
            % --- GET PLOT ANNOTATION COORDINATES ---
            % set height for peak distance annotations based on maximum of smoothed signal
            annotationsHeight = max(obj.YSmooth);
            % get annotation coordinates
            out = model.analysis.PeaksData.getAnnotationCoordinates( ...
                obj.YSmooth, ...
                obj.X, ...
                obj.PeakValues, ...
                obj.PeakLocations, ...
                obj.PeakProminences, ...
                'WidthReference', obj.WidthReference, ...
                'VerticalLinesHeight', annotationsHeight, ...
                'PeakToPeakLinesHeight', annotationsHeight);
            obj.BorderLineXY = out.BorderLineXY;
            obj.VerticalLineXY = out.VerticalLineXY;
            obj.WidthLineXY = out.WidthLineXY;
            obj.PeakToPeakLineXY = out.PeakToPeakLineXY;
            obj.WidthLabelXY = out.WidthLabelXY;
            obj.PeakToPeakLabelXY = out.PeakToPeakLabelXY;
            % if required, replace PeakWidths from findpeaks() with those measured directly from the FWHM lines
            if obj.RecomputeWidths, obj.PeakWidths = out.PeakWidths; end

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

        function h = plot(obj,opts)
            arguments
                obj         (1,1) model.analysis.PeaksData
                opts.Parent (:,1) matlab.ui.control.UIAxes = matlab.ui.control.UIAxes.empty()
            end

            if isempty(opts.Parent)
                fig = uifigure();
                ax = uiaxes(fig);
            else
                ax = opts.Parent;
            end
            h = model.analysis.PeaksPlot(ax,obj);
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
            locs = arrayfun(@(loc) find(obj.X==loc,1),locs);

            % convert location vector to idxs
            nSamples = numel(obj.X);
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
            out.X = obj.X;
            out.Y = obj.Y;
            out.YNorm = obj.YNorm;
            out.YSmooth = obj.YSmooth;
            out.PeakValues = obj.PeakValues;
            out.PeakLocations = obj.PeakLocations;
            out.PeakWidths = obj.PeakWidths;
            out.PeakProminences = obj.PeakProminences;
            out.PeakDistances = obj.PeakDistances;
            out.BorderLineXY = obj.BorderLineXY;
            out.VerticalLineXY = obj.VerticalLineXY;
            out.WidthLineXY = obj.WidthLineXY;
            out.PeakToPeakLineXY = obj.PeakToPeakLineXY;
            out.WidthLabelXY = obj.WidthLabelXY;
            out.PeakToPeakLabelXY = obj.PeakToPeakLabelXY;
        end

        % package scaled output (multiplied by obj.DistanceScale)
        function out = get.OutputScaled(obj)
            out = obj.OutputRaw;
            out.X = out.X*obj.DistanceScale;
            out.PeakLocations = out.PeakLocations*obj.DistanceScale;
            out.PeakWidths = out.PeakWidths*obj.DistanceScale;
            out.PeakDistances = out.PeakDistances*obj.DistanceScale;
            out.BorderLineXY(1,:) = out.BorderLineXY(1,:)*obj.DistanceScale;
            out.VerticalLineXY(1,:) = out.VerticalLineXY(1,:)*obj.DistanceScale;
            out.WidthLineXY(1,:) = out.WidthLineXY(1,:)*obj.DistanceScale;
            out.PeakToPeakLineXY(1,:) = out.PeakToPeakLineXY(1,:)*obj.DistanceScale;
            out.WidthLabelXY(:,1) = out.WidthLabelXY(:,1)*obj.DistanceScale;
            out.PeakToPeakLabelXY(:,1) = out.PeakToPeakLabelXY(:,1)*obj.DistanceScale;
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

        function out = detect(Y, X, MinPeakDistance, MinPeakHeight, MinPeakProminence, WidthReference)
            arguments
                Y                   (:,1) double
                X                   (:,1) double
                MinPeakDistance     (1,1) double
                MinPeakHeight       (1,1) double
                MinPeakProminence   (1,1) double
                WidthReference      (1,:) char = 'halfheight'
            end
            % make sure signal has at least two more elements than the value of MinPeakDistance
            if length(Y) > (MinPeakDistance+1)
                % 4th output is prominence for each peak, may use in future
                [PeakValues,PeakLocations,PeakWidths,PeakProminences] = findpeaks(...
                    Y,X,...
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
        function out = normalizeSignal(Y)
            out = rescale(Y);
        end

        % smooth with moving average filter
        function out = smooth(Y,span)
            out = smooth(Y,span);
        end

        % get coordinates for plot annotations
        function out = getAnnotationCoordinates(y,x,pks,locs,proms,opts)
            arguments
                    y (:,1) double
                    x (:,1) double
                    pks (:,1) double
                    locs (:,1) double
                    proms (:,1) double
                    opts.WidthReference (1,:) char = 'halfheight'
                    opts.VerticalLinesHeight = 1
                    opts.PeakToPeakLinesHeight = 0.9
                end
                % compute annotation line/label coordinates and store 
                % in a structured format for plotting with line() and text()

                % initialize output struct
                out = struct( ...
                    'WidthLineXY',          [], ...
                    'VerticalLineXY',       [], ...
                    'PeakToPeakLineXY',     [], ...
                    'BorderLineXY',         [], ...
                    'WidthLabelXY',         [], ...
                    'PeakToPeakLabelXY',    [], ...
                    'PeakWidths',           []);

                if isempty(locs)
                    return
                end

                % number of peaks
                nPeaks = numel(locs);

                % number of sample points
                nSamples = numel(x);

                % Initialize arrays to store FWHM coordinates
                xL = zeros(size(locs));
                xR = zeros(size(locs));

                % Initialize array to store recomputed peak widths
                peakWidths = nan(size(locs));

                % convert distance vector to idxs
                locs = arrayfun(@(loc) find(x==loc,1),locs);

                % find peak border idxs (idx to x position of lowest valley between peaks)
                borderIdx = 1:(nPeaks-1);
                borders = arrayfun(@(idx) find(y==min(y(locs(idx):locs(idx+1))),1,'first'),borderIdx);
                borders = [1,borders,nSamples];


                borderX = x(borders);
                borderY = y(borders);
                nBorders = numel(borders);

                % border line coordinates flanking each peak
                borderLineXY = zeros(2,nBorders*3);

                for i = 1:nBorders
                    lineIdx = 3*(i-1)+1;
                    borderLineXY(1,lineIdx:lineIdx+2) = [borderX(i),borderX(i),NaN];
                    borderLineXY(2,lineIdx:lineIdx+2) = [0,borderY(i),NaN];
                end

                % FWHM line coordinates for each peak
                widthLineXY = zeros(2,nPeaks*3);

                % vertical lines centered on each peak
                verticalLineXY = zeros(2,nPeaks*3);

                if nPeaks > 1
                    % coordinates for peak distance lines
                    peakToPeakLineXY = zeros(2,(nPeaks-1)*3);
                    % coordinates for peak distance line labels
                    peakToPeakLabelXY = zeros(nPeaks-1,2);
                else
                    peakToPeakLineXY = [NaN;NaN];
                    peakToPeakLabelXY = [];
                end

                % coordinates for width line labels
                widthLabelXY = zeros(nPeaks,2);



                for i = 1:length(locs)
                    switch opts.WidthReference
                        case 'halfheight'
                            halfHeight = pks(i)/2;
                        case 'halfprom'
                            halfHeight = proms(i)/2;
                    end


                    % --- get x coordinates for horizontal FWHM line ---

                    % find left and right border idxs for this peak
                    leftBorder = borders(i); rightBorder = borders(i+1);

                    % find last sample to left of peak below half height
                    idxL = find(y(leftBorder:locs(i)) <= halfHeight, 1, 'last');
                    idxL = idxL + borders(i) - 1; % Adjust index to original array
                    idxL = max(idxL,leftBorder); % clamp to border

                    % interpolate with next point to find intersection x location
                    if isempty(idxL) || idxL == leftBorder
                        % guard for edge/plateau
                        xL(i) = x(leftBorder);
                    else
                        % linear interpolation between (idxL, idxL+1)
                        xL(i) = interp1(y(idxL:idxL+1), x(idxL:idxL+1), halfHeight, 'linear');
                    end

                    % find first sample to right of peak below half height
                    idxR = find(y(locs(i):rightBorder) <= halfHeight, 1, 'first');
                    idxR = idxR + locs(i) - 1; % Adjust index to original array
                    idxR = min(idxR,rightBorder); % clamp to border

                    % interpolate with next point to find intersection x location
                    if isempty(idxR) || idxR == rightBorder
                        % guard for edge/plateau
                        xR(i) = x(rightBorder);
                    else
                        % linear interpolation between (idxR, idxR-1)
                        xR(i) = interp1(y(idxR-1:idxR), x(idxR-1:idxR), halfHeight, 'linear');
                    end

                    % --- add to line coordinate arrays ---
                    lineIdx = 3*(i-1)+1;

                    % FWHM horizontal lines
                    widthLineXY(1,lineIdx:lineIdx+2) = [xL(i),xR(i),NaN];
                    widthLineXY(2,lineIdx:lineIdx+2) = [halfHeight,halfHeight,NaN];

                    % peak center vertical lines
                    verticalLineXY(1,lineIdx:lineIdx+2) = [x(locs(i)),x(locs(i)),NaN];
                    verticalLineXY(2,lineIdx:lineIdx+2) = [0,opts.VerticalLinesHeight,NaN];

                    % peak distance lines (number of lines is one less than number of peaks)
                    if i < nPeaks
                        peakToPeakLineXY(1,lineIdx:lineIdx+2) = [x(locs(i)),x(locs(i+1)),NaN];
                        peakToPeakLineXY(2,lineIdx:lineIdx+2) = [opts.PeakToPeakLinesHeight,opts.PeakToPeakLinesHeight,NaN];
                        % add position coordinates for peak distance label
                        peakToPeakLabelXY(i,:) = [mean(x(locs(i:i+1))) opts.PeakToPeakLinesHeight];
                    end

                    % add position coordinates for width label
                    widthLabelXY(i,:) = [x(locs(i)) halfHeight];

                    % add recomputed width to peakWidths
                    peakWidths(i) = xR(i) - xL(i);

                end

                out.WidthLineXY = widthLineXY;
                out.VerticalLineXY = verticalLineXY;
                out.PeakToPeakLineXY = peakToPeakLineXY;
                out.BorderLineXY = borderLineXY;
                out.WidthLabelXY = widthLabelXY;
                out.PeakToPeakLabelXY = peakToPeakLabelXY;

                out.PeakWidths = peakWidths;

        end

        % generate random noisy peaks for testing
        function [X,Y] = generateRandomGaussPeaks(N, nPeaks, noiseSigma)
            %GENERATERANDOMGAUSSPEAKS  Random smooth peaks + noise
            %
            %   [X,Y,params] = generateRandomGaussPeaks(N, nPeaks, noiseSigma)
            %
            %   INPUTS
            %       N           – number of points (must be odd)
            %       nPeaks      – number of peaks to generate
            %       noiseSigma  – amplitude of additive noise
            %
            %   OUTPUTS
            %       X           – integer vector centered at 0
            %       Y           – noisy signal with smooth underlying peaks
            %       params      – struct holding randomized peak parameters (Pos, Hgt, Wdt)

            if nargin < 1 || isempty(N),        N = 1001;     end
            if nargin < 2 || isempty(nPeaks),   nPeaks = 6;   end
            if nargin < 3 || isempty(noiseSigma), noiseSigma = 0.3; end

            % Ensure odd N
            if mod(N,2)==0
                error('N must be odd so that X can be symmetric around 0.');
            end

            % X centered at 0
            halfRange = (N-1)/2;
            X = -halfRange:halfRange;
            x = (X - min(X)) / (max(X) - min(X));   % normalized coordinate [0,1]

            % ---- RANDOMIZE PEAK PARAMETERS ----

            % Peak positions: uniform in [0.05, 0.95] so they aren't on the edges
            Pos = 0.05 + 0.90*rand(1, nPeaks);
            % Peak heights: between 1 and 4 (tunable)
            Hgt = 1 + 3*rand(1, nPeaks);
            % Peak widths: between 1% and 10% of the full domain
            Wdt = (0.01 + 0.09*rand(1, nPeaks));

            % ---- BUILD GAUSSIAN PEAKS ----

            % Vectorized: Gauss(i,:) = Hgt(i)*exp(-((x - Pos(i))/Wdt(i)).^2)
            Gauss = Hgt(:) .* exp(-((x - Pos(:))./Wdt(:)).^2);
            cleanSignal = sum(Gauss, 1);

            % ---- ADD NOISE ----
            Y = cleanSignal + noiseSigma * randn(size(cleanSignal));

            % normalize such that all(Y(:)>=0)
            Y = Y - min(Y);
        end

    end

end

