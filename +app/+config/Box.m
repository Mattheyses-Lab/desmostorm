classdef Box < handle
% Display options with directory-based colormap selection

    % --- Region boxes ---
    properties (Access=private)
        BoxFaceColor_     (1,3) double {mustBeInRange(BoxFaceColor_,0,1)} = [0 0 0]
        BoxEdgeColor_     (1,3) double {mustBeInRange(BoxEdgeColor_,0,1)} = [1 1 1]
    end

    properties (Dependent)
        BoxFaceColor
        BoxEdgeColor
    end

    events
        Changed       % generic
        BoxChanged    % domain-specific
    end

    methods
        
        function v = get.BoxFaceColor(this),     v = this.BoxFaceColor_;     end
        function v = get.BoxEdgeColor(this),     v = this.BoxEdgeColor_;     end

        % ---------- Setters ----------

        function set.BoxFaceColor(this,v)
            old = this.BoxFaceColor_;
            this.BoxFaceColor_ = v;
            ev = app.config.ChangeEvent("Display","BoxFaceColor",old,v);
            notify(this,'DisplayChanged',ev);
            notify(this,'Changed',ev);
        end

        function set.BoxEdgeColor(this,v)
            old = this.BoxEdgeColor_;
            this.BoxEdgeColor_ = v;
            ev = app.config.ChangeEvent("Display","BoxEdgeColor",old,v);
            notify(this,'DisplayChanged',ev);
            notify(this,'Changed',ev);
        end

        % ---------- Serialization ----------
        function S = toStruct(this)
            S = struct( ...
                'BoxFaceColor',     this.BoxFaceColor, ...
                'BoxEdgeColor',     this.BoxEdgeColor);
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