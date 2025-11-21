classdef uirangeslidereditfield < matlab.ui.componentcontainer.ComponentContainer

    %% Public API

    properties

        % flag to determine whether fractional values are rounded
        RoundFractionalValues (1,1) matlab.lang.OnOffSwitchState = 'off'

    end

    % properties we want property-based, minimal updates for
    properties(SetObservable, AbortSet)
        % min and max of the slider track
        Limits double = [0,1]

        % color of the thumb faces
        ThumbFaceColor (1,3) double {mustBeInRange(ThumbFaceColor,0,1)} = [1 1 1]
        % color of the thumb edges
        ThumbEdgeColor (1,3) double {mustBeInRange(ThumbEdgeColor,0,1)} = [0 0 0]

        % track colormap (spans the range between low and high thumbs)
        Colormap (256,3) double = gray

        % height of the track
        TrackHeight (1,1) double = 4
        % height of the range
        RangeHeight (1,1) double = 7
        % overall height of the slider component (excluding labels)
        Height (1,1) double = 25

        % text displayed above the slider
        Title (1,:) char = "Untitled slider"
        % size of the font
        FontSize (1,1) double = 12
        % color of the font
        FontColor (1,3) double = [0 0 0]

    end

    properties(SetAccess=private)
        % true if the slider is currently moving
        isSliding (1,1) logical = false
        % index of the active thumb (1 or 2, NaN if none)
        activeThumbIdx (1,1) double = NaN
        % index of thumb currently hovered (1 or 2, NaN if none)
        hoverThumbIdx double = NaN

        % flag to help coalesce updates
        pendingUpdate (1,1) logical = false
    end

    properties(SetObservable=true,Dependent=true)
        Value (1,2) double = [0,1]
    end

    properties(Access=private,Dependent=true)
        % ancestor figure of the component
        parentFig
    end

    %% UI / graphics handles

    properties(Access = private,Transient,NonCopyable)
        % outermost grid for the entire component
        containerGrid (1,1) matlab.ui.container.GridLayout

        % uilabel for the Title
        titleLabel (1,1) matlab.ui.control.Label
        % uilabel for the minimum value editfield
        minLabel (1,1) matlab.ui.control.Label
        % uilabel for the maximum value editfield
        maxLabel (1,1) matlab.ui.control.Label

        % axes to hold slider thumbs and patches
        sliderThumbAxes (1,1) matlab.ui.control.UIAxes
        % patch object for slider track
        trackPatch (1,1) matlab.graphics.primitive.Patch
        % patch object for slider range
        rangePatch (1,1) matlab.graphics.primitive.Patch
        % the slider thumbs (lower=1, upper=2)
        sliderThumb (:,1) widgets.sliderthumb
        % editfields for text control of slider values [low high]
        sliderValueEditField (:,1) matlab.ui.control.NumericEditField

        % PostSet listener for the slider value
        sliderValueListener (1,1)

        % listeners for property-based updates (ThumbFaceColor, etc.)
        L event.listener = event.listener.empty
    end

    %% Hub registration

    properties(Access=private)
        Hub app.FigureEventHub
        RouterId double = NaN
    end

    %% Events

    events (HasCallbackProperty, NotifyAccess = protected)
        ValueChanged % ValueChangedFcn callback property will be generated
    end

    %% ComponentContainer lifecycle

    methods(Access=protected)

        function setup(obj)

            obj.Units    = "normalized";
            obj.Position = [0 0 1 1];

            % grid layout manager to enclose all the components
            obj.containerGrid = uigridlayout(obj,...
                [1,3],...
                "ColumnWidth",{'1x',50,50},...
                "RowHeight",{'fit',obj.TrackHeight},...
                "BackgroundColor",[0 0 0],...
                "Padding",[5 5 5 5],...
                "Scrollable","on",...
                "RowSpacing",0);

            % uilabel to display the title text
            obj.titleLabel = uilabel(obj.containerGrid,...
                "Text",obj.Title,...
                "FontColor",obj.FontColor,...
                "FontSize",obj.FontSize);
            obj.titleLabel.Layout.Row    = 1;
            obj.titleLabel.Layout.Column = 1;

            % uilabel for the minimum value editfield
            obj.minLabel = uilabel(obj.containerGrid,...
                "Text","Min",...
                "FontColor",obj.FontColor,...
                "FontSize",obj.FontSize);
            obj.minLabel.Layout.Row    = 1;
            obj.minLabel.Layout.Column = 2;

            % uilabel for the maximum value editfield
            obj.maxLabel = uilabel(obj.containerGrid,...
                "Text","Max",...
                "FontColor",obj.FontColor,...
                "FontSize",obj.FontSize);
            obj.maxLabel.Layout.Row    = 1;
            obj.maxLabel.Layout.Column = 3;

            % axes to hold the slider thumbs and patches
            obj.sliderThumbAxes = uiaxes(obj.containerGrid,...
                'XTick',[],...
                'YTick',[],...
                'XLim',obj.Limits,...
                'YLim',[0 obj.Height],...
                'XColor','none',...
                'YColor','none',...
                'Color','none',...
                'Units','normalized',...
                'InnerPosition',[0 0 1 1],...
                'LineWidth',1,...
                'Box','off',...
                'HitTest','on',...
                'PickableParts','all',...
                'Visible','off');
            obj.sliderThumbAxes.Layout.Row    = 2;
            obj.sliderThumbAxes.Layout.Column = 1;
            obj.sliderThumbAxes.Toolbar.Visible = 'off';
            disableDefaultInteractivity(obj.sliderThumbAxes);

            % track patch (full Limits range)
            obj.trackPatch = patch(obj.sliderThumbAxes,...
                'Faces',[1,2,3,4],...
                'Vertices',[0,0;1,0;1,1;0,1],...
                'EdgeColor',[0 0 0],...
                'FaceColor','flat',...
                'PickableParts','none',...
                'HitTest','off',...
                'LineWidth',0.5);

            % range patch (between low and high values)
            obj.rangePatch = patch(obj.sliderThumbAxes,...
                'Faces',1:4,...
                'Vertices',[0,0;1,0;1,1;0,1],...
                'EdgeColor',[0 0 0],...
                'FaceColor','interp',...
                'PickableParts','none',...
                'HitTest','off',...
                'LineWidth',0.5);

            % create lower and upper thumbs
            obj.sliderThumb(1) = widgets.sliderthumb(obj.sliderThumbAxes,...
                "EdgeColor",obj.ThumbEdgeColor,...
                "FaceColor",obj.ThumbFaceColor,...
                "Value",obj.Limits(1),...
                "YPosition",0.5*obj.Height,...
                "ID",1,...
                "EdgeWidth",0.5);

            obj.sliderThumb(2) = widgets.sliderthumb(obj.sliderThumbAxes,...
                "EdgeColor",obj.ThumbEdgeColor,...
                "FaceColor",obj.ThumbFaceColor,...
                "Value",obj.Limits(2),...
                "YPosition",0.5*obj.Height,...
                "ID",2,...
                "EdgeWidth",0.5);

            % listener for Value to enable the ValueChanged callback
            obj.sliderValueListener = addlistener(...
                obj,'Value',...
                'PostSet',@obj.valueChanged);

            % editfields for numeric control
            obj.sliderValueEditField(1) = uieditfield(obj.containerGrid,"numeric",...
                'Limits',obj.Limits,...
                'Value',obj.Limits(1),...
                'ValueChangedFcn',@(o,e) obj.sliderEditfieldValueChanged(o,e),...
                'UserData',1);
            obj.sliderValueEditField(1).Layout.Row    = 2;
            obj.sliderValueEditField(1).Layout.Column = 2;

            obj.sliderValueEditField(2) = uieditfield(obj.containerGrid,"numeric",...
                'Limits',obj.Limits,...
                'Value',obj.Limits(2),...
                'ValueChangedFcn',@(o,e) obj.sliderEditfieldValueChanged(o,e),...
                'UserData',2);
            obj.sliderValueEditField(2).Layout.Row    = 2;
            obj.sliderValueEditField(2).Layout.Column = 3;

            % property-based listeners for granular updates
            obj.L(end+1) = addlistener(obj,{'ThumbFaceColor','ThumbEdgeColor'},'PostSet',@(~,~)obj.onThumbColorsChanged());
            obj.L(end+1) = addlistener(obj,'Colormap','PostSet',@(~,~)obj.onColormapChanged());
            obj.L(end+1) = addlistener(obj,{'TrackHeight','RangeHeight','Height'},'PostSet',@(~,~)obj.onDimensionsChanged());
            obj.L(end+1) = addlistener(obj,'Limits','PostSet',@(~,~)obj.onLimitsChanged());
            obj.L(end+1) = addlistener(obj,{'Title','FontSize','FontColor'},'PostSet',@(~,~)obj.updateText());




            % Register with FigureEventHub
            obj.Hub = app.FigureEventHub.ensure(obj.parentFig);
            obj.RouterId = obj.Hub.register(obj, ...
                'Priority', 10, ...
                'CaptureDuringDrag', true);


            % set SizeChangedFcn so we can force visual update upon resizing (AutoResizeChildren of parent must be Off)
            obj.SizeChangedFcn = @(~,~) obj.queueSizeUpdate();

        end

        function update(obj)
            % Keep update focused on layout + basic appearance; more granular
            % changes are handled by property listeners and set.Value.

            % % Row height for slider row
            % obj.containerGrid.RowHeight{2} = obj.Height;

            % % Labels appearance
            % set([obj.titleLabel,obj.minLabel,obj.maxLabel],...
            %     "FontSize",obj.FontSize,...
            %     "FontColor",obj.FontColor);
            % 
            % % Label text
            % obj.titleLabel.Text = obj.Title;

            % Axes limits
            % obj.sliderThumbAxes.XLim = obj.Limits;
            % obj.sliderThumbAxes.YLim = [0 obj.Height];

            % % Thumb Y position (centered vertically)
            % obj.sliderThumb(1).YPosition = 0.5 * obj.Height;
            % obj.sliderThumb(2).YPosition = 0.5 * obj.Height;

            % Background color
            obj.containerGrid.BackgroundColor = obj.BackgroundColor;

            % % Ensure thumbs are within Limits
            % obj.sliderThumb(1).Value = max(obj.sliderThumb(1).Value, obj.Limits(1));
            % obj.sliderThumb(2).Value = min(obj.sliderThumb(2).Value, obj.Limits(2));
            % 
            % % Update editfield limits based on current thumbs
            % lowVal  = obj.sliderThumb(1).Value;
            % highVal = obj.sliderThumb(2).Value;
            % obj.sliderValueEditField(1).Limits = [obj.Limits(1) highVal];
            % obj.sliderValueEditField(2).Limits = [lowVal obj.Limits(2)];

            % Track/range patches depend on Limits, Height, TrackHeight, RangeHeight, Value, Colormap.
            obj.updateTrackPatch();
            obj.updateRangePatch();
        end

    end

    %% Destructor

    methods

        function delete(obj)
            % remove listeners
            if ~isempty(obj.sliderValueListener) && isvalid(obj.sliderValueListener)
                delete(obj.sliderValueListener);
            end
            if ~isempty(obj.L)
                delete(obj.L(isvalid(obj.L)));
            end

            % unregister from hub
            try
                if ~isempty(obj.Hub) && isvalid(obj.Hub) && ~isnan(obj.RouterId)
                    obj.Hub.unregister(obj.RouterId);
                end
            catch
                % ignore if figure already gone
            end
        end

    end

    %% Update helpers

    methods(Access=private)

        function updateOnResize(obj)
            if ~isvalid(obj); return; end
            
            obj.onDimensionsChanged();
        end

        function queueSizeUpdate(obj)
            if obj.pendingUpdate
                return
            end
            obj.pendingUpdate = true;
            % coalesce updates
            drawnow limitrate nocallbacks
            obj.updateOnResize();
            obj.pendingUpdate = false;
        end



        function updateRangePatch(obj)
            sliderValue = obj.Value;
            lowVal  = sliderValue(1);
            highVal = sliderValue(2);

            % X and Y coordinates of each vertex along the bottom of colorbar (left to right)
            bottomX = linspace(lowVal, highVal, 256).';
            bottomY = repmat(0.5*(obj.Height-obj.RangeHeight), size(bottomX));
            % coordinates of each vertex along the top of colorbar (right to left)
            topX = flipud(bottomX);
            topY = bottomY + obj.RangeHeight;

            V = [bottomX,bottomY; topX,topY];
            F = 1:512;
            C = vertcat(obj.Colormap, flipud(obj.Colormap));

            set(obj.rangePatch, ...
                "Vertices", V, ...
                "Faces",    F, ...
                "FaceVertexCData", C);
        end

        function updateTrackPatch(obj)
            sliderLimits = obj.Limits;
            sliderValue  = obj.Value;

            % x values
            leftX  = sliderLimits(1);
            rightX = sliderLimits(2);
            midX   = mean(sliderValue);

            % y values
            bottomY = 0.5*(obj.Height - obj.TrackHeight);
            topY    = bottomY + obj.TrackHeight;

            Vx = [leftX; midX; rightX; rightX; midX; leftX];
            Vy = [bottomY; bottomY; bottomY; topY; topY; topY];

            V = [Vx, Vy];
            F = [1,2,5,6; 2,3,4,5];
            C = obj.Colormap([1,256],:);

            set(obj.trackPatch, ...
                "Vertices", V, ...
                "Faces",    F, ...
                "FaceVertexCData", C);
        end

        function updateText(obj)
            % Labels appearance
            set([obj.titleLabel,obj.minLabel,obj.maxLabel],...
                "FontSize",obj.FontSize,...
                "FontColor",obj.FontColor);
            % Label text
            obj.titleLabel.Text = obj.Title;
        end

        function onThumbColorsChanged(obj)
            % Only update thumb colors when ThumbFaceColor/ThumbEdgeColor change
            if ~all(isvalid(obj.sliderThumb))
                return;
            end
            obj.sliderThumb(1).FaceColor = obj.ThumbFaceColor;
            obj.sliderThumb(2).FaceColor = obj.ThumbFaceColor;
            obj.sliderThumb(1).EdgeColor = obj.ThumbEdgeColor;
            obj.sliderThumb(2).EdgeColor = obj.ThumbEdgeColor;
        end

        function onColormapChanged(obj)
            % Only recompute FaceVertexCData of patches when colormap changes
            if isvalid(obj.trackPatch)
                set(obj.trackPatch,"FaceVertexCData",obj.Colormap([1,256],:));
                %obj.updateTrackPatch();
            end
            if isvalid(obj.rangePatch)
                set(obj.rangePatch,"FaceVertexCData",vertcat(obj.Colormap, flipud(obj.Colormap)));
                %obj.updateRangePatch();
            end
        end

        function onDimensionsChanged(obj)

            % Set row height for slider row
            obj.containerGrid.RowHeight{2} = obj.Height;

            % Adjust axes YLim
            obj.sliderThumbAxes.YLim = [0 obj.Height];

            % Thumb Y position (centered vertically)
            obj.sliderThumb(1).YPosition = 0.5 * obj.Height;
            obj.sliderThumb(2).YPosition = 0.5 * obj.Height;

            % Full recompute of patches when heights change
            if isvalid(obj.trackPatch)
                obj.updateTrackPatch();
            end
            if isvalid(obj.rangePatch)
                obj.updateRangePatch();
            end
        end

        function onLimitsChanged(obj)

            % Adjust axes XLim
            obj.sliderThumbAxes.XLim = obj.Limits;

            % Ensure thumbs are within Limits
            obj.sliderThumb(1).Value = max(obj.sliderThumb(1).Value, obj.Limits(1));
            obj.sliderThumb(2).Value = min(obj.sliderThumb(2).Value, obj.Limits(2));

            % Update editfield limits based on current thumbs
            lowVal  = obj.sliderThumb(1).Value;
            highVal = obj.sliderThumb(2).Value;
            obj.sliderValueEditField(1).Limits = [obj.Limits(1) highVal];
            obj.sliderValueEditField(2).Limits = [lowVal obj.Limits(2)];

        end

        function idx = getThumbIndexFromTarget(obj, tgt)
            idx = NaN;
            if ~isgraphics(tgt, "line")
                return;
            end
            if isprop(tgt, 'ID')
                idVal = tgt.ID;
                if any(idVal == [1 2])
                    idx = idVal;
                end
            end
        end

        function selectThumb(obj, thumbIdx)
            obj.activeThumbIdx = thumbIdx;
            obj.sliderThumb(thumbIdx).select();
            otherIdx = setdiff(1:2, thumbIdx);
            for k = otherIdx
                obj.sliderThumb(k).deselect();
            end
        end

        function clearHover(obj)
            if ~isnan(obj.hoverThumbIdx)
                if obj.hoverThumbIdx ~= obj.activeThumbIdx
                    obj.sliderThumb(obj.hoverThumbIdx).deselect();
                end
                obj.hoverThumbIdx = NaN;
            end
        end

        function handleHover(obj, tgt)
            if obj.isSliding
                return;
            end

            idx = obj.getThumbIndexFromTarget(tgt);

            if isnan(idx)
                if ~isnan(obj.hoverThumbIdx) && obj.hoverThumbIdx ~= obj.activeThumbIdx
                    obj.sliderThumb(obj.hoverThumbIdx).deselect();
                end
                obj.hoverThumbIdx = NaN;
                return;
            end

            if idx ~= obj.hoverThumbIdx
                if ~isnan(obj.hoverThumbIdx) && obj.hoverThumbIdx ~= obj.activeThumbIdx
                    obj.sliderThumb(obj.hoverThumbIdx).deselect();
                end
                obj.hoverThumbIdx = idx;
                if idx ~= obj.activeThumbIdx
                    obj.sliderThumb(idx).select();
                end
            end
        end

        function moveActiveThumbToCursor(obj)
            if isnan(obj.activeThumbIdx)
                return;
            end

            cp = obj.sliderThumbAxes.CurrentPoint;
            cursorX = cp(1,1);

            vals   = obj.Value;
            lowVal = vals(1);
            highVal = vals(2);

            if obj.activeThumbIdx == 1
                thumbLims = [obj.Limits(1), highVal];
            else
                thumbLims = [lowVal, obj.Limits(2)];
            end

            newVal = min(max(cursorX, thumbLims(1)), thumbLims(2));

            if obj.RoundFractionalValues
                newVal = round(newVal);
            end

            vals(obj.activeThumbIdx) = newVal;
            obj.Value = vals;
        end

    end

    %% Dependent property accessors

    methods

        function Value = get.Value(obj)
            Value = [obj.sliderThumb(1).Value, obj.sliderThumb(2).Value];
        end

        function set.Value(obj, val)
            validateattributes(val, {'numeric'}, {'vector','numel',2,'finite'});

            if obj.RoundFractionalValues
                val = round(val);
            end

            v1 = val(1);
            v2 = val(2);

            v1 = max(min(v1, obj.Limits(2)), obj.Limits(1));
            v2 = max(min(v2, obj.Limits(2)), obj.Limits(1));

            if v1 > v2
                tmp = v1; v1 = v2; v2 = tmp;
            end

            obj.sliderThumb(1).Value = v1;
            obj.sliderThumb(2).Value = v2;

            obj.sliderValueEditField(1).Limits = [obj.Limits(1) v2];
            obj.sliderValueEditField(2).Limits = [v1 obj.Limits(2)];
            obj.sliderValueEditField(1).Value  = v1;
            obj.sliderValueEditField(2).Value  = v2;

            if isvalid(obj.rangePatch) && isvalid(obj.trackPatch)
                obj.updateTrackPatch();
                obj.updateRangePatch();
            end
        end

        function parentFig = get.parentFig(obj)
            parentFig = ancestor(obj,'figure','toplevel');
        end

    end

    %% Callbacks / Value change

    methods

        function sliderEditfieldValueChanged(obj, source, ~)
            vals = obj.Value;
            idx  = source.UserData;
            vals(idx) = source.Value;
            obj.Value = vals;
        end

        function valueChanged(obj, ~, ~)
            notify(obj,'ValueChanged');
        end

    end

    %% Hub-facing event handlers

    methods

        function tf = matches(obj, tgt, ~, ~)
            tf = false;
            if ~isvalid(obj)
                return;
            end

            if ~isempty(ancestor(tgt,'matlab.ui.container.Toolbar')) || ...
               isa(tgt,'matlab.graphics.shape.internal.Button')
                return;
            end

            ax = ancestor(tgt, 'matlab.ui.control.UIAxes');
            tf = (ax == obj.sliderThumbAxes);
        end

        function onDown(obj, ~, tgt)
            if isvalid(obj.parentFig)
                obj.parentFig.Pointer = 'hand';
            end

            thumbIdx = obj.getThumbIndexFromTarget(tgt);

            if isnan(thumbIdx)
                cp = obj.sliderThumbAxes.CurrentPoint;
                clickedX = cp(1,1);
                vals = obj.Value;
                [~, thumbIdx] = min(abs(vals - clickedX));
            end

            obj.selectThumb(thumbIdx);
            obj.isSliding = true;
            obj.moveActiveThumbToCursor();
        end

        function onMove(obj, ~, tgt)
            if obj.isSliding
                obj.moveActiveThumbToCursor();
            else
                obj.handleHover(tgt);
            end

            if isvalid(obj.parentFig)
                obj.parentFig.Pointer = 'hand';
            end
        end

        function onUp(obj, ~, ~)
            % Stop sliding and restore states
            obj.isSliding = false;

            % Deselect the active thumb (return to default size)
            if ~isnan(obj.activeThumbIdx)
                obj.sliderThumb(obj.activeThumbIdx).deselect();
            end
            obj.activeThumbIdx = NaN;

            % Clear hover so nothing stays enlarged after release
            obj.clearHover();
        end

        function onScroll(~, ~, ~)
            % No scroll behavior
        end

        function onEnter(obj, ~, ~)
            if isvalid(obj.parentFig)
                obj.parentFig.Pointer = 'hand';
            end
        end

        function onLeave(obj, ~, ~)
            obj.clearHover();
            if isvalid(obj.parentFig)
                obj.parentFig.Pointer = 'arrow';
            end
        end

    end


    methods (Static)

        function s = demo()

            fig = uifigure(...
                "WindowStyle","alwaysontop",...
                "InnerPosition",[100,100,510,615],...
                "Color",[0 0 0]);

            g = uigridlayout(fig,[2,1],...
                "BackgroundColor",[0 0 0],...
                "ColumnWidth",{500},...
                "RowHeight",{500,'fit'},...
                "Padding",[5 5 5 5],...
                "RowSpacing",5);

            I = im2double(imread("rice.png"));

            ax = widgets.ImageAxes(g,"CData",I);

            s = widgets.uirangeslidereditfield(g,...
                "Title",'Adjust CLim',...
                "FontColor",[1 1 1],...
                "Limits",getrangefromclass(I),...
                "Value",[min(I(:)) max(I(:))],...
                "Colormap",ax.Colormap,...
                "ValueChangedFcn",@(o,~) set(ax,'CLim',o.Value));

        end

    end


end
