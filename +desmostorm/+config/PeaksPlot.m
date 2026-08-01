classdef PeaksPlot < handle
% PeaksPlot options for region linescan display and export

    properties (Access=private)
        RawLineWidth_       (1,1) double = 1
        Color_              (1,3) double {mustBeInRange(Color_,0,1)} = [0 0 0]
        SmoothLineWidth_    (1,1) double = 2
        BackgroundColor_    (1,3) double {mustBeInRange(BackgroundColor_,0,1)} = [1 1 1]
        ForegroundColor_    (1,3) double {mustBeInRange(ForegroundColor_,0,1)} = [0 0 0]
        ShownPlots_         (1,1) string {mustBeMember(ShownPlots_,["current","all"])} = "all"
        ColorSource_        (1,1) string {mustBeMember(ColorSource_,["channel","manual"])} = "channel"
        AnnotationColorMode_ (1,1) string {mustBeMember(AnnotationColorMode_,["auto","manual"])} = "auto"
        AnnotationColor_     (1,3) double {mustBeInRange(AnnotationColor_,0,1)} = [0 0 0]
        DistanceAnnotations_    (1,1) matlab.lang.OnOffSwitchState = "on"
        DistanceAnnotationsMode_ (1,1) string {mustBeMember(DistanceAnnotationsMode_,["data","lanes"])} = "lanes"
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

        function set.RawLineWidth(this,v)
            old = this.RawLineWidth_;
            this.RawLineWidth_ = v;
            ev = desmostorm.config.ChangeEvent("PeaksPlot","RawLineWidth",old,v);
            notify(this,'PeaksPlotChanged',ev);
            notify(this,'Changed',ev);
        end

        function set.Color(this,v)
            old = this.Color_;
            this.Color_ = v;
            ev = desmostorm.config.ChangeEvent("PeaksPlot","Color",old,v);
            notify(this,'PeaksPlotChanged',ev);
            notify(this,'Changed',ev);
        end

        function set.SmoothLineWidth(this,v)
            old = this.SmoothLineWidth_;
            this.SmoothLineWidth_ = v;
            ev = desmostorm.config.ChangeEvent("PeaksPlot","SmoothLineWidth",old,v);
            notify(this,'PeaksPlotChanged',ev);
            notify(this,'Changed',ev);
        end

        function set.BackgroundColor(this,v)
            old = this.BackgroundColor_;
            this.BackgroundColor_ = v;
            ev = desmostorm.config.ChangeEvent("PeaksPlot","BackgroundColor",old,v);
            notify(this,'PeaksPlotChanged',ev);
            notify(this,'Changed',ev);
        end

        function set.ForegroundColor(this,v)
            old = this.ForegroundColor_;
            this.ForegroundColor_ = v;
            ev = desmostorm.config.ChangeEvent("PeaksPlot","ForegroundColor",old,v);
            notify(this,'PeaksPlotChanged',ev);
            notify(this,'Changed',ev);
        end

        function set.ShownPlots(this,v)
            old = this.ShownPlots_;
            this.ShownPlots_ = string(v);
            ev = desmostorm.config.ChangeEvent("PeaksPlot","ShownPlots",old,this.ShownPlots_);
            notify(this,'PeaksPlotChanged',ev);
            notify(this,'Changed',ev);
        end

        function set.ColorSource(this,v)
            old = this.ColorSource_;
            this.ColorSource_ = string(v);
            ev = desmostorm.config.ChangeEvent("PeaksPlot","ColorSource",old,this.ColorSource_);
            notify(this,'PeaksPlotChanged',ev);
            notify(this,'Changed',ev);
        end

        function set.AnnotationColorMode(this,v)
            old = this.AnnotationColorMode_;
            this.AnnotationColorMode_ = string(v);
            ev = desmostorm.config.ChangeEvent("PeaksPlot","AnnotationColorMode",old,this.AnnotationColorMode_);
            notify(this,'PeaksPlotChanged',ev);
            notify(this,'Changed',ev);
        end

        function set.AnnotationColor(this,v)
            old = this.AnnotationColor_;
            this.AnnotationColor_ = v;
            ev = desmostorm.config.ChangeEvent("PeaksPlot","AnnotationColor",old,v);
            notify(this,'PeaksPlotChanged',ev);
            notify(this,'Changed',ev);
        end

        function set.DistanceAnnotations(this,v)
            old = this.DistanceAnnotations_;
            this.DistanceAnnotations_ = v;
            ev = desmostorm.config.ChangeEvent("PeaksPlot","DistanceAnnotations",old,v);
            notify(this,'PeaksPlotChanged',ev);
            notify(this,'Changed',ev);
        end

        function set.DistanceAnnotationsMode(this,v)
            old = this.DistanceAnnotationsMode_;
            this.DistanceAnnotationsMode_ = string(v);
            ev = desmostorm.config.ChangeEvent("PeaksPlot","DistanceAnnotationsMode",old,this.DistanceAnnotationsMode_);
            notify(this,'PeaksPlotChanged',ev);
            notify(this,'Changed',ev);
        end

        function set.WidthAnnotations(this,v)
            old = this.WidthAnnotations_;
            this.WidthAnnotations_ = v;
            ev = desmostorm.config.ChangeEvent("PeaksPlot","WidthAnnotations",old,v);
            notify(this,'PeaksPlotChanged',ev);
            notify(this,'Changed',ev);
        end

        function set.WidthAnnotationsMode(this,v)
            old = this.WidthAnnotationsMode_;
            this.WidthAnnotationsMode_ = string(v);
            ev = desmostorm.config.ChangeEvent("PeaksPlot","WidthAnnotationsMode",old,this.WidthAnnotationsMode_);
            notify(this,'PeaksPlotChanged',ev);
            notify(this,'Changed',ev);
        end





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

end
