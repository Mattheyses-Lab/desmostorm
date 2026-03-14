classdef Box < handle
% Display options with directory-based colormap selection

    % --- Region boxes ---
    properties (Access=private)
        FaceColor_          (1,3) double {mustBeInRange(FaceColor_,0,1)} = [0 0 0]
        EdgeColor_          (1,3) double {mustBeInRange(EdgeColor_,0,1)} = [1 1 1]
        ShowTitle_          (1,1) logical = true
        TitleContent_       (1,:) char {mustBeMember(TitleContent_,{'Name','Score'})} = 'Name'
    end

    properties (Dependent)
        FaceColor
        EdgeColor
        ShowTitle
        TitleContent
    end

    events
        Changed       % generic
        BoxChanged    % domain-specific
    end

    methods
        
        function v = get.FaceColor(this),       v = this.FaceColor_;     end
        function v = get.EdgeColor(this),       v = this.EdgeColor_;     end
        function v = get.ShowTitle(this),       v = this.ShowTitle_;     end
        function v = get.TitleContent(this),    v = this.TitleContent_;  end


        % ---------- Setters ----------

        function set.FaceColor(this,v)
            old = this.FaceColor_;
            this.FaceColor_ = v;
            ev = app.config.ChangeEvent("Display","FaceColor",old,v);
            notify(this,'DisplayChanged',ev);
            notify(this,'Changed',ev);
        end

        function set.EdgeColor(this,v)
            old = this.EdgeColor_;
            this.EdgeColor_ = v;
            ev = app.config.ChangeEvent("Display","EdgeColor",old,v);
            notify(this,'DisplayChanged',ev);
            notify(this,'Changed',ev);
        end

        function set.ShowTitle(this,v)
            old = this.ShowTitle_;
            this.ShowTitle_ = v;
            ev = app.config.ChangeEvent("Display","ShowTitle",old,v);
            notify(this,'DisplayChanged',ev);
            notify(this,'Changed',ev);
        end

        function set.TitleContent(this,v)
            old = this.TitleContent_;
            this.TitleContent_ = v;
            ev = app.config.ChangeEvent("Display","TitleContent",old,v);
            notify(this,'DisplayChanged',ev);
            notify(this,'Changed',ev);
        end

        % ---------- Serialization ----------
        function S = toStruct(this)
            S = struct( ...
                'FaceColor',        this.FaceColor, ...
                'EdgeColor',        this.EdgeColor, ...
                'ShowTitle',        this.ShowTitle, ...
                'TitleContent',     this.TitleContent);
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