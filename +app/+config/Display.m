classdef Display < handle
% Display options with directory-based colormap selection

    properties (Access=private)
        ColormapName_     string = "Gray"    % selection name
        ColormapCategory_ string = "Colors"   % selection category
        BoxFaceColor_     (1,3) double {mustBeGreaterThanOrEqual(BoxFaceColor_,0), mustBeLessThanOrEqual(BoxFaceColor_,1)} = [0 0 0]
        BoxEdgeColor_     (1,3) double {mustBeGreaterThanOrEqual(BoxEdgeColor_,0), mustBeLessThanOrEqual(BoxEdgeColor_,1)} = [1 1 1]
    end

    events
        Changed           % generic
        DisplayChanged    % domain-specific
    end

    properties (Dependent)
        Colormap          % Nx3 double (loaded on demand)
        ColormapName
        ColormapCategory
        BoxFaceColor
        BoxEdgeColor
    end

    methods
        
        % ---------- Dependent getters ----------
        function c = get.Colormap(this)
            % Returns Nx3 RGB array; loads from registry as needed.
            c = app.colormaps.Registry.map(this.ColormapName_, this.ColormapCategory_);
        end

        function s = get.ColormapName(this),     s = this.ColormapName_;     end
        function s = get.ColormapCategory(this), s = this.ColormapCategory_; end
        function v = get.BoxFaceColor(this),     v = this.BoxFaceColor_;     end
        function v = get.BoxEdgeColor(this),     v = this.BoxEdgeColor_;     end


        % ---------- Setters ----------
        function setColormap(this, name, category)
            % Atomic update with validation; only notify if changed
            name = string(name); 
            category = string(category);

            % make sure colormap with given name exists in the current category
            assert(app.colormaps.Registry.has(name, category), ...
                'Colormap "%s" not found in category "%s".', name, category);

            if name == this.ColormapName_ && category == this.ColormapCategory_
                return; % no-op, avoid redundant events
            end

            this.ColormapName_     = name;
            this.ColormapCategory_ = category;

            ev = app.config.ChangeEvent("Display","Colormap",[],[]);
            notify(this,'DisplayChanged',ev);
            notify(this,'Changed',ev);
        end

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
                'ColormapName',     this.ColormapName, ...
                'ColormapCategory', this.ColormapCategory, ...
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

    methods (Static)

        function cats = availableCategories()
            % get list of colormap categories
            cats = app.colormaps.Registry.categories();
        end

        function names = availableNames(category)
            % get list of colormap names for given colormap category
            names = app.colormaps.Registry.names(category);
        end

    end
end