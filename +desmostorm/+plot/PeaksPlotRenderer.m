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

classdef PeaksPlotRenderer < matlabx.ui.axes.PlotContent
%PEAKSPLOTRENDERER Mountable multi-channel linescan content.

    properties (SetAccess=private)
        % Data.
        Data (1,1) desmostorm.plot.PeaksPlotData = desmostorm.plot.PeaksPlotData()
        % Style.
        Style (1,1) desmostorm.plot.PeaksPlotStyle = desmostorm.plot.PeaksPlotStyle()
    end

    properties (Access=private)
        % Peaks plot.
        PeaksPlot (:,1) desmostorm.plot.PeaksPlot = desmostorm.plot.PeaksPlot.empty(0,1)
        % Whether the next render must recompute axes framing.
        UpdateLimits (1,1) logical = true
    end

    methods
        function update(obj,data,style)
        %UPDATE Refresh the graphics using the current data and appearance.
            arguments
                obj
                data (1,1) desmostorm.plot.PeaksPlotData
                style (1,1) desmostorm.plot.PeaksPlotStyle = obj.Style
            end
            obj.UpdateLimits = obj.UpdateLimits || ~isequaln(obj.Data.Traces,data.Traces) || ...
                ~isequal(obj.Data.ChannelIDs,data.ChannelIDs) || ...
                ~isequaln(obj.Style.XLim,style.XLim) || ...
                obj.Style.DistanceAnnotations ~= style.DistanceAnnotations || ...
                obj.Style.DistanceAnnotationsMode ~= style.DistanceAnnotationsMode;
            obj.Data = data;
            obj.Style = style;
            obj.refresh();
        end

        function capabilities = axesCapabilities(obj)
        %AXESCAPABILITIES Expose the host controls compatible with linescan annotation lanes.
            capabilities = axesCapabilities@matlabx.ui.axes.PlotContent(obj);
            capabilities = capabilities(~ismember(capabilities,["YLim","YTickInterval"]));
        end

        function defaults = axesViewDefaults(obj)
        %AXESVIEWDEFAULTS Declare the renderer’s X range and tick defaults for PlotAxes.
            % Struct for defaults.
            defaults = struct("XLim","auto","XTickInterval","auto");
            if ~isempty(obj.Style.XLim)
                defaults.XLim = obj.Style.XLim;
            end
        end

        function handleEvent(obj,kind,event)
        %HANDLEEVENT Route pointer events to peak hover and selection behavior.
            switch kind
                case "Move"
                    [trace,peak] = obj.pickPeak();
                    % Visit each entry in peaks plot.
                    for k = 1:numel(obj.PeaksPlot)
                        if k == trace
                            obj.PeaksPlot(k).highlightPeak(peak);
                        else
                            obj.PeaksPlot(k).clearPeakHighlight();
                        end
                    end
                case "Leave"
                    % Visit each entry in peaks plot.
                    for k = 1:numel(obj.PeaksPlot)
                        obj.PeaksPlot(k).clearPeakHighlight();
                    end
                case "Down"
                    if event.MouseChord ~= "click" || ~obj.Style.WidthAnnotations, return, end
                    [trace,peak] = obj.pickPeak();
                    if trace > 0
                        obj.PeaksPlot(trace).togglePeakLock(peak);
                        event.stop();
                    else
                        % Visit each entry in peaks plot.
                        for k = 1:numel(obj.PeaksPlot)
                            obj.PeaksPlot(k).clearPeakLock();
                        end
                    end
            end
        end

        function cleanup = beginExportStyleScale(obj,scale)
        %BEGINEXPORTSTYLESCALE Temporarily scale the renderer’s graphic styles for export.
            graphics = cell(1,0);
            % Process peaks plot in order.
            for k = 1:numel(obj.PeaksPlot)
                graphics = [graphics,obj.PeaksPlot(k).exportGraphics()]; %#ok<AGROW>
            end
            cleanup = matlabx.ui.axes.internal.scaleExportGraphics(graphics,scale);
        end

        function delete(obj)
        %DELETE Release resources owned by this object.
            obj.detach();
            delete(obj.PeaksPlot);
        end
    end

    methods (Access=protected)
        function refreshGraphics(obj)
        %REFRESHGRAPHICS Render the stored traces and apply chart-defined framing.
            if isempty(obj.Host) || ~isvalid(obj.Host), return, end
            axes = obj.Host.Axes;
            obj.Host.BackgroundColor = obj.Style.BackgroundColor;
            obj.Host.Color = obj.Style.BackgroundColor;
            obj.Host.ForegroundColor = obj.Style.ForegroundColor;
            axes.Clipping = 'off';
            axes.TitleHorizontalAlignment = 'left';

            count = numel(obj.Data.Traces);
            excess = obj.PeaksPlot(count+1:end);
            delete(excess);
            obj.PeaksPlot = obj.PeaksPlot(1:min(count,numel(obj.PeaksPlot)));
            % Process peaks plot in order.
            for k = numel(obj.PeaksPlot)+1:count
                obj.PeaksPlot(k,1) = desmostorm.plot.PeaksPlot(axes);
            end

            limits = obj.getDistanceAnnotationAxisLimits();
            % Vertical position of each distance annotation lane.
            laneY = obj.getDistanceAnnotationLanes(limits);
            for k = 1:count
                obj.PeaksPlot(k).render(obj.Data.Traces(k),obj.Style,k,laneY(k), ...
                    obj.Data.ChannelIDs(k),obj.Data.Names(k),obj.Host.FontName);
            end

            % Clearing a host override returns XLimMode to auto before refresh.
            if obj.UpdateLimits || (isempty(obj.Host.AxesView.XLim) && ...
                    ~isempty(obj.Style.XLim) && axes.XLimMode == "auto")
                if isempty(obj.Style.XLim)
                    axes.XLimMode = 'auto';
                else
                    axes.XLim = obj.Style.XLim;
                end
            end
            if obj.UpdateLimits
                if isempty(limits)
                    axes.YLimMode = 'auto';
                    axes.YTickMode = 'auto';
                else
                    axes.YLim = limits.DisplayLim;
                    axes.YTick = limits.Ticks;
                end
                obj.UpdateLimits = false;
            end
        end

        function attachGraphics(obj,axes)
        %ATTACHGRAPHICS Attach graphics.
            % Visit each entry in peaks plot.
            for k = 1:numel(obj.PeaksPlot)
                obj.PeaksPlot(k).attach(axes);
            end
            obj.UpdateLimits = true;
        end

        function hideGraphics(obj)
        %HIDEGRAPHICS Hide graphics.
            % Visit each entry in peaks plot.
            for k = 1:numel(obj.PeaksPlot)
                obj.PeaksPlot(k).hide();
            end
        end
    end

    methods (Access=private)
        function [trace,peak] = pickPeak(obj)
        %PICKPEAK Pick peak.
            trace = 0;
            peak = NaN;
            distance = Inf;
            point = obj.Host.Axes.CurrentPoint;
            % Process peaks plot in order.
            for k = 1:numel(obj.PeaksPlot)
                candidates = obj.PeaksPlot(k).peakCandidatesAtPoint(point(1,1:2));
                if isempty(candidates), continue, end
                [candidateDistance,index] = min([candidates.DistanceToPeak]);
                if candidateDistance < distance
                    distance = candidateDistance;
                    trace = k;
                    peak = candidates(index).PeakIndex;
                end
            end
        end

        function laneY = getDistanceAnnotationLanes(obj,lims)
        %GETDISTANCEANNOTATIONLANES Return distance annotation lanes.
            % Number of plots.
            nPlots = numel(obj.PeaksPlot);
            % Vertical position of each distance annotation lane.
            laneY = nan(nPlots,1);

            if isempty(lims)
                return
            end

            bandMin = lims.TickLim(2);
            bandMax = lims.DisplayLim(2);
            if bandMax <= bandMin
                return
            end

            % Band height.
            bandHeight = bandMax - bandMin;
            lanePad = 0.18*bandHeight;
            laneStep = 0;
            if nPlots > 1
                laneStep = (bandHeight - 2*lanePad)/(nPlots - 1);
            end

            laneY(:) = bandMax - lanePad - laneStep*(0:nPlots-1);
        end

        function lims = getDistanceAnnotationAxisLimits(obj)
        %GETDISTANCEANNOTATIONAXISLIMITS Return distance annotation axis limits.
            lims = [];
            if ~obj.Style.DistanceAnnotations || obj.Style.DistanceAnnotationsMode ~= "lanes", return, end
            dataLim = obj.getDataYLim();
            if isempty(dataLim)
                return
            end

            bandFraction = obj.getDistanceAnnotationBandFraction();

            lims = matlabx.ui.axes.niceLimitsAndTicks(dataLim, ...
                IncludeZero=true, ...
                TargetTicks=5, ...
                ExtendTopFraction=bandFraction);
        end

        function bandFraction = getDistanceAnnotationBandFraction(obj)
        %GETDISTANCEANNOTATIONBANDFRACTION Return distance annotation band fraction.
            nLanes = max(numel(obj.PeaksPlot),1);
            bandFraction = 0.10 + 0.075*(nLanes - 1);
            bandFraction = min(bandFraction,0.50);
        end

        function dataLim = getDataYLim(obj)
        %GETDATAYLIM Return data y lim.
            yMin = Inf;
            yMax = -Inf;

            % Visit each entry in traces.
            for i = 1:numel(obj.Data.Traces)
                if isempty(obj.Data.Traces(i))
                    continue
                end

                % Raw and smoothed samples used to bound the current trace.
                y = [obj.Data.Traces(i).SignalNorm; obj.Data.Traces(i).SignalSmooth];
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

    end
end
