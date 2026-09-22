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
        ROIColor_ (1,3) double {mustBeInRange(ROIColor_,0,1)} = [1 1 1]
        ROILineWidth_ (1,1) double {mustBePositive} = 1
        ROIFaceAlpha_ (1,1) double {mustBeInRange(ROIFaceAlpha_,0,1)} = 0.1
        ROIMarkerSize_ (1,1) double {mustBePositive} = 8
        AnnotationLineColor_ (1,3) double {mustBeInRange(AnnotationLineColor_,0,1)} = [1 1 1]
        AnnotationLineWidth_ (1,1) double {mustBePositive} = 0.5
        RotationAngleVisible_ (1,1) matlab.lang.OnOffSwitchState = "on"
        RotationAngleMode_ (1,:) char {mustBeMember(RotationAngleMode_,{'full-circle','half-circle'})} = 'half-circle'
        FontSize_ (1,1) double {mustBePositive} = 12
        FontColor_ (1,3) double {mustBeInRange(FontColor_,0,1)} = [1 1 1]
    end

    properties (Dependent)
        ROIColor
        ROILineWidth
        ROIFaceAlpha
        ROIMarkerSize
        AnnotationLineColor
        AnnotationLineWidth
        RotationAngleVisible
        RotationAngleMode
        FontSize
        FontColor
    end

    events
        Changed
        ROIChanged
    end

    methods
        function v = get.ROIColor(this),               v = this.ROIColor_;              end
        function v = get.ROILineWidth(this),           v = this.ROILineWidth_;          end
        function v = get.ROIFaceAlpha(this),           v = this.ROIFaceAlpha_;          end
        function v = get.ROIMarkerSize(this),          v = this.ROIMarkerSize_;         end
        function v = get.AnnotationLineColor(this),    v = this.AnnotationLineColor_;   end
        function v = get.AnnotationLineWidth(this),    v = this.AnnotationLineWidth_;   end
        function v = get.RotationAngleVisible(this),   v = this.RotationAngleVisible_;  end
        function v = get.RotationAngleMode(this),      v = this.RotationAngleMode_;     end
        function v = get.FontSize(this),               v = this.FontSize_;              end
        function v = get.FontColor(this),              v = this.FontColor_;             end

        function set.ROIColor(this,v),              this.setValue("ROIColor",v);              end
        function set.ROILineWidth(this,v),          this.setValue("ROILineWidth",v);          end
        function set.ROIFaceAlpha(this,v),          this.setValue("ROIFaceAlpha",v);          end
        function set.ROIMarkerSize(this,v),         this.setValue("ROIMarkerSize",v);         end
        function set.AnnotationLineColor(this,v),   this.setValue("AnnotationLineColor",v);   end
        function set.AnnotationLineWidth(this,v),   this.setValue("AnnotationLineWidth",v);   end
        function set.RotationAngleVisible(this,v),  this.setValue("RotationAngleVisible",v);  end
        function set.RotationAngleMode(this,v),     this.setValue("RotationAngleMode",v);     end
        function set.FontSize(this,v),              this.setValue("FontSize",v);              end
        function set.FontColor(this,v),             this.setValue("FontColor",v);             end

        function S = toStruct(this)
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
