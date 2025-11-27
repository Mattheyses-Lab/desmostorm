% classdef uirangeslidereditfield < matlab.ui.componentcontainer.ComponentContainer
% 
%     %% Public API
% 
%     properties
% 
%         % flag to determine whether fractional values are rounded
%         RoundValues (1,1) matlab.lang.OnOffSwitchState = 'off'
% 
%     end
% 
%     % properties we want property-based, minimal updates for
%     properties(SetObservable, AbortSet)
%         % min and max of the slider track
%         Limits double = [0,1]
% 
%         % color of the thumb faces
%         ThumbFaceColor (1,3) double {mustBeInRange(ThumbFaceColor,0,1)} = [1 1 1]
%         % color of the thumb edges
%         ThumbEdgeColor (1,3) double {mustBeInRange(ThumbEdgeColor,0,1)} = [0 0 0]
% 
%         % track colormap (spans the range between low and high thumbs)
%         Colormap (256,3) double = gray
% 
%         % height of the track
%         TrackHeight (1,1) double = 4
%         % height of the range
%         RangeHeight (1,1) double = 7
%         % overall height of the slider component (excluding labels)
%         Height (1,1) double = 25
% 
%         % text displayed above the slider
%         Title (1,:) char = "Untitled slider"
%         % size of the font
%         FontSize (1,1) double = 12
%         % color of the font
%         FontColor (1,3) double = [0 0 0]
% 
%     end
% 
%     properties(SetAccess=private)
%         % true if the slider is currently moving
%         isSliding (1,1) logical = false
%         % index of the active thumb (1 or 2, NaN if none)
%         activeThumbIdx (1,1) double = NaN
%         % index of thumb currently hovered (1 or 2, NaN if none)
%         hoverThumbIdx double = NaN
% 
%         % flag to help coalesce updates
%         pendingUpdate (1,1) logical = false
%     end
% 
%     properties(SetObservable=true,Dependent=true)
%         Value (1,2) double = [0,1]
%     end
% 
%     properties(Access=private,Dependent=true)
%         % ancestor figure of the component
%         parentFig
%     end
% 
% 
%     %% helpers to speed up some computations
%     properties(Access=private)
%         rangeV = widgets.uirangeslidereditfield.getRangePatchBaseVertices();
%         rangeF = 1:512
%         rangeC = [gray(256);flipud(gray(256))]
%         trackV = widgets.uirangeslidereditfield.getTrackPatchBaseVertices();
%         trackF = [1,2,5,6; 2,3,4,5];
%         trackC = [0 0 0; 1 1 1];
%     end
% 
%     %% UI / graphics handles
% 
%     properties(Access = private,Transient,NonCopyable)
%         % outermost grid for the entire component
%         containerGrid (1,1) matlab.ui.container.GridLayout
% 
%         % uilabel for the Title
%         titleLabel (1,1) matlab.ui.control.Label
%         % uilabel for the minimum value editfield
%         minLabel (1,1) matlab.ui.control.Label
%         % uilabel for the maximum value editfield
%         maxLabel (1,1) matlab.ui.control.Label
% 
%         % axes to hold slider thumbs and patches
%         sliderThumbAxes (1,1) matlab.ui.control.UIAxes
%         % patch object for slider track
%         trackPatch (1,1) matlab.graphics.primitive.Patch
%         % patch object for slider range
%         rangePatch (1,1) matlab.graphics.primitive.Patch
%         % the slider thumbs (lower=1, upper=2)
%         sliderThumb (:,1) widgets.sliderthumb
%         % editfields for text control of slider values [low high]
%         sliderValueEditField (:,1) matlab.ui.control.NumericEditField
% 
%         % PostSet listener for the slider value
%         sliderValueListener event.listener
% 
%         % listeners for property-based updates (ThumbFaceColor, etc.)
%         L event.listener = event.listener.empty
%     end
% 
%     %% Hub registration
% 
%     properties(Access=private)
%         Hub app.FigureEventHub
%         RouterId double = NaN
%     end
% 
%     %% Events
% 
%     events (HasCallbackProperty, NotifyAccess = protected)
%         ValueChanged % ValueChangedFcn callback property will be generated
%     end
% 
%     %% ComponentContainer lifecycle
% 
%     methods(Access=protected)
% 
%         function setup(obj)
% 
%             obj.Units    = "normalized";
%             obj.Position = [0 0 1 1];
% 
%             % grid layout manager to enclose all the components
%             obj.containerGrid = uigridlayout(obj,...
%                 [1,3],...
%                 "ColumnWidth",{'1x',50,50},...
%                 "RowHeight",{'fit',obj.TrackHeight},...
%                 "BackgroundColor",[0 0 0],...
%                 "Padding",[5 5 5 5],...
%                 "Scrollable","on",...
%                 "RowSpacing",0);
% 
%             % uilabel to display the title text
%             obj.titleLabel = uilabel(obj.containerGrid,...
%                 "Text",obj.Title,...
%                 "FontColor",obj.FontColor,...
%                 "FontSize",obj.FontSize);
%             obj.titleLabel.Layout.Row    = 1;
%             obj.titleLabel.Layout.Column = 1;
% 
%             % uilabel for the minimum value editfield
%             obj.minLabel = uilabel(obj.containerGrid,...
%                 "Text","Min",...
%                 "FontColor",obj.FontColor,...
%                 "FontSize",obj.FontSize);
%             obj.minLabel.Layout.Row    = 1;
%             obj.minLabel.Layout.Column = 2;
% 
%             % uilabel for the maximum value editfield
%             obj.maxLabel = uilabel(obj.containerGrid,...
%                 "Text","Max",...
%                 "FontColor",obj.FontColor,...
%                 "FontSize",obj.FontSize);
%             obj.maxLabel.Layout.Row    = 1;
%             obj.maxLabel.Layout.Column = 3;
% 
%             % axes to hold the slider thumbs and patches
%             obj.sliderThumbAxes = uiaxes(obj.containerGrid,...
%                 'XTick',[],...
%                 'YTick',[],...
%                 'XLim',obj.Limits,...
%                 'YLim',[0 obj.Height],...
%                 'XColor','none',...
%                 'YColor','none',...
%                 'Color','none',...
%                 'Units','normalized',...
%                 'InnerPosition',[0 0 1 1],...
%                 'LineWidth',1,...
%                 'Box','off',...
%                 'HitTest','on',...
%                 'PickableParts','all',...
%                 'Visible','off');
%             obj.sliderThumbAxes.Layout.Row    = 2;
%             obj.sliderThumbAxes.Layout.Column = 1;
%             obj.sliderThumbAxes.Toolbar.Visible = 'off';
%             disableDefaultInteractivity(obj.sliderThumbAxes);
% 
%             % track patch (full Limits range)
%             obj.trackPatch = patch(obj.sliderThumbAxes,...
%                 'Faces',[1,2,3,4],...
%                 'Vertices',[0,0;1,0;1,1;0,1],...
%                 'EdgeColor',[0 0 0],...
%                 'FaceColor','flat',...
%                 'PickableParts','none',...
%                 'HitTest','off',...
%                 'LineWidth',0.5);
% 
%             % range patch (between low and high values)
%             obj.rangePatch = patch(obj.sliderThumbAxes,...
%                 'Faces',1:4,...
%                 'Vertices',[0,0;1,0;1,1;0,1],...
%                 'EdgeColor',[0 0 0],...
%                 'FaceColor','interp',...
%                 'PickableParts','none',...
%                 'HitTest','off',...
%                 'LineWidth',0.5);
% 
%             % create lower and upper thumbs
%             obj.sliderThumb(1) = widgets.sliderthumb(obj.sliderThumbAxes,...
%                 "EdgeColor",obj.ThumbEdgeColor,...
%                 "FaceColor",obj.ThumbFaceColor,...
%                 "Value",obj.Limits(1),...
%                 "YPosition",0.5*obj.Height,...
%                 "ID",1,...
%                 "EdgeWidth",0.5);
% 
%             obj.sliderThumb(2) = widgets.sliderthumb(obj.sliderThumbAxes,...
%                 "EdgeColor",obj.ThumbEdgeColor,...
%                 "FaceColor",obj.ThumbFaceColor,...
%                 "Value",obj.Limits(2),...
%                 "YPosition",0.5*obj.Height,...
%                 "ID",2,...
%                 "EdgeWidth",0.5);
% 
%             % editfields for numeric control
%             obj.sliderValueEditField(1) = uieditfield(obj.containerGrid,"numeric",...
%                 'Limits',obj.Limits,...
%                 'Value',obj.Limits(1),...
%                 'ValueChangedFcn',@(o,e) obj.sliderEditfieldValueChanged(o,e),...
%                 'UserData',1);
%             obj.sliderValueEditField(1).Layout.Row    = 2;
%             obj.sliderValueEditField(1).Layout.Column = 2;
% 
%             obj.sliderValueEditField(2) = uieditfield(obj.containerGrid,"numeric",...
%                 'Limits',obj.Limits,...
%                 'Value',obj.Limits(2),...
%                 'ValueChangedFcn',@(o,e) obj.sliderEditfieldValueChanged(o,e),...
%                 'UserData',2);
%             obj.sliderValueEditField(2).Layout.Row    = 2;
%             obj.sliderValueEditField(2).Layout.Column = 3;
% 
%             % Register with FigureEventHub
%             obj.Hub = app.FigureEventHub.ensure(obj.parentFig);
%             obj.RouterId = obj.Hub.register(obj, ...
%                 'Priority', 10, ...
%                 'CaptureDuringDrag', true);
% 
%             obj.updateTrackPatch();
%             obj.updateRangePatch();
% 
%             % set SizeChangedFcn so we can force visual update upon resizing (AutoResizeChildren of parent must be Off)
%             obj.SizeChangedFcn = @(~,~) obj.queueSizeUpdate();
% 
%             % property-based listeners for granular updates
%             obj.L(end+1) = addlistener(obj,{'ThumbFaceColor','ThumbEdgeColor'},'PostSet',@(~,~)obj.onThumbColorsChanged());
%             obj.L(end+1) = addlistener(obj,'Colormap','PostSet',@(~,~)obj.onColormapChanged());
%             obj.L(end+1) = addlistener(obj,{'TrackHeight','RangeHeight','Height'},'PostSet',@(~,~)obj.onDimensionsChanged());
%             obj.L(end+1) = addlistener(obj,'Limits','PostSet',@(~,~)obj.onLimitsChanged());
%             obj.L(end+1) = addlistener(obj,{'Title','FontSize','FontColor'},'PostSet',@(~,~)obj.updateText());
% 
% 
%             % listener for Value to enable the ValueChanged callback
%             obj.sliderValueListener = addlistener(...
%                 obj,'Value',...
%                 'PostSet',@obj.valueChanged);
% 
%         end
% 
%         function update(obj)
%             % Background color
%             obj.containerGrid.BackgroundColor = obj.BackgroundColor;
%         end
% 
%     end
% 
%     %% Destructor
% 
%     methods
% 
%         function delete(obj)
%             % remove listeners
%             if ~isempty(obj.sliderValueListener) && isvalid(obj.sliderValueListener)
%                 delete(obj.sliderValueListener);
%             end
%             if ~isempty(obj.L)
%                 delete(obj.L(isvalid(obj.L)));
%             end
% 
%             % unregister from hub
%             try
%                 if ~isempty(obj.Hub) && isvalid(obj.Hub) && ~isnan(obj.RouterId)
%                     obj.Hub.unregister(obj.RouterId);
%                 end
%             catch
%                 % ignore if figure already gone
%             end
%         end
% 
%     end
% 
%     %% Update helpers
% 
%     methods(Access=private)
% 
%         function updateOnResize(obj)
%             if ~isvalid(obj); return; end
% 
%             obj.onDimensionsChanged();
%         end
% 
%         function queueSizeUpdate(obj)
% 
%             if obj.pendingUpdate
%                 return
%             end
%             obj.pendingUpdate = true;
%             % coalesce updates
%             drawnow limitrate nocallbacks
%             obj.updateOnResize();
%             obj.pendingUpdate = false;
%         end
% 
%         function updateRangePatch(obj)
%             % full update of Vertices, Faces, and FaceVertexCData
% 
%             lowVal = obj.sliderThumb(1).Value;
%             highVal = obj.sliderThumb(2).Value;
% 
%             % V = obj.getRangePatchBaseVertices();
%             V = obj.rangeV; % base range Vertices template
% 
%             % adjust X coordinates of vertices
%             V(:,1) = V(:,1)*(highVal-lowVal)+lowVal;
%             % adjust Y coordinates of vertices
%             V(1:256,2) = 0.5*(obj.Height-obj.RangeHeight); % bottom edge Y
%             V(257:end,2) = 0.5*(obj.Height+obj.RangeHeight); % top edge Y
% 
%             set(obj.rangePatch, ...
%                 "Vertices", V, ...
%                 "Faces",    1:512, ...
%                 "FaceVertexCData", vertcat(obj.Colormap, flipud(obj.Colormap)));
%         end
% 
%         function updateRangePatchVx(obj)
%             loVal = obj.sliderThumb(1).Value;
%             hiVal = obj.sliderThumb(2).Value;
%             % update of Vertex X coordinates only
%             obj.rangePatch.Vertices(:,1) = obj.rangeV(:,1)*(hiVal-loVal)+loVal;
%         end
% 
%         function updateTrackPatch(obj)
%             % full update of Vertices, Faces, and FaceVertexCData
% 
%             sliderLimits = obj.Limits;
%             sliderValue = [obj.sliderThumb(1).Value, obj.sliderThumb(2).Value];
% 
%             % x values
%             lo  = sliderLimits(1);
%             hi = sliderLimits(2);
%             mid   = mean(sliderValue);
% 
%             V = obj.trackV; % base track Vertices template
%             % adjust X coordinates of Vertices
%             V(:,1) = [lo; mid; hi; hi; mid; lo];
%             % adjust Y coordinates of Vertices
%             V(1:3,2) = 0.5*(obj.Height - obj.TrackHeight);
%             V(4:end,2) = 0.5*(obj.Height + obj.TrackHeight);
% 
%             set(obj.trackPatch, ...
%                 "Vertices", V, ...
%                 "Faces",    [1,2,5,6; 2,3,4,5], ...
%                 "FaceVertexCData", obj.Colormap([1,256],:));
%         end
% 
%         function updateTrackPatchVx(obj)
%             sliderValue = [obj.sliderThumb(1).Value, obj.sliderThumb(2).Value];
%             sliderLimits = obj.Limits;
%             % x values
%             loLim  = sliderLimits(1);
%             hiLim = sliderLimits(2);
%             midVal   = mean(sliderValue);
%             % update of Vertex X coordinates only
%             obj.trackPatch.Vertices(:,1) = [loLim; midVal; hiLim; hiLim; midVal; loLim];
%         end
% 
%         function updatePatchVx(obj)
%             % x values used to calculate range patch coordinates
%             loVal = obj.sliderThumb(1).Value;
%             hiVal = obj.sliderThumb(2).Value;
%             % x values used to calculate track patch coordinates
%             sliderLimits = obj.Limits;
%             loLim  = sliderLimits(1);
%             hiLim = sliderLimits(2);
%             midVal   = mean([loVal,hiVal]);
%             % update of Vertex X coordinates only
%             obj.trackPatch.Vertices(:,1) = [loLim; midVal; hiLim; hiLim; midVal; loLim];
%             obj.rangePatch.Vertices(:,1) = obj.rangeV(:,1)*(hiVal-loVal)+loVal;
%         end
% 
%         function updateText(obj)
%             % Labels appearance
%             set([obj.titleLabel,obj.minLabel,obj.maxLabel],...
%                 "FontSize",obj.FontSize,...
%                 "FontColor",obj.FontColor);
%             % Label text
%             obj.titleLabel.Text = obj.Title;
%         end
% 
%         function onThumbColorsChanged(obj)
%             % Only update thumb colors when ThumbFaceColor/ThumbEdgeColor change
%             if ~all(isvalid(obj.sliderThumb))
%                 return;
%             end
%             obj.sliderThumb(1).FaceColor = obj.ThumbFaceColor;
%             obj.sliderThumb(2).FaceColor = obj.ThumbFaceColor;
%             obj.sliderThumb(1).EdgeColor = obj.ThumbEdgeColor;
%             obj.sliderThumb(2).EdgeColor = obj.ThumbEdgeColor;
%         end
% 
%         function onColormapChanged(obj)
%             % Only recompute FaceVertexCData of patches when colormap changes
%             if isvalid(obj.trackPatch)
%                 set(obj.trackPatch,"FaceVertexCData",obj.Colormap([1,256],:));
%             end
%             if isvalid(obj.rangePatch)
%                 set(obj.rangePatch,"FaceVertexCData",vertcat(obj.Colormap, flipud(obj.Colormap)));
%             end
%         end
% 
%         function onDimensionsChanged(obj)
% 
%             % Set row height for slider row
%             obj.containerGrid.RowHeight{2} = obj.Height;
% 
%             % Adjust axes YLim
%             obj.sliderThumbAxes.YLim = [0 obj.Height];
% 
%             % Thumb Y position (centered vertically)
%             obj.sliderThumb(1).YPosition = 0.5 * obj.Height;
%             obj.sliderThumb(2).YPosition = 0.5 * obj.Height;
% 
%             % Full recompute of patches when heights change
%             if isvalid(obj.trackPatch)
%                 obj.updateTrackPatch();
%             end
% 
%             if isvalid(obj.rangePatch)
%                 obj.updateRangePatch();
%             end
% 
%         end
% 
%         function onLimitsChanged(obj)
% 
%             % Adjust axes XLim
%             obj.sliderThumbAxes.XLim = obj.Limits;
% 
%             % Ensure thumbs are within Limits
%             obj.sliderThumb(1).Value = max(obj.sliderThumb(1).Value, obj.Limits(1));
%             obj.sliderThumb(2).Value = min(obj.sliderThumb(2).Value, obj.Limits(2));
% 
%             % Update editfield limits based on current thumbs
%             obj.sliderValueEditField(1).Limits = [obj.Limits(1) obj.sliderThumb(2).Value];
%             obj.sliderValueEditField(2).Limits = [obj.sliderThumb(1).Value obj.Limits(2)];
% 
%         end
% 
%         function idx = getThumbIndexFromTarget(obj, tgt)
%             idx = NaN;
%             if isprop(tgt, 'ID')
%                 idx = tgt.ID;
%             end
%         end
% 
%         function selectThumb(obj, thumbIdx)
%             % deselect other if it exists
%             if ~isnan(obj.activeThumbIdx)
%                 obj.sliderThumb(obj.activeThumbIdx).deselect();
%             end
% 
%             obj.activeThumbIdx = thumbIdx;
%             obj.sliderThumb(thumbIdx).select();
%         end
% 
%         function clearHover(obj)
%             if ~isnan(obj.hoverThumbIdx)
%                 if obj.hoverThumbIdx ~= obj.activeThumbIdx
%                     obj.sliderThumb(obj.hoverThumbIdx).deselect();
%                 end
%                 obj.hoverThumbIdx = NaN;
%             end
%         end
% 
%         function handleHover(obj, tgt)
%             if obj.isSliding
%                 return;
%             end
% 
%             if isprop(tgt, 'ID')
%                 idx = tgt.ID;
%             else
%                 if ~isnan(obj.hoverThumbIdx) && obj.hoverThumbIdx ~= obj.activeThumbIdx
%                     obj.sliderThumb(obj.hoverThumbIdx).deselect();
%                 end
%                 obj.hoverThumbIdx = NaN;
%                 return;
%             end
% 
%             if idx ~= obj.hoverThumbIdx
%                 if ~isnan(obj.hoverThumbIdx) && obj.hoverThumbIdx ~= obj.activeThumbIdx
%                     obj.sliderThumb(obj.hoverThumbIdx).deselect();
%                 end
%                 obj.hoverThumbIdx = idx;
%                 if idx ~= obj.activeThumbIdx
%                     obj.sliderThumb(idx).select();
%                 end
%             end
%         end
% 
%         function moveActiveThumbToCursor(obj)
%             if isnan(obj.activeThumbIdx), return; end
% 
%             thumbLims = obj.sliderValueEditField(obj.activeThumbIdx).Limits;
% 
%             obj.Value(obj.activeThumbIdx) = clip(obj.sliderThumbAxes.CurrentPoint(1,1),thumbLims(1),thumbLims(2));
%         end
% 
%     end
% 
%     %% Dependent property accessors
% 
%     methods
% 
%         function Value = get.Value(obj)
%             Value = [obj.sliderThumb(1).Value, obj.sliderThumb(2).Value];
%         end
% 
%         function set.Value(obj, val)
%             % Very cheap shape check (optional)
%             if numel(val) ~= 2
%                 error('Value must be a 1x2 numeric vector.');
%             end
% 
%             if obj.RoundValues
%                 val = round(val);
%             end
% 
%             lims = obj.Limits;
%             lo = lims(1);
%             hi = lims(2);
% 
%             % val = clip(sort(val),lo,hi);
%             val = clip(val,lo,hi);
% 
%             % update thumbs
%             obj.sliderThumb(1).Value = val(1);
%             obj.sliderThumb(2).Value = val(2);
% 
%             % update editfield limits + values
%             obj.sliderValueEditField(1).Limits = [lo val(2)];
%             obj.sliderValueEditField(2).Limits = [val(1) hi];
%             obj.sliderValueEditField(1).Value  = val(1);
%             obj.sliderValueEditField(2).Value  = val(2);
% 
%             % % update X coordinates of patch vertices
%             obj.updatePatchVx();
%         end
% 
%         function parentFig = get.parentFig(obj)
%             parentFig = ancestor(obj,'figure','toplevel');
%         end
% 
%     end
% 
%     %% Callbacks / Value change
% 
%     methods
% 
%         function sliderEditfieldValueChanged(obj, source, ~)
%             obj.Value(source.UserData) = source.Value;
%         end
% 
%         function valueChanged(obj, ~, ~)
%             notify(obj,'ValueChanged');
%         end
% 
%     end
% 
%     %% Hub-facing event handlers
% 
%     methods
% 
%         function tf = matches(obj, tgt, ~, ~)
%             tf = (obj.sliderThumbAxes == ancestor(tgt, 'matlab.ui.control.UIAxes'));
%         end
% 
%         function onDown(obj, ~, tgt)
% 
%             if isprop(tgt, 'ID')
%                 thumbIdx = tgt.ID;
%             else
%                 cursorX = obj.sliderThumbAxes.CurrentPoint(1,1);
%                 [~, thumbIdx] = min(abs(obj.Value - cursorX));
%             end
% 
%             obj.selectThumb(thumbIdx);
%             obj.isSliding = true;
%             obj.moveActiveThumbToCursor();
%         end
% 
%         function onMove(obj, ~, tgt)
%             if obj.isSliding
%                 obj.moveActiveThumbToCursor();
%             else
%                 obj.handleHover(tgt);
%             end
%         end
% 
%         function onUp(obj, ~, ~)
%             % Stop sliding and restore states
%             obj.isSliding = false;
% 
%             % Deselect the active thumb (return to default size)
%             if ~isnan(obj.activeThumbIdx)
%                 obj.sliderThumb(obj.activeThumbIdx).deselect();
%             end
%             obj.activeThumbIdx = NaN;
% 
%             % Clear hover so nothing stays enlarged after release
%             obj.clearHover();
%         end
% 
%         function onScroll(~, ~, ~)
%             % No scroll behavior
%         end
% 
%         function onEnter(obj, ~, ~)
%             obj.parentFig.Pointer = 'hand';
%         end
% 
%         function onLeave(obj, ~, ~)
%             obj.clearHover();
%             obj.parentFig.Pointer = 'arrow';
%         end
% 
%     end
% 
%     methods (Static)
% 
%         function [V,F,C] = getRangePatchTemplate()
% 
%             cmap = gray(256);
% 
%             % X and Y coordinates of each vertex along the bottom of colorbar (left to right)
%             bottomX = linspace(0, 1, 256).';
%             Vx = [bottomX;flipud(bottomX)];
% 
%             Vy = [zeros(256,1);ones(256,1)];
% 
%             V = [Vx, Vy];
%             F = 1:512;
%             C = vertcat(cmap, flipud(cmap));
%         end
% 
% 
%         function V = getRangePatchBaseVertices()
% 
%             % X and Y coordinates of each vertex along the bottom of colorbar (left to right)
%             bottomX = linspace(0, 1, 256).';
%             Vx = [bottomX;flipud(bottomX)];
% 
%             Vy = [zeros(256,1);ones(256,1)];
% 
%             V = [Vx, Vy];
%         end
% 
%         function V = getTrackPatchBaseVertices()
%             % Vertices template for track patch
%             V = [0 0; 0.5 0; 1 0; 1 1; 0.5 1; 1 1];
%         end
% 
% 
% 
% 
%         function s = demo()
% 
%             fig = uifigure(...
%                 "WindowStyle","alwaysontop",...
%                 "InnerPosition",[100,100,510,615],...
%                 "Color",[0 0 0]);
% 
%             g = uigridlayout(fig,[2,1],...
%                 "BackgroundColor",[0 0 0],...
%                 "ColumnWidth",{500},...
%                 "RowHeight",{500,'fit'},...
%                 "Padding",[5 5 5 5],...
%                 "RowSpacing",5);
% 
%             I = im2double(imread("rice.png"));
% 
%             % I = imresize(I,5);
% 
%             ax = widgets.ImageAxes(g,"CData",I);
% 
%             s = widgets.uirangeslidereditfield(g,...
%                 "Title",'Adjust CLim',...
%                 "FontColor",[1 1 1],...
%                 "Limits",getrangefromclass(I),...
%                 "Value",[min(I(:)) max(I(:))],...
%                 "Colormap",ax.Colormap,...
%                 "ValueChangedFcn",@(o,~) set(ax,'CLim',o.Value));
% 
%         end
% 
%     end
% 
% end

classdef uirangeslidereditfield < matlab.ui.componentcontainer.ComponentContainer

    %% Public API

    properties
        % flag to determine whether values are rounded
        RoundValues (1,1) matlab.lang.OnOffSwitchState = 'off'
        % number of digits used for rounding 
        %   N > 0: round to N digits to the right of the decimal point.
        %   N = 0: round to the nearest integer.
        %   N < 0: round to N digits to the left of the decimal point.
        RoundDigits (1,1) double = 0
    end


    % dependent public properties with private backing
    properties(Dependent=true)
        % format specifier for numeric editfields
        ValueDisplayFormat (1,:) char
        % text displayed above the slider
        Title (1,:) char
        % size of the font
        FontSize (1,1) double
        % color of the font
        FontColor (1,3) double
    end

    % private backing for above
    properties(Access=private)
        ValueDisplayFormat_ (1,:) char = '%d'
        % text displayed above the slider
        Title_ (1,:) char = "Untitled slider"
        % size of the font
        FontSize_ (1,1) double = 12
        % color of the font
        FontColor_ (1,3) double = [0 0 0]
    end

    properties(SetObservable=true,Dependent=true)
        Value (1,2) double = [0,1]
    end


    % properties we want property-based, minimal updates for
    properties(SetObservable, AbortSet)
        % min and max of the slider track
        Limits double = [0,1]

        % color of the thumb faces
        ThumbFaceColor (1,3) double {mustBeInRange(ThumbFaceColor,0,1)} = [1 1 1]
        % color of the thumb edges
        ThumbEdgeColor (1,3) double {mustBeInRange(ThumbEdgeColor,0,1)} = [0 0 0]

        % height of the track
        TrackHeight (1,1) double = 4
        % overall height of the slider component (excluding labels)
        Height (1,1) double = 25

        % color of the track patch face
        TrackColor (1,3) double = [0 0 0]
        % color of the track patch edge
        TrackEdgeColor (1,3) double = [1 1 1]

    end

    properties(Dependent=true)
        ComponentHeight
    end




    properties(Access=private)
        % true if the slider is currently moving
        isSliding (1,1) logical = false
        % index of the active thumb (1 or 2, NaN if none)
        activeThumbIdx (1,1) double = NaN
        % index of thumb currently hovered (1 or 2, NaN if none)
        hoverThumbIdx double = NaN
        % flag to help coalesce updates
        pendingUpdate (1,1) logical = false
        % helpers for patch coordinates
        trackV = [0 0; 1 0; 1 1; 1 1]
        trackF = [1,2,3,4]

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
        % the slider thumbs (lower=1, upper=2)
        sliderThumb (:,1) widgets.sliderthumb
        % editfields for text control of slider values [low high]
        sliderValueEditField (:,1) matlab.ui.control.NumericEditField

        % PostSet listener for the slider value
        sliderValueListener event.listener

        % listeners for property-based updates (ThumbFaceColor, etc.)
        L event.listener = event.listener.empty
    end

    %% Hub registration

    properties(Access=private)
        Hub app.FigureEventHub
        RouterId double = NaN
    end

    %% private helpers
    properties
        inCallback (1,1) logical = false
        inStartup (1,1) logical = true
    end

    %% Events

    events (HasCallbackProperty, NotifyAccess = protected)
        ValueChanging   % ValueChangingFcn callback property will be generated
        ValueChanged    % ValueChangedFcn callback property will be generated
    end

    %% ComponentContainer lifecycle

    methods(Access=protected)

        function setup(obj)

            % obj.Units    = "normalized";
            % obj.Position = [0 0 1 1];

            % % grid layout manager to enclose all the components
            % obj.containerGrid = uigridlayout(obj,...
            %     [1,3],...
            %     "ColumnWidth",{'1x',50,50},...
            %     "RowHeight",{'fit',obj.Height},...
            %     "BackgroundColor",[0 0 0],...
            %     "Padding",[5 5 5 5],...
            %     "Scrollable","on",...
            %     "RowSpacing",0);

            % obj.BusyAction = "queue";
            % obj.Interruptible = "on";


            % grid layout manager to enclose all the components
            obj.containerGrid = uigridlayout(obj,...
                [1,3],...
                "ColumnWidth",{'1x',50,50},...
                "RowHeight",{obj.Height,obj.Height},...
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
                'FaceVertexCData',obj.TrackColor,...
                'EdgeColor',obj.TrackEdgeColor,...
                'FaceColor','flat',...
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

            % editfields for numeric control
            obj.sliderValueEditField(1) = uieditfield(obj.containerGrid,"numeric",...
                'Limits',obj.Limits,...
                'Value',obj.Limits(1),...
                'ValueChangedFcn',@(o,e) obj.sliderEditfieldValueChanged(o,e),...
                'UserData',1,...
                'ValueDisplayFormat',obj.ValueDisplayFormat);
            obj.sliderValueEditField(1).Layout.Row    = 2;
            obj.sliderValueEditField(1).Layout.Column = 2;

            obj.sliderValueEditField(2) = uieditfield(obj.containerGrid,"numeric",...
                'Limits',obj.Limits,...
                'Value',obj.Limits(2),...
                'ValueChangedFcn',@(o,e) obj.sliderEditfieldValueChanged(o,e),...
                'UserData',2,...
                'ValueDisplayFormat',obj.ValueDisplayFormat);
            obj.sliderValueEditField(2).Layout.Row    = 2;
            obj.sliderValueEditField(2).Layout.Column = 3;

            % Register with FigureEventHub
            obj.Hub = app.FigureEventHub.ensure(obj.parentFig);
            obj.RouterId = obj.Hub.register(obj, ...
                'Priority', 10, ...
                'CaptureDuringDrag', true);

            obj.updateTrackPatch();
            obj.onColorsChanged();
            obj.onDimensionsChanged();

            % set SizeChangedFcn so we can force visual update upon resizing (AutoResizeChildren of parent must be Off)
            obj.SizeChangedFcn = @(~,~) obj.queueSizeUpdate();

            % property-based listeners for granular updates
            obj.L(end+1) = addlistener(obj,{'TrackColor','TrackEdgeColor'},'PostSet',@(~,~)obj.updateTrackPatchColors());
            obj.L(end+1) = addlistener(obj,{'BackgroundColor','ThumbFaceColor','ThumbEdgeColor'},'PostSet',@(~,~)obj.onColorsChanged());
            obj.L(end+1) = addlistener(obj,{'TrackHeight','Height'},'PostSet',@(~,~)obj.onDimensionsChanged());
            obj.L(end+1) = addlistener(obj,'Limits','PostSet',@(~,~)obj.onLimitsChanged());


            % listener for Value to enable the ValueChanged callback
            obj.sliderValueListener = addlistener(...
                obj,'Value',...
                'PostSet',@obj.onValueChanging);

        end

        function update(obj)
            if obj.inStartup
                obj.updateEditfieldLimits();
                obj.inStartup = false;
            end
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

        function updateTrackPatch(obj)
            % full update of Vertices, Faces, and FaceVertexCData

            sliderLimits = obj.Limits;

            % x values
            lo  = sliderLimits(1);
            hi = sliderLimits(2);

            V = obj.trackV; % base track Vertices template
            % adjust X coordinates of Vertices
            V(:,1) = [lo; hi; hi; lo];
            % adjust Y coordinates of Vertices
            V(1:2,2) = 0.5*(obj.Height - obj.TrackHeight);
            V(3:end,2) = 0.5*(obj.Height + obj.TrackHeight);

            set(obj.trackPatch, ...
                "Vertices", V, ...
                "Faces",    [1,2,3,4], ...
                "FaceVertexCData", obj.TrackColor);
        end

        % function updateTrackPatchVx(obj)
        %     sliderLimits = obj.Limits;
        %     % x values
        %     loLim  = sliderLimits(1);
        %     hiLim = sliderLimits(2);
        %     % update of Vertex X coordinates only
        %     obj.trackPatch.Vertices(:,1) = [loLim; hiLim; hiLim; loLim];
        % end

        function updateTrackPatchColors(obj)

            obj.TrackPatch.FaceVertexCData = obj.TrackColor;

        end

        function updatePatchVx(obj)
            % x values used to calculate track patch coordinates
            sliderLimits = obj.Limits;
            loLim  = sliderLimits(1);
            hiLim = sliderLimits(2);
            % update of Vertex X coordinates only
            obj.trackPatch.Vertices(:,1) = [loLim; hiLim; hiLim; loLim];
        end

        function onColorsChanged(obj)
            % Only update thumb colors when ThumbFaceColor/ThumbEdgeColor change
            obj.containerGrid.BackgroundColor = obj.BackgroundColor;
            obj.sliderThumb(1).FaceColor = obj.ThumbFaceColor;
            obj.sliderThumb(2).FaceColor = obj.ThumbFaceColor;
            obj.sliderThumb(1).EdgeColor = obj.ThumbEdgeColor;
            obj.sliderThumb(2).EdgeColor = obj.ThumbEdgeColor;
        end

        function onColormapChanged(obj)
            % Only recompute FaceVertexCData of patches when colormap changes
            if isvalid(obj.trackPatch)
                set(obj.trackPatch,"FaceVertexCData",obj.TrackColor);
            end
        end

        function onDimensionsChanged(obj)
            % Set row height for labels row
            obj.containerGrid.RowHeight{1} = obj.Height;

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

        end

        function onLimitsChanged(obj)

            % Adjust axes XLim
            obj.sliderThumbAxes.XLim = obj.Limits;

            % adjust track patch coordinates
            obj.updatePatchVx();

            % Ensure thumbs are within Limits
            % obj.sliderThumb(1).Value = max(obj.sliderThumb(1).Value, obj.Limits(1));
            % obj.sliderThumb(2).Value = min(obj.sliderThumb(2).Value, obj.Limits(2));

            obj.sliderThumb(1).Value = clip(obj.sliderThumb(1).Value, obj.Limits(1), obj.Limits(2));
            obj.sliderThumb(2).Value = clip(obj.sliderThumb(2).Value, obj.Limits(1), obj.Limits(2));


            % Update editfield limits based on current thumbs
            obj.updateEditfieldLimits();

        end

        function updateEditfieldLimits(obj)
            % Update editfield limits based on current thumbs
            obj.sliderValueEditField(1).Limits = [obj.Limits(1) obj.sliderThumb(2).Value];
            obj.sliderValueEditField(2).Limits = [obj.sliderThumb(1).Value obj.Limits(2)];
        end

        function selectThumb(obj, thumbIdx)
            % deselect other if it exists
            if ~isnan(obj.activeThumbIdx)
                obj.sliderThumb(obj.activeThumbIdx).deselect();
            end

            obj.activeThumbIdx = thumbIdx;
            obj.sliderThumb(thumbIdx).select();
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

            if isprop(tgt, 'ID')
                idx = tgt.ID;
            else
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
            if isnan(obj.activeThumbIdx), return; end

            thumbLims = obj.sliderValueEditField(obj.activeThumbIdx).Limits;

            obj.Value(obj.activeThumbIdx) = clip(obj.sliderThumbAxes.CurrentPoint(1,1),thumbLims(1),thumbLims(2));


            % oldVal = obj.LastValueSet(obj.activeThumbIdx);
            % newVal = clip(obj.sliderThumbAxes.CurrentPoint(1,1),thumbLims(1),thumbLims(2));
            % 
            % StepPct = 0.01;
            % Step = StepPct*abs(diff(obj.Limits));
            % 
            % if abs(diff([oldVal,newVal])) < Step
            %     obj.sliderThumb(obj.activeThumbIdx).Value = newVal;
            % else
            %     obj.Value(obj.activeThumbIdx) = newVal;
            % end
        end

    end

    %% Dependent Set/Get

    methods

        function Value = get.Value(obj)
            Value = [obj.sliderThumb(1).Value, obj.sliderThumb(2).Value];
        end

        function set.Value(obj, val)
            % if isequal(val,[obj.sliderThumb(1).Value, obj.sliderThumb(2).Value])
            %     warning('redudnant set')
            % end


            if obj.inCallback
                warning('callback overlap')
            end
            obj.inCallback = true;

            if obj.RoundValues
                val = round(val,obj.RoundDigits);
            end

            % lims = obj.Limits;
            % lo = lims(1);
            % hi = lims(2);
            % 
            % % val = clip(sort(val),lo,hi);
            % val = clip(val,lo,hi);
            % 
            % % update thumbs
            % obj.sliderThumb(1).Value = val(1);
            % obj.sliderThumb(2).Value = val(2);

            lims1 = obj.sliderValueEditField(1).Limits;
            lims2 = obj.sliderValueEditField(2).Limits;

            val(1) = clip(val(1),lims1(1),lims1(2));
            val(2) = clip(val(2),lims2(1),lims2(2));

            % update thumbs
            obj.sliderThumb(1).Value = val(1);
            obj.sliderThumb(2).Value = val(2);




            % update editfield values
            obj.sliderValueEditField(1).Value  = val(1);
            obj.sliderValueEditField(2).Value  = val(2);

            % indicate callback is completed
            obj.inCallback = false;
        end

        function parentFig = get.parentFig(obj)
            parentFig = ancestor(obj,'figure','toplevel');
        end

        function H = get.ComponentHeight(obj)
            % H = ceil(obj.Height + obj.titleLabel.Position(4) + 10);
            % H = ceil(obj.Height + obj.FontSize*1.4 + 10);

            H = obj.Height*2 + 10 + 1;
        end


        function val = get.ValueDisplayFormat(obj)
            val = obj.ValueDisplayFormat_;
        end

        function set.ValueDisplayFormat(obj,val)
            set(obj.sliderValueEditField,'ValueDisplayFormat',val);
        end

        function val = get.Title(obj)
            val = obj.Title_;
        end

        function set.Title(obj,val)
            obj.titleLabel.Text = val;
            obj.Title_ = val;
        end


        function val = get.FontSize(obj)
            val = obj.FontSize_;
        end

        function set.FontSize(obj,val)
            set([obj.titleLabel,obj.minLabel,obj.maxLabel],...
                "FontSize",val);
            obj.FontSize_ = val;
        end


        function val = get.FontColor(obj)
            val = obj.FontColor_;
        end

        function set.FontColor(obj,val)
            set([obj.titleLabel,obj.minLabel,obj.maxLabel],...
                "FontColor",val);
            obj.FontColor_ = val;
        end

    end

    %% Callbacks / Value change

    methods

        function sliderEditfieldValueChanged(obj, source, ~)
            obj.Value(source.UserData) = source.Value;
        end

        function onValueChanging(obj, ~, ~)
            notify(obj,'ValueChanging');
        end

        function onValueChanged(obj, ~, ~)
            notify(obj,'ValueChanged');
        end


    end

    %% Hub-facing event handlers

    methods

        function tf = matches(obj, tgt, ~, ~)
            tf = (obj.sliderThumbAxes == ancestor(tgt, 'matlab.ui.control.UIAxes'));
        end

        function onDown(obj, ~, tgt)

            if isprop(tgt, 'ID')
                thumbIdx = tgt.ID;
            else
                cursorX = obj.sliderThumbAxes.CurrentPoint(1,1);
                [~, thumbIdx] = min(abs(obj.Value - cursorX));
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

            % Update limits
            obj.updateEditfieldLimits();

            % emit ValueChanged
            obj.onValueChanged();
        end

        function onScroll(~, ~, ~)
            % No scroll behavior
        end

        function onEnter(obj, ~, ~)
            obj.parentFig.Pointer = 'hand';
        end

        function onLeave(obj, ~, ~)
            obj.clearHover();
            obj.parentFig.Pointer = 'arrow';
        end

    end

    methods (Static)

        function s = demo()

            fig = uifigure(...
                "WindowStyle","alwaysontop",...
                "InnerPosition",[100,100,510,110],...
                "Color",[0 0 0]);

            g = uigridlayout(fig,[1,1],...
                "BackgroundColor",[0 0 0],...
                "ColumnWidth",{500},...
                "RowHeight",{'fit'},...
                "Padding",[5 5 5 5],...
                "RowSpacing",5);

            s = widgets.uirangeslidereditfield(g,...
                "Title",'Adjust CLim',...
                "FontColor",[1 1 1],...
                "Limits",[0 1],...
                "Value",[0 1],...
                "TrackColor",[0 0 0],...
                "FontSize",12);

            fig.InnerPosition(4) = s.ComponentHeight + 10;

            % s = uislider(g,...
            %     "range",...
            %     "Limits",getrangefromclass(I),...
            %     "Value",[min(I(:)) max(I(:))],...
            %     "ValueChangedFcn",@(o,~) set(ax,'CLim',o.Value),...
            %     "ValueChangingFcn",@(~,e) set(ax,'CLim',e.Value));

        end

        function s = demo2()

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

            I = imresize(I,5);

            ax = widgets.ImageAxes(g,"CData",I);

            s = widgets.uirangeslidereditfield(g,...
                "Title",'Adjust CLim',...
                "FontColor",[1 1 1],...
                "Limits",[0 1],...
                "Value",[min(I(:)) max(I(:))],...
                "RoundValues","on",...
                "RoundDigits",2,...
                "ValueDisplayFormat",'%.2f',...
                "TrackColor",[0 0 0],...
                "ValueChangingFcn",@(o,~) setCLimDuringSlide(o),...
                "ValueChangedFcn",@(o,~) setCLim(o));


            function setCLimDuringSlide(src)
                maxChange = max(abs(ax.CLim-src.Value));

                if maxChange > 0.025
                    set(ax,'CLim',src.Value)
                    %drawnow limitrate nocallbacks
                else
                    return
                end
            end

            function setCLim(src)
                set(ax,'CLim',src.Value)
            end


            % s = uislider(g,...
            %     "range",...
            %     "Limits",getrangefromclass(I),...
            %     "Value",[min(I(:)) max(I(:))],...
            %     "ValueChangedFcn",@(o,~) setCLim(o),...
            %     "ValueChangingFcn",@(~,e) setCLimDuringSlide(e));

        end


        function s = demo3()

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

            ax = uiaxes(g,...
                "Visible","off");

            I = im2double(imread("rice.png"));
            I = imresize(I,5);

            img = imshow(I,"Parent",ax);

            ax.PlotBoxAspectRatio = [1 1 1];
            ax.DataAspectRatio = [1 1 1];
            ax.XLim = [0 size(I,2)]+0.5;
            ax.YLim = [0 size(I,1)]+0.5;

            s = widgets.uirangeslidereditfield(g,...
                "Title",'Adjust CLim',...
                "FontColor",[1 1 1],...
                "Limits",[0 1],...
                "Value",[min(I(:)) max(I(:))],...
                "RoundValues","on",...
                "RoundDigits",2,...
                "ValueDisplayFormat",'%.2f',...
                "TrackColor",[0 0 0],...
                "ValueChangingFcn",@(o,~) setCLimDuringSlide(o),...
                "ValueChangedFcn",@(o,~) setCLim(o));

            function setCLimDuringSlide(src)
                maxChange = max(abs(ax.CLim-src.Value));

                if maxChange > 0.025
                    set(ax,'CLim',src.Value)
                    drawnow limitrate nocallbacks
                else
                    return
                end
            end

            function setCLim(src)
                set(ax,'CLim',src.Value)
            end


        end







    end
    
end
