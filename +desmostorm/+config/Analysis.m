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

classdef Analysis < handle
%ANALYSIS Settings for image analysis, ROI geometry, and peak detection.

    % Group analysis parameters; validate on set; raise Changed.
    properties (Access=private)
        % Min peak distance.
        MinPeakDistance_    (1,1) double {mustBeNonnegative} = 15
        % Min peak height.
        MinPeakHeight_      (1,1) double {mustBeNonnegative} = 0.4
        % Min peak prominence.
        MinPeakProminence_  (1,1) double {mustBeNonnegative} = 0
        % Side length of the square region box in pixels.
        BoxSize_            (1,1) double {mustBePositive}    = 300
        % Whether to normalize intensities before peak detection.
        Normalize_          (1,1) logical = true
        % Peak smoothing.
        PeakSmoothing_      (1,1) double {mustBeNonnegative} = 15
        % Pixel size value.
        PixelSizeValue_     (1,1) double {mustBePositive} = 1
        % Pixel size unit.
        PixelSizeUnit_      (1,:) char = 'px'
    end

    events
        Changed           % generic
        AnalysisChanged   % domain-specific
    end

    properties (Dependent)
        % Min peak distance.
        MinPeakDistance
        % Min peak height.
        MinPeakHeight
        % Min peak prominence.
        MinPeakProminence
        % Side length of the square region box in pixels.
        BoxSize
        % Normalize.
        Normalize
        % Peak smoothing.
        PeakSmoothing
        % Pixel size value.
        PixelSizeValue   % numeric, e.g. 4
        % Pixel size unit.
        PixelSizeUnit    % string, e.g. 'nm'
    end

    methods
        % Getters
        function v = get.MinPeakDistance(this),     v = this.MinPeakDistance_;      end
        %GET.MINPEAKHEIGHT Return the min peak height.
        function v = get.MinPeakHeight(this),       v = this.MinPeakHeight_;        end
        %GET.MINPEAKPROMINENCE Return the min peak prominence.
        function v = get.MinPeakProminence(this),   v = this.MinPeakProminence_;    end
        %GET.BOXSIZE Return the box size.
        function v = get.BoxSize(this),             v = this.BoxSize_;              end
        %GET.NORMALIZE Return the normalize.
        function v = get.Normalize(this),           v = this.Normalize_;            end
        %GET.PEAKSMOOTHING Return the peak smoothing.
        function v = get.PeakSmoothing(this),       v = this.PeakSmoothing_;        end
        %GET.PIXELSIZEVALUE Return the pixel size value.
        function v = get.PixelSizeValue(this),      v = this.PixelSizeValue_;       end
        %GET.PIXELSIZEUNIT Return the pixel size unit.
        function v = get.PixelSizeUnit(this),       v = this.PixelSizeUnit_;        end

        % Setters
        function set.MinPeakDistance(this,v),     this.setValue("MinPeakDistance",v);     end
        %SET.MINPEAKHEIGHT Set the min peak height.
        function set.MinPeakHeight(this,v),       this.setValue("MinPeakHeight",v);       end
        %SET.MINPEAKPROMINENCE Set the min peak prominence.
        function set.MinPeakProminence(this,v),   this.setValue("MinPeakProminence",v);   end
        %SET.BOXSIZE Set the box size.
        function set.BoxSize(this,v),             this.setValue("BoxSize",v);             end
        %SET.NORMALIZE Set the normalize.
        function set.Normalize(this,v),           this.setValue("Normalize",v);           end
        %SET.PEAKSMOOTHING Set the peak smoothing.
        function set.PeakSmoothing(this,v),       this.setValue("PeakSmoothing",v);       end
        %SET.PIXELSIZEVALUE Set the pixel size value.
        function set.PixelSizeValue(this,v),      this.setValue("PixelSizeValue",v);      end
        %SET.PIXELSIZEUNIT Set the pixel size unit.
        function set.PixelSizeUnit(this,v),       this.setValue("PixelSizeUnit",v);       end

        % Serialization helpers
        function S = toStruct(this)
        %TOSTRUCT Serialize the current values into a plain MATLAB structure.
            % Struct carrying serialized or resolved settings.
            S = struct( ...
                'MinPeakDistance',      this.MinPeakDistance, ...
                'MinPeakHeight',        this.MinPeakHeight, ...
                'MinPeakProminence',    this.MinPeakProminence, ...
                'BoxSize',              this.BoxSize, ...
                'Normalize',            this.Normalize, ...
                'PeakSmoothing',        this.PeakSmoothing, ...
                'PixelSizeValue',       this.PixelSizeValue, ...
                'PixelSizeUnit',        this.PixelSizeUnit);
        end
        
        function fromStruct(this,S)
        %FROMSTRUCT Read saved values from a MATLAB structure.
            f = fieldnames(this.toStruct());
            for i=1:numel(f)
                if isfield(S,f{i}), this.(f{i}) = S.(f{i}); end
            end
        end

    end

    %% Helpers
    methods

        function ps = getDefaultPixelSize(this)
        %GETDEFAULTPIXELSIZE Return default pixel size.
            % Physical calibration used to convert pixel measurements.
            ps = desmostorm.model.units.PixelSize(this.PixelSizeValue, this.PixelSizeUnit);
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
            ev = desmostorm.config.ChangeEvent("Analysis",name,old,value);
            notify(this,'AnalysisChanged',ev);
            notify(this,'Changed',ev);
        end
    end

end
