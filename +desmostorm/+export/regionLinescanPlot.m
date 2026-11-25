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

function regionLinescanPlot(region,filename,opts)
%DESMOSTORM.EXPORT.REGIONLINSCANPLOT  Export linescan plot for the given region
    arguments
        region      (1,1) desmostorm.model.STORMRegion
        filename    (1,:) char
        % plot appearance options
        opts.FontSize (1,1) double {mustBePositive,mustBeFinite} = 9
        opts.AnnotationFontSize (1,1) double {mustBePositive,mustBeFinite} = 7
        opts.TitleFontSizeMultiplier (1,1) double {mustBePositive,mustBeFinite} = 1
        opts.LabelFontSizeMultiplier (1,1) double {mustBePositive,mustBeFinite} = 1
        opts.TitleVisible           (1,1) matlab.lang.OnOffSwitchState = "off"
        opts.DistanceAnnotations    (1,1) matlab.lang.OnOffSwitchState = "on"
        opts.DistanceAnnotationsMode (1,1) string {mustBeMember(opts.DistanceAnnotationsMode,["data","lanes"])} = "data"
        opts.WidthAnnotations       (1,1) matlab.lang.OnOffSwitchState = "on"
        opts.WidthAnnotationsMode   (1,1) string {mustBeMember(opts.WidthAnnotationsMode,["normal","hover"])} = "normal"
        opts.Channels               = "1"
        opts.CurrentChannel         (1,1) double {mustBeInteger,mustBePositive} = 1
        opts.RawLineWidth           (1,1) double = 0.5
        opts.RawLineColor           (1,3) double = [0.5 0.5 0.5]
        opts.SmoothLineWidth        (1,1) double = 1
        opts.AnnotationLineWidth (1,1) double {mustBePositive,mustBeFinite} = 0.5
        opts.SmoothLineColor        (1,3) double = [0 0 0]
        opts.Color                  (1,3) double = [0 0 0]
        opts.ColorSource            (1,1) string {mustBeMember(opts.ColorSource,["channel","manual"])} = "manual"
        opts.AnnotationColorMode    (1,1) string {mustBeMember(opts.AnnotationColorMode,["auto","manual"])} = "auto"
        opts.AnnotationColor        (1,3) double = [0 0 0]
        opts.ColorMode              (1,1) string {mustBeMember(opts.ColorMode,["auto","manual"])} = "auto"
        opts.AlphaMode              (1,1) string {mustBeMember(opts.AlphaMode,["auto","manual"])} = "auto"
        opts.XLabel                 (1,:) char = ''
        opts.YLabel                 (1,:) char = ''
        opts.StyleSizing (1,1) string {mustBeMember(opts.StyleSizing,["physical","scale"])} = "physical"
        opts.PreserveAspectRatio (1,1) matlab.lang.OnOffSwitchState = "off"
        opts.Resolution (1,1) double {mustBePositive,mustBeFinite} = 300
        % export options
        opts.ContentType        (1,:) char {mustBeMember(opts.ContentType,{'vector','image'})} = 'vector'
        opts.Units              (1,:) char = 'inches'
        opts.Width              double = 6.5
        opts.Height             double = 3
        opts.AspectRatio        (1,1) double {mustBePositive,mustBeFinite} = 6.5/3
        opts.AxesAppearance     (1,1) struct = struct()
        opts.AxesView           (1,1) struct = struct()
        opts.BackgroundColor    = [1 1 1]
        opts.ForegroundColor    (1,3) double = [0 0 0]
        opts.ProgressDialog = matlab.ui.dialog.ProgressDialog.empty()
    end

    desmostorm.runtime.updateProgress(opts.ProgressDialog,'Preparing linescan plot...');

    width = opts.Width;
    height = opts.Height;
    if isempty(width) && isempty(height)
        error('desmostorm:export:MissingPlotSize','Specify a plot width or height.');
    elseif isempty(width)
        width = height * opts.AspectRatio;
    elseif isempty(height)
        height = width / opts.AspectRatio;
    end
    validateattributes(width,{'double'},{'scalar','positive','finite'});
    validateattributes(height,{'double'},{'scalar','positive','finite'});
    figureSize = desmostorm.export.outputSizeInches([width height],opts.Units,opts.Resolution);
    if opts.StyleSizing == "scale"
        figureSize = [6.5 3];
    end
    % Width and height of the temporary rendering figure in inches.
    W = figureSize(1);
    H = figureSize(2);
    plotBackgroundColor = resolvePlotBackgroundColor(opts.BackgroundColor);

    screenCenter = matlabx.ui.calibration.getScreenCenter("inches");
    pos = [screenCenter(1) - W/2, screenCenter(2) - H/2, W, H];

    % create new figure
    fig = uifigure(...
        "WindowStyle","normal",...
        "Units","inches",...
        "InnerPosition",pos);

    % close figure on function completion
    c = onCleanup(@() delete(fig));

    % add grid with a single row and column
    g = uigridlayout(fig,[1,1],...
        "ColumnWidth",{'1x'},...
        "RowHeight",{'1x'},...
        "Padding",[0 0 0 0]);

    channels = resolveChannels(region,opts.Channels,opts.CurrentChannel);
    plotData = region.LinescanResults(channels);
    plotColors = resolvePlotColors(region,channels,opts.Color,opts.ColorSource);

    img = region.Parent;
    names = img.channelNames();
    data = desmostorm.plot.PeaksPlotData(plotData, ...
        ChannelIDs=img.ChannelIDs(channels),Names=names(channels));
    style = desmostorm.plot.PeaksPlotStyle( ...
        Colors=plotColors,AnnotationColors=manualAnnotationColor(opts), ...
        RawLineWidth=opts.RawLineWidth,SmoothLineWidth=opts.SmoothLineWidth, ...
        AnnotationLineWidth=opts.AnnotationLineWidth,AnnotationsFontSize=opts.AnnotationFontSize, ...
        BackgroundColor=plotBackgroundColor,ForegroundColor=opts.ForegroundColor, ...
        DistanceAnnotations=opts.DistanceAnnotations,DistanceAnnotationsMode=opts.DistanceAnnotationsMode, ...
        WidthAnnotations=opts.WidthAnnotations,WidthAnnotationsMode=opts.WidthAnnotationsMode);
    % Retain explicit trace overrides accepted by this export entry point.
    if opts.ColorMode == "manual"
        style.RawLineColor = opts.RawLineColor;
        style.SmoothLineColor = opts.SmoothLineColor;
    end
    if opts.AlphaMode == "manual", style.RawLineAlpha = 0.5; end

    % Container for the controls or graphics created below.
    host = matlabx.ui.axes.PlotAxes(g,FontName="Arial",FontSize=opts.FontSize, ...
        TitleFontSizeMultiplier=opts.TitleFontSizeMultiplier,LabelFontSizeMultiplier=opts.LabelFontSizeMultiplier, ...
        TitleVisible=opts.TitleVisible,ToolbarVisible="off");
    renderer = desmostorm.plot.PeaksPlotRenderer();
    % Release the temporary object when this scope exits.
    cleanupRenderer = onCleanup(@() delete(renderer));
    renderer.update(data,style);
    host.mount(renderer);
    xlabel(host.Axes,opts.XLabel);
    ylabel(host.Axes,opts.YLabel);
    title(host.Axes,matlabx.utils.text.texFriendly(img.Name) + " | " + ...
        matlabx.utils.text.texFriendly(region.Name));

    % Canvas or container background color.
    background = opts.BackgroundColor;
    axesColor = opts.BackgroundColor;
    appearance = opts.AxesAppearance;
    if isfield(appearance,"BackgroundColorOverride") && ~isempty(appearance.BackgroundColorOverride)
        background = appearance.BackgroundColorOverride;
    end
    if isfield(appearance,"AxesColorOverride") && ~isempty(appearance.AxesColorOverride)
        axesColor = appearance.AxesColorOverride;
    end
    % Process the named fields in appearance.
    for name = reshape(string(fieldnames(appearance)),1,[])
        if ~ismember(name,["BackgroundColorOverride","AxesColorOverride"])
            host.(name) = appearance.(name);
        end
    end
    viewArgs = namedargs2cell(opts.AxesView);
    host.setAxesView(viewArgs{:});

    % draw and pause briefly for graphics to render
    drawnow
    pause(1)

    % Bring the main figure back to front immediately after the render pass
    % so the export figure disappears
    desmostorm.app.focusMainFigure();

    % --- export plot to specified file location ---
    desmostorm.runtime.updateProgress(opts.ProgressDialog,'Writing linescan plot...');
    host.exportPlot(filename,ContentType=opts.ContentType, ...
        BackgroundColor=background,Color=axesColor,Units=opts.Units, ...
        Height=opts.Height,Width=opts.Width,Resolution=opts.Resolution, ...
        StyleSizing=opts.StyleSizing, ...
        PreserveAspectRatio=logical(opts.PreserveAspectRatio) || opts.StyleSizing == "physical" || ...
            isempty(opts.Width) || isempty(opts.Height));
end

function color = resolvePlotBackgroundColor(color)
%RESOLVEPLOTBACKGROUNDCOLOR Resolve plot background color.
    if isstring(color) || ischar(color)
        color = [1 1 1];
    end
end

function channels = resolveChannels(region,requested,currentChannel)
%RESOLVECHANNELS Resolve channels.
    % Number of channels to process.
    nChannels = numel(region.LinescanResults);

    if isnumeric(requested)
        channels = requested;
    else
        requested = string(requested);
        if isscalar(requested)
            switch requested
                case "all"
                    channels = 1:nChannels;
                case "current"
                    channels = currentChannel;
                otherwise
                    channels = str2double(requested);
            end
        else
            channels = str2double(requested);
        end
    end

    channels = channels(:).';
    channels = channels(isfinite(channels) & channels >= 1 & channels <= nChannels);
    channels = unique(channels,"stable");

    if isempty(channels)
        error('desmostorm:export:regionLinescanPlot:NoChannels', ...
            'No linescan data found for the selected channel(s).')
    end
end

function colors = resolvePlotColors(region,channels,manualColor,colorSource)
%RESOLVEPLOTCOLORS Resolve plot colors.
    if colorSource == "manual"
        colors = repmat(manualColor,numel(channels),1);
        return
    end

    project = region.Project;
    colors = zeros(numel(channels),3);
    % Process each source channel in its original component order.
    for i = 1:numel(channels)
        colors(i,:) = project.getChannelRGB(region.Parent.ChannelIDs(channels(i)));
    end
end

function colors = manualAnnotationColor(opts)
%MANUALANNOTATIONCOLOR Return an explicit annotation color when manual mode is selected.
    colors = zeros(0,3);
    if opts.AnnotationColorMode == "manual", colors = opts.AnnotationColor; end
end
