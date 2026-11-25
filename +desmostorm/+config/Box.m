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
        % RGB color for face.
        FaceColor_          (1,3) double {mustBeInRange(FaceColor_,0,1)} = [0 0 0]
        % RGB color for edge.
        EdgeColor_          (1,3) double {mustBeInRange(EdgeColor_,0,1)} = [1 1 1]
        % Policy for choosing the display color.
        ColorMode_ (1,1) string {mustBeMember(ColorMode_,["label","manual"])} = "label"
        % Font size in points for overlay labels.
        LabelFontSize_ (1,1) double {mustBePositive,mustBeFinite} = 7
        % Whether the configured label is shown.
        ShowTitle_          (1,1) logical = true
        % Field displayed in the region box label.
        TitleContent_       (1,:) char {mustBeMember(TitleContent_,{'Name','Score'})} = 'Name'
    end

    properties (Dependent)
        % RGB color for face.
        FaceColor
        % RGB color for edge.
        EdgeColor
        % Policy for choosing the display color.
        ColorMode
        % Font size in points for overlay labels.
        LabelFontSize
        % Whether the configured label is shown.
        ShowTitle
        % Field displayed in the region box label.
        TitleContent
    end

    events
        Changed       % generic
        BoxChanged    % domain-specific
    end

    methods
        
        %GET.FACECOLOR Return the face color.
        function v = get.FaceColor(this),       v = this.FaceColor_;     end
        %GET.EDGECOLOR Return the edge color.
        function v = get.EdgeColor(this),       v = this.EdgeColor_;     end
        %GET.SHOWTITLE Return the show title.
        function v = get.ShowTitle(this),       v = this.ShowTitle_;     end
        %GET.TITLECONTENT Return the title content.
        function v = get.TitleContent(this),    v = this.TitleContent_;  end


        %GET.COLORMODE Return the color mode.
        function v = get.ColorMode(this), v = this.ColorMode_; end
        %GET.LABELFONTSIZE Return the label font size.
        function v = get.LabelFontSize(this), v = this.LabelFontSize_; end

        % ---------- Setters ----------

        %SET.COLORMODE Set the color mode.
        function set.ColorMode(this,v), this.setValue("ColorMode",string(v)); end
        %SET.LABELFONTSIZE Set the label font size.
        function set.LabelFontSize(this,v), this.setValue("LabelFontSize",v); end

        %SET.FACECOLOR Set the face color.
        function set.FaceColor(this,v),       this.setValue("FaceColor",v);       end
        %SET.EDGECOLOR Set the edge color.
        function set.EdgeColor(this,v),       this.setValue("EdgeColor",v);       end
        %SET.SHOWTITLE Set the show title.
        function set.ShowTitle(this,v),       this.setValue("ShowTitle",v);       end
        %SET.TITLECONTENT Set the title content.
        function set.TitleContent(this,v),    this.setValue("TitleContent",v);    end

        % ---------- Serialization ----------
        function S = toStruct(this)
        %TOSTRUCT Serialize the current values into a plain MATLAB structure.
            % Struct carrying serialized or resolved settings.
            S = struct( ...
                'FaceColor',        this.FaceColor, ...
                'EdgeColor',        this.EdgeColor, ...
                'ColorMode',this.ColorMode, ...
                'LabelFontSize',this.LabelFontSize, ...
                'ShowTitle',        this.ShowTitle, ...
                'TitleContent',     this.TitleContent);
        end

        function fromStruct(this,S)
        %FROMSTRUCT Read saved values from a MATLAB structure.
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
        %SETVALUE Update a stored value and notify listeners when it changes.
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
