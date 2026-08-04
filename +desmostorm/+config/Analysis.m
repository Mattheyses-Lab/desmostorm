classdef Analysis < handle

    % Group analysis parameters; validate on set; raise Changed.
    properties (Access=private)
        MinPeakDistance_    (1,1) double {mustBeNonnegative} = 15
        MinPeakHeight_      (1,1) double {mustBeNonnegative} = 0.4
        MinPeakProminence_  (1,1) double {mustBeNonnegative} = 0
        BoxSize_            (1,1) double {mustBePositive}    = 300
        Normalize_          (1,1) logical = true
        PeakSmoothing_      (1,1) double {mustBeNonnegative} = 15
        PixelSizeValue_     (1,1) double {mustBePositive} = 1
        PixelSizeUnit_      (1,:) char = 'px'
    end

    events
        Changed           % generic
        AnalysisChanged   % domain-specific
    end

    properties (Dependent)
        MinPeakDistance
        MinPeakHeight
        MinPeakProminence
        BoxSize
        Normalize
        PeakSmoothing
        PixelSizeValue   % numeric, e.g. 4
        PixelSizeUnit    % string, e.g. 'nm'
    end

    methods
        % Getters
        function v = get.MinPeakDistance(this),     v = this.MinPeakDistance_;      end
        function v = get.MinPeakHeight(this),       v = this.MinPeakHeight_;        end
        function v = get.MinPeakProminence(this),   v = this.MinPeakProminence_;        end
        function v = get.BoxSize(this),             v = this.BoxSize_;              end
        function v = get.Normalize(this),           v = this.Normalize_;    end
        function v = get.PeakSmoothing(this),       v = this.PeakSmoothing_;        end
        function v = get.PixelSizeValue(this),      v = this.PixelSizeValue_;       end
        function v = get.PixelSizeUnit(this),       v = this.PixelSizeUnit_;        end

        % Setters
        function set.MinPeakDistance(this,v),     this.setValue("MinPeakDistance",v);     end
        function set.MinPeakHeight(this,v),       this.setValue("MinPeakHeight",v);       end
        function set.MinPeakProminence(this,v),   this.setValue("MinPeakProminence",v);   end
        function set.BoxSize(this,v),             this.setValue("BoxSize",v);             end
        function set.Normalize(this,v),           this.setValue("Normalize",v);           end
        function set.PeakSmoothing(this,v),       this.setValue("PeakSmoothing",v);       end
        function set.PixelSizeValue(this,v),      this.setValue("PixelSizeValue",v);      end
        function set.PixelSizeUnit(this,v),       this.setValue("PixelSizeUnit",v);       end

        % Serialization helpers
        function S = toStruct(this)
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
            f = fieldnames(this.toStruct());
            for i=1:numel(f)
                if isfield(S,f{i}), this.(f{i}) = S.(f{i}); end
            end
        end

    end

    %% Helpers
    methods

        function ps = getDefaultPixelSize(this)
            ps = desmostorm.model.units.PixelSize(this.PixelSizeValue, this.PixelSizeUnit);
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
            ev = desmostorm.config.ChangeEvent("Analysis",name,old,value);
            notify(this,'AnalysisChanged',ev);
            notify(this,'Changed',ev);
        end
    end

end
