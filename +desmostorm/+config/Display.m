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

classdef Display < handle
% Display options with directory-based colormap selection

    % --- Colormaps ---
    properties (Constant)
        % Available methods for calculating display limits.
        AutoMethods = ["Light contrast","Medium contrast","Strong contrast","Zero to max","Data range"]
    end

    properties (Access=private)
        % Colormap name.
        ColormapName_     string = "turbo"    % selection name
        % Colormap category.
        ColormapCategory_ string = "MATLAB"   % selection category
        % Mode used for channel color.
        ChannelColorMode_ string = "colors"     % "colors" or "luts"
        % Default automatic scaling policy for channels without saved overrides.
        DefaultKeepAuto_ (1,1) logical = true
        % Channel policies.
        ChannelPolicies_ struct = struct('ID',{},'KeepAuto',{},'Lock',{}, ...
            'LockedRange',{},'Method',{})
    end

    properties (Dependent)
        % Colormap.
        Colormap          % Nx3 double (loaded on demand)
        % Colormap name.
        ColormapName
        % Colormap category.
        ColormapCategory
        % Mode used for channel color.
        ChannelColorMode
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

        %GET.COLORMAPNAME Return the colormap name.
        function s = get.ColormapName(this),     s = this.ColormapName_;     end
        %GET.COLORMAPCATEGORY Return the colormap category.
        function s = get.ColormapCategory(this), s = this.ColormapCategory_; end
        %GET.CHANNELCOLORMODE Return the channel color mode.
        function s = get.ChannelColorMode(this), s = this.ChannelColorMode_; end



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

            ev = desmostorm.config.ChangeEvent("Display","Colormap",[],[]);
            notify(this,'DisplayChanged',ev);
            notify(this,'Changed',ev);
        end

        function policy = channelPolicy(this,id)
        %CHANNELPOLICY Return the saved display policy or defaults for a project channel.
            index = find(string({this.ChannelPolicies_.ID}) == id,1);
            if isempty(index)
                % Saved range and automatic scaling settings for this project channel.
                policy = struct('ID',id,'KeepAuto',this.DefaultKeepAuto_, ...
                    'Lock',false,'LockedRange',[],'Method',"Light contrast");
            else
                policy = this.ChannelPolicies_(index);
            end
        end

        function setChannelPolicy(this,policy)
        %SETCHANNELPOLICY Set channel policy.
            index = find(string({this.ChannelPolicies_.ID}) == policy.ID,1);
            if isempty(index), index = numel(this.ChannelPolicies_)+1; end
            this.ChannelPolicies_(index) = policy;
        end

        function set.ChannelColorMode(this, v)
        %SET.CHANNELCOLORMODE Set the channel color mode.
            v = string(v);
            mustBeMember(v,["colors","luts"]);
            this.setValue("ChannelColorMode",v);
        end

        % ---------- Serialization ----------
        function S = toStruct(this)
        %TOSTRUCT Serialize the current values into a plain MATLAB structure.
            % Struct carrying serialized or resolved settings.
            S = struct( ...
                'ColormapName',     this.ColormapName, ...
                'ColormapCategory', this.ColormapCategory, ...
                'ChannelColorMode', this.ChannelColorMode, ...
                'DefaultKeepAuto',this.DefaultKeepAuto_, ...
                'ChannelPolicies',this.ChannelPolicies_);
        end

        function fromStruct(this,S)
        %FROMSTRUCT Read saved values from a MATLAB structure.
            f = fieldnames(this.toStruct());

            for i = 1:numel(f)
                prop = [f{i}, '_'];  % append underscore
                if strcmp(f{i},'ChannelPolicies') && isfield(S,f{i}) && isempty(S.(f{i}))
                    this.ChannelPolicies_ = this.ChannelPolicies_([]);
                elseif isprop(this, prop) && isfield(S,f{i})
                    this.(prop) = S.(f{i});
                    if strcmp(f{i},'ChannelPolicies')
                        % Process channel policies in order.
                        for k = 1:numel(this.ChannelPolicies_)
                            this.ChannelPolicies_(k).LockedRange = ...
                                reshape(this.ChannelPolicies_(k).LockedRange,1,[]);
                        end
                    end
                end
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
            ev = desmostorm.config.ChangeEvent("Display",name,old,value);
            notify(this,'DisplayChanged',ev);
            notify(this,'Changed',ev);
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
