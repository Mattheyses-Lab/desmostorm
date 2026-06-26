classdef PeaksPlot < handle & matlab.mixin.SetGetExactNames

    % Appearance
    properties(AbortSet)
        % color of axes and title text
        FontColor (1,3) double = [0 0 0]
        % name of the axes font for titles and labels, defaul Arial
        FontName (1,:) char = 'Arial'
        % size of the various text objects
        FontSize (1,1) double = 12
        % color of label background
        BackgroundColor (1,3) double = [1 1 1]
        % color of annotation lines and borders
        ForegroundColor (1,3) double = [0 0 0]
        % width of raw signal line
        RawLineWidth (1,1) double = 1
        % color of raw signal line
        RawLineColor (1,3) double = [0.5 0.5 0.5]
        % width of smoothed signal line
        SmoothLineWidth (1,1) double = 1
        % color of smoothed signal line
        SmoothLineColor (1,3) double = [0 0 0]
        % visibility of the peak FWHM annotations
        WidthAnnotations (1,1) matlab.lang.OnOffSwitchState = "on"
        % visibility of the peak distance annotations
        DistanceAnnotations (1,1) matlab.lang.OnOffSwitchState = "on"
    end

    %% public properties with private backing
    properties(Dependent)
        Parent (1,1) matlab.ui.control.UIAxes
        Data desmostorm.analysis.PeaksData
    end

    properties(Access=private)
        Parent_ (1,1) matlab.ui.control.UIAxes
        Data_ desmostorm.analysis.PeaksData
    end

    %% graphics components the PeaksPlot is built from
    properties(Access = private,Transient,NonCopyable)
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
                data (:,1) desmostorm.analysis.PeaksData
            end

            % create empty line/text objects to show signal profile, peak annotations, distance/width values, etc.
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

        function update(obj) % update helper
            %% update plot objects

            ax = obj.Parent;

            if ~isempty(obj.Data)
                % get the SCALED output data (data multiplied by user-defined scaling-factor)
                S = obj.Data.OutputScaled;
                % signal profile lines
                set(obj.ProfileRaw,'XData',S.Location,'YData',S.SignalNorm);
                set(obj.Profile,'XData',S.Location,'YData',S.SignalSmooth);
                % annotation lines
                set(obj.PeakVerticalLines,'XData',S.VerticalLineXY(1,:),'YData',S.VerticalLineXY(2,:));
                set(obj.PeakToPeakLines,'XData',S.PeakToPeakLineXY(1,:),'YData',S.PeakToPeakLineXY(2,:));
                set(obj.PeakWidthLines,'XData',S.WidthLineXY(1,:),'YData',S.WidthLineXY(2,:));
                set(obj.PeakBorderLines,'XData',S.BorderLineXY(1,:),'YData',S.BorderLineXY(2,:));
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
                        'Position',S.WidthLabelXY(i,:),...
                        'Color',obj.ForegroundColor,...
                        'BackgroundColor',[obj.BackgroundColor],...
                        'EdgeColor',obj.ForegroundColor,...
                        'String',sprintf('%.2f %s',S.PeakWidths(i),obj.Data.DistanceUnit),...
                        'VerticalAlignment','middle',...
                        'HorizontalAlignment','center',...
                        'FontSize',obj.FontSize);
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
                        'Position',S.PeakToPeakLabelXY(i,:),...
                        'Color',obj.ForegroundColor,...
                        'BackgroundColor',[obj.BackgroundColor],...
                        'EdgeColor',obj.ForegroundColor,...
                        'String',sprintf('%.2f %s',S.PeakDistances(i),obj.Data.DistanceUnit),...
                        'VerticalAlignment','middle',...
                        'HorizontalAlignment','center',...
                        'FontSize',obj.FontSize);
                end
                % release hold
                hold(ax,"off");
            else
                % signal profile lines
                set(obj.ProfileRaw,'XData',[],'YData',[]);
                set(obj.Profile,'XData',[],'YData',[]);
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
            set(obj.ProfileRaw,'Color',obj.RawLineColor,'LineWidth',obj.RawLineWidth);
            set(obj.Profile,'Color',obj.SmoothLineColor,'LineWidth',obj.SmoothLineWidth);

            % annotation lines
            set([obj.PeakVerticalLines,obj.PeakToPeakLines], ...
                "Color",obj.ForegroundColor, ...
                "LineWidth",1, ...
                "Visible",obj.DistanceAnnotations);
            set(obj.PeakWidthLines, ...
                "Color",obj.ForegroundColor, ...
                "LineWidth",1, ...
                "Visible",obj.WidthAnnotations);
            set(obj.PeakBorderLines, ...
                "Color",obj.ForegroundColor, ...
                "LineWidth",1);

            % annotation labels
            set(obj.PeakToPeakLabels, ...
                "Color",obj.ForegroundColor, ...
                "Visible",obj.DistanceAnnotations, ...
                "FontName",obj.FontName, ...
                "FontSize",obj.FontSize);
            set(obj.WidthLabels, ...
                "Color",obj.ForegroundColor, ...
                "Visible",obj.WidthAnnotations, ...
                "FontName",obj.FontName, ...
                "FontSize",obj.FontSize);
        end

        function h = get.Parent(obj)
            h = obj.Parent_;
        end

        function set.Parent(obj,h)
            arguments
                obj (1,1) desmostorm.analysis.PeaksPlot
                h (1,1) matlab.ui.control.UIAxes
            end

            set([...
                obj.ProfileRaw,...
                obj.Profile,...
                obj.PeakVerticalLines,...
                obj.PeakToPeakLines,...
                obj.PeakWidthLines,...
                obj.PeakBorderLines,...
                obj.WidthLabels,...
                obj.PeakToPeakLabels,...
                obj.AxesTitle],...
                'Parent',h);

            obj.Parent_ = h;
        end

        function h = get.Data(obj)
            h = obj.Data_;
        end

        function set.Data(obj,data)
            arguments
                obj (1,1) desmostorm.widgets.PeaksPlot
                data (:,1) desmostorm.analysis.PeaksData
            end
            obj.Data_ = data;
            obj.update();
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

