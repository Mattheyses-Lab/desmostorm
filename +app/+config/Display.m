classdef Display < handle
% Display options with directory-based colormap selection

    % --- Colormaps ---
    properties (Access=private)
        ColormapName_     string = "turbo"    % selection name
        ColormapCategory_ string = "MATLAB"   % selection category
        AutoScaleDisplayIntensity_ logical = false     % whether to automatically set display limits
    end

    properties (Dependent)
        Colormap          % Nx3 double (loaded on demand)
        ColormapName
        ColormapCategory
        AutoScaleDisplayIntensity
    end

    events
        Changed           % generic
        DisplayChanged    % domain-specific
    end

    methods
        
        % ---------- Dependent getters ----------
        function c = get.Colormap(this)
            % Returns Nx3 RGB array; loads from registry as needed.
            c = matlabx.colors.maps.Registry.map(this.ColormapName_, this.ColormapCategory_);
        end

        function s = get.ColormapName(this),     s = this.ColormapName_;     end
        function s = get.ColormapCategory(this), s = this.ColormapCategory_; end

        function s = get.AutoScaleDisplayIntensity(this),   s = this.AutoScaleDisplayIntensity_; end


        % ---------- Setters ----------
        function setColormap(this, name, category)
            % Atomic update with validation; only notify if changed
            name = string(name); 
            category = string(category);

            % make sure colormap with given name exists in the current category
            assert(matlabx.colors.maps.Registry.has(name, category), ...
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

        function set.AutoScaleDisplayIntensity(this, v)
            old = this.AutoScaleDisplayIntensity_;
            this.AutoScaleDisplayIntensity_ = v;
            ev = app.config.ChangeEvent("Display","AutoScaleDisplayIntensity",old,v);
            notify(this,'DisplayChanged',ev);
            notify(this,'Changed',ev);
        end

        % ---------- Serialization ----------
        function S = toStruct(this)
            S = struct( ...
                'ColormapName',     this.ColormapName, ...
                'ColormapCategory', this.ColormapCategory, ...
                'AutoScaleDisplayIntensity', this.AutoScaleDisplayIntensity);
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
            cats = matlabx.colors.maps.Registry.categories();
        end

        function names = availableNames(category)
            % get list of colormap names for given colormap category
            names = matlabx.colors.maps.Registry.names(category);
        end

    end
end