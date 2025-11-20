% classdef uirangeslidereditfield < matlab.ui.componentcontainer.ComponentContainer
% 
%     properties
%         % min and max of the slider track
%         Limits double = [0,1]
%         % height of the track
%         TrackHeight (1,1) double = 4
%         % height of the range
%         RangeHeight (1,1) double = 7
%         % overall height of the slider component (excluding labels)
%         Height (1,1) double = 25
%         % flag to determine whether fractional values are rounded
%         RoundFractionalValues (1,1) matlab.lang.OnOffSwitchState = 'off'
%         % color of the thumb faces
%         ThumbFaceColor (1,3) double {mustBeInRange(ThumbFaceColor,0,1)} = [1 1 1]
%         % color of the thumb edges
%         ThumbEdgeColor (1,3) double {mustBeInRange(ThumbEdgeColor,0,1)} = [0 0 0]
%         % track colormap
%         Colormap (256,3) double = gray
% 
%         % text displayed above the slider
%         Title (1,:) char = "Untitled slider"
%         % size of the font
%         FontSize (1,1) double = 12
%         % color of the font
%         FontColor (1,3) double = [0 0 0]
%     end
% 
%     properties(SetAccess=private)
%         % true if the slider is currently moving
%         isSliding (1,1) logical = false
%         % index of the active thumb
%         activeThumbIdx (1,1) = NaN
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
%         % axes to hold slider thumb
%         sliderThumbAxes (1,1) matlab.ui.control.UIAxes
%         % patch object for slider track
%         trackPatch (1,1) matlab.graphics.primitive.Patch
%         % patch object for slider range
%         rangePatch (1,1) matlab.graphics.primitive.Patch
%         % the slider thumb
%         sliderThumb (:,1) widgets.sliderthumb
%         % editfield for text control of slider value
%         sliderValueEditField (:,1) matlab.ui.control.NumericEditField
% 
%         % PostSet listener for the slider value
%         sliderValueListener (1,1)
%         % context menu for the thumb
%         thumbCM (:,1)
%     end
% 
%     events (HasCallbackProperty, NotifyAccess = protected)
%         ValueChanged % ValueChangedFcn callback property will be generated
%     end
% 
%     methods(Access=protected)
% 
%         function setup(obj)
% 
%             obj.Units = "normalized";
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
%             % uilabel to diaply the title text
%             obj.titleLabel = uilabel(obj.containerGrid,...
%                 "Text",obj.Title,...
%                 "FontColor",obj.FontColor,...
%                 "FontSize",obj.FontSize);
%             obj.titleLabel.Layout.Row = 1;
%             obj.titleLabel.Layout.Column = 1;
% 
%             % uilabel for the minimum value editfield
%             obj.minLabel = uilabel(obj.containerGrid,...
%                 "Text","Min",...
%                 "FontColor",obj.FontColor,...
%                 "FontSize",obj.FontSize);
%             obj.minLabel.Layout.Row = 1;
%             obj.minLabel.Layout.Column = 2;
% 
%             % uilabel for the maximum value editfield
%             obj.maxLabel = uilabel(obj.containerGrid,...
%                 "Text","Max",...
%                 "FontColor",obj.FontColor,...
%                 "FontSize",obj.FontSize);
%             obj.maxLabel.Layout.Row = 1;
%             obj.maxLabel.Layout.Column = 3;
% 
%             % axes to hold the slider thumb
%             obj.sliderThumbAxes = uiaxes(obj.containerGrid,...
%                 'XTick',[],...
%                 'YTick',[],...
%                 'XLim',obj.Limits,...
%                 'YLim',[0 obj.Height],...
%                 'XColor','none',...
%                 'YColor','none',...
%                 'Color','none',...
%                 'Units','Normalized',...
%                 'InnerPosition',[0 0 1 1],...
%                 'LineWidth',1,...
%                 'Box','off',...
%                 'HitTest','on',...
%                 'PickableParts','all',...
%                 'Visible','off',...
%                 'ButtonDownFcn',@(o,e) obj.trackClicked(o,e));
%             obj.sliderThumbAxes.Layout.Row =  2;
%             obj.sliderThumbAxes.Layout.Column =  1;
%             obj.sliderThumbAxes.Toolbar.Visible = 'off';
%             disableDefaultInteractivity(obj.sliderThumbAxes)
% 
%             % create the patch object for the track
%             obj.trackPatch = patch(obj.sliderThumbAxes,...
%                 'Faces',[1,2,3,4],...
%                 'Vertices',[0,0;1,0;1,1;0,1],...
%                 'EdgeColor',[0 0 0],...
%                 'FaceColor','flat',...
%                 'PickableParts','none',...
%                 'HitTest','off',...
%                 'LineWidth',0.5);
% 
%             % create the patch object for the range
%             obj.rangePatch = patch(obj.sliderThumbAxes,...
%                 'Faces',[1,2,3,4],...
%                 'Vertices',[0,0;1,0;1,1;0,1],...
%                 'EdgeColor',[0 0 0],...
%                 'FaceColor','interp',...
%                 'PickableParts','none',...
%                 'HitTest','off',...
%                 'LineWidth',0.5);
% 
%             % create the lower value thumb
%             obj.sliderThumb(1) = widgets.sliderthumb(obj.sliderThumbAxes,...
%                 "EdgeColor",obj.ThumbEdgeColor,...
%                 "FaceColor",obj.ThumbFaceColor,...
%                 "Value",0,...
%                 "YPosition",0.5*obj.Height,...
%                 "ButtonDownFcn",@(o,e) obj.thumbClicked(o,e),...
%                 "ID",1,...
%                 "EdgeWidth",0.5);
% 
%             % create the upper value thumb
%             obj.sliderThumb(2) = widgets.sliderthumb(obj.sliderThumbAxes,...
%                 "EdgeColor",obj.ThumbEdgeColor,...
%                 "FaceColor",obj.ThumbFaceColor,...
%                 "Value",1,...
%                 "YPosition",0.5*obj.Height,...
%                 "ButtonDownFcn",@(o,e) obj.thumbClicked(o,e),...
%                 "ID",2,...
%                 "EdgeWidth",0.5);
% 
%             % set up listener for Value to enable the ValueChanged callback
%             obj.sliderValueListener = addlistener(...
%                 obj,'Value',...
%                 'PostSet',@obj.valueChanged);
% 
%             % editfield for text input control of low slider value
%             obj.sliderValueEditField(1) = uieditfield(obj.containerGrid,"numeric",...
%                 'Limits',obj.Limits,...
%                 'Value',obj.Value(1),...
%                 'ValueChangedFcn',@(o,e) obj.sliderEditfieldValueChanged(o,e),...
%                 'UserData',1);
%             obj.sliderValueEditField(1).Layout.Row = 2;
%             obj.sliderValueEditField(1).Layout.Column = 2;
% 
%             % editfield for text input control of high slider value
%             obj.sliderValueEditField(2) = uieditfield(obj.containerGrid,"numeric",...
%                 'Limits',obj.Limits,...
%                 'Value',obj.Value(2),...
%                 'ValueChangedFcn',@(o,e) obj.sliderEditfieldValueChanged(o,e),...
%                 'UserData',2);
%             obj.sliderValueEditField(2).Layout.Row = 2;
%             obj.sliderValueEditField(2).Layout.Column = 3;
% 
%         end
% 
%         function update(obj)
%             % set size of gridlayout manager row
%             obj.containerGrid.RowHeight{2} = obj.Height;
% 
%             % set size and color of font for labels
%             set([obj.titleLabel,obj.minLabel,obj.maxLabel],...
%                 "FontSize",obj.FontSize,...
%                 "FontColor",obj.FontColor);
% 
%             % update title label text
%             obj.titleLabel.Text = obj.Title;
% 
%             % set the limits of the slider axes
%             set(obj.sliderThumbAxes,'XLim',obj.Limits,'YLim',[0 obj.Height])
% 
%             % set vertical position of slider thumbs
%             obj.sliderThumb(1).YPosition = 0.5*obj.Height;
%             obj.sliderThumb(2).YPosition = 0.5*obj.Height;
%             % set the limits of the editfield
%             obj.sliderValueEditField(1).Limits = [obj.Limits(1) obj.sliderThumb(2).Value];
%             obj.sliderValueEditField(2).Limits = [obj.sliderThumb(1).Value obj.Limits(2)];
%             % set position of thumbs to fall within slider limits
%             obj.sliderThumb(1).Value = max(obj.sliderThumb(1).Value,obj.Limits(1));
%             obj.sliderThumb(2).Value = min(obj.sliderThumb(2).Value,obj.Limits(2)); 
%             % background color of the component
%             obj.containerGrid.BackgroundColor = obj.BackgroundColor;
% 
%             % adjust the coordinates of the track patch
%             [Vt,Ft,Ct] = obj.getTrackPatchData();
%             set(obj.trackPatch,...
%                 "Vertices",Vt,...
%                 "Faces",Ft,...
%                 "FaceVertexCData",Ct);
% 
%             % adjust the coordinates of the range patch
%             [Vr,Fr,Cr] = obj.getRangePatchData();
%             set(obj.rangePatch,...
%                 "Vertices",Vr,...
%                 "Faces",Fr,...
%                 "FaceVertexCData",Cr);
% 
%             % update thumb colors
%             obj.sliderThumb(1).FaceColor = obj.ThumbFaceColor;
%             obj.sliderThumb(2).FaceColor = obj.ThumbFaceColor;
%             obj.sliderThumb(1).EdgeColor = obj.ThumbEdgeColor;
%             obj.sliderThumb(2).EdgeColor = obj.ThumbEdgeColor;
%         end
% 
%     end
% 
% 
%     %% destructor
% 
%     methods
% 
%         function delete(obj)
% 
%             delete(obj.sliderValueListener)
% 
%         end
% 
%     end
% 
% 
%     %% update helpers
% 
%     methods
% 
% 
% 
% 
% 
%     end
% 
% 
% 
%     %% helper methods
% 
%     methods
% 
%         function [V,F,C] = getRangePatchData(obj)
%             % Vertices (V), Faces (F), and FaceVertexCData (C) for 
%             % the rectangular patch object showing the range
% 
%             sliderValue = obj.Value;
%             % X and Y coordinates of each vertex along the bottom of colorbar (left to right)
%             bottomX = (linspace(sliderValue(1),sliderValue(2),256)).';
%             bottomY = repmat(0.5*(obj.Height-obj.RangeHeight),size(bottomX));
%             % coordinates of each vertex along the top of colorbar (right to left)
%             topX = flipud(bottomX);
%             topY = bottomY + obj.RangeHeight;
%             % 512 total vertices, 256 on top, 256 on bottom (two vertices per color in the colormap)
%             V = [bottomX,bottomY;topX,topY];
%             % one face made of vertices around the rectangle border
%             F = 1:512;
%             % RGB triplets for each vertex, such that the color of the vertex at V(n,:) is C(n,:)
%             C = vertcat(obj.Colormap,flipud(obj.Colormap));
%         end
% 
%         function [V,F,C] = getTrackPatchData(obj)
%             % Vertices (V), Faces (F), and FaceVertexCData (C) for 
%             % the rectangular patch object showing the track
% 
%             sliderLimits = obj.Limits;
%             sliderValue = obj.Value;
%             % x values
%             leftX = sliderLimits(1);
%             rightX = sliderLimits(2);
%             midX = mean(sliderValue);
%             % y values
%             bottomY = 0.5*(obj.Height - obj.TrackHeight);
%             topY = bottomY + obj.TrackHeight;
%             % x and y vertices
%             Vx = [leftX;midX;rightX;rightX;midX;leftX];
%             Vy = [bottomY;bottomY;bottomY;topY;topY;topY];
%             % 256 total vertices, one per color in the colormap
%             V = [Vx,Vy];
%             % one face made of vertices around the rectangle border
%             F = [1,2,5,6;2,3,4,5];
%             % RGB triplets for each vertex, such that the color of the vertex at Vertices(n,:) is FaceVertexCData(n,:)
%             C = obj.Colormap([1,256],:);
%         end
% 
%     end
% 
%     methods
% 
%         function Value = get.Value(obj)
%             % get the component value based on the position of the slider thumb
%             Value = [obj.sliderThumb(1).Value,obj.sliderThumb(2).Value];
%         end
% 
%         function set.Value(obj,val)
% 
%             if obj.RoundFractionalValues
%                 val = round(val);
%             end
% 
%             v1 = val(1);
%             v2 = val(2);
% 
%             % set position of thumbs
%             obj.sliderThumb(1).Value = v1;
%             obj.sliderThumb(2).Value = v2;
% 
%             % set text shown in edit field (adjust limits first to avoid error)
%             obj.sliderValueEditField(1).Limits = [obj.Limits(1) obj.sliderThumb(2).Value];
%             obj.sliderValueEditField(2).Limits = [obj.sliderThumb(1).Value obj.Limits(2)];
%             obj.sliderValueEditField(1).Value = v1;
%             obj.sliderValueEditField(2).Value = v2;
% 
%         end
% 
%         function parentFig = get.parentFig(obj)
%             parentFig = ancestor(obj,'figure','toplevel');
%         end
% 
%     end
% 
%     %% callback methods
% 
%     methods
% 
%         % called when one of the sliding thumbs is clicked
%         function thumbClicked(obj,source,~)
%             % the index of the clicked thumb
%             thumbIdx = source.ID;
%             % select the thumb
%             obj.selectThumb(thumbIdx);
%             % set window callbacks
%             set(obj.parentFig,...
%                 "WindowButtonMotionFcn",@(o,e) obj.startSliding(o,e),...
%                 "WindowButtonUpFcn",@(o,e) obj.stopSliding(o,e));
%             % start sliding
%             obj.startSliding();
%         end
% 
%         % called when the track is clicked
%         function trackClicked(obj,source,~)
%             % get the x value of point clicked on the slider thumb axes
%             clickedPoint = source.CurrentPoint(1,1);
%             % find which thumb is closest to the point
%             [~,thumbIdx] = min(abs(obj.Value-clickedPoint));
%             % select the thumb
%             obj.selectThumb(thumbIdx);
%             % set window callbacks
%             set(obj.parentFig,...
%                 "WindowButtonMotionFcn",@(o,e) obj.startSliding(o,e),...
%                 "WindowButtonUpFcn",@(o,e) obj.stopSliding(o,e));
%             % start sliding
%             obj.startSliding();
%         end
% 
%         function startSliding(obj,~,~)
%             % set status flag to indicate slider is active
%             obj.isSliding = true;
%             % get limits for the currently sliding thumb
%             if obj.activeThumbIdx == 1
%                 thumbLims = [obj.Limits(1) obj.sliderThumb(2).Value];
%             else
%                 thumbLims = [obj.sliderThumb(1).Value obj.Limits(2)];
%             end
%             % get the x value of the cursor position on the slider track
%             cursorX = obj.sliderThumbAxes.CurrentPoint(1,1);
%             % set the element of the component Value corresponding to the active thumb
%             obj.Value(obj.activeThumbIdx) = min(max(cursorX,thumbLims(1)),thumbLims(2));
%         end
% 
%         function stopSliding(obj,~,~)
%             % remove WindowButtonMotionFcn and WindowButtonUpFcn callbacks 
%             obj.parentFig.WindowButtonMotionFcn = '';
%             obj.parentFig.WindowButtonUpFcn = '';
%             % restore status flag to indicate slider is no longer active
%             obj.isSliding = false;
%             % deselect the thumb
%             obj.sliderThumb(obj.activeThumbIdx).deselect;
%         end
% 
%         function sliderEditfieldValueChanged(obj,source,~)
%             % set component value
%             obj.Value(source.UserData) = source.Value;
%         end  
% 
%         function valueChanged(obj,~,~)
%             % notify object that slider value has changed - ValueChangedFcn will be called
%             notify(obj,'ValueChanged');
%         end
% 
%         function selectThumb(obj,thumbPosition)
%             % set the active thumb idx
%             obj.activeThumbIdx = thumbPosition;
%             % select the corresponding thumb
%             obj.sliderThumb(obj.activeThumbIdx).select();
%         end
% 
%     end
% 
% end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% classdef uirangeslidereditfield < matlab.ui.componentcontainer.ComponentContainer
% 
%     %% Public API
% 
%     properties
%         % min and max of the slider track
%         Limits double = [0,1]
% 
%         % height of the track
%         TrackHeight (1,1) double = 4
% 
%         % height of the range
%         RangeHeight (1,1) double = 7
% 
%         % overall height of the slider component (excluding labels)
%         Height (1,1) double = 25
% 
%         % flag to determine whether fractional values are rounded
%         RoundFractionalValues (1,1) matlab.lang.OnOffSwitchState = 'off'
% 
%         % color of the thumb faces
%         ThumbFaceColor (1,3) double {mustBeInRange(ThumbFaceColor,0,1)} = [1 1 1]
% 
%         % color of the thumb edges
%         ThumbEdgeColor (1,3) double {mustBeInRange(ThumbEdgeColor,0,1)} = [0 0 0]
% 
%         % track colormap
%         Colormap (256,3) double = gray
% 
%         % text displayed above the slider
%         Title (1,:) char = "Untitled slider"
% 
%         % size of the font
%         FontSize (1,1) double = 12
% 
%         % color of the font
%         FontColor (1,3) double = [0 0 0]
%     end
% 
%     properties(SetAccess=private)
%         % true if the slider is currently moving
%         isSliding (1,1) logical = false
%         % index of the active thumb (1 or 2, NaN if none)
%         activeThumbIdx (1,1) double = NaN
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
%         sliderValueListener (1,1)
%     end
% 
%     %% Hub registration
% 
%     properties(Access=private)
%         Hub app.FigureEventHub
%         RouterId double = NaN
% 
%         % index of thumb currently hovered (1 or 2, NaN if none)
%         hoverThumbIdx double = NaN
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
%                 'Faces',1:4,...  % will be updated to the correct topology
%                 'Vertices',[0,0;1,0;1,1;0,1],...
%                 'EdgeColor',[0 0 0],...
%                 'FaceColor','interp',...
%                 'PickableParts','none',...
%                 'HitTest','off',...
%                 'LineWidth',0.5);
% 
%             % create the lower value thumb
%             obj.sliderThumb(1) = widgets.sliderthumb(obj.sliderThumbAxes,...
%                 "EdgeColor",obj.ThumbEdgeColor,...
%                 "FaceColor",obj.ThumbFaceColor,...
%                 "Value",obj.Limits(1),...
%                 "YPosition",0.5*obj.Height,...
%                 "ID",1,...
%                 "EdgeWidth",0.5);
% 
%             % create the upper value thumb
%             obj.sliderThumb(2) = widgets.sliderthumb(obj.sliderThumbAxes,...
%                 "EdgeColor",obj.ThumbEdgeColor,...
%                 "FaceColor",obj.ThumbFaceColor,...
%                 "Value",obj.Limits(2),...
%                 "YPosition",0.5*obj.Height,...
%                 "ID",2,...
%                 "EdgeWidth",0.5);
% 
%             % set up listener for Value to enable the ValueChanged callback
%             obj.sliderValueListener = addlistener(...
%                 obj,'Value',...
%                 'PostSet',@obj.valueChanged);
% 
%             % editfield for text input control of low slider value
%             obj.sliderValueEditField(1) = uieditfield(obj.containerGrid,"numeric",...
%                 'Limits',obj.Limits,...
%                 'Value',obj.Limits(1),...
%                 'ValueChangedFcn',@(o,e) obj.sliderEditfieldValueChanged(o,e),...
%                 'UserData',1);
%             obj.sliderValueEditField(1).Layout.Row    = 2;
%             obj.sliderValueEditField(1).Layout.Column = 2;
% 
%             % editfield for text input control of high slider value
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
%         end
% 
%         function update(obj)
%             fprintf('uirangeslidereditfield.update()\n')
%             % NOTE: update is called when non-dependent public properties change.
%             % We keep this focused on layout + appearance; Value-specific
%             % graphics are handled in set.Value.
% 
%             % Row height for slider row
%             obj.containerGrid.RowHeight{2} = obj.Height;
% 
%             % Labels appearance
%             set([obj.titleLabel,obj.minLabel,obj.maxLabel],...
%                 "FontSize",obj.FontSize,...
%                 "FontColor",obj.FontColor);
% 
%             % Label text
%             obj.titleLabel.Text = obj.Title;
% 
%             % Axes limits
%             obj.sliderThumbAxes.XLim = obj.Limits;
%             obj.sliderThumbAxes.YLim = [0 obj.Height];
% 
%             % Thumb Y position (centered vertically)
%             obj.sliderThumb(1).YPosition = 0.5 * obj.Height;
%             obj.sliderThumb(2).YPosition = 0.5 * obj.Height;
% 
%             % Background color of the component
%             obj.containerGrid.BackgroundColor = obj.BackgroundColor;
% 
%             % Update thumb colors
%             obj.sliderThumb(1).FaceColor = obj.ThumbFaceColor;
%             obj.sliderThumb(2).FaceColor = obj.ThumbFaceColor;
%             obj.sliderThumb(1).EdgeColor = obj.ThumbEdgeColor;
%             obj.sliderThumb(2).EdgeColor = obj.ThumbEdgeColor;
% 
%             % Update editfield limits based on current thumbs
%             lowVal  = obj.sliderThumb(1).Value;
%             highVal = obj.sliderThumb(2).Value;
%             obj.sliderValueEditField(1).Limits = [obj.Limits(1) highVal];
%             obj.sliderValueEditField(2).Limits = [lowVal obj.Limits(2)];
% 
%             % Ensure thumbs are within Limits
%             obj.sliderThumb(1).Value = max(obj.sliderThumb(1).Value, obj.Limits(1));
%             obj.sliderThumb(2).Value = min(obj.sliderThumb(2).Value, obj.Limits(2));
% 
%             % Update track and range patches (geometry + colormap)
%             obj.updateTrackPatch();
%             obj.updateRangePatch();
%         end
% 
%     end
% 
%     %% Destructor
% 
%     methods
% 
%         function delete(obj)
%             % remove listener
%             if ~isempty(obj.sliderValueListener) && isvalid(obj.sliderValueListener)
%                 delete(obj.sliderValueListener);
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
%     %% Helpers for patch data
% 
%     methods(Access=private)
% 
%         function updateRangePatch(obj)
%             % Vertices (V), Faces (F), and FaceVertexCData (C) for
%             % the rectangular patch object showing the selected range.
% 
%             sliderValue = obj.Value;
%             lowVal  = sliderValue(1);
%             highVal = sliderValue(2);
% 
%             % X and Y coordinates of each vertex along the bottom of colorbar (left to right)
%             bottomX = linspace(lowVal, highVal, 256).';
%             bottomY = repmat(0.5*(obj.Height-obj.RangeHeight), size(bottomX));
%             % coordinates of each vertex along the top of colorbar (right to left)
%             topX = flipud(bottomX);
%             topY = bottomY + obj.RangeHeight;
% 
%             % 512 total vertices, 256 on top, 256 on bottom
%             V = [bottomX,bottomY; topX,topY];
%             % one face made of vertices around the rectangle border
%             F = 1:512;
%             % RGB triplets for each vertex
%             C = vertcat(obj.Colormap, flipud(obj.Colormap));
% 
%             set(obj.rangePatch, ...
%                 "Vertices", V, ...
%                 "Faces",    F, ...
%                 "FaceVertexCData", C);
%         end
% 
%         function updateTrackPatch(obj)
%             % Vertices (V), Faces (F), and FaceVertexCData (C) for
%             % the rectangular patch object showing the full track.
% 
%             sliderLimits = obj.Limits;
%             sliderValue  = obj.Value;
% 
%             % x values
%             leftX  = sliderLimits(1);
%             rightX = sliderLimits(2);
%             midX   = mean(sliderValue);
% 
%             % y values
%             bottomY = 0.5*(obj.Height - obj.TrackHeight);
%             topY    = bottomY + obj.TrackHeight;
% 
%             % x and y vertices
%             Vx = [leftX; midX; rightX; rightX; midX; leftX];
%             Vy = [bottomY; bottomY; bottomY; topY; topY; topY];
% 
%             V = [Vx, Vy];
%             F = [1,2,5,6; 2,3,4,5];
% 
%             % simple two-color track using endpoints of colormap
%             C = obj.Colormap([1,256],:);
% 
%             set(obj.trackPatch, ...
%                 "Vertices", V, ...
%                 "Faces",    F, ...
%                 "FaceVertexCData", C);
%         end
% 
%         function idx = getThumbIndexFromTarget(obj, tgt)
%             % Determine if tgt is one of this slider's thumbs.
%             idx = NaN;
%             if ~isgraphics(tgt, "line")
%                 return;
%             end
%             % sliderthumb adds a dynamic "ID" property to the line
%             if isprop(tgt, 'ID')
%                 idVal = tgt.ID;
%                 if any(idVal == [1 2])
%                     idx = idVal;
%                 end
%             end
%         end
% 
%         function selectThumb(obj, thumbIdx)
%             obj.activeThumbIdx = thumbIdx;
%             % visually emphasize the active thumb
%             obj.sliderThumb(thumbIdx).select();
%             % optionally deselect the other thumb
%             otherIdx = setdiff(1:2, thumbIdx);
%             for k = otherIdx
%                 obj.sliderThumb(k).deselect();
%             end
%         end
% 
%         function clearHover(obj)
%             if ~isnan(obj.hoverThumbIdx)
%                 % return hovered thumb to normal size (unless it is active)
%                 if obj.hoverThumbIdx ~= obj.activeThumbIdx
%                     obj.sliderThumb(obj.hoverThumbIdx).deselect();
%                 end
%                 obj.hoverThumbIdx = NaN;
%             end
%         end
% 
%         function handleHover(obj, tgt)
%             % Only update hover when not sliding
%             if obj.isSliding
%                 return;
%             end
% 
%             idx = obj.getThumbIndexFromTarget(tgt);
% 
%             if isnan(idx)
%                 % no thumb under cursor
%                 if ~isnan(obj.hoverThumbIdx) && obj.hoverThumbIdx ~= obj.activeThumbIdx
%                     obj.sliderThumb(obj.hoverThumbIdx).deselect();
%                 end
%                 obj.hoverThumbIdx = NaN;
%                 return;
%             end
% 
%             % cursor over thumb idx
%             if idx ~= obj.hoverThumbIdx
%                 % new hover thumb
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
%             % Move the active thumb based on current cursor X position
% 
%             if isnan(obj.activeThumbIdx)
%                 return;
%             end
% 
%             cp = obj.sliderThumbAxes.CurrentPoint;
%             cursorX = cp(1,1);
% 
%             % Current values
%             vals = obj.Value;
%             lowVal  = vals(1);
%             highVal = vals(2);
% 
%             if obj.activeThumbIdx == 1
%                 % lower thumb: cannot go above upper thumb
%                 thumbLims = [obj.Limits(1), highVal];
%             else
%                 % upper thumb: cannot go below lower thumb
%                 thumbLims = [lowVal, obj.Limits(2)];
%             end
% 
%             newVal = min(max(cursorX, thumbLims(1)), thumbLims(2));
% 
%             % Round if needed (use public property semantics)
%             if obj.RoundFractionalValues
%                 newVal = round(newVal);
%             end
% 
%             vals(obj.activeThumbIdx) = newVal;
%             obj.Value = vals;  % triggers set.Value
%         end
% 
%     end
% 
%     %% Dependent property accessors
% 
%     methods
% 
%         function Value = get.Value(obj)
%             % get the component value based on the position of the slider thumbs
%             Value = [obj.sliderThumb(1).Value, obj.sliderThumb(2).Value];
%         end
% 
%         function set.Value(obj, val)
% 
%             % basic shape enforcement
%             validateattributes(val, {'numeric'}, {'vector','numel',2,'finite'});
% 
%             if obj.RoundFractionalValues
%                 val = round(val);
%             end
% 
%             v1 = val(1);
%             v2 = val(2);
% 
%             % clamp to Limits and enforce ordering
%             v1 = max(min(v1, obj.Limits(2)), obj.Limits(1));
%             v2 = max(min(v2, obj.Limits(2)), obj.Limits(1));
% 
%             if v1 > v2
%                 % swap to enforce v1 <= v2
%                 tmp = v1;
%                 v1  = v2;
%                 v2  = tmp;
%             end
% 
%             % set position of thumbs
%             obj.sliderThumb(1).Value = v1;
%             obj.sliderThumb(2).Value = v2;
% 
%             % set text shown in edit fields (adjust limits first to avoid error)
%             obj.sliderValueEditField(1).Limits = [obj.Limits(1) v2];
%             obj.sliderValueEditField(2).Limits = [v1 obj.Limits(2)];
%             obj.sliderValueEditField(1).Value  = v1;
%             obj.sliderValueEditField(2).Value  = v2;
% 
%             % Update patches that depend on Value
%             if isvalid(obj.rangePatch) && isvalid(obj.trackPatch)
%                 obj.updateTrackPatch();
%                 obj.updateRangePatch();
%             end
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
%             % set component value from editfield
%             vals = obj.Value;
%             idx  = source.UserData;
%             vals(idx) = source.Value;
%             obj.Value = vals;
%         end
% 
%         function valueChanged(obj, ~, ~)
%             % notify object that slider value has changed - ValueChangedFcn will be called
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
%             % Determine whether this instance should claim event from FigureEventHub
% 
%             tf = false;
%             if ~isvalid(obj)
%                 return;
%             end
% 
%             % skip toolbar buttons
%             if ~isempty(ancestor(tgt,'matlab.ui.container.Toolbar')) || ...
%                isa(tgt,'matlab.graphics.shape.internal.Button')
%                 return;
%             end
% 
%             % accept anything that belongs to this slider's axes
%             ax = ancestor(tgt, 'matlab.ui.control.UIAxes');
%             tf = (ax == obj.sliderThumbAxes);
%         end
% 
%         function onDown(obj, ~, tgt)
%             % Determine if a thumb or the track was clicked
% 
%             % pointer feedback
%             if isvalid(obj.parentFig)
%                 obj.parentFig.Pointer = 'hand';
%             end
% 
%             thumbIdx = obj.getThumbIndexFromTarget(tgt);
% 
%             if isnan(thumbIdx)
%                 % clicked somewhere on the track (axes)
%                 cp = obj.sliderThumbAxes.CurrentPoint;
%                 clickedX = cp(1,1);
%                 vals = obj.Value;
%                 [~, thumbIdx] = min(abs(vals - clickedX));
%             end
% 
%             % select the chosen thumb and start sliding
%             obj.selectThumb(thumbIdx);
%             obj.isSliding = true;
% 
%             % Snap immediately to clicked position
%             obj.moveActiveThumbToCursor();
%         end
% 
%         function onMove(obj, ~, tgt)
%             % Hover and drag behavior
% 
%             if obj.isSliding
%                 % active drag: move thumb based on cursor
%                 obj.moveActiveThumbToCursor();
%             else
%                 % hover behavior
%                 obj.handleHover(tgt);
%             end
% 
%             % pointer feedback while inside slider axes
%             if isvalid(obj.parentFig)
%                 obj.parentFig.Pointer = 'hand';
%             end
%         end
% 
%         function onUp(obj, ~, ~)
%             % Stop sliding and restore states
% 
%             obj.isSliding = false;
% 
%             % After mouse up, we keep activeThumbIdx set (so edit fields remain
%             % conceptually linked), but visually we can return to hover-based
%             % selection on the next move event.
% 
%             % We do NOT clear activeThumbIdx here; it is harmless to keep.
%         end
% 
%         function onScroll(obj, ~, ~)
%             % No scroll behavior for this control (by design)
%         end
% 
%         function onEnter(obj, ~, ~)
%             % pointer feedback on entering slider region
%             if isvalid(obj.parentFig)
%                 obj.parentFig.Pointer = 'hand';
%             end
%         end
% 
%         function onLeave(obj, ~, ~)
%             % clear hover and restore pointer
%             obj.clearHover();
%             if isvalid(obj.parentFig)
%                 obj.parentFig.Pointer = 'arrow';
%             end
%         end
% 
%     end
% 
% end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


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
