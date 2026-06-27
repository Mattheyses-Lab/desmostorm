classdef RunConfig
    %% RUNCONFIG  Value class with immutable snapshot of current Analysis settings for processing runs

    properties
        MinPeakDistance     (1,1) double
        MinPeakHeight       (1,1) double
        MinPeakProminence   (1,1) double
        BoxSize             (1,1) double
        PeakSmoothing       (1,1) double
        Normalize           (1,1) logical
    end

    methods(Static)
        function rc = fromSettings(S)
            rc = desmostorm.config.RunConfig;
            rc.MinPeakDistance      = S.Analysis.MinPeakDistance;
            rc.MinPeakHeight        = S.Analysis.MinPeakHeight;
            rc.MinPeakProminence    = S.Analysis.MinPeakProminence;
            rc.BoxSize              = S.Analysis.BoxSize;
            rc.PeakSmoothing        = S.Analysis.PeakSmoothing;
            rc.Normalize            = S.Analysis.Normalize;
        end
    end

end