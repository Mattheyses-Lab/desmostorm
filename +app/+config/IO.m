classdef IO < handle

    properties (Access=private)
        DefaultFolder_ string = app.Paths.user
        AutoSave_      logical = true
    end

    events
        Changed           % generic
        IOChanged         % domain-specific
    end

    properties (Dependent)
        DefaultFolder
        AutoSave
    end

    methods
        
        % Getters
        function v = get.DefaultFolder(this), v = this.DefaultFolder_; end
        function v = get.AutoSave(this),      v = this.AutoSave_;      end

        % Setters (with validation)
        function set.DefaultFolder(this, v)
            arguments
                this
                v string
            end

            % Allow empty (user hasn't chosen yet) or existing folder
            if strlength(v) > 0
                assert(isfolder(v), 'DefaultFolder must be an existing folder or empty.');
            end

            old = this.DefaultFolder_;
            this.DefaultFolder_ = v; 
            ev = app.config.ChangeEvent("IO","DefaultFolder",old,v);
            notify(this,'IOChanged',ev);
            notify(this,'Changed',ev);
        end
        
        function set.AutoSave(this, v)
            old = this.AutoSave_;
            this.AutoSave_ = logical(v);
            ev = app.config.ChangeEvent("IO","AutoSave",old,v);
            notify(this,'IOChanged',ev);
            notify(this,'Changed',ev);
        end

        % Serialization helpers
        function S = toStruct(this)
            S = struct('DefaultFolder', this.DefaultFolder, 'AutoSave', this.AutoSave);
        end

        function fromStruct(this,S)
            f = fieldnames(this.toStruct());
            for i=1:numel(f)
                if isfield(S,f{i}), this.(f{i}) = S.(f{i}); end
            end
        end

    end

end