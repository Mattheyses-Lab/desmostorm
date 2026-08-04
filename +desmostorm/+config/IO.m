classdef IO < handle

    properties (Access=private)
        DefaultFolder_ string = desmostorm.Paths.user
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
                warning('%s is not a folder or is not accessible, reverting to default: %s',v,desmostorm.Paths.user);
                v = desmostorm.Paths.user;
            end

            this.setValue("DefaultFolder",v);
        end
        
        function set.AutoSave(this, v)
            this.setValue("AutoSave",logical(v));
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

    methods (Access=private)
        function setValue(this,name,value)
            prop = char(name + "_");
            old = this.(prop);
            if isequaln(old,value)
                return
            end
            this.(prop) = value;
            ev = desmostorm.config.ChangeEvent("IO",name,old,value);
            notify(this,'IOChanged',ev);
            notify(this,'Changed',ev);
        end
    end

end
