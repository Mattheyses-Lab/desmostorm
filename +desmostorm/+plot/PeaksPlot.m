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

classdef PeaksPlot < handle & matlab.mixin.SetGetExactNames

    % Graphics for one trace. The mounted renderer owns data and style policy.
    properties (SetAccess=private)
        Parent matlab.ui.control.UIAxes
        Data desmostorm.analysis.PeaksData = desmostorm.analysis.PeaksData.empty()
    end

    properties (Access=private)
        Style (1,1) desmostorm.plot.PeaksPlotStyle = desmostorm.plot.PeaksPlotStyle()
        ChannelID (1,1) string = ""
        ScaledGeometry struct = struct.empty()
        AnnotationGeometry struct = struct.empty()
        Color (1,3) double = [0 0 0]
        RawColor (1,3) double = [0 0 0]
        SmoothColor (1,3) double = [0 0 0]
        AnnotationsColor (1,3) double = [0 0 0]
        AnnotationsFontName (1,1) string = "Arial"
        DistanceAnnotationY (1,1) double = NaN
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
        function obj = PeaksPlot(ax)
            obj.Parent = ax;
            obj.ProfileRaw = line(ax,NaN,NaN,'DisplayName','Raw');
            obj.Profile = line(ax,NaN,NaN,'DisplayName','Smoothed');
            obj.PeakVerticalLines = line(ax,NaN,NaN,'LineStyle','--');
            obj.PeakToPeakLines = line(ax,NaN,NaN);
            obj.PeakWidthLines = line(ax,NaN,NaN);
            obj.PeakBorderLines = line(ax,NaN,NaN);
            lines = [obj.PeakVerticalLines,obj.PeakToPeakLines,obj.PeakWidthLines,obj.PeakBorderLines];
            for k = 1:numel(lines)
                lines(k).Annotation.LegendInformation.IconDisplayStyle = 'off';
            end
        end

        function render(obj,data,style,index,laneY,channelID,name,fontName)
            if obj.ChannelID ~= channelID || ~isequaln(obj.Data,data)
                obj.ActivePeakIndex_ = NaN;
                obj.LockedPeakIndices_ = [];
            end
            obj.ChannelID = channelID;
            obj.Data = data;
            obj.Style = style;
            obj.DistanceAnnotationY = laneY;
            obj.AnnotationsFontName = fontName;
            obj.Color = [0 0 0];
            if ~isempty(style.Colors)
                obj.Color = style.Colors(min(index,size(style.Colors,1)),:);
            end
            obj.RawColor = obj.Color;
            obj.SmoothColor = obj.Color;
            if ~isempty(style.RawLineColor), obj.RawColor = style.RawLineColor; end
            if ~isempty(style.SmoothLineColor), obj.SmoothColor = style.SmoothLineColor; end
            obj.AnnotationsColor = obj.Color;
            if ~isempty(style.AnnotationColors)
                obj.AnnotationsColor = style.AnnotationColors(min(index,size(style.AnnotationColors,1)),:);
            end
            obj.ProfileRaw.DisplayName = name + " (raw)";
            obj.Profile.DisplayName = name;
            obj.ProfileRaw.Visible = 'on';
            obj.Profile.Visible = 'on';
            obj.PeakBorderLines.Visible = 'on';
            obj.update();
        end

        function attach(obj,ax)
            obj.Parent = ax;
            graphics = obj.primitives();
            for k = 1:numel(graphics)
                if ~isempty(graphics{k}), set(graphics{k},'Parent',ax); end
            end
        end

        function hide(obj)
            obj.ActivePeakIndex_ = NaN;
            graphics = obj.primitives();
            for k = 1:numel(graphics)
                if ~isempty(graphics{k}), set(graphics{k},'Visible','off'); end
            end
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
                obj.ScaledGeometry = S.PeakGeometry;
                obj.AnnotationGeometry = G;
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
                % for each peak
                for i = 1:numel(S.PeakLocations)
                    % create new peak width labels as needed
                    if numel(obj.WidthLabels) < i
                        obj.WidthLabels(i) = text("Parent",ax);
                    end
                    % update peak width labels
                    set(obj.WidthLabels(i),...
                        'Position',G.WidthLabelXY(i,:),...
                        'Color',obj.AnnotationsColor,...
                        'BackgroundColor','none',...
                        'EdgeColor','none',...
                        'String',sprintf('%.2f %s',S.PeakWidths(i),obj.Data.DistanceUnit),...
                        'VerticalAlignment','bottom',...
                        'HorizontalAlignment','center',...
                        'FontUnits','points',...
                        'FontSize',obj.Style.AnnotationsFontSize,...
                        'Margin',obj.Style.AnnotationsMargin);
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
                        'Color',obj.AnnotationsColor,...
                        'BackgroundColor','none',...
                        'EdgeColor','none',...
                        'String',sprintf('%.2f %s',S.PeakDistances(i),obj.Data.DistanceUnit),...
                        'VerticalAlignment','bottom',...
                        'HorizontalAlignment','center',...
                        'FontUnits','points',...
                        'FontSize',obj.Style.AnnotationsFontSize,...
                        'Margin',obj.Style.AnnotationsMargin);
                end
            else
                obj.ScaledGeometry = struct.empty();
                obj.AnnotationGeometry = struct.empty();
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
            set(obj.ProfileRaw,'Color',[obj.RawColor obj.Style.RawLineAlpha], ...
                'LineWidth',obj.Style.RawLineWidth);
            set(obj.Profile,'Color',obj.SmoothColor,'LineWidth',obj.Style.SmoothLineWidth);

            % shaded peak areas
            set(obj.PeakPatches, ...
                "EdgeColor","none");
            obj.updatePeakPatchAppearance();

            % annotation lines
            set([obj.PeakVerticalLines,obj.PeakToPeakLines,obj.PeakWidthLines,obj.PeakBorderLines], ...
                "Color",obj.AnnotationsColor, ...
                "LineWidth",obj.Style.AnnotationLineWidth);

            % annotation labels
            set(obj.PeakToPeakLabels, ...
                "FontName",obj.AnnotationsFontName, ...
                "FontSize",obj.Style.AnnotationsFontSize, ...
                "Margin",obj.Style.AnnotationsMargin);
            obj.updateDistanceAnnotationVisibility();
            set(obj.WidthLabels, ...
                "FontName",obj.AnnotationsFontName, ...
                "FontSize",obj.Style.AnnotationsFontSize, ...
                "Margin",obj.Style.AnnotationsMargin);
            obj.updateWidthAnnotationVisibility();
        end

        function candidates = peakCandidatesAtPoint(obj,xy)
            arguments
                obj (1,1) desmostorm.plot.PeaksPlot
                xy (1,2) double
            end

            candidates = obj.findPeakCandidatesAtPoint(xy);
        end

        function highlightPeak(obj,peakIdx)
            arguments
                obj (1,1) desmostorm.plot.PeaksPlot
                peakIdx (1,1) double
            end

            obj.setActivePeak(peakIdx);
        end

        function clearPeakHighlight(obj)
            obj.setActivePeak(NaN);
        end

        function tf = togglePeakLock(obj,peakIdx)
            arguments
                obj (1,1) desmostorm.plot.PeaksPlot
                peakIdx (1,1) double
            end

            if obj.Style.WidthAnnotations == "off" || isnan(peakIdx)
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

        function graphics = exportGraphics(obj)
            items = obj.primitives();
            graphics = cell(1,0);
            for k = 1:numel(items)
                for j = 1:numel(items{k})
                    graphics{end+1} = items{k}(j); %#ok<AGROW>
                end
            end
        end

        function clearPeakLock(obj)
            obj.LockedPeakIndices_ = [];
            obj.updatePeakPatchAppearance();
            obj.updateWidthAnnotationVisibility();
        end

    end


    methods(Access=private)
        function items = primitives(obj)
            items = {obj.ProfileRaw,obj.Profile,obj.PeakPatches,obj.PeakVerticalLines, ...
                obj.PeakToPeakLines,obj.PeakWidthLines,obj.PeakBorderLines, ...
                obj.WidthLabels,obj.PeakToPeakLabels};
            items = cellfun(@(h) h(isvalid(h)),items,'UniformOutput',false);
        end

        function deleteGraphics(obj)
            items = obj.primitives();
            for k = 1:numel(items)
                if ~isempty(items{k}), delete(items{k}); end
            end
        end

        function candidates = findPeakCandidatesAtPoint(obj,xy)
            candidates = struct( ...
                "PeakIndex",{}, ...
                "PeakLocation",{}, ...
                "DistanceToPeak",{});

            if isempty(obj.PeakPatches) || isempty(obj.ScaledGeometry)
                return
            end

            geom = obj.ScaledGeometry;

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
        end

        function updatePeakPatchAppearance(obj)
            if isempty(obj.PeakPatches)
                return
            end

            for i = 1:numel(obj.PeakPatches)
                alpha = 0;
                if isequal(i,obj.ActivePeakIndex_)
                    alpha = 0.10;
                elseif ismember(i,obj.LockedPeakIndices_)
                    alpha = 0.20;
                end
                set(obj.PeakPatches(i),'FaceColor',obj.Color,'FaceAlpha',alpha,'Visible','on');
            end
        end

        function updateWidthAnnotationVisibility(obj)
            if obj.Style.WidthAnnotations == "off" || isempty(obj.Data)
                set(obj.PeakWidthLines,"Visible","off");
                set(obj.WidthLabels,"Visible","off");
                return
            end

            switch obj.Style.WidthAnnotationsMode
                case 'normal'
                    if ~isempty(obj.Data)
                        G = obj.AnnotationGeometry;
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

                    G = obj.AnnotationGeometry;
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
            if obj.Style.DistanceAnnotations == "off" || isempty(obj.Data)
                set(obj.PeakVerticalLines,"Visible","off");
                set(obj.PeakToPeakLines,"Visible","off");
                set(obj.PeakToPeakLabels,"Visible","off");
                return
            end

            G = obj.AnnotationGeometry;
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
                    "FaceAlpha",0, ...
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
            if strcmp(obj.Style.DistanceAnnotationsMode,'lanes') && isfinite(obj.DistanceAnnotationY)
                distanceAnnotationHeight = obj.DistanceAnnotationY;
            end
            G.WidthLineXY = nan(2,nPeaks*3);
            G.VerticalLineXY = nan(2,nPeaks*3);
            G.WidthLabelXY = nan(nPeaks,2);

            for i = 1:nPeaks
                lineIdx = 3*(i-1)+1;

                G.WidthLineXY(:,lineIdx:lineIdx+2) = [ ...
                    geom(i).LeftWidthLocation, geom(i).RightWidthLocation, NaN; ...
                    geom(i).WidthHeight, geom(i).WidthHeight, NaN];

                if nPeaks > 1 && geom(i).PeakValue < distanceAnnotationHeight
                    G.VerticalLineXY(:,lineIdx:lineIdx+2) = [ ...
                        geom(i).PeakLocation, geom(i).PeakLocation, NaN; ...
                        geom(i).PeakValue, distanceAnnotationHeight, NaN];
                end

                widthCenter = mean([geom(i).LeftWidthLocation,geom(i).RightWidthLocation]);
                G.WidthLabelXY(i,:) = [widthCenter,geom(i).WidthHeight];
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


end
