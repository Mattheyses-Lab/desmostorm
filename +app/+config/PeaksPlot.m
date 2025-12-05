classdef PeaksPlot < handle
% PeaksPlot options with directory-based colormap selection

    properties (Access=private)
        RawLineColor_       (1,3) double {mustBeInRange(RawLineColor_,0,1)} = [1 0 0]
        RawLineWidth_       (1,1) double = 1
        SmoothLineColor_    (1,3) double {mustBeInRange(SmoothLineColor_,0,1)} = [0 0 1]
        SmoothLineWidth_    (1,1) double = 2
        BackgroundColor_    (1,3) double {mustBeInRange(BackgroundColor_,0,1)} = [0 0 0]
        ForegroundColor_    (1,3) double {mustBeInRange(ForegroundColor_,0,1)} = [1 1 1]
    end

    properties (Dependent)
        RawLineColor
        RawLineWidth
        SmoothLineColor
        SmoothLineWidth
        BackgroundColor
        ForegroundColor
    end


    events
        Changed       % generic
        PeaksPlotChanged    % domain-specific
    end

    methods
        
        % ---------- Getters ----------

        function v = get.RawLineColor(this),    v = this.RawLineColor_;     end
        function v = get.RawLineWidth(this),    v = this.RawLineWidth_;     end
        function v = get.SmoothLineColor(this), v = this.SmoothLineColor_;  end
        function v = get.SmoothLineWidth(this), v = this.SmoothLineWidth_;  end
        function v = get.BackgroundColor(this), v = this.BackgroundColor_;  end
        function v = get.ForegroundColor(this), v = this.ForegroundColor_;  end

        % ---------- Setters ----------

        function set.RawLineColor(this,v)
            old = this.RawLineColor_;
            this.RawLineColor_ = v;
            ev = app.config.ChangeEvent("PeaksPlot","RawLineColor",old,v);
            notify(this,'PeaksPlotChanged',ev);
            notify(this,'Changed',ev);
        end

        function set.RawLineWidth(this,v)
            old = this.RawLineWidth_;
            this.RawLineWidth_ = v;
            ev = app.config.ChangeEvent("PeaksPlot","RawLineWidth",old,v);
            notify(this,'PeaksPlotChanged',ev);
            notify(this,'Changed',ev);
        end

        function set.SmoothLineColor(this,v)
            old = this.SmoothLineColor_;
            this.SmoothLineColor_ = v;
            ev = app.config.ChangeEvent("PeaksPlot","SmoothLineColor",old,v);
            notify(this,'PeaksPlotChanged',ev);
            notify(this,'Changed',ev);
        end

        function set.SmoothLineWidth(this,v)
            old = this.SmoothLineWidth_;
            this.SmoothLineWidth_ = v;
            ev = app.config.ChangeEvent("PeaksPlot","SmoothLineWidth",old,v);
            notify(this,'PeaksPlotChanged',ev);
            notify(this,'Changed',ev);
        end

        function set.BackgroundColor(this,v)
            old = this.BackgroundColor_;
            this.BackgroundColor_ = v;
            ev = app.config.ChangeEvent("PeaksPlot","BackgroundColor",old,v);
            notify(this,'PeaksPlotChanged',ev);
            notify(this,'Changed',ev);
        end

        function set.ForegroundColor(this,v)
            old = this.ForegroundColor_;
            this.ForegroundColor_ = v;
            ev = app.config.ChangeEvent("PeaksPlot","ForegroundColor",old,v);
            notify(this,'PeaksPlotChanged',ev);
            notify(this,'Changed',ev);
        end





        % ---------- Serialization ----------
        function S = toStruct(this)
            S = struct( ...
                'RawLineColor',     this.RawLineColor, ...
                'RawLineWidth',     this.RawLineWidth, ...
                'SmoothLineColor',  this.SmoothLineColor, ...
                'SmoothLineWidth',  this.SmoothLineWidth, ...
                'BackgroundColor',  this.BackgroundColor, ...
                'ForegroundColor',  this.ForegroundColor);
        end

        function fromStruct(this,S)
            f = fieldnames(this.toStruct());

            for i = 1:numel(f)
                prop = [f{i}, '_'];  % append underscore
                if isprop(this, prop)
                    this.(prop) = S.(f{i});
                end
            end
        end

    end

end