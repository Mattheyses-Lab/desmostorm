classdef PeaksPlotContainer < matlab.ui.componentcontainer.ComponentContainer

    
    %% data used to build the plot
    properties(AbortSet)
        % PeaksData object, empty by default
        Data desmostorm.analysis.PeaksData = desmostorm.analysis.PeaksData.empty()
    end

    %% axes appearance properties
    properties(AbortSet)
        % title of the chart displayed at the top of the axes
        Title (1,:) char = 'Untitled'
        % visibility of the title
        TitleVisible (1,1) logical = true
        % color of axes and title text
        FontColor (1,3) double = [0 0 0]
        % name of the axes font for titles and labels, defaul Arial
        FontName (1,:) char = 'Arial'
        % size of the various text objects
        FontSize (1,1) double = 12
        % size of peak annotation label text
        AnnotationsFontSize (1,1) double = 10
        % margin around peak annotation label text
        AnnotationsMargin (1,1) double = 1
        % color of axes axis lines
        ForegroundColor (1,3) double = [0 0 0]
        % color of peak annotation lines
        AnnotationsColor (1,3) double = [0 0 0]
        % optional per-plot peak annotation line colors
        AnnotationsColors (:,3) double = zeros(0,3)
        % auto matches annotations to each plot color; manual uses AnnotationColor
        AnnotationColorMode (1,:) char {mustBeMember(AnnotationColorMode,{'auto','manual'})} = 'auto'
        % single annotation color used when AnnotationColorMode is manual
        AnnotationColor (1,3) double {mustBeInRange(AnnotationColor,0,1)} = [0 0 0]
        % base color applied to child PeaksPlot objects in auto color mode
        Color (1,3) double {mustBeInRange(Color,0,1)} = [0 0 0]
        % optional per-plot base colors
        Colors (:,3) double {mustBeInRange(Colors,0,1)} = zeros(0,3)
        % auto derives object colors from Color; manual uses per-object colors
        ColorMode (1,:) char {mustBeMember(ColorMode,{'auto','manual'})} = 'auto'
        % auto uses default object alpha values; manual uses per-object alpha values
        AlphaMode (1,:) char {mustBeMember(AlphaMode,{'auto','manual'})} = 'auto'
        % color of shaded peak areas in manual color mode
        PeakAreaColor (1,3) double {mustBeInRange(PeakAreaColor,0,1)} = [0 0 0]
        % optional per-plot shaded peak area colors in manual color mode
        PeakAreaColors (:,3) double {mustBeInRange(PeakAreaColors,0,1)} = zeros(0,3)
        % alpha of shaded peak areas in manual alpha mode
        PeakAreaAlpha (1,1) double {mustBeInRange(PeakAreaAlpha,0,1)} = 0
        % label of the x-axis
        XLabel (1,:) char = 'X'
        % label of the y-axis
        YLabel (1,:) char = 'Y'
    end


    %% PeaksPlot-specific appearance properties
    properties(AbortSet)
        % width of raw signal line
        RawLineWidth (1,1) double = 1
        % color of raw signal line
        RawLineColor (1,3) double = [0.5 0.5 0.5]
        % optional per-plot raw signal line colors
        RawLineColors (:,3) double = zeros(0,3)
        % width of smoothed signal line
        SmoothLineWidth (1,1) double = 1
        % color of smoothed signal line
        SmoothLineColor (1,3) double = [0 0 0]
        % optional per-plot smoothed signal line colors
        SmoothLineColors (:,3) double = zeros(0,3)
        % color cycle used for overlaid scans when per-plot colors are not supplied
        ColorOrder (:,3) double = [ ...
            0.0000 0.4470 0.7410; ...
            0.8500 0.3250 0.0980; ...
            0.9290 0.6940 0.1250; ...
            0.4940 0.1840 0.5560; ...
            0.4660 0.6740 0.1880; ...
            0.3010 0.7450 0.9330; ...
            0.6350 0.0780 0.1840]
        % visibility of the peak FWHM annotations
        WidthAnnotations (1,1) matlab.lang.OnOffSwitchState = "on"
        % display mode for peak FWHM annotations
        WidthAnnotationsMode (1,:) char {mustBeMember(WidthAnnotationsMode,{'normal','hover'})} = 'normal'
        % visibility of the peak distance annotations
        DistanceAnnotations (1,1) matlab.lang.OnOffSwitchState = "on"
        % display mode for peak distance annotations
        DistanceAnnotationsMode (1,:) char {mustBeMember(DistanceAnnotationsMode,{'data','lanes'})} = 'lanes'
        % base fraction of the nice data axis range reserved above the top tick for distance annotation lanes
        DistanceAnnotationBaseBandFraction (1,1) double {mustBeNonnegative} = 0.10
        % additional annotation-band fraction added for each extra lane
        DistanceAnnotationLaneBandFraction (1,1) double {mustBeNonnegative} = 0.075
        % maximum annotation-band fraction reserved above the top tick
        DistanceAnnotationBandFraction (1,1) double {mustBeNonnegative} = 0.50
        % target number of y-axis ticks when distance annotation lanes are active
        DistanceAnnotationTargetTicks (1,1) double {mustBeInteger,mustBePositive} = 5
    end


    %% graphics components
    properties(Access = private,Transient,NonCopyable)
        Grid        (1,1) matlab.ui.container.GridLayout
        MainAxes    (1,1) matlab.ui.control.UIAxes
        PeaksPlot   (:,1) desmostorm.widgets.PeaksPlot
        AxesTitle   (1,1) matlab.graphics.primitive.Text
        Hub          matlabx.ui.interaction.FigureEventHub
        HubID        double = NaN
    end

    %% protected methods - setup(), update(), etc...
    methods(Access = protected)
        function setup(obj)
            % default BackgroundColor
            obj.BackgroundColor = [1 1 1];
            % grid layout manager to hold the components
            obj.Grid = uigridlayout(obj,...
                [1,1],...
                "ColumnWidth",{'1x'},...
                "RowHeight",{'1x'},...
                "BackgroundColor",[1 1 1],...
                "Padding",[0 0 0 0]);
            % % uiaxes to hold scatter plots
            obj.MainAxes = uiaxes(obj.Grid,...
                "XLim",[0 1],...
                "XLimMode","auto",...
                "YLim",[0 1],...
                "YLimMode","auto",...
                "Clipping","off",...
                "OuterPosition",[0 0 1 1],...
                "Units","normalized",...
                "TitleHorizontalAlignment","left");
            obj.MainAxes.Layout.Row = 1;
            obj.MainAxes.Layout.Column = 1;
            obj.MainAxes.XLabel.String = 'Distance';
            obj.MainAxes.YLabel.String = 'Intensity';
            % PeaksPlot instances are created lazily to match Data length.
            obj.PeaksPlot = desmostorm.widgets.PeaksPlot.empty(0,1);
            % set up a title for the axes
            obj.AxesTitle = title(obj.MainAxes,'',...
                "BackgroundColor","none",...
                "HorizontalAlignment","left",...
                "VerticalAlignment","bottom",...
                "Units","normalized");
            % replace default toolbar with an empty one
            axtoolbar(obj.MainAxes,{});
            % use normalized units for the component, stretched to fill the container by default
            obj.Units = 'Normalized';
            obj.OuterPosition = [0 0 1 1];
            % Register once with the figure-level event hub for lightweight hover behavior.
            obj.registerFigureEventHub();
        end
        
        function update(obj)
            obj.syncPeaksPlotCount();

            % --- PeaksPlot properties ---
            if ~isempty(obj.PeaksPlot)
                laneY = obj.getDistanceAnnotationLanes();
                set(obj.PeaksPlot,...
                    "FontName",             obj.FontName,...
                    "FontSize",             obj.FontSize,...
                    "AnnotationsFontSize",  obj.AnnotationsFontSize,...
                    "AnnotationsMargin",    obj.AnnotationsMargin,...
                    "RawLineWidth",         obj.RawLineWidth,...
                    "SmoothLineWidth",      obj.SmoothLineWidth,...
                    "BackgroundColor",      obj.BackgroundColor,...
                    "ForegroundColor",      obj.ForegroundColor,...
                    "AnnotationsColor",     obj.AnnotationsColor,...
                    "ColorMode",            obj.ColorMode,...
                    "AlphaMode",            obj.AlphaMode,...
                    "PeakAreaAlpha",        obj.PeakAreaAlpha,...
                    "DistanceAnnotations",  obj.DistanceAnnotations,...
                    "DistanceAnnotationsMode", obj.DistanceAnnotationsMode,...
                    "WidthAnnotations",     obj.WidthAnnotations,...
                    "WidthAnnotationsMode", obj.WidthAnnotationsMode);

                for i = 1:numel(obj.PeaksPlot)
                    [color,rawColor,smoothColor,annotationsColor,areaColor] = obj.getPlotColors(i);
                    set(obj.PeaksPlot(i), ...
                        "Color",color, ...
                        "RawLineColor",rawColor, ...
                        "SmoothLineColor",smoothColor, ...
                        "AnnotationsColor",annotationsColor, ...
                        "PeakAreaColor",areaColor, ...
                        "DistanceAnnotationY",laneY(i));
                    obj.PeaksPlot(i).Data = obj.Data(i);
                end
            end
            % --- axes title properties ---
            obj.AxesTitle.String    = obj.Title; % title text
            obj.AxesTitle.Color     = obj.ForegroundColor; % title font color
            obj.AxesTitle.Visible   = obj.TitleVisible;
            obj.AxesTitle.FontSize  = obj.FontSize;
            % --- grid properties ---
            obj.Grid.BackgroundColor = obj.BackgroundColor;
            % --- axes properties ---
            obj.MainAxes.Color          = obj.BackgroundColor; % axis background color
            obj.MainAxes.XColor         = obj.ForegroundColor; % x-axis line color
            obj.MainAxes.YColor         = obj.ForegroundColor; % y-axis line color
            obj.MainAxes.XLabel.Color   = obj.ForegroundColor; % x-axis label font color
            obj.MainAxes.YLabel.Color   = obj.ForegroundColor; % y-axis label font color
            obj.MainAxes.XLabel.String  = obj.XLabel; % x-axis label text
            obj.MainAxes.YLabel.String  = obj.YLabel; % y-axis label text
            obj.MainAxes.FontSize       = obj.FontSize;
            obj.MainAxes.FontName       = obj.FontName;
            obj.updateDistanceAnnotationAxes();
        end
    end

    %% private helpers
    methods(Access=private)
        function registerFigureEventHub(obj)
            fig = ancestor(obj,'figure');
            if isempty(fig) || ~isvalid(fig)
                return
            end

            obj.Hub = matlabx.ui.interaction.FigureEventHub.ensure(fig);
            obj.HubID = obj.Hub.register(obj, ...
                "Priority",0, ...
                "CaptureDuringDrag",false);
        end

        function unregisterFigureEventHub(obj)
            if isempty(obj.Hub) || ~isvalid(obj.Hub) || ~isfinite(obj.HubID)
                return
            end

            obj.Hub.unregister(obj.HubID);
            obj.HubID = NaN;
        end

        function syncPeaksPlotCount(obj)
            % Match the number of scalar PeaksPlot renderers to Data length.
            nDesired = numel(obj.Data);
            nCurrent = numel(obj.PeaksPlot);

            if nCurrent > nDesired
                delete(obj.PeaksPlot(nDesired+1:end));
                if nDesired == 0
                    obj.PeaksPlot = desmostorm.widgets.PeaksPlot.empty(0,1);
                else
                    obj.PeaksPlot = obj.PeaksPlot(1:nDesired);
                end
                nCurrent = nDesired;
            end

            for i = nCurrent+1:nDesired
                obj.PeaksPlot(i,1) = desmostorm.widgets.PeaksPlot( ...
                    obj.MainAxes, ...
                    desmostorm.analysis.PeaksData.empty());
            end
        end

        function clearPeakHighlights(obj)
            for i = 1:numel(obj.PeaksPlot)
                obj.PeaksPlot(i).clearPeakHighlight();
            end
        end

        function clearPeakLocks(obj)
            for i = 1:numel(obj.PeaksPlot)
                obj.PeaksPlot(i).clearPeakLock();
            end
        end

        function laneY = getDistanceAnnotationLanes(obj)
            nPlots = numel(obj.PeaksPlot);
            laneY = nan(nPlots,1);

            if ~strcmp(obj.DistanceAnnotationsMode,'lanes') || isempty(obj.Data)
                return
            end

            lims = obj.getDistanceAnnotationAxisLimits();
            if isempty(lims)
                return
            end

            bandMin = lims.TickLim(2);
            bandMax = lims.DisplayLim(2);
            if bandMax <= bandMin
                return
            end

            bandHeight = bandMax - bandMin;
            lanePad = 0.18*bandHeight;
            laneStep = 0;
            if nPlots > 1
                laneStep = (bandHeight - 2*lanePad)/(nPlots - 1);
            end

            laneY(:) = bandMax - lanePad - laneStep*(0:nPlots-1);
        end

        function updateDistanceAnnotationAxes(obj)
            if ~strcmp(obj.DistanceAnnotationsMode,'lanes') || isempty(obj.Data)
                obj.MainAxes.YLimMode = "auto";
                obj.MainAxes.YTickMode = "auto";
                return
            end

            lims = obj.getDistanceAnnotationAxisLimits();
            if isempty(lims)
                return
            end

            obj.MainAxes.YLim = lims.DisplayLim;
            obj.MainAxes.YTick = lims.Ticks;
        end

        function lims = getDistanceAnnotationAxisLimits(obj)
            lims = [];
            dataLim = obj.getDataYLim();
            if isempty(dataLim)
                return
            end

            bandFraction = obj.getDistanceAnnotationBandFraction();

            lims = matlabx.ui.axes.niceLimitsAndTicks(dataLim, ...
                IncludeZero=true, ...
                TargetTicks=obj.DistanceAnnotationTargetTicks, ...
                ExtendTopFraction=bandFraction);
        end

        function bandFraction = getDistanceAnnotationBandFraction(obj)
            nLanes = max(numel(obj.PeaksPlot),1);
            bandFraction = obj.DistanceAnnotationBaseBandFraction + ...
                obj.DistanceAnnotationLaneBandFraction*(nLanes - 1);
            bandFraction = min(bandFraction,obj.DistanceAnnotationBandFraction);
        end

        function dataLim = getDataYLim(obj)
            yMin = Inf;
            yMax = -Inf;

            for i = 1:numel(obj.Data)
                if isempty(obj.Data(i))
                    continue
                end

                y = [obj.Data(i).SignalNorm; obj.Data(i).SignalSmooth];
                y = y(isfinite(y));
                if isempty(y)
                    continue
                end

                yMin = min(yMin,min(y));
                yMax = max(yMax,max(y));
            end

            if isinf(yMin) || isinf(yMax)
                dataLim = [];
            else
                dataLim = [yMin yMax];
            end
        end

        function xy = getAxesPoint(obj,E)
            % Prefer the hub-provided current axes when available.
            ax = obj.MainAxes;
            if isprop(E,'CurrentAxes') && obj.isLiveGraphicsHandle(E.CurrentAxes)
                if obj.isSameHandle(E.CurrentAxes,obj.MainAxes)
                    ax = E.CurrentAxes;
                end
            end

            cp = ax.CurrentPoint;
            xy = cp(1,1:2);
        end

        function claim = getPeakClaimAtPoint(obj,xy)
            claim = struct( ...
                "PlotIndex",NaN, ...
                "PeakIndex",NaN, ...
                "DistanceToPeak",Inf);

            candidates = struct( ...
                "PlotIndex",{}, ...
                "PeakIndex",{}, ...
                "DistanceToPeak",{});

            for i = 1:numel(obj.PeaksPlot)
                plotCandidates = obj.PeaksPlot(i).peakCandidatesAtPoint(xy);
                for j = 1:numel(plotCandidates)
                    candidates(end+1,1) = struct( ...
                        "PlotIndex",i, ...
                        "PeakIndex",plotCandidates(j).PeakIndex, ...
                        "DistanceToPeak",plotCandidates(j).DistanceToPeak); %#ok<AGROW>
                end
            end

            if isempty(candidates)
                return
            end

            [~,idx] = min([candidates.DistanceToPeak]);
            claim = candidates(idx);
        end

        function tf = isDescendantOfMainAxes(obj,tgt)
            tf = false;

            while isprop(tgt,'Parent')
                tgt = tgt.Parent;
                if ~obj.isLiveGraphicsHandle(tgt)
                    return
                end

                if obj.isSameHandle(tgt,obj.MainAxes)
                    tf = true;
                    return
                end
            end
        end

        function tf = isLiveGraphicsHandle(~,h)
            % Hub event targets can occasionally be opaque graphics wrappers.
            % Use isgraphics first, then fall back to isvalid only for handles
            % that support it.
            tf = false;
            if isempty(h)
                return
            end

            try
                tf = isgraphics(h);
            catch
                tf = false;
            end

            if tf
                return
            end

            if isa(h,'handle')
                try
                    tf = isvalid(h);
                catch
                    tf = false;
                end
            end
        end

        function tf = isSameHandle(~,a,b)
            try
                tf = isequal(a,b);
            catch
                tf = false;
            end
        end

        function [color,rawColor,smoothColor,annotationsColor,areaColor] = getPlotColors(obj,idx)
            % Use explicit per-plot colors when present, otherwise cycle overlays.
            if idx <= size(obj.Colors,1)
                color = obj.Colors(idx,:);
            elseif idx <= size(obj.SmoothLineColors,1)
                color = obj.SmoothLineColors(idx,:);
            elseif numel(obj.Data) > 1
                colorIdx = mod(idx-1,size(obj.ColorOrder,1)) + 1;
                color = obj.ColorOrder(colorIdx,:);
            else
                color = obj.Color;
            end

            if idx <= size(obj.SmoothLineColors,1)
                smoothColor = obj.SmoothLineColors(idx,:);
            elseif strcmp(obj.ColorMode,'auto')
                smoothColor = color;
            else
                smoothColor = obj.SmoothLineColor;
            end

            if idx <= size(obj.RawLineColors,1)
                rawColor = obj.RawLineColors(idx,:);
            elseif strcmp(obj.ColorMode,'auto')
                rawColor = color;
            else
                rawColor = obj.RawLineColor;
            end

            if idx <= size(obj.AnnotationsColors,1)
                annotationsColor = obj.AnnotationsColors(idx,:);
            elseif strcmp(obj.AnnotationColorMode,'auto')
                annotationsColor = color;
            else
                annotationsColor = obj.AnnotationColor;
            end

            if idx <= size(obj.PeakAreaColors,1)
                areaColor = obj.PeakAreaColors(idx,:);
            elseif strcmp(obj.ColorMode,'auto')
                areaColor = color;
            else
                areaColor = obj.PeakAreaColor;
            end
        end
    end

    %% public-facing helpers
    methods
        function delete(obj)
            obj.unregisterFigureEventHub();
        end

        function export(obj,filename,opts)
            arguments
                obj                         (1,1) desmostorm.widgets.PeaksPlotContainer
                filename                    (1,:) char = 'peaks-plot.pdf'
                opts.ContentType            = "vector"
                opts.Append                 = false
                % BackgroundColor - "current" (default) | "none" | RGB triplet | "r" | "g" | "b" | ...
                opts.BackgroundColor        = [1 1 1]
                opts.Units                  (1,:) char = 'inches'
                opts.Width                  (1,1) double = 6.5
                opts.Height                 (1,1) double = 3
                opts.PreserveAspectRatio    (1,:) char {mustBeMember(opts.PreserveAspectRatio,{'auto','on','off'})} = 'off'
            end

            exportgraphics(obj.MainAxes,filename,...
                "ContentType",opts.ContentType,...
                "Append",opts.Append,...
                "BackgroundColor",opts.BackgroundColor,...
                "Units",opts.Units,...
                "Width",opts.Width,...
                "Height",opts.Height,...
                "PreserveAspectRatio",opts.PreserveAspectRatio)
        end
    end

    %% Hub-facing event handlers
    methods
        function tf = matches(obj,E)
            if E.Kind == "Key" || isempty(obj.MainAxes) || ~isvalid(obj.MainAxes)
                tf = false;
                return
            end

            tgt = E.Target;
            if ~obj.isLiveGraphicsHandle(tgt)
                tf = false;
                return
            end

            tf = obj.isSameHandle(tgt,obj.MainAxes) || obj.isDescendantOfMainAxes(tgt);
        end

        function onMove(obj,E)
            if isempty(obj.MainAxes) || ~isvalid(obj.MainAxes)
                return
            end

            xy = obj.getAxesPoint(E);
            claim = obj.getPeakClaimAtPoint(xy);

            for i = 1:numel(obj.PeaksPlot)
                if i == claim.PlotIndex
                    obj.PeaksPlot(i).highlightPeak(claim.PeakIndex);
                else
                    obj.PeaksPlot(i).clearPeakHighlight();
                end
            end
        end

        function onDown(obj,E)
            if obj.WidthAnnotations == "off"
                return
            end

            xy = obj.getAxesPoint(E);
            claim = obj.getPeakClaimAtPoint(xy);
            if isnan(claim.PlotIndex)
                obj.clearPeakLocks();
                return
            end

            obj.PeaksPlot(claim.PlotIndex).togglePeakLock(claim.PeakIndex);
        end

        % No-ops required by FigureEventHub.
        function onUp(~,~),     end
        function onScroll(~,~), end
        function onKey(~,~),    end
        function onEnter(~,~),  end

        function onLeave(obj,~)
            obj.clearPeakHighlights();
        end
    end

    %% static helpers
    methods (Static)
        function [peaksData,peaksPlot] = demo()
            % generate some random sample data
            [X,Y] = desmostorm.analysis.PeaksData.generateRandomGaussPeaks(1001,10,0.2);
            % create an instance of PeaksData
            peaksData = desmostorm.analysis.PeaksData(Y,X,...
                "MinPeakHeight",0.2,...
                "MinPeakDistance",25,...
                "PeakSmoothing",15,...
                "MinPeakProminence",0.05,...
                "PeakSmoothing",15,...
                "Normalize",true);
            % create new figure
            fig = uifigure("WindowStyle","alwaysontop");
            % create a PeaksPlotContainer in the figure
            peaksPlot = desmostorm.widgets.PeaksPlotContainer(fig,'Data',peaksData);
        end


        function [peaksData,peaksPlotContainer] = demo2()
            % generate some random sample data
            [X,Y,data] = desmostorm.analysis.PeaksData.generateRandomGaussPeaks(...
                "N",1001,...
                "nPeaks",10,...
                "noiseSigma",0.05);
            % create an instance of PeaksData
            peaksData = desmostorm.analysis.PeaksData(Y,X,...
                "MinPeakHeight",0.2,...
                "MinPeakDistance",25,...
                "PeakSmoothing",15,...
                "MinPeakProminence",0.05,...
                "Normalize",false);

            pos = matlabx.UICal.centeredFigOuterPosition(750,350);

            % create new figure
            fig = uifigure(...
                "WindowStyle","alwaysontop",...
                "OuterPosition",pos);
            % add grid with a single row and column
            g = uigridlayout(fig,[1,1],...
                "ColumnWidth",{'1x'},...
                "RowHeight",{'1x'},...
                "Padding",[0 0 0 0]);
            % create a PeaksPlotContainer in the figure
            peaksPlotContainer = desmostorm.widgets.PeaksPlotContainer(g,...
                "Data",peaksData);

            matlabx.struct.prettyPrint(data);
        end


        function [peaksData,peaksPlotContainer] = demoOverlay(nScans)
            arguments
                nScans (1,1) double {mustBeInteger,mustBePositive} = 3
            end

            peaksData = desmostorm.analysis.PeaksData.empty(0,1);

            for i = 1:nScans
                [X,Y] = desmostorm.analysis.PeaksData.generateRandomGaussPeaks(...
                    "N",1001,...
                    "nPeaks",8,...
                    "noiseSigma",0.04 + 0.02*i);

                peaksData(i,1) = desmostorm.analysis.PeaksData(Y,X,...
                    "MinPeakHeight",0.2,...
                    "MinPeakDistance",25,...
                    "PeakSmoothing",15,...
                    "MinPeakProminence",0.05,...
                    "Normalize",true);
            end

            pos = matlabx.UICal.centeredFigOuterPosition(750,350);

            fig = uifigure(...
                "WindowStyle","alwaysontop",...
                "OuterPosition",pos);

            g = uigridlayout(fig,[1,1],...
                "ColumnWidth",{'1x'},...
                "RowHeight",{'1x'},...
                "Padding",[0 0 0 0]);

            peaksPlotContainer = desmostorm.widgets.PeaksPlotContainer(g,...
                "Data",peaksData,...
                "Title",sprintf("%d overlaid linescans",nScans));
        end



    end

end
