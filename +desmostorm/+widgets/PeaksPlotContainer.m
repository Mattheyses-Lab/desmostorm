% classdef PeaksPlotContainer < matlab.ui.componentcontainer.ComponentContainer
% 
% 
%     %% data used to build the plot
%     properties(AbortSet = true)
%         % PeaksData object, empty by default
%         Data desmostorm.analysis.PeaksData = desmostorm.analysis.PeaksData.empty()
%     end
% 
%     %% plot appearance properties
%     properties(AbortSet)
%         % title of the chart displayed at the top of the axes
%         Title (1,:) char = 'Untitled'
%         % color of axes and title text
%         FontColor (1,3) double = [0 0 0]
%         % name of the axes font for titles and labels, defaul Arial
%         FontName (1,:) char = 'Arial'
%         % color of axes axis lines
%         ForegroundColor (1,3) double = [0 0 0]
%         % label of the x-axis
%         XLabel (1,:) char = 'X'
%         % label of the y-axis
%         YLabel (1,:) char = 'Y'
%         % size of the various text objects
%         FontSize (1,1) double = 12
%         % width of raw signal line
%         RawLineWidth (1,1) double = 1
%         % color of raw signal line
%         RawLineColor (1,3) double = [0.5 0.5 0.5]
%         % width of smoothed signal line
%         SmoothLineWidth (1,1) double = 1
%         % color of smoothed signal line
%         SmoothLineColor (1,3) double = [0 0 0]
%     end
% 
%     %% graphics components
%     properties(Access = private,Transient,NonCopyable)
%         Grid (1,1) matlab.ui.container.GridLayout
%         MainAxes (1,1) matlab.ui.control.UIAxes
%         ProfileRaw (1,1) matlab.graphics.primitive.Line
%         Profile (1,1) matlab.graphics.primitive.Line
%         PeakVerticalLines (1,1) matlab.graphics.primitive.Line
%         PeakToPeakLines (1,1) matlab.graphics.primitive.Line
%         PeakWidthLines (1,1) matlab.graphics.primitive.Line
%         PeakBorderLines (1,1) matlab.graphics.primitive.Line
%         WidthLabels (:,1) matlab.graphics.primitive.Text
%         PeakToPeakLabels (:,1) matlab.graphics.primitive.Text
%         AxesTitle (1,1) matlab.graphics.primitive.Text
%     end
% 
%     %% protected methods - setup(), update(), etc...
%     methods(Access = protected)
%         function setup(obj)
%             % grid layout manager to hold the components
%             obj.Grid = uigridlayout(obj,...
%                 [1,1],...
%                 "ColumnWidth",{'1x'},...
%                 "RowHeight",{'1x'},...
%                 "BackgroundColor",[1 1 1],...
%                 "Padding",[0 0 0 0]);
%             % uiaxes to hold scatter plots
%             obj.MainAxes = uiaxes(obj.Grid,...
%                 "XLim",[0 1],...
%                 "XLimMode","auto",...
%                 "YLim",[0 1],...
%                 "YLimMode","auto",...
%                 "Clipping","off",...
%                 "OuterPosition",[0 0 1 1],...
%                 "Units","normalized");
%             obj.MainAxes.Layout.Row = 1;
%             obj.MainAxes.Layout.Column = 1;
%             obj.MainAxes.XLabel.String = 'Distance';
%             obj.MainAxes.YLabel.String = 'Intensity';
%             % set up a title for the axes
%             obj.AxesTitle = title(obj.MainAxes,'','BackgroundColor','none');
%             % create empty line/text objects to show signal profile, peak annotations, distance/width values, etc.
%             % the raw input signal (after normalization)
%             obj.ProfileRaw = line(obj.MainAxes,...
%                 NaN,NaN,...
%                 'LineWidth',obj.RawLineWidth,...
%                 'Color',obj.RawLineColor,...
%                 'DisplayName','Raw');
%             % the final signal used for peak detection (after appying optional smoothing)
%             obj.Profile = line(obj.MainAxes,...
%                 NaN,NaN,...
%                 'LineWidth',obj.SmoothLineWidth,...
%                 'Color',obj.SmoothLineColor,...
%                 'DisplayName','Smoothed');
%             % dashed vertical lines showing peak locations, from baseline to maximum value of normalized/smoothed signal
%             obj.PeakVerticalLines = line(obj.MainAxes,...
%                 NaN,NaN,'LineWidth',0.5,'Color',[1 1 1],'LineStyle','--');
%             obj.PeakVerticalLines.Annotation.LegendInformation.IconDisplayStyle = "off";
%             % horizontal lines showing distances between peaks
%             obj.PeakToPeakLines = line(obj.MainAxes,...
%                 NaN,NaN,'LineWidth',0.5,'Color',[1 1 1],'LineStyle','-');
%             obj.PeakToPeakLines.Annotation.LegendInformation.IconDisplayStyle = "off";
%             % horizontal lines showing FWHM
%             obj.PeakWidthLines = line(obj.MainAxes,...
%                 NaN,NaN,'LineWidth',0.5,'Color',[1 1 1],'LineStyle','-');
%             obj.PeakWidthLines.Annotation.LegendInformation.IconDisplayStyle = "off";
%             % vertical lines showing peak borders, from baseline to signal
%             obj.PeakBorderLines = line(obj.MainAxes,...
%                 NaN,NaN,'LineWidth',0.5,'Color',[1 1 1],'LineStyle','-');
%             obj.PeakBorderLines.Annotation.LegendInformation.IconDisplayStyle = "off";
%             % empty label arrays for peak widths and distances
%             obj.WidthLabels = matlab.graphics.primitive.Text.empty();
%             obj.PeakToPeakLabels = matlab.graphics.primitive.Text.empty();
%             % replace default toolbar with an empty one
%             axtoolbar(obj.MainAxes,{});
%             % use normalized units for the component, stretched to fill the container by default
%             obj.Units = 'Normalized';
%             obj.OuterPosition = [0 0 1 1];
%         end
% 
%         function update(obj)
%             % if we have non-empty data -> create/update graphics objects accordingly
%             if ~isempty(obj.Data)
%                 % get the SCALED output data (data multiplied by user-defined scaling-factor)
%                 S = obj.Data.OutputScaled;
%                 % signal profile lines
%                 set(obj.ProfileRaw,'XData',S.X,'YData',S.YNorm);
%                 set(obj.Profile,'XData',S.X,'YData',S.YSmooth);
%                 % annotation lines
%                 set(obj.PeakVerticalLines,'XData',S.VerticalLineXY(1,:),'YData',S.VerticalLineXY(2,:));
%                 set(obj.PeakToPeakLines,'XData',S.PeakToPeakLineXY(1,:),'YData',S.PeakToPeakLineXY(2,:));
%                 set(obj.PeakWidthLines,'XData',S.WidthLineXY(1,:),'YData',S.WidthLineXY(2,:));
%                 set(obj.PeakBorderLines,'XData',S.BorderLineXY(1,:),'YData',S.BorderLineXY(2,:));
%                 % annotation labels
%                 % --- width ---
%                 % only keep existing labels with valid handles
%                 if ~isempty(obj.WidthLabels), obj.WidthLabels = obj.WidthLabels(isvalid(obj.WidthLabels)); end
%                 % determine how many peak width labels we need
%                 nLabels = numel(obj.WidthLabels);
%                 nNeeded = numel(S.PeakWidths);
%                 % delete excess peak width labels as needed
%                 if nLabels > nNeeded
%                     delete(obj.WidthLabels(nNeeded+1:end,1));
%                     obj.WidthLabels = obj.WidthLabels(1:nNeeded,1);
%                 end
%                 % --- peak distance ---
%                 % only keep existing labels with valid handles
%                 if ~isempty(obj.PeakToPeakLabels)
%                     obj.PeakToPeakLabels = obj.PeakToPeakLabels(isvalid(obj.PeakToPeakLabels)); 
%                 end
%                 % determine how many peak distance labels we need
%                 nLabels = numel(obj.PeakToPeakLabels);
%                 if numel(S.PeakLocations) > 0, nNeeded = numel(S.PeakLocations)-1; else, nNeeded = 0; end
%                 % delete excess peak distance labels as needed
%                 if nLabels > nNeeded
%                     delete(obj.PeakToPeakLabels(nNeeded+1:end,1));
%                     obj.PeakToPeakLabels = obj.PeakToPeakLabels(1:nNeeded,1);
%                 end
%                 % hold on so we can plot multiple objects with overwriting
%                 hold(obj.MainAxes,"on");
%                 % for each peak
%                 for i = 1:numel(S.PeakLocations)
%                     % create new peak width labels as needed
%                     if numel(obj.WidthLabels) < i, obj.WidthLabels(i) = text("Parent",obj.MainAxes); end
%                     % update peak width labels
%                     set(obj.WidthLabels(i),...
%                         'Position',S.WidthLabelXY(i,:),...
%                         'Color',obj.ForegroundColor,...
%                         'BackgroundColor',[obj.BackgroundColor],...
%                         'EdgeColor',obj.ForegroundColor,...
%                         'String',sprintf('%.2f %s',S.PeakWidths(i),obj.Data.DistanceUnit),...
%                         'VerticalAlignment','middle',...
%                         'HorizontalAlignment','center',...
%                         'FontSize',obj.FontSize)
%                     % break loop if i == (num peaks - 1)
%                     if i==numel(S.PeakLocations), continue; end
%                     % create new peak distance label if needed
%                     if numel(obj.PeakToPeakLabels) < i, obj.PeakToPeakLabels(i) = text("Parent",obj.MainAxes); end
%                     % update peak distance label properties
%                     set(obj.PeakToPeakLabels(i),...
%                         'Position',S.PeakToPeakLabelXY(i,:),...
%                         'Color',obj.ForegroundColor,...
%                         'BackgroundColor',[obj.BackgroundColor],...
%                         'EdgeColor',obj.ForegroundColor,...
%                         'String',sprintf('%.2f %s',S.PeakDistances(i),obj.Data.DistanceUnit),...
%                         'VerticalAlignment','middle',...
%                         'HorizontalAlignment','center',...
%                         'FontSize',obj.FontSize);
%                 end
%                 % release hold
%                 hold(obj.MainAxes,"off");
%             else % otherwise -> set all coordinate data to empty, delete all labels, replace with empty placeholders
%                 % signal profile lines
%                 set(obj.ProfileRaw,'XData',[],'YData',[]);
%                 set(obj.Profile,'XData',[],'YData',[]);
%                 % annotation lines
%                 set(obj.PeakVerticalLines,'XData',[],'YData',[]);
%                 set(obj.PeakToPeakLines,'XData',[],'YData',[]);
%                 set(obj.PeakWidthLines,'XData',[],'YData',[]);
%                 set(obj.PeakBorderLines,'XData',[],'YData',[]);
%                 % width labels
%                 delete(obj.WidthLabels(:));
%                 obj.WidthLabels = matlab.graphics.primitive.Text.empty();
%                 % peak distance labels
%                 delete(obj.PeakToPeakLabels(:));
%                 obj.PeakToPeakLabels = matlab.graphics.primitive.Text.empty();
%             end
%             % --- update various axes components ---
%             % text displayed in the title
%             obj.AxesTitle.String = obj.Title;
%             % color of the title font
%             obj.AxesTitle.Color = obj.ForegroundColor;
%             % visibility of the title text
%             obj.AxesTitle.Visible = 'on';
%             % title font size
%             obj.AxesTitle.FontSize = obj.FontSize;
%             % axes font name
%             obj.MainAxes.FontName = obj.FontName;  
%             % grid background color
%             obj.Grid.BackgroundColor = obj.BackgroundColor;
%             % axes background color
%             obj.MainAxes.Color = obj.BackgroundColor;
%             % x-axis line color
%             obj.MainAxes.XColor = obj.ForegroundColor;
%             % y-axis line color
%             obj.MainAxes.YColor = obj.ForegroundColor;
%             % x-axis label font color
%             obj.MainAxes.XLabel.Color = obj.ForegroundColor;
%             % y-axis label font color
%             obj.MainAxes.YLabel.Color = obj.ForegroundColor;
%             % x-axis label text
%             obj.MainAxes.XLabel.String = obj.XLabel;
%             % y-axis label text
%             obj.MainAxes.YLabel.String = obj.YLabel;
%             % axes font size
%             obj.MainAxes.FontSize = obj.FontSize;
%             % signal profile lines
%             set(obj.ProfileRaw,'Color',obj.RawLineColor,'LineWidth',obj.RawLineWidth);
%             set(obj.Profile,'Color',obj.SmoothLineColor,'LineWidth',obj.SmoothLineWidth);
%             % annotation lines
%             set([obj.PeakVerticalLines,obj.PeakToPeakLines,obj.PeakWidthLines,obj.PeakBorderLines],...
%                 'Color',obj.ForegroundColor,...
%                 'LineWidth',1);
%             % annotation labels
%             set([obj.WidthLabels; obj.PeakToPeakLabels], ...
%                 'Color',obj.ForegroundColor);
%         end
%     end
% 
%     %% public-facing helpers
%     methods
%         function export(obj,filename,opts)
%             arguments
%                 obj (1,1) desmostorm.widgets.PeaksPlotContainer
%                 filename (1,:) char = 'peaks-plot.pdf'
%                 opts.ContentType = "vector"
%                 opts.Append = false
%                 % BackgroundColor - "current" (default) | "none" | RGB triplet | "r" | "g" | "b" | ...
%                 opts.BackgroundColor = [1 1 1]
%             end
% 
%             exportgraphics(obj.MainAxes,filename,...
%                 "ContentType",opts.ContentType,...
%                 "Append",opts.Append,...
%                 "BackgroundColor",opts.BackgroundColor,...
%                 "Units","inches",...
%                 "Width",6.5,...
%                 "Height",3,...
%                 "PreserveAspectRatio","off")
%         end
%     end
% 
%     %% static helpers
%     methods (Static)
%         function [peaksData,peaksPlot] = demo()
%             % generate some random sample data
%             [X,Y] = desmostorm.analysis.PeaksData.generateRandomGaussPeaks(1001,10,0.2);
%             % create an instance of PeaksData
%             peaksData = desmostorm.analysis.PeaksData(Y,X,...
%                 "MinPeakHeight",0.2,...
%                 "MinPeakDistance",25,...
%                 "PeakSmoothing",15,...
%                 "MinPeakProminence",0.05,...
%                 "PeakSmoothing",15,...
%                 "Normalize",true);
%             % create new figure
%             fig = uifigure("WindowStyle","alwaysontop");
%             % create a PeaksPlotContainer in the figure
%             peaksPlot = desmostorm.widgets.PeaksPlotContainer(fig,'Data',peaksData);
%         end
%     end
% 
% end

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
        % color of axes axis lines
        ForegroundColor (1,3) double = [0 0 0]
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
        % width of smoothed signal line
        SmoothLineWidth (1,1) double = 1
        % color of smoothed signal line
        SmoothLineColor (1,3) double = [0 0 0]
    end


    %% graphics components
    properties(Access = private,Transient,NonCopyable)
        Grid        (1,1) matlab.ui.container.GridLayout
        MainAxes    (1,1) matlab.ui.control.UIAxes
        PeaksPlot   (:,1) desmostorm.widgets.PeaksPlot
        AxesTitle   (1,1) matlab.graphics.primitive.Text
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
            % the dedicated class for our PeaksData plot
            obj.PeaksPlot = desmostorm.widgets.PeaksPlot(obj.MainAxes,desmostorm.analysis.PeaksData.empty());
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
        end
        
        function update(obj)
            % --- PeaksPlot properties ---
            set(obj.PeaksPlot,...
                "FontSize",         obj.FontSize,...
                "RawLineColor",     obj.RawLineColor,...
                "RawLineWidth",     obj.RawLineWidth,...
                "SmoothLineColor",  obj.SmoothLineColor,...
                "SmoothLineWidth",  obj.SmoothLineWidth,...
                "BackgroundColor",  obj.BackgroundColor,...
                "ForegroundColor",  obj.ForegroundColor);
            obj.PeaksPlot.Data = obj.Data;
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
        end
    end

    %% public-facing helpers
    methods
        function export(obj,filename,opts)
            arguments
                obj (1,1) desmostorm.widgets.PeaksPlotContainer
                filename (1,:) char = 'peaks-plot.pdf'
                opts.ContentType = "vector"
                opts.Append = false
                % BackgroundColor - "current" (default) | "none" | RGB triplet | "r" | "g" | "b" | ...
                opts.BackgroundColor = [1 1 1]
            end

            exportgraphics(obj.MainAxes,filename,...
                "ContentType",opts.ContentType,...
                "Append",opts.Append,...
                "BackgroundColor",opts.BackgroundColor,...
                "Units","inches",...
                "Width",6.5,...
                "Height",3,...
                "PreserveAspectRatio","off")
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

            pos = matlabx.ui.calibration.getCenteredFigOuterPosition(750,350);

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



    end

end