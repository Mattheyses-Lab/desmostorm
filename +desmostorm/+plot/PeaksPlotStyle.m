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
        Colors (:,3) double {mustBeInRange(Colors,0,1)} = [0 0 0]
        AnnotationColors (:,3) double {mustBeInRange(AnnotationColors,0,1)} = zeros(0,3)
        RawLineColor double = []
        SmoothLineColor double = []
        RawLineAlpha (1,1) double {mustBeInRange(RawLineAlpha,0,1)} = 0.45
        RawLineWidth (1,1) double {mustBePositive,mustBeFinite} = 1
        SmoothLineWidth (1,1) double {mustBePositive,mustBeFinite} = 1
        AnnotationLineWidth (1,1) double {mustBePositive,mustBeFinite} = 1
        BackgroundColor (1,3) double {mustBeInRange(BackgroundColor,0,1)} = [1 1 1]
        ForegroundColor (1,3) double {mustBeInRange(ForegroundColor,0,1)} = [0 0 0]
        DistanceAnnotations (1,1) matlab.lang.OnOffSwitchState = "on"
        WidthAnnotations (1,1) matlab.lang.OnOffSwitchState = "on"
        DistanceAnnotationsMode (1,1) string {mustBeMember(DistanceAnnotationsMode,["data","lanes"])} = "lanes"
        WidthAnnotationsMode (1,1) string {mustBeMember(WidthAnnotationsMode,["normal","hover"])} = "normal"
        AnnotationsFontSize (1,1) double {mustBePositive,mustBeFinite} = 10
        AnnotationsMargin (1,1) double {mustBeNonnegative,mustBeFinite} = 1
        XLim double = []
    end

    methods
        function obj = PeaksPlotStyle(opts)
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
