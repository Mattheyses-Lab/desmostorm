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

classdef PeaksPlotStyle
%PEAKSPLOTSTYLE Resolved trace styling and axes presentation for a linescan.

    properties
        % Colors.
        Colors (:,3) double {mustBeInRange(Colors,0,1)} = [0 0 0]
        % Annotation colors.
        AnnotationColors (:,3) double {mustBeInRange(AnnotationColors,0,1)} = zeros(0,3)
        % RGB color for raw line.
        RawLineColor double = []
        % RGB color for smooth line.
        SmoothLineColor double = []
        % Opacity of raw line.
        RawLineAlpha (1,1) double {mustBeInRange(RawLineAlpha,0,1)} = 0.45
        % Stroke width in points for raw.
        RawLineWidth (1,1) double {mustBePositive,mustBeFinite} = 1
        % Stroke width in points for smooth.
        SmoothLineWidth (1,1) double {mustBePositive,mustBeFinite} = 1
        % Stroke width in points for annotation.
        AnnotationLineWidth (1,1) double {mustBePositive,mustBeFinite} = 1
        % RGB color for background.
        BackgroundColor (1,3) double {mustBeInRange(BackgroundColor,0,1)} = [1 1 1]
        % RGB color for foreground.
        ForegroundColor (1,3) double {mustBeInRange(ForegroundColor,0,1)} = [0 0 0]
        % Distance annotations.
        DistanceAnnotations (1,1) matlab.lang.OnOffSwitchState = "on"
        % Width annotations.
        WidthAnnotations (1,1) matlab.lang.OnOffSwitchState = "on"
        % Mode used for distance annotations.
        DistanceAnnotationsMode (1,1) string {mustBeMember(DistanceAnnotationsMode,["data","lanes"])} = "lanes"
        % Mode used for width annotations.
        WidthAnnotationsMode (1,1) string {mustBeMember(WidthAnnotationsMode,["normal","hover"])} = "normal"
        % Font size in points for measurement annotations.
        AnnotationsFontSize (1,1) double {mustBePositive,mustBeFinite} = 10
        % Padding around annotation text.
        AnnotationsMargin (1,1) double {mustBeNonnegative,mustBeFinite} = 1
        % X lim.
        XLim double = []
    end

    methods
        function obj = PeaksPlotStyle(opts)
        %PEAKSPLOTSTYLE Initialize appearance and annotation options for linescan content.
            arguments
                opts.Colors (:,3) double {mustBeInRange(opts.Colors,0,1)} = [0 0 0]
                opts.AnnotationColors (:,3) double {mustBeInRange(opts.AnnotationColors,0,1)} = zeros(0,3)
                opts.RawLineColor double = []
                opts.SmoothLineColor double = []
                opts.RawLineAlpha (1,1) double {mustBeInRange(opts.RawLineAlpha,0,1)} = 0.45
                opts.RawLineWidth (1,1) double {mustBePositive,mustBeFinite} = 1
                opts.SmoothLineWidth (1,1) double {mustBePositive,mustBeFinite} = 1
                opts.AnnotationLineWidth (1,1) double {mustBePositive,mustBeFinite} = 1
                opts.BackgroundColor (1,3) double {mustBeInRange(opts.BackgroundColor,0,1)} = [1 1 1]
                opts.ForegroundColor (1,3) double {mustBeInRange(opts.ForegroundColor,0,1)} = [0 0 0]
                opts.DistanceAnnotations (1,1) matlab.lang.OnOffSwitchState = "on"
                opts.WidthAnnotations (1,1) matlab.lang.OnOffSwitchState = "on"
                opts.DistanceAnnotationsMode (1,1) string {mustBeMember(opts.DistanceAnnotationsMode,["data","lanes"])} = "lanes"
                opts.WidthAnnotationsMode (1,1) string {mustBeMember(opts.WidthAnnotationsMode,["normal","hover"])} = "normal"
                opts.AnnotationsFontSize (1,1) double {mustBePositive,mustBeFinite} = 10
                opts.AnnotationsMargin (1,1) double {mustBeNonnegative,mustBeFinite} = 1
                opts.XLim double = []
            end
            % Process the named fields in opts.
            for name = reshape(string(fieldnames(opts)),1,[])
                obj.(name) = opts.(name);
            end
            if isempty(obj.Colors), obj.Colors = [0 0 0]; end
            if ~isempty(obj.XLim)
                validateattributes(obj.XLim,{'double'},{'size',[1 2],'finite','increasing'});
            end
        end
    end
end
