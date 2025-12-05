% classdef PeaksData < handle
% 
%     % input data
%     properties
%         Y (:,1) double
%         X (:,1) double
%     end
% 
%     % processed input
%     properties
%         YNorm (:,1) double
%         YSmooth (:,1) double
%     end
% 
%     % analysis settings
%     properties
%         Normalize (1,1) logical
%         Smooth (1,1) logical
%         MinPeakDistance (1,1) double
%         MinPeakHeight (1,1) double
%         PeakSmoothing (1,1) double
%         WidthReference (1,:) char
%     end
% 
%     % output measurements
%     properties
%         PeakValues (:,1) double = []
%         PeakLocations (:,1) double = []
%         PeakWidths (:,1) double = []
%         PeakProminences (:,1) double = []
%     end
% 
%     % plot annotation coordinates
%     properties
%         BorderLineXY (2,:) double = [NaN; NaN]
%         VerticalLineXY (2,:) double = [NaN; NaN]
%         WidthLineXY (2,:) double = [NaN; NaN]
%         PeakToPeakLineXY (2,:) double = [NaN; NaN]
%     end
% 
% 
%     methods
% 
%         % constructor
%         function obj = PeaksData(Y,X,opts)
%             arguments
%                 Y (:,1) double
%                 X (:,1) double
%                 opts.Normalize (1,1) logical = true
%                 opts.Smooth (1,1) logical = true
%                 opts.MinPeakDistance (1,1) double = 0
%                 opts.MinPeakHeight (1,1) double = -Inf
%                 opts.PeakSmoothing (1,1) double = 15
%                 opts.WidthReference (1,:) char = 'halfheight'
%             end
%             % collect inputs
%             obj.Y = Y;
%             obj.X = X;
%             obj.Normalize = opts.Normalize;
%             obj.Smooth = opts.Smooth;
%             obj.MinPeakDistance = opts.MinPeakDistance;
%             obj.MinPeakHeight = opts.MinPeakHeight;
%             obj.PeakSmoothing = opts.PeakSmoothing;
%             obj.WidthReference = opts.WidthReference;
% 
%             % process the data
%             obj.process();
%         end
% 
%         function process(obj)
% 
%             % normalize the raw signal if required
%             if obj.Normalize
%                 obj.YNorm = model.analysis.PeaksData.normalizeSignal(obj.Y);
%             else
%                 obj.YNorm = obj.Y; % Assign raw signal to normalized if not normalizing
%             end
% 
%             % smooth the normalized signal if required
%             if obj.Smooth
%                 obj.YSmooth = model.analysis.PeaksData.smooth(obj.YNorm,obj.PeakSmoothing);
%             else
%                 obj.YSmooth = obj.YNorm;
%             end
% 
%             % detect peaks in the smoothed signal
%             out = model.analysis.PeaksData.detect(obj.YSmooth, ...
%                 obj.X, ...
%                 obj.MinPeakDistance, ...
%                 obj.MinPeakHeight, ...
%                 obj.WidthReference);
%             obj.PeakValues = out.PeakValues;
%             obj.PeakLocations = out.PeakLocations;
%             obj.PeakWidths = out.PeakWidths;
%             obj.PeakProminences = out.PeakProminences;
% 
%             % get coordinates for plot annotations
%             out = model.analysis.PeaksData.getAnnotationCoordinates( ...
%                 obj.YSmooth, ...
%                 obj.X, ...
%                 obj.PeakValues, ...
%                 obj.PeakLocations, ...
%                 obj.PeakProminences, ...
%                 'WidthReference', obj.WidthReference);
%             obj.BorderLineXY = out.BorderLineXY;
%             obj.VerticalLineXY = out.VerticalLineXY;
%             obj.WidthLineXY = out.WidthLineXY;
%             obj.PeakToPeakLineXY = out.PeakToPeakLineXY;
% 
%         end
% 
% 
%         function h = plot(obj,opts)
%             arguments
%                 obj (1,1) model.analysis.PeaksData
%                 opts.Parent (:,1) matlab.ui.control.UIAxes = matlab.ui.control.UIAxes.empty()
%             end
% 
%             if isempty(opts.Parent)
%                 fig = uifigure();
%                 ax = uiaxes(fig);
%             else
%                 ax = opts.Parent;
%             end
%             h = model.analysis.PeaksPlot(ax,obj);
% 
%         end
% 
% 
%     end
% 
% 
% 
%     methods(Static)
% 
%         function out = detect(Y, X, MinPeakDistance, MinPeakHeight, WidthReference)
%             arguments
%                 Y (:,1) double
%                 X (:,1) double
%                 MinPeakDistance (1,1) double
%                 MinPeakHeight (1,1) double
%                 WidthReference (1,:) char = 'halfheight'
%             end
% 
%             if length(Y) >= MinPeakDistance
%                 % 4th output is prominence for each peak, may use in future
%                 [PeakValues,PeakLocations,PeakWidths,PeakProminences] = findpeaks(...
%                     Y,X,...
%                     'MinPeakHeight',MinPeakHeight,...
%                     'MinPeakDistance',MinPeakDistance,...
%                     'WidthReference',WidthReference,...
%                     'MinPeakProminence',0.1); % so we do not pick up tiny peaks
%             else
%                 PeakValues = NaN;
%                 PeakLocations = NaN;
%                 PeakWidths = NaN;
%                 PeakProminences = NaN;
%             end
% 
%             % collect output
%             out = struct(...
%                 'PeakValues',       PeakValues, ...
%                 'PeakLocations',    PeakLocations, ...
%                 'PeakWidths',       PeakWidths, ...
%                 'PeakProminences',  PeakProminences);
% 
%             end
% 
%             % rescale to [0,1]
%             function out = normalizeSignal(Y)
%                 out = rescale(Y);
%             end
% 
%             % smooth with moving average filter
%             function out = smooth(Y,span)
%                 out = smooth(Y,span);
%             end
% 
%             % get coordinates for plot annotations
%             function out = getAnnotationCoordinates(y,x,pks,locs,proms,opts)
%                 arguments
%                     y (:,1) double
%                     x (:,1) double
%                     pks (:,1) double
%                     locs (:,1) double
%                     proms (:,1) double
%                     opts.WidthReference (1,:) char = 'halfheight'
%                     opts.VerticalLinesHeight = 1
%                     opts.PeakToPeakLinesHeight = 0.9
%                 end
% 
%                 % compute annotation lines coordinates and store 
%                 % in a structured format for plotting with line()
% 
%                 % number of peaks
%                 nPeaks = numel(locs);
% 
%                 % number of sample points
%                 nSamples = numel(x);
% 
%                 % Initialize arrays to store FWHM coordinates
%                 xL = zeros(size(locs));
%                 xR = zeros(size(locs));
% 
%                 % convert distance vector to idxs
%                 locs = arrayfun(@(loc) find(x==loc,1),locs);
% 
%                 % find peak border idxs (idx to x position of lowest valley between peaks)
%                 borderIdx = 1:(nPeaks-1);
%                 borders = arrayfun(@(idx) find(y==min(y(locs(idx):locs(idx+1))),1,'first'),borderIdx);
%                 borders = [1,borders,nSamples];
% 
% 
%                 borderX = x(borders);
%                 borderY = y(borders);
%                 nBorders = numel(borders);
% 
%                 % border line coordinates flanking each peak
%                 borderLineXY = zeros(2,nBorders*3);
% 
%                 for i = 1:nBorders
%                     lineIdx = 3*(i-1)+1;
%                     borderLineXY(1,lineIdx:lineIdx+2) = [borderX(i),borderX(i),NaN];
%                     borderLineXY(2,lineIdx:lineIdx+2) = [0,borderY(i),NaN];
%                 end
% 
%                 % FWHM line coordinates for each peak
%                 widthLineXY = zeros(2,nPeaks*3);
%                 % vertical lines centered on each peak
%                 verticalLineXY = zeros(2,nPeaks*3);
% 
%                 % horizontal lines showing distance between each peak
%                 if nPeaks > 1
%                     peakToPeakLineXY = zeros(2,(nPeaks-1)*3);
%                 else
%                     peakToPeakLineXY = [NaN;NaN];
%                 end
% 
% 
% 
%                 for i = 1:length(locs)
%                     switch opts.WidthReference
%                         case 'halfheight'
%                             halfHeight = pks(i)/2;
%                         case 'halfprom'
%                             halfHeight = proms(i)/2;
%                     end
% 
%                     % find left and right border idxs for this peak
%                     leftBorder = borders(i); rightBorder = borders(i+1);
% 
%                     % find last sample to left of peak below half height
%                     idxL = find(y(leftBorder:locs(i)) <= halfHeight, 1, 'last');
%                     idxL = idxL + borders(i) - 1; % Adjust index to original array
%                     idxL = max(idxL,leftBorder); % clamp to border
% 
%                     % interpolate with next point to find intersection x location
%                     if isempty(idxL) || idxL == leftBorder
%                         % guard for edge/plateau
%                         xL(i) = x(leftBorder);
%                     else
%                         % linear interpolation between (idxL, idxL+1)
%                         xL(i) = interp1(y(idxL:idxL+1), x(idxL:idxL+1), halfHeight, 'linear');
%                     end
% 
%                     % find first sample to right of peak below half height
%                     idxR = find(y(locs(i):rightBorder) <= halfHeight, 1, 'first');
%                     idxR = idxR + locs(i) - 1; % Adjust index to original array
%                     idxR = min(idxR,rightBorder); % clamp to border
% 
%                     % interpolate with next point to find intersection x location
%                     if isempty(idxR) || idxR == rightBorder
%                         % guard for edge/plateau
%                         xR(i) = x(rightBorder);
%                     else
%                         % linear interpolation between (idxR, idxR-1)
%                         xR(i) = interp1(y(idxR-1:idxR), x(idxR-1:idxR), halfHeight, 'linear');
%                     end
% 
%                     % add to line coordinate arrays
%                     lineIdx = 3*(i-1)+1;
%                     widthLineXY(1,lineIdx:lineIdx+2) = [xL(i),xR(i),NaN];
%                     widthLineXY(2,lineIdx:lineIdx+2) = [halfHeight,halfHeight,NaN];
% 
%                     verticalLineXY(1,lineIdx:lineIdx+2) = [x(locs(i)),x(locs(i)),NaN];
%                     verticalLineXY(2,lineIdx:lineIdx+2) = [0,opts.VerticalLinesHeight,NaN];
% 
%                     if i < nPeaks
%                         peakToPeakLineXY(1,lineIdx:lineIdx+2) = [x(locs(i)),x(locs(i+1)),NaN];
%                         peakToPeakLineXY(2,lineIdx:lineIdx+2) = [opts.PeakToPeakLinesHeight,opts.PeakToPeakLinesHeight,NaN];
%                     end
% 
%                 end
% 
%                 out.WidthLineXY = widthLineXY;
%                 out.VerticalLineXY = verticalLineXY;
%                 out.PeakToPeakLineXY = peakToPeakLineXY;
%                 out.BorderLineXY = borderLineXY;
% 
%             end
% 
%     end
% 
% end

classdef PeaksData

    % input data
    properties
        Y (:,1) double
        X (:,1) double
    end

    % processed input
    properties
        YNorm (:,1) double
        YSmooth (:,1) double
    end

    % analysis settings
    properties
        Normalize (1,1) logical
        Smooth (1,1) logical
        MinPeakDistance (1,1) double
        MinPeakHeight (1,1) double
        PeakSmoothing (1,1) double
        WidthReference (1,:) char
        DistanceScale (1,1) double
        DistanceUnit (1,:) char
    end

    % output measurements
    properties
        PeakValues (:,1) double = []
        PeakLocations (:,1) double = []
        PeakWidths (:,1) double = []
        PeakProminences (:,1) double = []
        PeakDistances (:,1) double = []
    end

    % plot annotation coordinates
    properties
        BorderLineXY (2,:) double = [NaN; NaN]
        VerticalLineXY (2,:) double = [NaN; NaN]
        WidthLineXY (2,:) double = [NaN; NaN]
        PeakToPeakLineXY (2,:) double = [NaN; NaN]
        WidthLabelXY (:,2) = [NaN NaN]
        PeakToPeakLabelXY (:,2) = [NaN NaN]
    end

    % output structs
    properties(Dependent)
        OutputRaw struct
        OutputScaled struct
    end

    % other derived outputs
    properties(Dependent)
        nPeaks (1,1) double
    end


    methods

        % constructor
        function obj = PeaksData(Y,X,opts)
            arguments
                Y (:,1) double
                X (:,1) double
                opts.Normalize (1,1) logical = true
                opts.Smooth (1,1) logical = true
                opts.MinPeakDistance (1,1) double = 0
                opts.MinPeakHeight (1,1) double = -Inf
                opts.PeakSmoothing (1,1) double = 15
                opts.WidthReference (1,:) char = 'halfheight'
                opts.DistanceScale (1,1) = 1
                opts.DistanceUnit (1,:) char = 'px'
            end
            % collect inputs
            obj.Y = Y;
            obj.X = X;
            obj.Normalize = opts.Normalize;
            obj.Smooth = opts.Smooth;
            obj.MinPeakDistance = opts.MinPeakDistance;
            obj.MinPeakHeight = opts.MinPeakHeight;
            obj.PeakSmoothing = opts.PeakSmoothing;
            obj.WidthReference = opts.WidthReference;
            obj.DistanceScale = opts.DistanceScale;
            obj.DistanceUnit = opts.DistanceUnit;

            % process the data
            obj = obj.process();
        end

        function obj = process(obj)

            % normalize the raw signal if required
            if obj.Normalize
                obj.YNorm = model.analysis.PeaksData.normalizeSignal(obj.Y);
            else
                obj.YNorm = obj.Y; % Assign raw signal to normalized if not normalizing
            end

            % smooth the normalized signal if required
            if obj.Smooth
                obj.YSmooth = model.analysis.PeaksData.smooth(obj.YNorm,obj.PeakSmoothing);
            else
                obj.YSmooth = obj.YNorm;
            end

            % detect peaks in the smoothed signal
            out = model.analysis.PeaksData.detect(obj.YSmooth, ...
                obj.X, ...
                obj.MinPeakDistance, ...
                obj.MinPeakHeight, ...
                obj.WidthReference);
            obj.PeakValues = out.PeakValues;
            obj.PeakLocations = out.PeakLocations;
            obj.PeakWidths = out.PeakWidths;
            obj.PeakProminences = out.PeakProminences;
            obj.PeakDistances = out.PeakDistances;

            % get coordinates for plot annotations

            % if obj.Normalize
            %     annotationsHeight = 1;
            % else
            %     annotationsHeight = max(obj.YNorm); % Set height for annotations based on normalized signal
            % end

            annotationsHeight = max(obj.YSmooth); % Set height for annotations based on normalized, smoothed


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
        end


        function h = plot(obj,opts)
            arguments
                obj (1,1) model.analysis.PeaksData
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


    %% derived getters
    methods

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

        function n = get.nPeaks(obj)
            n = numel(obj.PeakLocations);
        end

    end



    methods(Static)

        function out = detect(Y, X, MinPeakDistance, MinPeakHeight, WidthReference)
            arguments
                Y (:,1) double
                X (:,1) double
                MinPeakDistance (1,1) double
                MinPeakHeight (1,1) double
                WidthReference (1,:) char = 'halfheight'
            end

            if length(Y) > (MinPeakDistance+1)
                try
                    % 4th output is prominence for each peak, may use in future
                    [PeakValues,PeakLocations,PeakWidths,PeakProminences] = findpeaks(...
                        Y,X,...
                        'MinPeakHeight',MinPeakHeight,...
                        'MinPeakDistance',MinPeakDistance,...
                        'WidthReference',WidthReference,...
                        'MinPeakProminence',0); % so we do not pick up tiny peaks
                catch
                    warning('Error')
                end
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
                    'PeakToPeakLabelXY',    []);

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

                    % add to line coordinate arrays
                    lineIdx = 3*(i-1)+1;
                    widthLineXY(1,lineIdx:lineIdx+2) = [xL(i),xR(i),NaN];
                    widthLineXY(2,lineIdx:lineIdx+2) = [halfHeight,halfHeight,NaN];

                    verticalLineXY(1,lineIdx:lineIdx+2) = [x(locs(i)),x(locs(i)),NaN];
                    verticalLineXY(2,lineIdx:lineIdx+2) = [0,opts.VerticalLinesHeight,NaN];

                    if i < nPeaks
                        peakToPeakLineXY(1,lineIdx:lineIdx+2) = [x(locs(i)),x(locs(i+1)),NaN];
                        peakToPeakLineXY(2,lineIdx:lineIdx+2) = [opts.PeakToPeakLinesHeight,opts.PeakToPeakLinesHeight,NaN];
                        % add position coordinates for peak distance label
                        peakToPeakLabelXY(i,:) = [mean(x(locs(i:i+1))) opts.PeakToPeakLinesHeight];
                    end

                    % add position coordinates for width label
                    widthLabelXY(i,:) = [x(locs(i)) halfHeight];

                end

                out.WidthLineXY = widthLineXY;
                out.VerticalLineXY = verticalLineXY;
                out.PeakToPeakLineXY = peakToPeakLineXY;
                out.BorderLineXY = borderLineXY;
                out.WidthLabelXY = widthLabelXY;
                out.PeakToPeakLabelXY = peakToPeakLabelXY;

            end

    end

end

