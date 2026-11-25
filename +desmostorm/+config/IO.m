% DesmoSTORM - MATLAB app for desmosomal plaque protein analysis.
% Copyright (C) 2026 William Dean
%
% This program is free software; you can redistribute it and/or modify it
% under the terms of the GNU General Public License as published by the Free
% Software Foundation; either version 2 of the License, or (at your option)
% any later version.
%
% This program is distributed in the hope that it will be useful, but WITHOUT
% ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
% FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
% details.
%
% You should have received a copy of the GNU General Public License along
% with this program; if not, see <https://www.gnu.org/licenses/>.

classdef IO < handle
%IO Settings for project file handling.

    properties (Access=private)
        % Filesystem location for default.
        DefaultFolder_ string = desmostorm.Paths.user
        % Whether the application saves projects automatically.
        AutoSave_      logical = true
    end

    events
        Changed           % generic
        IOChanged         % domain-specific
    end

    properties (Dependent)
        % Filesystem location for default.
        DefaultFolder
        % Auto save.
        AutoSave
    end

    methods
        
        % Getters
        function v = get.DefaultFolder(this), v = this.DefaultFolder_; end
        %GET.AUTOSAVE Return the auto save.
        function v = get.AutoSave(this),      v = this.AutoSave_;      end

        % Setters (with validation)
        function set.DefaultFolder(this, v)
        %SET.DEFAULTFOLDER Set the default folder.
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
        %SET.AUTOSAVE Set the auto save.
            this.setValue("AutoSave",logical(v));
        end

        % Serialization helpers
        function S = toStruct(this)
        %TOSTRUCT Serialize the current values into a plain MATLAB structure.
            % Struct carrying serialized or resolved settings.
            S = struct( ...
                'DefaultFolder', this.DefaultFolder, ...
                'AutoSave', this.AutoSave);
        end

        function fromStruct(this,S)
        %FROMSTRUCT Read saved values from a MATLAB structure.
            f = fieldnames(this.toStruct());
            for i=1:numel(f)
                if isfield(S,f{i}), this.(f{i}) = S.(f{i}); end
            end
        end

    end

    methods (Access=private)
        function setValue(this,name,value)
        %SETVALUE Update a stored value and notify listeners when it changes.
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
