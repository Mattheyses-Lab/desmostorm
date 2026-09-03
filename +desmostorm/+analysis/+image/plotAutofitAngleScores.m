function h = plotAutofitAngleScores(ax,T,opts)
%PLOTAUTOFITANGLESCORES Compatibility wrapper for auto-fit score plotting.
%
% New code should call desmostorm.analysis.image.autofit.plotAngleScores.

arguments
    ax (1,1) matlab.ui.control.UIAxes
    T table
    opts.CurrentTheta (1,1) double = NaN
    opts.SelectedTheta (1,1) double = NaN
    opts.Title (1,1) string = "Angle score"
    opts.FontSize (1,1) double {mustBePositive} = 12
    opts.LineScale (1,1) double {mustBePositive} = 1
    opts.ShowLegend (1,1) logical = true
end

h = desmostorm.analysis.image.autofit.plotAngleScores(ax,T, ...
    "CurrentTheta",opts.CurrentTheta, ...
    "SelectedTheta",opts.SelectedTheta, ...
    "Title",opts.Title, ...
    "FontSize",opts.FontSize, ...
    "LineScale",opts.LineScale, ...
    "ShowLegend",opts.ShowLegend);
end
