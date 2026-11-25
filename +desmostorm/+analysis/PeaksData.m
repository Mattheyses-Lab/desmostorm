% DesmoSTORM - MATLAB app for desmosomal plaque protein analysis.
% Copyright (C) 2026 William Dean
%
% This program is free software; you can redistribute it and/or modify it
% under the terms of the GNU General Public License as published by the Free
% Software Foundation; either version 2 of the License, or (at your option)
% any later version.
%
% This program is distributed in the hope that it will be useful, but WITHOUT
% ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
% FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
% details.
%
% You should have received a copy of the GNU General Public License along
% with this program; if not, see <https://www.gnu.org/licenses/>.

classdef PeaksData
%PEAKSDATA Analyze the peaks in a sampled intensity profile.

    % input data
    properties
        % Raw intensity samples along the linescan.
        Signal (:,1) double  % signal values
        % Sample positions before conversion to calibrated distance units.
        Location (:,1) double  % signal value location vector (distance/time/etc)
    end

    % processed input
    properties
        % Intensity samples after optional normalization.
        SignalNorm   (:,1) double
        % Normalized profile after optional smoothing.
        SignalSmooth (:,1) double
    end

    % analysis settings
    properties
        % Whether to normalize intensities before peak detection.
        Normalize               (1,1) logical
        % Whether to smooth the intensity profile before peak detection.
        Smooth                  (1,1) logical
        % Minimum separation between adjacent candidate peaks.
        MinPeakDistance         (1,1) double
        % Height threshold interpreted using MinPeakHeightMode.
        MinPeakHeight           (1,1) double
        % Mode used for min peak height.
        MinPeakHeightMode       (1,:) char
        % Prominence threshold interpreted using MinPeakProminenceMode.
        MinPeakProminence       (1,1) double
        % Mode used for min peak prominence.
        MinPeakProminenceMode   (1,:) char
        % Smoothing span in samples.
        PeakSmoothing           (1,1) double
        % Intensity reference used to measure peak widths.
        WidthReference          (1,:) char
        % Factor applied to sample positions to obtain calibrated distances.
        DistanceScale           (1,1) double
        % Display unit for calibrated profile positions and widths.
        DistanceUnit            (1,:) char
        % Whether to recompute peak width after detecting the peak borders.
        RecomputeWidths         (1,1) logical % T/F - whether to recompute widths from findpeaks() to match FWHM annotations
    end

    % primary output measurements
    properties
        % Intensity at each detected peak.
        PeakValues      (:,1) double = []
        % Sample positions of the detected peaks.
        PeakLocations   (:,1) double = []
        % Width measurements in detection order.
        PeakWidths      (:,1) double = []
        % Prominence of each peak relative to its surrounding profile.
        PeakProminences (:,1) double = []
        % Separation between successive peak locations.
        PeakDistances   (:,1) double = []
    end

    % additional collected outputs for central peak pair (if it exists)
    properties
        % CentralPeakPairValues      (:,1) double = []
        % CentralPeakPairLocations   (:,1) double = []
        % CentralPeakPairWidths      (:,1) double = []
        % CentralPeakPairProminences (:,1) double = []
        CentralPeakPairDistance    (:,1) double = []

        % Left peak index.
        LeftPeakIdx         (:,1) double = []
        % Left peak value.
        LeftPeakValue       (:,1) double = []
        % Left peak location.
        LeftPeakLocation    (:,1) double = []
        % Left peak width.
        LeftPeakWidth       (:,1) double = []
        % Left peak prominence.
        LeftPeakProminence  (:,1) double = []

        % Right peak index.
        RightPeakIdx         (:,1) double = []
        % Right peak value.
        RightPeakValue       (:,1) double = []
        % Right peak location.
        RightPeakLocation    (:,1) double = []
        % Right peak width.
        RightPeakWidth       (:,1) double = []
        % Right peak prominence.
        RightPeakProminence  (:,1) double = []
    end

    % analysis geometry derived from detected peaks
    properties
        % Peak borders and width intersections used by the plot.
        PeakGeometry struct = desmostorm.analysis.PeaksData.emptyPeakGeometry()
    end

    % output structs
    properties(Dependent)
        % Measurement snapshot in the original sample coordinates.
        OutputRaw       struct
        % Measurement snapshot in calibrated units.
        OutputScaled    struct
    end

    % other derived outputs
    properties(Dependent)
        % Number of peaks detected in the current profile.
        nPeaks              (1,1) double
        % Whether valid peaks flank the center of the profile.
        hasCentralPeakPair  (1,1) logical
        % Whether a peak was detected to the left of the profile center.
        hasLeftPeak         (1,1) logical
        % Whether a peak was detected to the right of the profile center.
        hasRightPeak        (1,1) logical
    end


    methods
        function obj = PeaksData(Signal,Location,opts)
        %PEAKSDATA Analyze the peaks in a sampled intensity profile.
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
            % Geometry used to render or measure this ROI or trace.
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
        %PLOT Plot the measured profile and return the graphics and axes handles.
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
        %GETCENTRALPEAKPAIRSTATS Return central peak pair stats.

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
        %GET.OUTPUTRAW Package the measured profile and peaks in source coordinates.
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
        %GET.OUTPUTSCALED Package measurements after applying distance calibration.
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
        %GET.NPEAKS Count the detected peak locations.
            n = numel(obj.PeakLocations);
        end


        function tf = get.hasCentralPeakPair(obj)
        %GET.HASCENTRALPEAKPAIR Indicate whether the profile contains a central peak pair.
            tf = obj.hasLeftPeak && obj.hasRightPeak;
        end

        function tf = get.hasLeftPeak(obj)
        %GET.HASLEFTPEAK Indicate whether the profile contains a left peak.
            tf = ~isempty(obj.LeftPeakIdx);
        end

        function tf = get.hasRightPeak(obj)
        %GET.HASRIGHTPEAK Indicate whether the profile contains a right peak.
            tf = ~isempty(obj.RightPeakIdx);
        end

    end



    methods(Static)

      function out = detect(Signal, Location, MinPeakDistance, MinPeakHeight, MinPeakProminence, WidthReference, opts)
      %DETECT Detect peaks and their geometry in the sampled profile.
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
                % Min peak height.
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
        %NORMALIZESIGNAL Normalize signal.
            out = rescale(Signal);
        end

        % smooth with moving average filter
        function out = smooth(Signal,span)
        %SMOOTH Smooth the sampled intensity profile.
            out = smooth(Signal,span);
        end

        function geom = getPeakGeometry(y,x,pks,locs,proms,opts)
        %GETPEAKGEOMETRY Return peak geometry.
            arguments
                y (:,1) double
                x (:,1) double
                pks (:,1) double
                locs (:,1) double
                proms (:,1) double
                opts.WidthReference (1,:) char = 'halfheight'
            end

            % Geometry used to render or measure this ROI or trace.
            geom = desmostorm.analysis.PeaksData.emptyPeakGeometry();
            if isempty(locs)
                return
            end

            % Indices of the peaks used by the current operation.
            peakIdx = desmostorm.analysis.PeaksData.getPeakIndices(x,locs);
            % Index for border.
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

            % Number of detected peaks in the profile.
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
        %GETPEAKINDICES Return peak indices.
            arguments
                x (:,1) double
                locs (:,1) double
            end

            % Indices of the peaks used by the current operation.
            peakIdx = arrayfun(@(loc) find(x==loc,1),locs);
            peakIdx = reshape(peakIdx,[],1);
        end

        function borderIdx = getPeakBorderIndices(y,peakIdx)
        %GETPEAKBORDERINDICES Return peak border indices.
            arguments
                y (:,1) double
                peakIdx (:,1) double
            end

            % Number of detected peaks in the profile.
            nPeaks = numel(peakIdx);
            % Number of samples.
            nSamples = numel(y);

            if nPeaks == 0
                % Index for border.
                borderIdx = zeros(0,1);
                return
            end

            borderIdx = zeros(nPeaks+1,1);
            borderIdx(1) = 1;
            borderIdx(end) = nSamples;

            for i = 1:nPeaks-1
                % Index for segment.
                segmentIdx = peakIdx(i):peakIdx(i+1);
                [~,minIdx] = min(y(segmentIdx));
                borderIdx(i+1) = segmentIdx(minIdx);
            end
        end

        function out = getPeakWidthIntersections(y,x,peakIdx,pks,proms,leftBorderIdx,rightBorderIdx,opts)
        %GETPEAKWIDTHINTERSECTIONS Return peak width intersections.
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

            % Number of detected peaks in the profile.
            nPeaks = numel(peakIdx);

            leftWidthLocation = nan(nPeaks,1);
            rightWidthLocation = nan(nPeaks,1);
            % Width height.
            widthHeight = nan(nPeaks,1);
            width = nan(nPeaks,1);

            for i = 1:nPeaks
                switch opts.WidthReference
                    case 'halfheight'
                        % Half height.
                        halfHeight = pks(i)/2;
                    case 'halfprom'
                        halfHeight = proms(i)/2;
                end

                leftBorder = leftBorderIdx(i);
                rightBorder = rightBorderIdx(i);

                % Last sample below the half-height threshold on the left side.
                idxL = find(y(leftBorder:peakIdx(i)) <= halfHeight,1,'last');
                idxL = idxL + leftBorder - 1;
                idxL = max(idxL,leftBorder);

                if isempty(idxL) || idxL == leftBorder
                    xL = x(leftBorder);
                else
                    xL = interp1(y(idxL:idxL+1),x(idxL:idxL+1),halfHeight,'linear');
                end

                % First sample below the half-height threshold on the right side.
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
        %EMPTYPEAKGEOMETRY Return an empty struct array with the peak geometry fields.
            % Geometry used to render or measure this ROI or trace.
            geom = repmat(desmostorm.analysis.PeaksData.blankPeakGeometry(),0,1);
        end

        function geom = blankPeakGeometry()
        %BLANKPEAKGEOMETRY Initialize peak geometry fields for a single peak.
            % Geometry used to render or measure this ROI or trace.
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
        %SCALEPEAKGEOMETRY Scale peak geometry.
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

            % Scale geometry fields that represent positions or distances.
            for f = 1:numel(distanceFields)
                name = distanceFields{f};
                % Convert this distance field for every peak in the profile.
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
            % Number of detected peaks in the profile.
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
            % Index for sorted positions.
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
