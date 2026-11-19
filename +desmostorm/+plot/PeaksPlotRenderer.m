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
        Data (1,1) desmostorm.plot.PeaksPlotData = desmostorm.plot.PeaksPlotData()
        Style (1,1) desmostorm.plot.PeaksPlotStyle = desmostorm.plot.PeaksPlotStyle()
    end

    properties (Access=private)
        PeaksPlot (:,1) desmostorm.plot.PeaksPlot = desmostorm.plot.PeaksPlot.empty(0,1)
        UpdateLimits (1,1) logical = true
    end

    methods
        function update(obj,data,style)
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

        function refresh(obj)
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
            for k = numel(obj.PeaksPlot)+1:count
                obj.PeaksPlot(k,1) = desmostorm.plot.PeaksPlot(axes);
            end

            limits = obj.getDistanceAnnotationAxisLimits();
            laneY = obj.getDistanceAnnotationLanes(limits);
            for k = 1:count
                obj.PeaksPlot(k).render(obj.Data.Traces(k),obj.Style,k,laneY(k), ...
                    obj.Data.ChannelIDs(k),obj.Data.Names(k),obj.Host.FontName);
            end

            if obj.UpdateLimits
                if isempty(obj.Style.XLim)
                    axes.XLimMode = 'auto';
                else
                    axes.XLim = obj.Style.XLim;
                end
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

        function handleEvent(obj,kind,event)
            switch kind
                case "Move"
                    [trace,peak] = obj.pickPeak();
                    for k = 1:numel(obj.PeaksPlot)
                        if k == trace
                            obj.PeaksPlot(k).highlightPeak(peak);
                        else
                            obj.PeaksPlot(k).clearPeakHighlight();
                        end
                    end
                case "Leave"
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
                        for k = 1:numel(obj.PeaksPlot)
                            obj.PeaksPlot(k).clearPeakLock();
                        end
                    end
            end
        end

        function delete(obj)
            obj.detach();
            delete(obj.PeaksPlot);
        end
    end

    methods (Access=protected)
        function attachGraphics(obj,axes)
            for k = 1:numel(obj.PeaksPlot)
                obj.PeaksPlot(k).attach(axes);
            end
            obj.UpdateLimits = true;
        end

        function hideGraphics(obj)
            for k = 1:numel(obj.PeaksPlot)
                obj.PeaksPlot(k).hide();
            end
        end
    end

    methods (Access=private)
        function [trace,peak] = pickPeak(obj)
            trace = 0;
            peak = NaN;
            distance = Inf;
            point = obj.Host.Axes.CurrentPoint;
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
            nPlots = numel(obj.PeaksPlot);
            laneY = nan(nPlots,1);

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

        function lims = getDistanceAnnotationAxisLimits(obj)
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
            nLanes = max(numel(obj.PeaksPlot),1);
            bandFraction = 0.10 + 0.075*(nLanes - 1);
            bandFraction = min(bandFraction,0.50);
        end

        function dataLim = getDataYLim(obj)
            yMin = Inf;
            yMax = -Inf;

            for i = 1:numel(obj.Data.Traces)
                if isempty(obj.Data.Traces(i))
                    continue
                end

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
