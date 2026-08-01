classdef PeaksPlot < handle & matlab.mixin.SetGetExactNames

    % Appearance
    properties(AbortSet)
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
        % color of label background
        BackgroundColor (1,3) double = [1 1 1]
        % color of annotation lines and borders
        ForegroundColor (1,3) double = [0 0 0]
        % color of peak annotation lines
        AnnotationsColor (1,3) double = [0 0 0]
        % base color used when ColorMode is auto
        Color (1,3) double {mustBeInRange(Color,0,1)} = [0 0 0]
        % auto derives raw/smooth/area colors from Color; manual uses per-object colors
        ColorMode (1,:) char {mustBeMember(ColorMode,{'auto','manual'})} = 'auto'
        % auto uses default alpha levels; manual uses per-object alpha values
        AlphaMode (1,:) char {mustBeMember(AlphaMode,{'auto','manual'})} = 'auto'
        % width of raw signal line
        RawLineWidth (1,1) double = 1
        % color of raw signal line
        RawLineColor (1,3) double {mustBeInRange(RawLineColor,0,1)} = [0.5 0.5 0.5]
        % raw signal color used on hover
        RawLineHoverColor (1,3) double {mustBeInRange(RawLineHoverColor,0,1)} = [0.5 0.5 0.5]
        % raw signal color used when selected
        RawLineSelectedColor (1,3) double {mustBeInRange(RawLineSelectedColor,0,1)} = [0.5 0.5 0.5]
        % alpha of raw signal line
        RawLineAlpha (1,1) double {mustBeInRange(RawLineAlpha,0,1)} = 0.5
        % raw signal alpha used on hover
        RawLineHoverAlpha (1,1) double {mustBeInRange(RawLineHoverAlpha,0,1)} = 0.65
        % raw signal alpha used when selected
        RawLineSelectedAlpha (1,1) double {mustBeInRange(RawLineSelectedAlpha,0,1)} = 0.75
        % width of smoothed signal line
        SmoothLineWidth (1,1) double = 1
        % color of smoothed signal line
        SmoothLineColor (1,3) double {mustBeInRange(SmoothLineColor,0,1)} = [0 0 0]
        % smoothed signal color used on hover
        SmoothLineHoverColor (1,3) double {mustBeInRange(SmoothLineHoverColor,0,1)} = [0 0 0]
        % smoothed signal color used when selected
        SmoothLineSelectedColor (1,3) double {mustBeInRange(SmoothLineSelectedColor,0,1)} = [0 0 0]
        % alpha of smoothed signal line
        SmoothLineAlpha (1,1) double {mustBeInRange(SmoothLineAlpha,0,1)} = 1
        % smoothed signal alpha used on hover
        SmoothLineHoverAlpha (1,1) double {mustBeInRange(SmoothLineHoverAlpha,0,1)} = 1
        % smoothed signal alpha used when selected
        SmoothLineSelectedAlpha (1,1) double {mustBeInRange(SmoothLineSelectedAlpha,0,1)} = 1
        % color of shaded peak areas
        PeakAreaColor (1,3) double {mustBeInRange(PeakAreaColor,0,1)} = [0 0 0]
        % shaded peak area color used on hover
        PeakAreaHoverColor (1,3) double {mustBeInRange(PeakAreaHoverColor,0,1)} = [0 0 0]
        % shaded peak area color used when selected
        PeakAreaSelectedColor (1,3) double {mustBeInRange(PeakAreaSelectedColor,0,1)} = [0 0 0]
        % alpha of shaded peak areas
        PeakAreaAlpha (1,1) double {mustBeInRange(PeakAreaAlpha,0,1)} = 0
        % shaded peak area alpha used on hover
        PeakAreaHoverAlpha (1,1) double {mustBeInRange(PeakAreaHoverAlpha,0,1)} = 0.2
        % shaded peak area alpha used when selected
        PeakAreaSelectedAlpha (1,1) double {mustBeInRange(PeakAreaSelectedAlpha,0,1)} = 0.4
        % visibility of the peak FWHM annotations
        WidthAnnotations (1,1) matlab.lang.OnOffSwitchState = "on"
        % display mode for peak FWHM annotations
        WidthAnnotationsMode (1,:) char {mustBeMember(WidthAnnotationsMode,{'normal','hover'})} = 'normal'
        % visibility of the peak distance annotations
        DistanceAnnotations (1,1) matlab.lang.OnOffSwitchState = "on"
        % display mode for peak distance annotations
        DistanceAnnotationsMode (1,:) char {mustBeMember(DistanceAnnotationsMode,{'data','lanes'})} = 'lanes'
        % y-position for peak distance annotations when DistanceAnnotationsMode is lanes
        DistanceAnnotationY (1,1) double = NaN
    end

    %% public properties with private backing
    properties(Dependent)
        Parent (1,1) matlab.ui.control.UIAxes
        Data desmostorm.analysis.PeaksData
    end

    properties(Access=private)
        Parent_ (1,1) matlab.ui.control.UIAxes
        Data_ desmostorm.analysis.PeaksData
        ActivePeakIndex_ (1,1) double = NaN
        LockedPeakIndices_ (:,1) double = []
    end

    %% graphics components the PeaksPlot is built from
    properties(Access = private,Transient,NonCopyable)
        PeakPatches (:,1) matlab.graphics.primitive.Patch
        ProfileRaw (1,1) matlab.graphics.primitive.Line
        Profile (1,1) matlab.graphics.primitive.Line
        PeakVerticalLines (1,1) matlab.graphics.primitive.Line
        PeakToPeakLines (1,1) matlab.graphics.primitive.Line
        PeakWidthLines (1,1) matlab.graphics.primitive.Line
        PeakBorderLines (1,1) matlab.graphics.primitive.Line
        WidthLabels (:,1) matlab.graphics.primitive.Text
        PeakToPeakLabels (:,1) matlab.graphics.primitive.Text
    end


    methods
        function obj = PeaksPlot(ax,data) % constructor
            arguments
                ax (1,1) matlab.ui.control.UIAxes
                data desmostorm.analysis.PeaksData
            end

            if numel(data) > 1
                error("desmostorm:PeaksPlot:NonScalarData", ...
                    "PeaksPlot accepts one PeaksData object. Use PeaksPlotContainer for multiple scans.");
            end

            % create empty line/text objects to show signal profile, peak annotations, distance/width values, etc.
            obj.PeakPatches = matlab.graphics.primitive.Patch.empty();
            % the raw input signal (after normalization)
            obj.ProfileRaw = line(ax,...
                NaN,NaN,...
                'LineWidth',obj.RawLineWidth,...
                'Color',obj.RawLineColor,...
                'DisplayName','Raw');
            % the final signal used for peak detection (after appying optional smoothing)
            obj.Profile = line(ax,...
                NaN,NaN,...
                'LineWidth',obj.SmoothLineWidth,...
                'Color',obj.SmoothLineColor,...
                'DisplayName','Smoothed');
            % dashed vertical lines showing peak locations, from baseline to maximum value of normalized/smoothed
            obj.PeakVerticalLines = line(ax,...
                NaN,NaN,'LineWidth',0.5,'Color',[1 1 1],'LineStyle','--');
            obj.PeakVerticalLines.Annotation.LegendInformation.IconDisplayStyle = "off";
            % horizontal lines showing distances between peaks
            obj.PeakToPeakLines = line(ax,...
                NaN,NaN,'LineWidth',0.5,'Color',[1 1 1],'LineStyle','-');
            obj.PeakToPeakLines.Annotation.LegendInformation.IconDisplayStyle = "off";
            % horizontal lines showing FWHM
            obj.PeakWidthLines = line(ax,...
                NaN,NaN,'LineWidth',0.5,'Color',[1 1 1],'LineStyle','-');
            obj.PeakWidthLines.Annotation.LegendInformation.IconDisplayStyle = "off";
            % vertical lines showing peak borders, from baseline to signal
            obj.PeakBorderLines = line(ax,...
                NaN,NaN,'LineWidth',0.5,'Color',[1 1 1],'LineStyle','-');
            obj.PeakBorderLines.Annotation.LegendInformation.IconDisplayStyle = "off";
            % empty label arrays for peak widths and distances
            obj.WidthLabels = matlab.graphics.primitive.Text.empty();
            obj.PeakToPeakLabels = matlab.graphics.primitive.Text.empty();

            % Initialize the axes and update the plot with the provided data
            obj.Parent_ = ax;
            obj.Data_ = data;
            obj.update();
        end

        function delete(obj)
            % Remove graphics owned by this renderer when a container drops it.
            for i = 1:numel(obj)
                obj(i).deleteGraphics();
            end
        end

        function update(obj) % update helper
            %% update plot objects

            ax = obj.Parent;

            if ~isempty(obj.Data)
                % get the SCALED output data (data multiplied by user-defined scaling-factor)
                S = obj.Data.OutputScaled;
                G = obj.annotationGraphicsFromData(S);
                % signal profile lines
                set(obj.ProfileRaw,'XData',S.Location,'YData',S.SignalNorm);
                set(obj.Profile,'XData',S.Location,'YData',S.SignalSmooth);
                % shaded peak areas
                obj.updatePeakPatches(S);
                % annotation lines
                set(obj.PeakVerticalLines,'XData',G.VerticalLineXY(1,:),'YData',G.VerticalLineXY(2,:));
                set(obj.PeakToPeakLines,'XData',G.PeakToPeakLineXY(1,:),'YData',G.PeakToPeakLineXY(2,:));
                set(obj.PeakWidthLines,'XData',G.WidthLineXY(1,:),'YData',G.WidthLineXY(2,:));
                set(obj.PeakBorderLines,'XData',G.BorderLineXY(1,:),'YData',G.BorderLineXY(2,:));
                % annotation labels
                % --- width ---
                % only keep existing labels with valid handles
                if ~isempty(obj.WidthLabels)
                    obj.WidthLabels = obj.WidthLabels(isvalid(obj.WidthLabels));
                end
                % determine how many peak width labels we need
                nLabels = numel(obj.WidthLabels);
                nNeeded = numel(S.PeakWidths);
                % delete excess peak width labels as needed
                if nLabels > nNeeded
                    delete(obj.WidthLabels(nNeeded+1:end,1));
                    obj.WidthLabels = obj.WidthLabels(1:nNeeded,1);
                end
                % --- peak distance ---
                % only keep existing labels with valid handles
                if ~isempty(obj.PeakToPeakLabels)
                    obj.PeakToPeakLabels = obj.PeakToPeakLabels(isvalid(obj.PeakToPeakLabels));
                end
                % determine how many peak distance labels we need
                nLabels = numel(obj.PeakToPeakLabels);
                if numel(S.PeakLocations) > 0
                    nNeeded = numel(S.PeakLocations)-1;
                else
                    nNeeded = 0;
                end
                % delete excess peak distance labels as needed
                if nLabels > nNeeded
                    delete(obj.PeakToPeakLabels(nNeeded+1:end,1));
                    obj.PeakToPeakLabels = obj.PeakToPeakLabels(1:nNeeded,1);
                end
                % hold on so we can plot multiple objects with overwriting
                hold(ax,"on");
                % for each peak
                for i = 1:numel(S.PeakLocations)
                    % create new peak width labels as needed
                    if numel(obj.WidthLabels) < i
                        obj.WidthLabels(i) = text("Parent",ax);
                    end
                    % update peak width labels
                    set(obj.WidthLabels(i),...
                        'Position',G.WidthLabelXY(i,:),...
                        'Color',obj.ForegroundColor,...
                        'BackgroundColor',[obj.BackgroundColor],...
                        'EdgeColor',obj.ForegroundColor,...
                        'String',sprintf('%.2f %s',S.PeakWidths(i),obj.Data.DistanceUnit),...
                        'VerticalAlignment','middle',...
                        'HorizontalAlignment','center',...
                        'FontSize',obj.AnnotationsFontSize,...
                        'Margin',obj.AnnotationsMargin);
                    % break loop if i == (num peaks - 1)
                    if i==numel(S.PeakLocations)
                        continue
                    end
                    % create new peak distance label if needed
                    if numel(obj.PeakToPeakLabels) < i
                        obj.PeakToPeakLabels(i) = text("Parent",ax);
                    end
                    % update peak distance label properties
                    set(obj.PeakToPeakLabels(i),...
                        'Position',G.PeakToPeakLabelXY(i,:),...
                        'Color',obj.ForegroundColor,...
                        'BackgroundColor',[obj.BackgroundColor],...
                        'EdgeColor',obj.ForegroundColor,...
                        'String',sprintf('%.2f %s',S.PeakDistances(i),obj.Data.DistanceUnit),...
                        'VerticalAlignment','middle',...
                        'HorizontalAlignment','center',...
                        'FontSize',obj.AnnotationsFontSize,...
                        'Margin',obj.AnnotationsMargin);
                end
                % release hold
                hold(ax,"off");
            else
                % signal profile lines
                set(obj.ProfileRaw,'XData',[],'YData',[]);
                set(obj.Profile,'XData',[],'YData',[]);
                % shaded peak areas
                obj.syncPeakPatchCount(0);
                % annotation lines
                set(obj.PeakVerticalLines,'XData',[],'YData',[]);
                set(obj.PeakToPeakLines,'XData',[],'YData',[]);
                set(obj.PeakWidthLines,'XData',[],'YData',[]);
                set(obj.PeakBorderLines,'XData',[],'YData',[]);
                % width labels
                delete(obj.WidthLabels(:));
                obj.WidthLabels = matlab.graphics.primitive.Text.empty();
                % peak distance labels
                delete(obj.PeakToPeakLabels(:));
                obj.PeakToPeakLabels = matlab.graphics.primitive.Text.empty();
            end


            % --- update various components ---

            % signal profile lines
            rawStyle = obj.resolveObjectStyle('RawLine','normal');
            smoothStyle = obj.resolveObjectStyle('SmoothLine','normal');
            set(obj.ProfileRaw,'Color',[rawStyle.Color rawStyle.Alpha],'LineWidth',obj.RawLineWidth);
            set(obj.Profile,'Color',[smoothStyle.Color smoothStyle.Alpha],'LineWidth',obj.SmoothLineWidth);

            % shaded peak areas
            set(obj.PeakPatches, ...
                "EdgeColor","none");
            obj.updatePeakPatchAppearance();

            % annotation lines
            set([obj.PeakVerticalLines,obj.PeakToPeakLines], ...
                "Color",obj.AnnotationsColor, ...
                "LineWidth",1);
            set(obj.PeakWidthLines, ...
                "Color",obj.AnnotationsColor, ...
                "LineWidth",1);
            set(obj.PeakBorderLines, ...
                "Color",obj.AnnotationsColor, ...
                "LineWidth",1);

            % annotation labels
            set(obj.PeakToPeakLabels, ...
                "FontName",obj.FontName, ...
                "FontSize",obj.AnnotationsFontSize, ...
                "Margin",obj.AnnotationsMargin);
            obj.updateAnnotationLabelAppearance();
            obj.updateDistanceAnnotationVisibility();
            set(obj.WidthLabels, ...
                "FontName",obj.FontName, ...
                "FontSize",obj.AnnotationsFontSize, ...
                "Margin",obj.AnnotationsMargin);
            obj.updateAnnotationLabelAppearance();
            obj.updateWidthAnnotationVisibility();
        end

        function h = get.Parent(obj)
            h = obj.Parent_;
        end

        function set.Parent(obj,h)
            arguments
                obj (1,1) desmostorm.widgets.PeaksPlot
                h (1,1) matlab.ui.control.UIAxes
            end

            set([...
                obj.PeakPatches,...
                obj.ProfileRaw,...
                obj.Profile,...
                obj.PeakVerticalLines,...
                obj.PeakToPeakLines,...
                obj.PeakWidthLines,...
                obj.PeakBorderLines,...
                obj.WidthLabels,...
                obj.PeakToPeakLabels],...
                'Parent',h);

            obj.Parent_ = h;
        end

        function h = get.Data(obj)
            h = obj.Data_;
        end

        function set.Data(obj,data)
            arguments
                obj (1,1) desmostorm.widgets.PeaksPlot
                data desmostorm.analysis.PeaksData
            end

            if numel(data) > 1
                error("desmostorm:PeaksPlot:NonScalarData", ...
                    "PeaksPlot accepts one PeaksData object. Use PeaksPlotContainer for multiple scans.");
            end

            dataChanged = ~isequal(obj.Data_,data);
            obj.Data_ = data;
            obj.ActivePeakIndex_ = NaN;
            if dataChanged
                obj.LockedPeakIndices_ = [];
            end
            obj.update();
        end

        function peakIdx = hitTestPeakAtPoint(obj,xy)
            arguments
                obj (1,1) desmostorm.widgets.PeaksPlot
                xy (1,2) double
            end

            peakIdx = obj.findPeakAtPoint(xy);
        end

        function candidates = peakCandidatesAtPoint(obj,xy)
            arguments
                obj (1,1) desmostorm.widgets.PeaksPlot
                xy (1,2) double
            end

            candidates = obj.findPeakCandidatesAtPoint(xy);
        end

        function highlightPeak(obj,peakIdx)
            arguments
                obj (1,1) desmostorm.widgets.PeaksPlot
                peakIdx (1,1) double
            end

            obj.setActivePeak(peakIdx);
        end

        function clearPeakHighlight(obj)
            obj.setActivePeak(NaN);
        end

        function tf = togglePeakLock(obj,peakIdx)
            arguments
                obj (1,1) desmostorm.widgets.PeaksPlot
                peakIdx (1,1) double
            end

            if obj.WidthAnnotations == "off" || isnan(peakIdx)
                tf = false;
                return
            end

            if ismember(peakIdx,obj.LockedPeakIndices_)
                obj.LockedPeakIndices_(obj.LockedPeakIndices_ == peakIdx) = [];
                tf = false;
            else
                obj.LockedPeakIndices_(end+1,1) = peakIdx;
                obj.LockedPeakIndices_ = unique(obj.LockedPeakIndices_,"stable");
                tf = true;
            end

            obj.updatePeakPatchAppearance();
            obj.updateWidthAnnotationVisibility();
        end

        function clearPeakLock(obj)
            obj.LockedPeakIndices_ = [];
            obj.updatePeakPatchAppearance();
            obj.updateWidthAnnotationVisibility();
        end

    end


    methods(Access=private)
        function deleteGraphics(obj)
            props = { ...
                "ProfileRaw", ...
                "Profile", ...
                "PeakPatches", ...
                "PeakVerticalLines", ...
                "PeakToPeakLines", ...
                "PeakWidthLines", ...
                "PeakBorderLines", ...
                "WidthLabels", ...
                "PeakToPeakLabels"};

            for p = 1:numel(props)
                h = obj.(props{p});
                if isempty(h)
                    continue
                end

                h = h(isvalid(h));
                if ~isempty(h)
                    delete(h);
                end
            end
        end

        function peakIdx = findPeakAtPoint(obj,xy)
            candidates = obj.findPeakCandidatesAtPoint(xy);
            if isempty(candidates)
                peakIdx = NaN;
            else
                [~,idx] = min([candidates.DistanceToPeak]);
                peakIdx = candidates(idx).PeakIndex;
            end
        end

        function candidates = findPeakCandidatesAtPoint(obj,xy)
            candidates = struct( ...
                "PeakIndex",{}, ...
                "PeakLocation",{}, ...
                "DistanceToPeak",{});

            if isempty(obj.PeakPatches)
                return
            end

            if isempty(obj.Data) || isempty(obj.Data.PeakGeometry)
                return
            end

            geom = obj.Data.OutputScaled.PeakGeometry;

            for i = 1:numel(obj.PeakPatches)
                h = obj.PeakPatches(i);
                if ~isvalid(h)
                    continue
                end

                if inpolygon(xy(1),xy(2),h.XData,h.YData)
                    candidates(end+1,1) = struct( ...
                        "PeakIndex",i, ...
                        "PeakLocation",geom(i).PeakLocation, ...
                        "DistanceToPeak",abs(xy(1) - geom(i).PeakLocation)); %#ok<AGROW>
                end
            end
        end

        function setActivePeak(obj,peakIdx)
            if isequaln(obj.ActivePeakIndex_,peakIdx)
                return
            end

            obj.ActivePeakIndex_ = peakIdx;
            obj.updatePeakPatchAppearance();
            obj.updateWidthAnnotationVisibility();
            obj.updateDistanceAnnotationVisibility();
        end

        function updatePeakPatchAppearance(obj)
            if isempty(obj.PeakPatches)
                return
            end

            for i = 1:numel(obj.PeakPatches)
                style = obj.resolveObjectStyle('PeakArea',obj.peakState(i));

                set(obj.PeakPatches(i), ...
                    "FaceColor",style.Color, ...
                    "FaceAlpha",style.Alpha);
            end

            obj.updateAnnotationLabelAppearance();
        end

        function updateAnnotationLabelAppearance(obj)
            labelColor = obj.resolveObjectStyle('PeakArea','normal').Color;
            fontColor = matlabx.colors.ops.getBWContrastColor(labelColor);

            labels = [reshape(obj.WidthLabels,1,[]), reshape(obj.PeakToPeakLabels,1,[])];
            if isempty(labels)
                return
            end

            labels = labels(isvalid(labels));
            set(labels, ...
                "Color",fontColor, ...
                "BackgroundColor",labelColor, ...
                "EdgeColor",labelColor);
        end

        function state = peakState(obj,peakIdx)
            if isequal(peakIdx,obj.ActivePeakIndex_)
                state = 'hover';
            elseif ismember(peakIdx,obj.LockedPeakIndices_)
                state = 'selected';
            else
                state = 'normal';
            end
        end

        function style = resolveObjectStyle(obj,objectName,state)
            arguments
                obj (1,1) desmostorm.widgets.PeaksPlot
                objectName (1,:) char {mustBeMember(objectName,{'RawLine','SmoothLine','PeakArea'})}
                state (1,:) char {mustBeMember(state,{'normal','hover','selected'})} = 'normal'
            end

            switch state
                case 'hover'
                    colorProp = [objectName 'HoverColor'];
                    alphaProp = [objectName 'HoverAlpha'];
                case 'selected'
                    colorProp = [objectName 'SelectedColor'];
                    alphaProp = [objectName 'SelectedAlpha'];
                otherwise
                    colorProp = [objectName 'Color'];
                    alphaProp = [objectName 'Alpha'];
            end

            if strcmp(obj.ColorMode,'auto')
                style.Color = obj.Color;
            else
                style.Color = obj.(colorProp);
            end

            if strcmp(obj.AlphaMode,'auto')
                style.Alpha = obj.defaultAlphaFor(objectName,state);
            else
                style.Alpha = obj.(alphaProp);
            end
        end

        function alpha = defaultAlphaFor(~,objectName,state)
            switch objectName
                case 'RawLine'
                    switch state
                        case 'normal',   alpha = 0.45;
                        case 'hover',    alpha = 0.65;
                        case 'selected', alpha = 0.75;
                    end
                case 'SmoothLine'
                    alpha = 1;
                case 'PeakArea'
                    switch state
                        case 'normal',   alpha = 0;
                        case 'hover',    alpha = 0.2;
                        case 'selected', alpha = 0.4;
                    end
            end
        end

        function updateWidthAnnotationVisibility(obj)
            if obj.WidthAnnotations == "off" || isempty(obj.Data)
                set(obj.PeakWidthLines,"Visible","off");
                set(obj.WidthLabels,"Visible","off");
                return
            end

            switch obj.WidthAnnotationsMode
                case 'normal'
                    if ~isempty(obj.Data)
                        G = obj.annotationGraphicsFromData(obj.Data.OutputScaled);
                        set(obj.PeakWidthLines, ...
                            "XData",G.WidthLineXY(1,:), ...
                            "YData",G.WidthLineXY(2,:), ...
                            "Visible","on");
                    end
                    set(obj.WidthLabels,"Visible","on");

                case 'hover'
                    peakIdx = unique([reshape(obj.LockedPeakIndices_,1,[]),obj.ActivePeakIndex_],"stable");
                    peakIdx = peakIdx(~isnan(peakIdx));

                    if isempty(peakIdx) || isempty(obj.Data)
                        set(obj.PeakWidthLines,"Visible","off");
                        set(obj.WidthLabels,"Visible","off");
                        return
                    end

                    G = obj.annotationGraphicsFromData(obj.Data.OutputScaled);
                    lineCols = arrayfun(@(idx) 3*(idx-1)+(1:3),peakIdx,'UniformOutput',false);
                    lineCols = [lineCols{:}];
                    set(obj.PeakWidthLines, ...
                        "XData",G.WidthLineXY(1,lineCols), ...
                        "YData",G.WidthLineXY(2,lineCols), ...
                        "Visible","on");

                    set(obj.WidthLabels,"Visible","off");
                    peakIdx = peakIdx(peakIdx <= numel(obj.WidthLabels));
                    set(obj.WidthLabels(peakIdx),"Visible","on");
            end
        end

        function updateDistanceAnnotationVisibility(obj)
            if obj.DistanceAnnotations == "off" || isempty(obj.Data)
                set(obj.PeakVerticalLines,"Visible","off");
                set(obj.PeakToPeakLines,"Visible","off");
                set(obj.PeakToPeakLabels,"Visible","off");
                return
            end

            G = obj.annotationGraphicsFromData(obj.Data.OutputScaled);
            set(obj.PeakVerticalLines, ...
                "XData",G.VerticalLineXY(1,:), ...
                "YData",G.VerticalLineXY(2,:), ...
                "Visible","on");
            set(obj.PeakToPeakLines, ...
                "XData",G.PeakToPeakLineXY(1,:), ...
                "YData",G.PeakToPeakLineXY(2,:), ...
                "Visible","on");
            set(obj.PeakToPeakLabels,"Visible","on");
        end

        function updatePeakPatches(obj,S)
            geom = S.PeakGeometry;
            obj.syncPeakPatchCount(numel(geom));

            if isempty(geom)
                return
            end

            for i = 1:numel(geom)
                idx = geom(i).LeftBorderIndex:geom(i).RightBorderIndex;
                x = S.Location(idx);
                y = S.SignalSmooth(idx);

                set(obj.PeakPatches(i), ...
                    "XData",[geom(i).LeftBorderLocation; x(:); geom(i).RightBorderLocation; geom(i).LeftBorderLocation], ...
                    "YData",[0; y(:); 0; 0]);
            end

            obj.updatePeakPatchAppearance();

            try
                uistack(obj.PeakPatches,"bottom");
            catch
                % Some UIAxes backends do not support uistack for patches.
            end
        end

        function syncPeakPatchCount(obj,nDesired)
            nCurrent = numel(obj.PeakPatches);

            if nCurrent > nDesired
                delete(obj.PeakPatches(nDesired+1:end));
                obj.PeakPatches = obj.PeakPatches(1:nDesired);
                nCurrent = nDesired;
            end

            for i = nCurrent+1:nDesired
                obj.PeakPatches(i,1) = patch(obj.Parent, ...
                    NaN, ...
                    NaN, ...
                    obj.Color, ...
                    "FaceAlpha",obj.defaultAlphaFor('PeakArea','normal'), ...
                    "EdgeColor","none", ...
                    "HitTest","off", ...
                    "PickableParts","none");
                obj.PeakPatches(i).Annotation.LegendInformation.IconDisplayStyle = "off";
            end
        end

        function G = annotationGraphicsFromData(obj,S)
            % Convert analysis geometry into line/text coordinates for this plot.
            G = struct( ...
                "WidthLineXY",[NaN; NaN], ...
                "VerticalLineXY",[NaN; NaN], ...
                "PeakToPeakLineXY",[NaN; NaN], ...
                "BorderLineXY",[NaN; NaN], ...
                "WidthLabelXY",zeros(0,2), ...
                "PeakToPeakLabelXY",zeros(0,2));

            geom = S.PeakGeometry;
            if isempty(geom)
                return
            end

            nPeaks = numel(geom);
            annotationHeight = max(S.SignalSmooth);
            distanceAnnotationHeight = annotationHeight;
            if strcmp(obj.DistanceAnnotationsMode,'lanes') && isfinite(obj.DistanceAnnotationY)
                distanceAnnotationHeight = obj.DistanceAnnotationY;
            end
            verticalLineHeight = max(annotationHeight,distanceAnnotationHeight);

            G.WidthLineXY = nan(2,nPeaks*3);
            G.VerticalLineXY = nan(2,nPeaks*3);
            G.WidthLabelXY = nan(nPeaks,2);

            for i = 1:nPeaks
                lineIdx = 3*(i-1)+1;

                G.WidthLineXY(:,lineIdx:lineIdx+2) = [ ...
                    geom(i).LeftWidthLocation, geom(i).RightWidthLocation, NaN; ...
                    geom(i).WidthHeight, geom(i).WidthHeight, NaN];

                G.VerticalLineXY(:,lineIdx:lineIdx+2) = [ ...
                    geom(i).PeakLocation, geom(i).PeakLocation, NaN; ...
                    0, verticalLineHeight, NaN];

                G.WidthLabelXY(i,:) = [geom(i).PeakLocation, geom(i).WidthHeight];
            end

            borderIdx = [reshape([geom.LeftBorderIndex],[],1); geom(end).RightBorderIndex];
            borderLocation = [reshape([geom.LeftBorderLocation],[],1); geom(end).RightBorderLocation];
            borderValue = [reshape([geom.LeftBorderValue],[],1); geom(end).RightBorderValue];
            [~,keepIdx] = unique(borderIdx,"stable");
            borderLocation = borderLocation(keepIdx);
            borderValue = borderValue(keepIdx);

            G.BorderLineXY = nan(2,numel(borderLocation)*3);
            for i = 1:numel(borderLocation)
                lineIdx = 3*(i-1)+1;
                G.BorderLineXY(:,lineIdx:lineIdx+2) = [ ...
                    borderLocation(i), borderLocation(i), NaN; ...
                    0, borderValue(i), NaN];
            end

            if nPeaks > 1
                G.PeakToPeakLineXY = nan(2,(nPeaks-1)*3);
                G.PeakToPeakLabelXY = nan(nPeaks-1,2);

                for i = 1:nPeaks-1
                    lineIdx = 3*(i-1)+1;
                    peakLocations = [geom(i).PeakLocation, geom(i+1).PeakLocation];

                    G.PeakToPeakLineXY(:,lineIdx:lineIdx+2) = [ ...
                        peakLocations, NaN; ...
                        distanceAnnotationHeight, distanceAnnotationHeight, NaN];
                    G.PeakToPeakLabelXY(i,:) = [mean(peakLocations), distanceAnnotationHeight];
                end
            end
        end
    end


    %% static helpers
    methods(Static)
        function [peaksData,peaksPlot] = demo()
            % generate some random sample data
            [Location,Signal,data] = desmostorm.analysis.PeaksData.generateRandomGaussPeaks();
            % PeaksData object to store/analyze the random data
            % peaksData = desmostorm.analysis.PeaksData(Signal,Location,...
            %     "MinPeakHeight",0.2,...
            %     "MinPeakDistance",25,...
            %     "MinPeakProminence",0.05,...
            %     "PeakSmoothing",15,...
            %     "Normalize",true);

            peaksData = desmostorm.analysis.PeaksData(Signal,Location,...
                "MinPeakHeight",0.2,...
                "MinPeakDistance",25,...
                "MinPeakProminence",0.5,...
                "PeakSmoothing",15,...
                "Normalize",false);      
            % plot the data (new figure and axes will be made if no axes handle given)
            [peaksPlot,ax] = peaksData.plot();

            hold(ax,"on");

            nBaseSignals = size(data.Gauss_Raw,1);

            colorIdxs = randi([1 256],[1 nBaseSignals]);

            cmap = jet(256);

            for i = 1:nBaseSignals
                clr = cmap(colorIdxs(i),:);
                line(ax,...
                    "XData",Location,...
                    "YData",data.Gauss_Noise(i,:),...
                    "LineWidth",0.5,...
                    "Color",clr);
                line(ax,...
                    "XData",Location,...
                    "YData",data.Gauss_Raw(i,:),...
                    "LineWidth",1,...
                    "Color",clr);
            end

            matlabx.struct.prettyPrint(data);
        end
    end

end
