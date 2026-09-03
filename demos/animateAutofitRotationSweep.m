function animateAutofitRotationSweep(I,filename,opts)
%ANIMATEAUTOFITROTATIONSWEEP Create a GIF of ROI auto-fit stages.
%
% animateAutofitRotationSweep(I,filename) writes a presentation-oriented GIF
% showing one region crop, the current height/width linescan profiles, and the
% angle-score landscape used by the ROI auto-fit heuristic.

arguments
    I (:,:) {mustBeNumeric}
    filename (1,1) string
    opts.Config = []
    opts.Thetas (1,:) double = -90:1:89
    opts.FramesPerSecond (1,1) double {mustBePositive} = 24
    opts.FigureSize (1,2) double {mustBePositive} = [1450 460]
    opts.OutputScale (1,1) double {mustBePositive} = 1
    opts.SelectedAnglePauseFrames (1,1) double {mustBeInteger,mustBeNonnegative} = 8
    opts.HeightRefinementFrames (1,1) double {mustBeInteger,mustBeNonnegative} = 24
    opts.WidthRefinementFrames (1,1) double {mustBeInteger,mustBeNonnegative} = 24
    opts.FinalPauseFrames (1,1) double {mustBeInteger,mustBeNonnegative} = 12
    opts.ProfileXLim (1,2) double {mustBeFinite,mustBeIncreasing} = [-150 150]
    opts.ROISizeFraction (1,1) double {mustBeGreaterThan(opts.ROISizeFraction,0),mustBeLessThanOrEqual(opts.ROISizeFraction,1)} = 0.70
    opts.Colormap (:,3) double = hot(256)
end

I = double(I);
config = getConfig(opts.Config);
ROI = desmostorm.analysis.image.autofit.initialROI( ...
    size(I,1),size(I,2),"SizeFraction",opts.ROISizeFraction);
scoreData = desmostorm.analysis.image.autofit.scoreRotationAngles( ...
    I,ROI,config,opts.Thetas);
[selectedTheta,~] = desmostorm.analysis.image.autofit.chooseRotationAngle(scoreData);

firstFrame = true;
delayTime = 1 / opts.FramesPerSecond;

[fig,roiTool,heightPlot,widthPlot,scorePlot] = buildFigure(I,scoreData,opts);
cleaner = onCleanup(@() closeFigure(fig));

% Stage 1: sweep through candidate angles and show the changing linescan.
for frame = 1:numel(opts.Thetas)
    ROI.RotationAngle = opts.Thetas(frame);
    scorePlot.CurrentAngleLine.Value = ROI.RotationAngle;
    firstFrame = updateSceneAndWriteFrame( ...
        fig,filename,firstFrame,delayTime,I,config,ROI,roiTool,heightPlot,widthPlot);
end

if isnan(selectedTheta)
    return
end

% Stage 2: jump to the selected angle and pause briefly.
selectedROI = ROI;
selectedROI.RotationAngle = selectedTheta;
scorePlot.CurrentAngleLine.Value = selectedTheta;
firstFrame = updateSceneAndWriteFrame( ...
    fig,filename,firstFrame,delayTime,I,config,selectedROI,roiTool,heightPlot,widthPlot);
for frame = 1:opts.SelectedAnglePauseFrames
    firstFrame = writeGifFrame(fig,filename,firstFrame,delayTime);
end

% Stage 3: animate height refinement.
heightRefinedROI = desmostorm.analysis.image.autofit.refineROIHeight( ...
    I,selectedROI,config);
for frame = 1:opts.HeightRefinementFrames
    t = smoothstep(frame / max(opts.HeightRefinementFrames,1));
    ROI = interpolateROI(selectedROI,heightRefinedROI,t);
    firstFrame = updateSceneAndWriteFrame( ...
        fig,filename,firstFrame,delayTime,I,config,ROI,roiTool,heightPlot,widthPlot);
end

% Stage 4: animate width refinement directly from the height-refined ROI.
widthRefinedROI = desmostorm.analysis.image.autofit.refineROIWidth( ...
    I,heightRefinedROI,config);
for frame = 1:opts.WidthRefinementFrames
    t = smoothstep(frame / max(opts.WidthRefinementFrames,1));
    ROI = interpolateROI(heightRefinedROI,widthRefinedROI,t);
    firstFrame = updateSceneAndWriteFrame( ...
        fig,filename,firstFrame,delayTime,I,config,ROI,roiTool,heightPlot,widthPlot);
end

% Hold the final fitted ROI long enough to read before the GIF loops.
for frame = 1:opts.FinalPauseFrames
    firstFrame = writeGifFrame(fig,filename,firstFrame,delayTime);
end
end

function [fig,roiTool,heightPlot,widthPlot,scorePlot] = buildFigure(I,scoreData,opts)
%BUILDFIGURE Create the UI components used by the animation frames.
fontSize = 12 * opts.OutputScale;
figureSize = round(opts.FigureSize .* opts.OutputScale);
imageAxesTopChromePx = matlabx.UICal.get().uipanelTopChromeHeightPx(fontSize);
imageAxesHeightPx = figureSize(2);
imageAxesWidthPx = imageAxesHeightPx - imageAxesTopChromePx;

fig = uifigure( ...
    "Name","Auto-fit rotation sweep", ...
    "Visible","on", ...
    "Color",[1 1 1], ...
    "InnerPosition",[100 100 figureSize]);

layout = uigridlayout(fig,[1 3], ...
    "ColumnWidth",{imageAxesWidthPx,"1x","1x"}, ...
    "RowHeight",{imageAxesHeightPx}, ...
    "Padding",[0 0 0 0], ...
    "ColumnSpacing",8 * opts.OutputScale, ...
    "BackgroundColor",[1 1 1]);

img = matlabx.image.Image5D.fromComponents({I},"Names","Region");
imageAx = matlabx.ui.axes.ImageAxes(layout, ...
    "Name","Region crop", ...
    "Tools",{'DrawRectangle'}, ...
    "ImageData",img, ...
    "Colormap",opts.Colormap, ...
    "FontSize",fontSize);
imageAx.Layout.Row = 1;
imageAx.Layout.Column = 1;
imageAx.setComponentColormap(opts.Colormap,1);

roiTool = imageAx.Tools.DrawRectangle;
roiTool.RotationAngleMode = 'half-circle';
roiTool.RotationAngleVisible = "on";
roiTool.ROIColor = [1 1 1];
roiTool.AnnotationLineColor = [1 1 1];
roiTool.FontColor = [1 1 1];
roiTool.ROIFaceAlpha = 0;
roiTool.ROILineWidth = 2 * opts.OutputScale;
roiTool.AnnotationLineWidth = 1 * opts.OutputScale;
roiTool.FontSize = fontSize;

profileLayout = uigridlayout(layout,[2 1], ...
    "ColumnWidth",{"1x"}, ...
    "RowHeight",{"1x","1x"}, ...
    "Padding",[0 0 0 0], ...
    "RowSpacing",8 * opts.OutputScale, ...
    "BackgroundColor",[1 1 1]);
profileLayout.Layout.Row = 1;
profileLayout.Layout.Column = 2;

heightPlot = makeProfilePlot(profileLayout,"Height profile",fontSize,opts.OutputScale,opts.ProfileXLim);
heightPlot.Layout.Row = 1;
heightPlot.Layout.Column = 1;

widthPlot = makeProfilePlot(profileLayout,"Width profile",fontSize,opts.OutputScale,opts.ProfileXLim);
widthPlot.Layout.Row = 2;
widthPlot.Layout.Column = 1;

scoreAx = uiaxes(layout);
scoreAx.Layout.Row = 1;
scoreAx.Layout.Column = 3;
scorePlot = desmostorm.analysis.image.autofit.plotAngleScores(scoreAx,scoreData, ...
    "CurrentTheta",opts.Thetas(1), ...
    "Title","Angle score", ...
    "FontSize",fontSize, ...
    "LineScale",opts.OutputScale);
end

function peaksPlot = makeProfilePlot(parent,titleText,fontSize,lineScale,xLim)
%MAKEPROFILEPLOT Create one profile plot with presentation-friendly styling.
peaksPlot = desmostorm.widgets.PeaksPlotContainer(parent, ...
    "Title",titleText, ...
    "TitleVisible",true, ...
    "XLabel","Distance (px)", ...
    "YLabel","Normalized intensity", ...
    "DistanceAnnotations","on", ...
    "DistanceAnnotationsMode","lanes", ...
    "WidthAnnotations","on", ...
    "WidthAnnotationsMode","normal", ...
    "ColorMode","auto", ...
    "AlphaMode","auto", ...
    "Color",[0.05 0.25 0.85], ...
    "AnnotationColorMode","auto", ...
    "BackgroundColor",[1 1 1], ...
    "ForegroundColor",[0 0 0], ...
    "FontColor",[0 0 0], ...
    "FontSize",fontSize, ...
    "AnnotationsFontSize",10 * lineScale, ...
    "AnnotationsMargin",lineScale, ...
    "RawLineWidth",lineScale, ...
    "SmoothLineWidth",lineScale, ...
    "XLim",xLim);
end

function updateProfilePlots(I,config,ROI,heightPlot,widthPlot)
%UPDATEPROFILEPLOTS Refresh both linescan profile plots for the current ROI.
heightPlot.Data = desmostorm.analysis.image.autofit.analyzeROIHeightProfile( ...
    I,ROI,config,ROI.RotationAngle);
widthPlot.Data = desmostorm.analysis.image.autofit.analyzeROIWidthProfile( ...
    I,ROI,config);
end

function firstFrame = updateSceneAndWriteFrame(fig,filename,firstFrame,delayTime,I,config,ROI,roiTool,heightPlot,widthPlot)
%UPDATESCENEANDWRITEFRAME Update ROI/profile visuals and append one GIF frame.
updateProfilePlots(I,config,ROI,heightPlot,widthPlot);
roiTool.setROIPosition(ROI);
drawnow;
firstFrame = writeGifFrame(fig,filename,firstFrame,delayTime);
end

function ROI = interpolateROI(ROI1,ROI2,t)
%INTERPOLATEROI Interpolate ROI geometry between two fitting stages.
fields = ["CenterX","CenterY","Width","Height","RotationAngle"];
ROI = ROI1;
for i = 1:numel(fields)
    f = fields(i);
    ROI.(f) = ROI1.(f) + (ROI2.(f) - ROI1.(f)) * t;
end
end

function t = smoothstep(t)
%SMOOTHSTEP Ease stage transitions without changing endpoints.
t = max(0,min(1,t));
t = t * t * (3 - 2 * t);
end

function firstFrame = writeGifFrame(fig,filename,firstFrame,delayTime)
%WRITEGIFFRAME Capture the current UI figure and append it to the GIF.
im = getframe(fig);
[A,map] = rgb2ind(im.cdata,256);

if firstFrame
    firstFrame = false;
    imwrite(A,map,filename,LoopCount=Inf,DelayTime=delayTime);
else
    imwrite(A,map,filename,WriteMode="append",DelayTime=delayTime);
end
end

function config = getConfig(config)
%GETCONFIG Use app analysis defaults unless the caller supplies a config.
if isempty(config)
    settings = desmostorm.config.Settings();
    config = desmostorm.config.RunConfig.fromSettings(settings);
end
end

function closeFigure(fig)
%CLOSEFIGURE Quietly close the UI figure when the GIF is complete or errors.
if ~isempty(fig) && isvalid(fig)
    close(fig);
end
end

function mustBeIncreasing(v)
%MUSTBEINCREASING Validate a two-element increasing numeric vector.
if numel(v) ~= 2 || ~(v(2) > v(1))
    error("animateAutofitRotationSweep:InvalidXLim", ...
        "ProfileXLim must be a two-element increasing vector.");
end
end
