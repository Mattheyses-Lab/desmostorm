classdef RunConfig
    %% RUNCONFIG  Value class with immutable snapshot of current Analysis settings for processing runs

    properties
        MinPeakDistance (1,1) double
        MinPeakHeight   (1,1) double
        BoxSize         (1,1) double
        PeakSmoothing   (1,1) double
    end

    methods(Static)
        function rc = fromSettings(S)
            rc = desmostorm.config.RunConfig;
            rc.MinPeakDistance = S.Analysis.MinPeakDistance;
            rc.MinPeakHeight   = S.Analysis.MinPeakHeight;
            rc.BoxSize         = S.Analysis.BoxSize;
            rc.PeakSmoothing   = S.Analysis.PeakSmoothing;
        end
    end

end