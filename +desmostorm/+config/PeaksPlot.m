classdef PeaksPlot < handle
% PeaksPlot options for region linescan display and export

    properties (Access=private)
        RawLineWidth_       (1,1) double = 0.5
        Color_              (1,3) double {mustBeInRange(Color_,0,1)} = [0 0 0]
        SmoothLineWidth_    (1,1) double = 1
        BackgroundColor_    (1,3) double {mustBeInRange(BackgroundColor_,0,1)} = [1 1 1]
        ForegroundColor_    (1,3) double {mustBeInRange(ForegroundColor_,0,1)} = [0 0 0]
        ShownPlots_         (1,1) string {mustBeMember(ShownPlots_,["current","all"])} = "all"
        ColorSource_        (1,1) string {mustBeMember(ColorSource_,["channel","manual"])} = "channel"
        AnnotationColorMode_ (1,1) string {mustBeMember(AnnotationColorMode_,["auto","manual"])} = "auto"
        AnnotationColor_     (1,3) double {mustBeInRange(AnnotationColor_,0,1)} = [0 0 0]
        DistanceAnnotations_    (1,1) matlab.lang.OnOffSwitchState = "on"
        DistanceAnnotationsMode_ (1,1) string {mustBeMember(DistanceAnnotationsMode_,["data","lanes"])} = "data"
        WidthAnnotations_       (1,1) matlab.lang.OnOffSwitchState = "on"
        WidthAnnotationsMode_    (1,1) string {mustBeMember(WidthAnnotationsMode_,["normal","hover"])} = "hover"
    end

    properties (Dependent)
        RawLineWidth
        Color
        SmoothLineWidth
        BackgroundColor
        ForegroundColor
        ShownPlots
        ColorSource
        AnnotationColorMode
        AnnotationColor
        DistanceAnnotations
        DistanceAnnotationsMode
        WidthAnnotations
        WidthAnnotationsMode
    end


    events
        Changed       % generic
        PeaksPlotChanged    % domain-specific
    end

    methods
        
        % ---------- Getters ----------

        function v = get.RawLineWidth(this),    v = this.RawLineWidth_;     end
        function v = get.Color(this),           v = this.Color_;            end
        function v = get.SmoothLineWidth(this), v = this.SmoothLineWidth_;  end
        function v = get.BackgroundColor(this), v = this.BackgroundColor_;  end
        function v = get.ForegroundColor(this), v = this.ForegroundColor_;  end
        function v = get.ShownPlots(this),      v = this.ShownPlots_;       end
        function v = get.ColorSource(this),     v = this.ColorSource_;      end
        function v = get.AnnotationColorMode(this), v = this.AnnotationColorMode_; end
        function v = get.AnnotationColor(this),     v = this.AnnotationColor_;     end
        function v = get.DistanceAnnotations(this),     v = this.DistanceAnnotations_;     end
        function v = get.DistanceAnnotationsMode(this), v = this.DistanceAnnotationsMode_; end
        function v = get.WidthAnnotations(this),        v = this.WidthAnnotations_;        end
        function v = get.WidthAnnotationsMode(this),    v = this.WidthAnnotationsMode_;    end

        % ---------- Setters ----------

        function set.RawLineWidth(this,v),             this.setValue("RawLineWidth",v);             end
        function set.Color(this,v),                    this.setValue("Color",v);                    end
        function set.SmoothLineWidth(this,v),          this.setValue("SmoothLineWidth",v);          end
        function set.BackgroundColor(this,v),          this.setValue("BackgroundColor",v);          end
        function set.ForegroundColor(this,v),          this.setValue("ForegroundColor",v);          end
        function set.ShownPlots(this,v),               this.setValue("ShownPlots",string(v));       end
        function set.ColorSource(this,v),              this.setValue("ColorSource",string(v));      end
        function set.AnnotationColorMode(this,v),      this.setValue("AnnotationColorMode",string(v)); end
        function set.AnnotationColor(this,v),          this.setValue("AnnotationColor",v);          end
        function set.DistanceAnnotations(this,v),      this.setValue("DistanceAnnotations",v);      end
        function set.DistanceAnnotationsMode(this,v),  this.setValue("DistanceAnnotationsMode",string(v)); end
        function set.WidthAnnotations(this,v),         this.setValue("WidthAnnotations",v);         end
        function set.WidthAnnotationsMode(this,v),     this.setValue("WidthAnnotationsMode",string(v)); end


        % ---------- Serialization ----------
        function S = toStruct(this)
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
                'DistanceAnnotations',     this.DistanceAnnotations, ...
                'DistanceAnnotationsMode', this.DistanceAnnotationsMode, ...
                'WidthAnnotations',        this.WidthAnnotations, ...
                'WidthAnnotationsMode',    this.WidthAnnotationsMode);
        end

        function fromStruct(this,S)
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
