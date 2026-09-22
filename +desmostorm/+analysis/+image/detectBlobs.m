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

function out = detectBlobs(I,opts)
%DETECTBLOBS Detects SURF (Speeded-Up Robust Features) points in an image
% (basically just a wrapper for detectSURFFeatures)

    arguments
        % image to detect blobs in
        I (:,:) double
        % strongest feature threshold for SURF point detection | lower values -> more sensitive
        opts.MetricThreshold (1,1) double {mustBePositive(opts.MetricThreshold)} = 50
        % number of octaves | integer >= 1 | higher values -> larger blobs | recommended values between 1 and 4
        opts.NumOctaves (1,1) double {mustBeGreaterThanOrEqual(opts.NumOctaves,1)} = 3
        % number of scale levels per octave to compute | integer >= 3
        % higher values -> detect more blobs at finer scale increments | recommended values between 3 and 6
        opts.NumScaleLevels (1,1) double {mustBeGreaterThanOrEqual(opts.NumScaleLevels,3)} = 3
        % whether to show SURF detection results
        opts.DisplayOutput (1,1) logical = false
    end

    %% detect blobs using SURF features (SURFPoints object)
    points = detectSURFFeatures(I,...
        "MetricThreshold",opts.MetricThreshold,...
        "NumOctaves",opts.NumOctaves,...
        "NumScaleLevels",opts.NumScaleLevels);

    % return point locations (converted to double)
    out = double(points.Location);

    %% display intermediate output if requested
    if opts.DisplayOutput
        fH = uifigure("WindowStyle","alwaysontop",...
            "Position",[200 200 700 700],...
            "Visible","off");
        ax = matlabx.ui.axes.ImageAxes(fH,...
            "Units","normalized",...
            "Position",[0 0 1 1],...
            "CData",I,...
            "Tools",{'Zoom'},...
            "Colormap",turbo);
        points.plot(ax.getAxes());
        movegui(fH,"north");
        fH.Visible = "on";
    end

end
