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

classdef Analyzer
    methods (Static)
        function out = analyzeRegionLinescan(I, data, rc, opts)
            arguments
                % image to analyze
                I cell
                % ROI data struct - ROI within which we will perform the linescan
                %   fields: CenterX, CenterY, Width, Height, RotationAngle
                data (1,1) struct
                % Analysis settings snapshot
                rc (1,1) desmostorm.config.RunConfig
                opts.ProgressDialog = []
                opts.ProgressMessagePrefix (1,1) string = ""
            end

            % Return quietly for invalid ROI input. This usually means a
            % region has not had a linescan ROI placed or fitted yet.
            if any(isnan([data.CenterX,data.CenterY,data.Width,data.Height,data.RotationAngle]))
                out = [];
                return
            end

            out = desmostorm.analysis.PeaksData.empty();
            nChannels = numel(I);

            for i = 1:nChannels
                desmostorm.analysis.Analyzer.updateProgress(opts.ProgressDialog, ...
                    sprintf("%sAnalyzing channel %d/%d...", ...
                    opts.ProgressMessagePrefix,i,nChannels));

                % Compute the rectified ROI linescan for this channel.
                linescanData = desmostorm.analysis.profile.measure2D(I{i}, ...
                    data.CenterX, ...
                    data.CenterY, ...
                    data.Width, ...
                    data.Height, ...
                    data.RotationAngle, ...
                    'Interp','linear');

                % Detect peaks from the height profile using the immutable
                % run-config snapshot supplied by the GUI/model layer.
                out(i) = desmostorm.analysis.PeaksData( ...
                    linescanData.HeightProfile, ...
                    linescanData.HeightDist, ...
                    "MinPeakDistance",      rc.MinPeakDistance, ...
                    "MinPeakHeight",        rc.MinPeakHeight, ...
                    "MinPeakProminence",    rc.MinPeakProminence, ...
                    "PeakSmoothing",        rc.PeakSmoothing, ...
                    "Normalize",            rc.Normalize);
            end
        end

        function [out,diagnostics] = autofitRegionROI(I, rc, opts)
            arguments
                % image to analyze
                I (:,:) double
                % Analysis settings snapshot
                rc (1,1) desmostorm.config.RunConfig
                opts.DebugOutput = []
                opts.ProgressDialog = []
                opts.ProgressMessagePrefix (1,1) string = ""
                opts.ProgressValueMode (1,1) string {mustBeMember(opts.ProgressValueMode,["stage","none"])} = "stage"
            end

            % Keep model classes pointed at the stable Analyzer facade while
            % the experimental implementation evolves inside +image/+autofit.
            args = {};
            if ~isempty(opts.DebugOutput)
                args = [args, {"DebugOutput",opts.DebugOutput}];
            end
            if ~isempty(opts.ProgressDialog)
                args = [args, {"ProgressDialog",opts.ProgressDialog}];
            end
            if opts.ProgressMessagePrefix ~= ""
                args = [args, {"ProgressMessagePrefix",opts.ProgressMessagePrefix}];
            end
            args = [args, {"ProgressValueMode",opts.ProgressValueMode}];

            [out,diagnostics] = desmostorm.analysis.image.autofit.fitRegionROI(I,rc,args{:});
        end

    end

    methods (Static, Access=private)
        function updateProgress(h,msg)
            %UPDATEPROGRESS Best-effort progress message update.
            if isempty(h), return; end

            try
                h.Message = msg;
                drawnow limitrate
            catch
            end
        end

    end
end
