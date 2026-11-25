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

classdef Box < handle
% Appearance settings for region boxes.

    % --- Region boxes ---
    properties (Access=private)
        FaceColor_          (1,3) double {mustBeInRange(FaceColor_,0,1)} = [0 0 0]
        EdgeColor_          (1,3) double {mustBeInRange(EdgeColor_,0,1)} = [1 1 1]
        ColorMode_ (1,1) string {mustBeMember(ColorMode_,["label","manual"])} = "label"
        LabelFontSize_ (1,1) double {mustBePositive,mustBeFinite} = 7
        ShowTitle_          (1,1) logical = true
        TitleContent_       (1,:) char {mustBeMember(TitleContent_,{'Name','Score'})} = 'Name'
    end

    properties (Dependent)
        FaceColor
        EdgeColor
        ColorMode
        LabelFontSize
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


        function v = get.ColorMode(this), v = this.ColorMode_; end
        function v = get.LabelFontSize(this), v = this.LabelFontSize_; end

        % ---------- Setters ----------

        function set.ColorMode(this,v), this.setValue("ColorMode",string(v)); end
        function set.LabelFontSize(this,v), this.setValue("LabelFontSize",v); end

        function set.FaceColor(this,v),       this.setValue("FaceColor",v);       end
        function set.EdgeColor(this,v),       this.setValue("EdgeColor",v);       end
        function set.ShowTitle(this,v),       this.setValue("ShowTitle",v);       end
        function set.TitleContent(this,v),    this.setValue("TitleContent",v);    end

        % ---------- Serialization ----------
        function S = toStruct(this)
            S = struct( ...
                'FaceColor',        this.FaceColor, ...
                'EdgeColor',        this.EdgeColor, ...
                'ColorMode',this.ColorMode, ...
                'LabelFontSize',this.LabelFontSize, ...
                'ShowTitle',        this.ShowTitle, ...
                'TitleContent',     this.TitleContent);
        end

        function fromStruct(this,S)
            f = fieldnames(this.toStruct());

            for i = 1:numel(f)
                prop = [f{i}, '_'];  % append underscore
                if isfield(S,f{i}) && isprop(this, prop)
                    this.(prop) = S.(f{i});
                end
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
            ev = desmostorm.config.ChangeEvent("Box",name,old,value);
            notify(this,'BoxChanged',ev);
            notify(this,'Changed',ev);
        end
    end

end
