classdef IO < handle

    properties (Access=private)
        DefaultFolder_ string = desmostorm.app.Paths.user
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

            % ensure DefaultFolder is an actual folder
            if ~isfolder(v)
                warning('%s is not a folder or is not accessible, reverting to default: %s',v,desmostorm.app.Paths.user);
                v = desmostorm.app.Paths.user;
            end

            old = this.DefaultFolder_;
            this.DefaultFolder_ = v; 
            ev = desmostorm.config.ChangeEvent("IO","DefaultFolder",old,v);
            notify(this,'IOChanged',ev);
            notify(this,'Changed',ev);
        end
        
        function set.AutoSave(this, v)
            old = this.AutoSave_;
            this.AutoSave_ = logical(v);
            ev = desmostorm.config.ChangeEvent("IO","AutoSave",old,v);
            notify(this,'IOChanged',ev);
            notify(this,'Changed',ev);
        end

        % Serialization helpers
        function S = toStruct(this)
            S = struct( ...
                'DefaultFolder', this.DefaultFolder, ...
                'AutoSave', this.AutoSave);
        end

        function fromStruct(this,S)
            f = fieldnames(this.toStruct());
            for i=1:numel(f)
                if isfield(S,f{i}), this.(f{i}) = S.(f{i}); end
            end
        end

    end

end