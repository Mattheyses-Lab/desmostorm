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

classdef ROI < handle
%ROI Appearance settings for the RegionViewer linescan ROI.

    properties (Access=private)
        % RGB color for ROI.
        ROIColor_ (1,3) double {mustBeInRange(ROIColor_,0,1)} = [1 1 1]
        % Stroke width in points for ROI.
        ROILineWidth_ (1,1) double {mustBePositive} = 1
        % Opacity of the linescan ROI fill.
        ROIFaceAlpha_ (1,1) double {mustBeInRange(ROIFaceAlpha_,0,1)} = 0
        % Marker size in points for the linescan ROI handles.
        ROIMarkerSize_ (1,1) double {mustBePositive} = 7
        % RGB color for annotation line.
        AnnotationLineColor_ (1,3) double {mustBeInRange(AnnotationLineColor_,0,1)} = [1 1 1]
        % Stroke width in points for annotation.
        AnnotationLineWidth_ (1,1) double {mustBePositive} = 0.5
        % Whether rotation angle is visible.
        RotationAngleVisible_ (1,1) matlab.lang.OnOffSwitchState = "on"
        % Mode used for rotation angle.
        RotationAngleMode_ (1,:) char {mustBeMember(RotationAngleMode_,{'full-circle','half-circle'})} = 'half-circle'
        % Font size used by this component.
        FontSize_ (1,1) double {mustBePositive} = 7
        % RGB color for font.
        FontColor_ (1,3) double {mustBeInRange(FontColor_,0,1)} = [1 1 1]
    end

    properties (Dependent)
        % RGB color for ROI.
        ROIColor
        % Stroke width in points for ROI.
        ROILineWidth
        % Opacity of the linescan ROI fill.
        ROIFaceAlpha
        % Marker size in points for the linescan ROI handles.
        ROIMarkerSize
        % RGB color for annotation line.
        AnnotationLineColor
        % Stroke width in points for annotation.
        AnnotationLineWidth
        % Whether rotation angle is visible.
        RotationAngleVisible
        % Mode used for rotation angle.
        RotationAngleMode
        % Font size used by this component.
        FontSize
        % RGB color for font.
        FontColor
    end

    events
        Changed
        ROIChanged
    end

    methods
        %GET.ROICOLOR Return the ROI color.
        function v = get.ROIColor(this),               v = this.ROIColor_;              end
        %GET.ROILINEWIDTH Return the ROI line width.
        function v = get.ROILineWidth(this),           v = this.ROILineWidth_;          end
        %GET.ROIFACEALPHA Return the ROI face alpha.
        function v = get.ROIFaceAlpha(this),           v = this.ROIFaceAlpha_;          end
        %GET.ROIMARKERSIZE Return the ROI marker size.
        function v = get.ROIMarkerSize(this),          v = this.ROIMarkerSize_;         end
        %GET.ANNOTATIONLINECOLOR Return the annotation line color.
        function v = get.AnnotationLineColor(this),    v = this.AnnotationLineColor_;   end
        %GET.ANNOTATIONLINEWIDTH Return the annotation line width.
        function v = get.AnnotationLineWidth(this),    v = this.AnnotationLineWidth_;   end
        %GET.ROTATIONANGLEVISIBLE Indicate whether rotation angle is visible.
        function v = get.RotationAngleVisible(this),   v = this.RotationAngleVisible_;  end
        %GET.ROTATIONANGLEMODE Return the rotation angle mode.
        function v = get.RotationAngleMode(this),      v = this.RotationAngleMode_;     end
        %GET.FONTSIZE Return the font size.
        function v = get.FontSize(this),               v = this.FontSize_;              end
        %GET.FONTCOLOR Return the font color.
        function v = get.FontColor(this),              v = this.FontColor_;             end

        %SET.ROICOLOR Set the ROI color.
        function set.ROIColor(this,v),              this.setValue("ROIColor",v);              end
        %SET.ROILINEWIDTH Set the ROI line width.
        function set.ROILineWidth(this,v),          this.setValue("ROILineWidth",v);          end
        %SET.ROIFACEALPHA Set the ROI face alpha.
        function set.ROIFaceAlpha(this,v),          this.setValue("ROIFaceAlpha",v);          end
        %SET.ROIMARKERSIZE Set the ROI marker size.
        function set.ROIMarkerSize(this,v),         this.setValue("ROIMarkerSize",v);         end
        %SET.ANNOTATIONLINECOLOR Set the annotation line color.
        function set.AnnotationLineColor(this,v),   this.setValue("AnnotationLineColor",v);   end
        %SET.ANNOTATIONLINEWIDTH Set the annotation line width.
        function set.AnnotationLineWidth(this,v),   this.setValue("AnnotationLineWidth",v);   end
        %SET.ROTATIONANGLEVISIBLE Set the rotation angle visible.
        function set.RotationAngleVisible(this,v),  this.setValue("RotationAngleVisible",v);  end
        %SET.ROTATIONANGLEMODE Set the rotation angle mode.
        function set.RotationAngleMode(this,v),     this.setValue("RotationAngleMode",v);     end
        %SET.FONTSIZE Set the font size.
        function set.FontSize(this,v),              this.setValue("FontSize",v);              end
        %SET.FONTCOLOR Set the font color.
        function set.FontColor(this,v),             this.setValue("FontColor",v);             end

        function S = toStruct(this)
        %TOSTRUCT Serialize the current values into a plain MATLAB structure.
            % Struct carrying serialized or resolved settings.
            S = struct( ...
                'ROIColor',this.ROIColor, ...
                'ROILineWidth',this.ROILineWidth, ...
                'ROIFaceAlpha',this.ROIFaceAlpha, ...
                'ROIMarkerSize',this.ROIMarkerSize, ...
                'AnnotationLineColor',this.AnnotationLineColor, ...
                'AnnotationLineWidth',this.AnnotationLineWidth, ...
                'RotationAngleVisible',this.RotationAngleVisible, ...
                'RotationAngleMode',this.RotationAngleMode, ...
                'FontSize',this.FontSize, ...
                'FontColor',this.FontColor);
        end

        function fromStruct(this,S)
        %FROMSTRUCT Read saved values from a MATLAB structure.
            f = fieldnames(this.toStruct());

            for i = 1:numel(f)
                prop = [f{i}, '_'];
                if isfield(S,f{i}) && isprop(this,prop)
                    this.(prop) = S.(f{i});
                end
            end
        end
    end

    methods (Access=private)
        function setValue(this,name,value)
        %SETVALUE Update a stored value and notify listeners when it changes.
            prop = char(name + "_");
            old = this.(prop);
            if isequaln(old,value)
                return
            end
            this.(prop) = value;
            ev = desmostorm.config.ChangeEvent("ROI",name,old,value);
            notify(this,'ROIChanged',ev);
            notify(this,'Changed',ev);
        end
    end
end
