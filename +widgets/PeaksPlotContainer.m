classdef PeaksPlotContainer < matlab.ui.componentcontainer.ComponentContainer


    %% Plot properties

    % Data
    properties(AbortSet = true)
        % data structure - PeaksData object
        Data model.analysis.PeaksData = model.analysis.PeaksData.empty()
    end

    % Appearance
    properties(AbortSet)
        % title of the chart displayed at the top of the axes
        Title (1,:) char = 'Untitled'
        % color of axes and title text
        FontColor (1,3) double = [1 1 1]
        % name of the axes font for titles and labels, defaul Arial
        FontName (1,:) char = 'Arial'
        % color of axes axis lines
        ForegroundColor (1,3) double = [1 1 1]
        % label of the x-axis
        XLabel (1,:) char = 'X'
        % label of the y-axis
        YLabel (1,:) char = 'Y'
        % size of the various text objects
        FontSize (1,1) double = 12

        RawLineWidth (1,1) double = 1
        RawLineColor (1,3) double = [1 0 0]
        SmoothLineWidth (1,1) double = 1
        SmoothLineColor (1,3) double = [0 0 1]
    end

    %% graphics components the PeaksPlotContainer is built from
        
    properties(Access = private,Transient,NonCopyable)
        Grid (1,1) matlab.ui.container.GridLayout
        MainAxes (1,1) matlab.ui.control.UIAxes
        ProfileRaw (1,1) matlab.graphics.primitive.Line
        Profile (1,1) matlab.graphics.primitive.Line
        PeakVerticalLines (1,1) matlab.graphics.primitive.Line
        PeakToPeakLines (1,1) matlab.graphics.primitive.Line
        PeakWidthLines (1,1) matlab.graphics.primitive.Line
        PeakBorderLines (1,1) matlab.graphics.primitive.Line

        WidthLabels (:,1) matlab.graphics.primitive.Text
        PeakToPeakLabels (:,1) matlab.graphics.primitive.Text

        AxesTitle (1,1) matlab.graphics.primitive.Text
    end

    %% protected methods - setup(), update(), etc...
    
    methods(Access = protected)

        function setup(obj)
            % grid layout manager to hold the components
            obj.Grid = uigridlayout(obj,...
                [1,1],...
                "ColumnWidth",{'1x'},...
                "RowHeight",{'1x'},...
                "BackgroundColor",[1 1 1],...
                "Padding",[0 0 0 0]);
            % uiaxes to hold scatter plots
            obj.MainAxes = uiaxes(obj.Grid,...
                "XLim",[0 1],...
                "XLimMode","auto",...
                "YLim",[0 1],...
                "YLimMode","auto",...
                "Clipping","off",...
                "OuterPosition",[0 0 1 1],...
                "Units","normalized");
            obj.MainAxes.Layout.Row = 1;
            obj.MainAxes.Layout.Column = 1;
            obj.MainAxes.XLabel.String = 'Distance';
            obj.MainAxes.YLabel.String = 'Intensity';

            % set up a title for the axes
            obj.AxesTitle = title(obj.MainAxes,'Untitled');

            % Create empty line plots to show the linescan data
            obj.ProfileRaw = line(obj.MainAxes,...
                NaN,NaN,...
                'LineWidth',obj.RawLineWidth,...
                'Color',obj.RawLineColor,...
                'DisplayName','Raw');
            obj.Profile = line(obj.MainAxes,...
                NaN,NaN,...
                'LineWidth',obj.SmoothLineWidth,...
                'Color',obj.SmoothLineColor,...
                'DisplayName','Smoothed');

            obj.PeakVerticalLines = line(obj.MainAxes,...
                NaN,NaN,'LineWidth',0.5,'Color',[1 1 1],'LineStyle','--');
            obj.PeakVerticalLines.Annotation.LegendInformation.IconDisplayStyle = "off";

            obj.PeakToPeakLines = line(obj.MainAxes,...
                NaN,NaN,'LineWidth',0.5,'Color',[1 1 1],'LineStyle','-');
            obj.PeakToPeakLines.Annotation.LegendInformation.IconDisplayStyle = "off";

            obj.PeakWidthLines = line(obj.MainAxes,...
                NaN,NaN,'LineWidth',0.5,'Color',[1 1 1],'LineStyle','-');
            obj.PeakWidthLines.Annotation.LegendInformation.IconDisplayStyle = "off";

            obj.PeakBorderLines = line(obj.MainAxes,...
                NaN,NaN,'LineWidth',0.5,'Color',[1 1 1],'LineStyle','-');
            obj.PeakBorderLines.Annotation.LegendInformation.IconDisplayStyle = "off";


            obj.WidthLabels = matlab.graphics.primitive.Text.empty();
            obj.PeakToPeakLabels = matlab.graphics.primitive.Text.empty();


            % replace default toolbar with an empty one
            axtoolbar(obj.MainAxes,{});

            % use normalized units for the component, stretched to fill the container by default
            obj.Units = 'Normalized';
            obj.OuterPosition = [0 0 1 1];
        end
        
        function update(obj)
            

            %% update plot objects

            if ~isempty(obj.Data)

                S = obj.Data.OutputScaled;

                % signal profile lines
                set(obj.ProfileRaw,'XData',S.X,'YData',S.YNorm);
                set(obj.Profile,'XData',S.X,'YData',S.YSmooth);

                % annotation lines
                set(obj.PeakVerticalLines,'XData',S.VerticalLineXY(1,:),'YData',S.VerticalLineXY(2,:));
                set(obj.PeakToPeakLines,'XData',S.PeakToPeakLineXY(1,:),'YData',S.PeakToPeakLineXY(2,:));
                set(obj.PeakWidthLines,'XData',S.WidthLineXY(1,:),'YData',S.WidthLineXY(2,:));
                set(obj.PeakBorderLines,'XData',S.BorderLineXY(1,:),'YData',S.BorderLineXY(2,:));

                % annotation labels

                % --- width ---
                if ~isempty(obj.WidthLabels)
                    obj.WidthLabels = obj.WidthLabels(isvalid(obj.WidthLabels));
                end

                nLabels = numel(obj.WidthLabels);
                nNeeded = numel(S.PeakWidths);

                if nLabels > nNeeded
                    delete(obj.WidthLabels(nNeeded+1:end,1));
                    obj.WidthLabels = obj.WidthLabels(1:nNeeded,1);
                end

                % --- peak distance ---
                if ~isempty(obj.PeakToPeakLabels)
                    obj.PeakToPeakLabels = obj.PeakToPeakLabels(isvalid(obj.PeakToPeakLabels));
                end

                nLabels = numel(obj.PeakToPeakLabels);
                if numel(S.PeakLocations) > 0
                    nNeeded = numel(S.PeakLocations)-1;
                else
                    nNeeded = 0;
                end

                if nLabels > nNeeded
                    delete(obj.PeakToPeakLabels(nNeeded+1:end,1));
                    obj.PeakToPeakLabels = obj.PeakToPeakLabels(1:nNeeded,1);
                end


                hold(obj.MainAxes,"on");

                

                for i = 1:numel(S.PeakLocations)

                    if numel(obj.WidthLabels) < i
                        obj.WidthLabels(i) = text("Parent",obj.MainAxes);
                    end

                    set(obj.WidthLabels(i),...
                        'Position',S.WidthLabelXY(i,:),...
                        'Color',obj.ForegroundColor,...
                        'BackgroundColor',[obj.BackgroundColor],...
                        'EdgeColor',obj.ForegroundColor,...
                        'String',sprintf('%.2f %s',S.PeakWidths(i),obj.Data.DistanceUnit),...
                        'VerticalAlignment','middle',...
                        'HorizontalAlignment','center')

                    if i==numel(S.PeakLocations)
                        continue
                    end

                    if numel(obj.PeakToPeakLabels) < i
                        obj.PeakToPeakLabels(i) = text("Parent",obj.MainAxes);
                    end

                    set(obj.PeakToPeakLabels(i),...
                        'Position',S.PeakToPeakLabelXY(i,:),...
                        'Color',obj.ForegroundColor,...
                        'BackgroundColor',[obj.BackgroundColor],...
                        'EdgeColor',obj.ForegroundColor,...
                        'String',sprintf('%.2f %s',S.PeakDistances(i),obj.Data.DistanceUnit),...
                        'VerticalAlignment','middle',...
                        'HorizontalAlignment','center');

                end

                hold(obj.MainAxes,"off");

            else

                % signal profile lines
                set(obj.ProfileRaw,'XData',[],'YData',[]);
                set(obj.Profile,'XData',[],'YData',[]);

                % annotation lines
                set(obj.PeakVerticalLines,'XData',[],'YData',[]);
                set(obj.PeakToPeakLines,'XData',[],'YData',[]);
                set(obj.PeakWidthLines,'XData',[],'YData',[]);
                set(obj.PeakBorderLines,'XData',[],'YData',[]);

                delete(obj.WidthLabels(:));
                obj.WidthLabels = matlab.graphics.primitive.Text.empty();

                delete(obj.PeakToPeakLabels(:));
                obj.PeakToPeakLabels = matlab.graphics.primitive.Text.empty();

            end


            %% update various axes components

            % text displayed in the title
            obj.AxesTitle.String = obj.Title;
            % color of the title font
            obj.AxesTitle.Color = obj.ForegroundColor;
            % background color of the title font
            obj.AxesTitle.BackgroundColor = obj.BackgroundColor;
            % visibility of the title text
            obj.AxesTitle.Visible = 'on';
            % title font size
            obj.AxesTitle.FontSize = obj.FontSize;



            % axes font name
            obj.MainAxes.FontName = obj.FontName;  
            % grid background color
            obj.Grid.BackgroundColor = obj.BackgroundColor;
            % axes background color
            obj.MainAxes.Color = obj.BackgroundColor;
            % x-axis line color
            obj.MainAxes.XColor = obj.ForegroundColor;
            % y-axis line color
            obj.MainAxes.YColor = obj.ForegroundColor;
            % x-axis label font color
            obj.MainAxes.XLabel.Color = obj.ForegroundColor;
            % y-axis label font color
            obj.MainAxes.YLabel.Color = obj.ForegroundColor;
            % x-axis label text
            obj.MainAxes.XLabel.String = obj.XLabel;
            % y-axis label text
            obj.MainAxes.YLabel.String = obj.YLabel;
            % axes font size
            obj.MainAxes.FontSize = obj.FontSize;


            % signal profile lines
            set(obj.ProfileRaw,'Color',obj.RawLineColor,'LineWidth',obj.RawLineWidth);
            set(obj.Profile,'Color',obj.SmoothLineColor,'LineWidth',obj.SmoothLineWidth);

            % annotation lines
            set([obj.PeakVerticalLines,obj.PeakToPeakLines,obj.PeakWidthLines,obj.PeakBorderLines],...
                'Color',obj.ForegroundColor,...
                'LineWidth',1);

            % annotation labels
            set([obj.WidthLabels; obj.PeakToPeakLabels], ...
                'Color',obj.ForegroundColor);


        end

    end


    %% public-facing methods
    methods

        function export(obj,filename,opts)
                arguments
                    obj (1,1) widgets.PeaksPlotContainer
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


        function g = getGrid(obj)

            g = obj.MainAxes;

        end


    end


    methods (Static)

        function [peaksData,peaksPlot] = demo()

            x = linspace(0,1,1000);

            Pos = [1 2 3 5 7 8]/10;
            Hgt = [4 4 2 2 2 3];
            Wdt = [3 8 4 3 4 6]/100;

            Gauss = zeros(6,1000);

            for n = 1:length(Pos)
                Gauss(n,:) =  Hgt(n)*exp(-((x - Pos(n))/Wdt(n)).^2);
            end

            PeakSig = sum(Gauss);

            peaksData = model.analysis.PeaksData(PeakSig,x);

            fig = uifigure("WindowStyle","alwaysontop");

            peaksPlot = widgets.PeaksPlotContainer(fig,'Data',peaksData,...
                'Title','Title goes here');

        end






    end







end