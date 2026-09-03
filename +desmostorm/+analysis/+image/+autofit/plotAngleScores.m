function h = plotAngleScores(ax,T,opts)
%PLOTANGLESCORES Plot total and component ROI angle scores.
%
% h = plotAngleScores(ax,T) draws the auto-fit rotation score table on ax.
% Component traces are plotted as weighted contributions so their values sum
% to the raw total score used by the angle-selection heuristic.

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

h = struct();
h.ComponentLines = matlab.graphics.chart.primitive.Line.empty(0,1);
h.RawScoreLine = matlab.graphics.chart.primitive.Line.empty();
h.SmoothedScoreLine = matlab.graphics.chart.primitive.Line.empty();
h.CurrentAngleLine = matlab.graphics.chart.decoration.ConstantLine.empty();
h.SelectedAngleLine = matlab.graphics.chart.decoration.ConstantLine.empty();

styleAngleScoreAxes(ax,opts.Title,opts.FontSize);

oldNextPlot = ax.NextPlot;
ax.NextPlot = "add";
cleanup = onCleanup(@() set(ax,"NextPlot",oldNextPlot));

[componentNames,componentValues,componentColors] = weightedScoreComponents(T);
legendLabels = strings(0,1);

for i = 1:numel(componentNames)
    h.ComponentLines(i,1) = plot(ax,T.Theta,componentValues(:,i), ...
        "Color",componentColors(i,:), ...
        "LineWidth",0.9 * opts.LineScale, ...
        "LineStyle","-");
    legendLabels(end+1,1) = componentNames(i); %#ok<AGROW>
end

h.RawScoreLine = plot(ax,T.Theta,T.Score, ...
    "Color",[0.45 0.45 0.45], ...
    "LineWidth",1.2 * opts.LineScale, ...
    "LineStyle","-");
legendLabels(end+1,1) = "Total";

h.SmoothedScoreLine = plot(ax,T.Theta,T.SmoothedScore, ...
    "Color",[0.05 0.25 0.85], ...
    "LineWidth",2.0 * opts.LineScale, ...
    "LineStyle","-");
legendLabels(end+1,1) = "Smoothed total";

if ~isnan(opts.SelectedTheta)
    h.SelectedAngleLine = xline(ax,opts.SelectedTheta, ...
        "Color",[0.15 0.15 0.15], ...
        "LineWidth",1.2 * opts.LineScale, ...
        "LineStyle",":");
    legendLabels(end+1,1) = "Selected angle";
end

if ~isnan(opts.CurrentTheta)
    h.CurrentAngleLine = xline(ax,opts.CurrentTheta, ...
        "Color",[0.85 0.15 0.10], ...
        "LineWidth",1.5 * opts.LineScale, ...
        "LineStyle","-");
    legendLabels(end+1,1) = "Current angle";
end

if opts.ShowLegend
    lgd = legend(ax);
    lgd.String = cellstr(legendLabels);
    lgd.Location = "northeast";
    lgd.Orientation = "vertical";
    lgd.Box = "off";
    lgd.Color = "none";
    lgd.TextColor = [0 0 0];
end

end

function styleAngleScoreAxes(ax,titleText,fontSize)
%STYLEANGLESCOREAXES Match the quiet white plotting style used in demos.
    ax.Color = [1 1 1];
    ax.Box = "on";
    ax.XColor = [0 0 0];
    ax.YColor = [0 0 0];
    ax.FontName = 'Arial';
    ax.FontSize = fontSize;
    ax.XGrid = "on";
    ax.YGrid = "on";
    ax.GridColor = [0.82 0.82 0.82];
    ax.Title.String = titleText;
    ax.Title.Color = [0 0 0];
    ax.XLabel.String = "Rotation angle (deg)";
    ax.YLabel.String = "Weighted score";
end

function [names,values,colors] = weightedScoreComponents(T)
%WEIGHTEDSCORECOMPONENTS Return weighted columns used by scorePeaksData.
    names = [
        "Valley"
        "Prominence"
        "Balance"
        "Center"
        "Distance"
        "Peak count"];

    values = [
        3.0 * tableColumn(T,"ValleyDepth"), ...
        2.0 * tableColumn(T,"ProminenceScore"), ...
        2.0 * tableColumn(T,"PeakBalance"), ...
        2.0 * tableColumn(T,"CenterScore"), ...
        2.5 * tableColumn(T,"DistanceScore"), ...
        0.5 * peakCountScore(T)];

    colors = [
        0.0000 0.4470 0.7410
        0.8500 0.3250 0.0980
        0.9290 0.6940 0.1250
        0.4940 0.1840 0.5560
        0.4660 0.6740 0.1880
        0.3010 0.7450 0.9330];
end

function values = tableColumn(T,name)
%TABLECOLUMN Return a score-table column or NaNs if unavailable.
    if ismember(name,T.Properties.VariableNames)
        values = T.(name);
    else
        values = nan(height(T),1);
    end
end

function values = peakCountScore(T)
%PEAKCOUNTSCORE Rebuild the count-score component from NPeaks.
    if ismember("CountScore",T.Properties.VariableNames)
        values = T.CountScore;
    elseif ismember("NPeaks",T.Properties.VariableNames)
        values = double(T.NPeaks == 2) + 0.75 * double(T.NPeaks > 2);
    else
        values = nan(height(T),1);
    end
end
