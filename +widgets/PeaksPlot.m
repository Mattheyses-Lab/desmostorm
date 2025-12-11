classdef PeaksPlot < handle

    % Appearance
    properties(AbortSet)
        % title of the chart displayed at the top of the axes
        Title (1,:) char = 'Untitled'
        % color of axes and title text
        FontColor (1,3) double = [1 1 1]
        % name of the axes font for titles and labels, defaul Arial
        FontName (1,:) char = 'Arial'
        % color of axes plotting area
        BackgroundColor (1,3) double = [0 0 0]
        % color of axes axis lines
        ForegroundColor (1,3) double = [1 1 1]
        % label of the x-axis
        XLabel (1,:) char = 'X'
        % label of the y-axis
        YLabel (1,:) char = 'Y'
        % size of the various text objects
        FontSize (1,1) double = 12
        % width of raw signal line
        RawLineWidth (1,1) double = 1
        % color of raw signal line
        RawLineColor (1,3) double = [1 0 0]
        % width of smoothed signal line
        SmoothLineWidth (1,1) double = 1
        % color of smoothed signal line
        SmoothLineColor (1,3) double = [0 0 1]
    end

    %% public properties with private backing
    properties(Dependent)
        Parent (1,1) matlab.ui.control.UIAxes
        Data model.analysis.PeaksData
    end

    properties(Access=private)
        Parent_ (1,1) matlab.ui.control.UIAxes
        Data_ model.analysis.PeaksData
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
        AxesTitle (1,1) matlab.graphics.primitive.Text
    end


    methods
        function obj = PeaksPlot(ax,data) % constructor
            arguments
                ax (1,1) matlab.ui.control.UIAxes
                data (1,1) model.analysis.PeaksData
            end

            % set up a title for the axes
            obj.AxesTitle = title(ax,'','BackgroundColor','none');

            % Create empty line plots to show the linescan data
            obj.ProfileRaw = line(ax,...
                NaN,NaN,...
                'LineWidth',obj.RawLineWidth,...
                'Color',obj.RawLineColor,...
                'DisplayName','Raw');
            obj.Profile = line(ax,...
                NaN,NaN,...
                'LineWidth',obj.SmoothLineWidth,...
                'Color',obj.SmoothLineColor,...
                'DisplayName','Smoothed');

            obj.PeakVerticalLines = line(ax,...
                NaN,NaN,'LineWidth',0.5,'Color',[1 1 1],'LineStyle','--');
            obj.PeakVerticalLines.Annotation.LegendInformation.IconDisplayStyle = "off";

            obj.PeakToPeakLines = line(ax,...
                NaN,NaN,'LineWidth',0.5,'Color',[1 1 1],'LineStyle','-');
            obj.PeakToPeakLines.Annotation.LegendInformation.IconDisplayStyle = "off";

            obj.PeakWidthLines = line(ax,...
                NaN,NaN,'LineWidth',0.5,'Color',[1 1 1],'LineStyle','-');
            obj.PeakWidthLines.Annotation.LegendInformation.IconDisplayStyle = "off";

            obj.PeakBorderLines = line(ax,...
                NaN,NaN,'LineWidth',0.5,'Color',[1 1 1],'LineStyle','-');
            obj.PeakBorderLines.Annotation.LegendInformation.IconDisplayStyle = "off";

            obj.WidthLabels = matlab.graphics.primitive.Text.empty();
            obj.PeakToPeakLabels = matlab.graphics.primitive.Text.empty();

            % replace default toolbar with an empty one
            axtoolbar(ax,{});

            % Initialize the axes and update the plot with the provided data
            obj.Parent_ = ax;
            obj.Data_ = data;
            obj.update();
        end

        function update(obj) % update helper
            %% update plot objects

            ax = obj.Parent;

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


                hold(ax,"on");

                for i = 1:numel(S.PeakLocations)

                    if numel(obj.WidthLabels) < i
                        obj.WidthLabels(i) = text("Parent",ax);
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
                        obj.PeakToPeakLabels(i) = text("Parent",ax);
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

                delete(obj.WidthLabels(:));
                obj.WidthLabels = matlab.graphics.primitive.Text.empty();

                delete(obj.PeakToPeakLabels(:));
                obj.PeakToPeakLabels = matlab.graphics.primitive.Text.empty();

            end


            % --- update various axes components ---

            % text displayed in the title
            obj.AxesTitle.String = obj.Title;
            % color of the title font
            obj.AxesTitle.Color = obj.ForegroundColor;
            % % background color of the title font
            % obj.AxesTitle.BackgroundColor = 'none';
            % visibility of the title text
            obj.AxesTitle.Visible = 'on';
            % title font size
            obj.AxesTitle.FontSize = obj.FontSize;
            % axes font name
            ax.FontName = obj.FontName;  
            % axes background color
            ax.Color = obj.BackgroundColor;
            % x-axis line color
            ax.XColor = obj.ForegroundColor;
            % y-axis line color
            ax.YColor = obj.ForegroundColor;
            % x-axis label font color
            ax.XLabel.Color = obj.ForegroundColor;
            % y-axis label font color
            ax.YLabel.Color = obj.ForegroundColor;
            % x-axis label text
            ax.XLabel.String = obj.XLabel;
            % y-axis label text
            ax.YLabel.String = obj.YLabel;
            % axes font size
            ax.FontSize = obj.FontSize;

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

        function h = get.Parent(obj)
            h = obj.Parent_;
        end

        function set.Parent(obj,h)
            arguments
                obj (1,1) model.analysis.PeaksPlot
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
                obj (1,1) model.analysis.PeaksPlot
                data (1,1) model.analysis.PeaksData
            end
            obj.Data_ = data;
            obj.update();
        end

    end


    %% static helpers
    methods(Static)
        function [peaksData,peaksPlot] = demo()
            % generate some random sample data
            [X,Y] = model.analysis.PeaksData.generateRandomGaussPeaks(1001,6,0.2);
            % create an instance of PeaksData
            peaksData = model.analysis.PeaksData(Y,X,...
                "MinPeakHeight",0.2,...
                "MinPeakDistance",25,...
                "MinPeakProminence",0.05,...
                "PeakSmoothing",15,...
                "Normalize",true);
            % create new figure
            fig = uifigure("WindowStyle","alwaysontop","Position",[0 0 750 500]);
            % move to center
            movegui(fig,"center");
            % add an axes
            ax = uiaxes(fig,"Units","normalized","Position",[0 0 1 1]);
            % create a PeaksPlot in the axes using the peaksData from above
            peaksPlot = widgets.PeaksPlot(ax,peaksData);
        end
    end

end