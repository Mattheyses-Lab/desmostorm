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