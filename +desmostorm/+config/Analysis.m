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

        % Setters (with any extra cross-field validation)
        function set.MinPeakDistance(this,v)
            old = this.MinPeakDistance_;
            this.MinPeakDistance_ = v;
            ev = desmostorm.config.ChangeEvent("Analysis","MinPeakDistance",old,v);
            notify(this,'AnalysisChanged',ev);
            notify(this,'Changed');
        end
        function set.MinPeakHeight(this,v)
            old = this.MinPeakHeight_;
            this.MinPeakHeight_ = v;
            ev = desmostorm.config.ChangeEvent("Analysis","MinPeakHeight",old,v);
            notify(this,'AnalysisChanged',ev);
            notify(this,'Changed');
        end
        function set.MinPeakProminence(this,v)
            old = this.MinPeakProminence_;
            this.MinPeakProminence_ = v;
            ev = desmostorm.config.ChangeEvent("Analysis","MinPeakProminence",old,v);
            notify(this,'AnalysisChanged',ev);
            notify(this,'Changed');
        end
        function set.BoxSize(this,v)
            old = this.BoxSize_;
            this.BoxSize_ = v;
            ev = desmostorm.config.ChangeEvent("Analysis","BoxSize",old,v);
            notify(this,'AnalysisChanged',ev);
            notify(this,'Changed');
        end
        function set.Normalize(this,v)
            old = this.Normalize_;
            this.Normalize_ = v;
            ev = desmostorm.config.ChangeEvent("Analysis","Normalize",old,v);
            notify(this,'AnalysisChanged',ev);
            notify(this,'Changed');
        end
        function set.PeakSmoothing(this,v)
            old = this.PeakSmoothing_;
            this.PeakSmoothing_ = v;
            ev = desmostorm.config.ChangeEvent("Analysis","PeakSmoothing",old,v);
            notify(this,'AnalysisChanged',ev);
            notify(this,'Changed');
        end
        function set.PixelSizeValue(this,v)
            old = this.PixelSizeValue_;
            this.PixelSizeValue_ = v;
            ev = desmostorm.config.ChangeEvent("Analysis","PixelSizeValue",old,v);
            notify(this,'AnalysisChanged',ev);
            notify(this,'Changed');
        end
        function set.PixelSizeUnit(this,v)
            old = this.PixelSizeUnit_;
            this.PixelSizeUnit_ = v;
            ev = desmostorm.config.ChangeEvent("Analysis","PixelSizeUnit",old,v);
            notify(this,'AnalysisChanged',ev);
            notify(this,'Changed');
        end

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

end