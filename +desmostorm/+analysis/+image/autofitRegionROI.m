function [ROI,diagnostics] = autofitRegionROI(I,config,opts)
%AUTOFITREGIONROI Estimate a rectangular linescan ROI for one region image.
%
% This public wrapper preserves the historical analysis.image API while the
% experimental implementation lives in +desmostorm/+analysis/+image/+autofit.
% Keeping the orchestration here makes the high-level fitting flow easy to
% read without hiding the stage-specific heuristics in one large file.

arguments
    I
    config
    opts.DebugOutput (1,1) logical = desmostorm.Preferences.get( ...
        "AnalysisDebugOutput", desmostorm.runtime.isDeveloperMode())
    opts.ShowPlots = []
    opts.ProgressDialog = []
end

diagnostics = struct();
debugOutput = opts.DebugOutput;
if ~isempty(opts.ShowPlots)
    % Backward-compatible alias for the old development option. New code
    % should use DebugOutput because diagnostics may include tables, plots,
    % logs, or other non-plot output.
    debugOutput = logical(opts.ShowPlots);
end

if isempty(I)
    ROI = [];
    return
end

af = @desmostorm.analysis.image.autofit.updateProgress;
af(opts.ProgressDialog,"Preparing ROI auto-fit...",0.02);

I = double(I);
[H,W] = size(I,[1 2]);
desmostorm.Log.DEBUG(sprintf("Auto-fit ROI input image size: %d x %d px.",H,W));

% Start from a centered ROI that can rotate freely inside the region crop.
ROI = desmostorm.analysis.image.autofit.initialROI(H,W);

% Cleanup currently removes sparse DBSCAN noise points and edge junk. These
% are useful for profile stability, but should remain swappable preprocessing
% steps while the autofit path is still experimental.
af(opts.ProgressDialog,"Preprocessing region image...",0.12);
[Ifit,diagnostics.Preprocess] = ...
    desmostorm.analysis.image.autofit.preprocessForAutofit(I,debugOutput);

% Keep the sweep broad for now. We can later narrow this using a cluster/mask
% orientation prior once enough bad cases have been examined.
thetas = -90:1:89;

af(opts.ProgressDialog,"Scoring candidate rotation angles...",0.32);
angleScores = desmostorm.analysis.image.autofit.scoreRotationAngles( ...
    Ifit,ROI,config,thetas);
diagnostics.AngleScores = angleScores;

[theta,choice] = desmostorm.analysis.image.autofit.chooseRotationAngle(angleScores);
diagnostics.AngleChoice = choice;

if isnan(theta)
    desmostorm.Log.WARN("Auto-fit ROI failed to converge: no suitable rotation angle found.");
    af(opts.ProgressDialog,"ROI auto-fit failed to converge.",1);
    if debugOutput
        ROI.RotationAngle = NaN;
        desmostorm.analysis.image.autofit.showDebugOutput(I,Ifit,ROI,diagnostics);
    end
    ROI = [];
    return
end

ROI.RotationAngle = theta;
desmostorm.Log.DEBUG(sprintf( ...
    "Auto-fit ROI selected rotation angle %.2f deg using %s.", ...
    theta,choice.Method));

% Refine height first: the plaque pair is usually best resolved along this
% axis, and a cleaner height gives the width profile a better average.
af(opts.ProgressDialog,"Refining ROI height...",0.62);
[ROI,diagnostics.HeightRefinement] = ...
    desmostorm.analysis.image.autofit.refineROIHeight(Ifit,ROI,config);

% Width is the axis most likely to exceed the initial fitting ROI. Reset it to
% the largest centered width that still fits at the chosen angle/refined height,
% then refine inward from that generous starting point.
af(opts.ProgressDialog,"Refining ROI width...",0.80);
ROI.Width = desmostorm.analysis.image.autofit.maxCenteredWidthForRotation( ...
    W,H,ROI.RotationAngle,ROI.Height);
[ROI,diagnostics.WidthRefinement] = ...
    desmostorm.analysis.image.autofit.refineROIWidth(Ifit,ROI,config);

af(opts.ProgressDialog,"ROI auto-fit complete.",1);
desmostorm.Log.DEBUG(sprintf( ...
    "Auto-fit ROI result: center=(%.1f, %.1f), width=%.1f px, height=%.1f px, theta=%.2f deg.", ...
    ROI.CenterX,ROI.CenterY,ROI.Width,ROI.Height,ROI.RotationAngle));

if debugOutput
    desmostorm.analysis.image.autofit.showDebugOutput(I,Ifit,ROI,diagnostics);
end

end
