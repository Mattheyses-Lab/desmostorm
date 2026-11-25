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

classdef PeaksPlot < handle
% PeaksPlot options for region linescan display and export

    properties (Access=private)
        % Stroke width in points for raw.
        RawLineWidth_       (1,1) double = 0.5
        % RGB color for.
        Color_              (1,3) double {mustBeInRange(Color_,0,1)} = [0 0 0]
        % Stroke width in points for smooth.
        SmoothLineWidth_    (1,1) double = 1
        % RGB color for background.
        BackgroundColor_    (1,3) double {mustBeInRange(BackgroundColor_,0,1)} = [1 1 1]
        % RGB color for foreground.
        ForegroundColor_    (1,3) double {mustBeInRange(ForegroundColor_,0,1)} = [0 0 0]
        % Whether to show n plots.
        ShownPlots_         (1,1) string {mustBeMember(ShownPlots_,["current","all"])} = "all"
        % Color source.
        ColorSource_        (1,1) string {mustBeMember(ColorSource_,["channel","manual"])} = "manual"
        % Mode used for annotation color.
        AnnotationColorMode_ (1,1) string {mustBeMember(AnnotationColorMode_,["auto","manual"])} = "auto"
        % Stroke width in points for annotation.
        AnnotationLineWidth_ (1,1) double {mustBePositive,mustBeFinite} = 0.5
        % RGB color for annotation.
        AnnotationColor_     (1,3) double {mustBeInRange(AnnotationColor_,0,1)} = [0 0 0]
        % Distance annotations.
        DistanceAnnotations_    (1,1) matlab.lang.OnOffSwitchState = "on"
        % Mode used for distance annotations.
        DistanceAnnotationsMode_ (1,1) string {mustBeMember(DistanceAnnotationsMode_,["data","lanes"])} = "data"
        % Width annotations.
        WidthAnnotations_       (1,1) matlab.lang.OnOffSwitchState = "on"
        % Mode used for width annotations.
        WidthAnnotationsMode_    (1,1) string {mustBeMember(WidthAnnotationsMode_,["normal","hover"])} = "hover"
        % Font size in points for measurement annotations.
        AnnotationFontSize_ (1,1) double {mustBePositive,mustBeFinite} = 7
        % Font size used by this component.
        FontSize_ (1,1) double {mustBePositive,mustBeFinite} = 9
        % Whether title is visible.
        TitleVisible_ (1,1) matlab.lang.OnOffSwitchState = "off"
    end

    properties (Dependent)
        % Stroke width in points for raw.
        RawLineWidth
        % RGB color for.
        Color
        % Stroke width in points for smooth.
        SmoothLineWidth
        % RGB color for background.
        BackgroundColor
        % RGB color for foreground.
        ForegroundColor
        % Whether to show n plots.
        ShownPlots
        % Color source.
        ColorSource
        % Mode used for annotation color.
        AnnotationColorMode
        % RGB color for annotation.
        AnnotationColor
        % Stroke width in points for annotation.
        AnnotationLineWidth
        % Distance annotations.
        DistanceAnnotations
        % Mode used for distance annotations.
        DistanceAnnotationsMode
        % Width annotations.
        WidthAnnotations
        % Mode used for width annotations.
        WidthAnnotationsMode
        % Font size in points for measurement annotations.
        AnnotationFontSize
        % Font size used by this component.
        FontSize
        % Whether title is visible.
        TitleVisible
    end


    events
        Changed       % generic
        PeaksPlotChanged    % domain-specific
    end

    methods
        
        % ---------- Getters ----------

        %GET.RAWLINEWIDTH Return the raw line width.
        function v = get.RawLineWidth(this),    v = this.RawLineWidth_;     end
        %GET.COLOR Return the color.
        function v = get.Color(this),           v = this.Color_;            end
        %GET.SMOOTHLINEWIDTH Return the smooth line width.
        function v = get.SmoothLineWidth(this), v = this.SmoothLineWidth_;  end
        %GET.BACKGROUNDCOLOR Return the background color.
        function v = get.BackgroundColor(this), v = this.BackgroundColor_;  end
        %GET.FOREGROUNDCOLOR Return the foreground color.
        function v = get.ForegroundColor(this), v = this.ForegroundColor_;  end
        %GET.SHOWNPLOTS Return the shown plots.
        function v = get.ShownPlots(this),      v = this.ShownPlots_;       end
        %GET.COLORSOURCE Return the color source.
        function v = get.ColorSource(this),     v = this.ColorSource_;      end
        %GET.ANNOTATIONCOLORMODE Return the annotation color mode.
        function v = get.AnnotationColorMode(this), v = this.AnnotationColorMode_; end
        %GET.ANNOTATIONLINEWIDTH Return the annotation line width.
        function v = get.AnnotationLineWidth(this), v = this.AnnotationLineWidth_; end
        %GET.ANNOTATIONCOLOR Return the annotation color.
        function v = get.AnnotationColor(this),     v = this.AnnotationColor_;     end
        %GET.DISTANCEANNOTATIONS Return the distance annotations.
        function v = get.DistanceAnnotations(this),     v = this.DistanceAnnotations_;     end
        %GET.DISTANCEANNOTATIONSMODE Return the distance annotations mode.
        function v = get.DistanceAnnotationsMode(this), v = this.DistanceAnnotationsMode_; end
        %GET.WIDTHANNOTATIONS Return the width annotations.
        function v = get.WidthAnnotations(this),        v = this.WidthAnnotations_;        end
        %GET.WIDTHANNOTATIONSMODE Return the width annotations mode.
        function v = get.WidthAnnotationsMode(this),    v = this.WidthAnnotationsMode_;    end

        %GET.ANNOTATIONFONTSIZE Return the annotation font size.
        function v = get.AnnotationFontSize(this), v = this.AnnotationFontSize_; end
        %GET.FONTSIZE Return the font size.
        function v = get.FontSize(this), v = this.FontSize_; end
        %GET.TITLEVISIBLE Indicate whether title is visible.
        function v = get.TitleVisible(this), v = this.TitleVisible_; end

        % ---------- Setters ----------

        %SET.RAWLINEWIDTH Set the raw line width.
        function set.RawLineWidth(this,v),             this.setValue("RawLineWidth",v);             end
        %SET.COLOR Set the color.
        function set.Color(this,v),                    this.setValue("Color",v);                    end
        %SET.SMOOTHLINEWIDTH Set the smooth line width.
        function set.SmoothLineWidth(this,v),          this.setValue("SmoothLineWidth",v);          end
        %SET.BACKGROUNDCOLOR Set the background color.
        function set.BackgroundColor(this,v),          this.setValue("BackgroundColor",v);          end
        %SET.FOREGROUNDCOLOR Set the foreground color.
        function set.ForegroundColor(this,v),          this.setValue("ForegroundColor",v);          end
        %SET.SHOWNPLOTS Set the shown plots.
        function set.ShownPlots(this,v),               this.setValue("ShownPlots",string(v));       end
        %SET.COLORSOURCE Set the color source.
        function set.ColorSource(this,v),              this.setValue("ColorSource",string(v));      end
        %SET.ANNOTATIONCOLORMODE Set the annotation color mode.
        function set.AnnotationColorMode(this,v),      this.setValue("AnnotationColorMode",string(v)); end
        %SET.ANNOTATIONLINEWIDTH Set the annotation line width.
        function set.AnnotationLineWidth(this,v), this.setValue("AnnotationLineWidth",v); end
        %SET.ANNOTATIONCOLOR Set the annotation color.
        function set.AnnotationColor(this,v),          this.setValue("AnnotationColor",v);          end
        %SET.DISTANCEANNOTATIONS Set the distance annotations.
        function set.DistanceAnnotations(this,v),      this.setValue("DistanceAnnotations",v);      end
        %SET.DISTANCEANNOTATIONSMODE Set the distance annotations mode.
        function set.DistanceAnnotationsMode(this,v),  this.setValue("DistanceAnnotationsMode",string(v)); end
        %SET.WIDTHANNOTATIONS Set the width annotations.
        function set.WidthAnnotations(this,v),         this.setValue("WidthAnnotations",v);         end
        %SET.WIDTHANNOTATIONSMODE Set the width annotations mode.
        function set.WidthAnnotationsMode(this,v),     this.setValue("WidthAnnotationsMode",string(v)); end


        %SET.ANNOTATIONFONTSIZE Set the annotation font size.
        function set.AnnotationFontSize(this,v), this.setValue("AnnotationFontSize",v); end
        %SET.FONTSIZE Set the font size.
        function set.FontSize(this,v), this.setValue("FontSize",v); end
        %SET.TITLEVISIBLE Set the title visible.
        function set.TitleVisible(this,v), this.setValue("TitleVisible",v); end

        % ---------- Serialization ----------
        function S = toStruct(this)
        %TOSTRUCT Serialize the current values into a plain MATLAB structure.
            % Struct carrying serialized or resolved settings.
            S = struct( ...
                'RawLineWidth',     this.RawLineWidth, ...
                'Color',            this.Color, ...
                'SmoothLineWidth',  this.SmoothLineWidth, ...
                'BackgroundColor',  this.BackgroundColor, ...
                'ForegroundColor',  this.ForegroundColor, ...
                'ShownPlots',       this.ShownPlots, ...
                'ColorSource',      this.ColorSource, ...
                'AnnotationColorMode', this.AnnotationColorMode, ...
                'AnnotationColor',     this.AnnotationColor, ...
                'AnnotationLineWidth', this.AnnotationLineWidth, ...
                'DistanceAnnotations',     this.DistanceAnnotations, ...
                'DistanceAnnotationsMode', this.DistanceAnnotationsMode, ...
                'WidthAnnotations',        this.WidthAnnotations, ...
                'WidthAnnotationsMode',    this.WidthAnnotationsMode, ...
                'AnnotationFontSize', this.AnnotationFontSize, ...
                'FontSize', this.FontSize, ...
                'TitleVisible', this.TitleVisible);
        end

        function fromStruct(this,S)
        %FROMSTRUCT Read saved values from a MATLAB structure.
            if isfield(S,'ColorMode') && ~isfield(S,'ColorSource')
                S.ColorSource = S.ColorMode;
            end
            if isfield(S,'SmoothLineColor') && ~isfield(S,'Color')
                S.Color = S.SmoothLineColor;
            end

            f = fieldnames(this.toStruct());

            for i = 1:numel(f)
                prop = [f{i}, '_'];  % append underscore
                if isfield(S,f{i}) && isprop(this, prop)
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
            ev = desmostorm.config.ChangeEvent("PeaksPlot",name,old,value);
            notify(this,'PeaksPlotChanged',ev);
            notify(this,'Changed',ev);
        end
    end

end
