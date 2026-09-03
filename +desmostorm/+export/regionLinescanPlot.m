function regionLinescanPlot(region,filename,opts)
%DESMOSTORM.EXPORT.REGIONLINSCANPLOT  Export linescan plot for the given region
    arguments
        region      (1,1) desmostorm.model.STORMRegion
        filename    (1,:) char
        % plot appearance options
        opts.TitleVisible           (1,1) matlab.lang.OnOffSwitchState = "on"
        opts.DistanceAnnotations    (1,1) matlab.lang.OnOffSwitchState = "on"
        opts.DistanceAnnotationsMode (1,1) string {mustBeMember(opts.DistanceAnnotationsMode,["data","lanes"])} = "lanes"
        opts.WidthAnnotations       (1,1) matlab.lang.OnOffSwitchState = "on"
        opts.WidthAnnotationsMode   (1,1) string {mustBeMember(opts.WidthAnnotationsMode,["normal","hover"])} = "normal"
        opts.Channels               = "1"
        opts.CurrentChannel         (1,1) double {mustBeInteger,mustBePositive} = 1
        opts.RawLineWidth           (1,1) double = 1
        opts.RawLineColor           (1,3) double = [0.5 0.5 0.5]
        opts.SmoothLineWidth        (1,1) double = 1
        opts.SmoothLineColor        (1,3) double = [0 0 0]
        opts.Color                  (1,3) double = [0 0 0]
        opts.ColorSource            (1,1) string {mustBeMember(opts.ColorSource,["channel","manual"])} = "manual"
        opts.AnnotationColorMode    (1,1) string {mustBeMember(opts.AnnotationColorMode,["auto","manual"])} = "auto"
        opts.AnnotationColor        (1,3) double = [0 0 0]
        opts.ColorMode              (1,1) string {mustBeMember(opts.ColorMode,["auto","manual"])} = "auto"
        opts.AlphaMode              (1,1) string {mustBeMember(opts.AlphaMode,["auto","manual"])} = "auto"
        opts.XLabel                 (1,:) char = ''
        opts.YLabel                 (1,:) char = ''
        % export options
        opts.ContentType        (1,:) char {mustBeMember(opts.ContentType,{'vector','image'})} = 'vector'
        opts.Units              (1,:) char = 'inches'
        opts.Width              (1,1) double = 6.5
        opts.Height             (1,1) double = 3
        opts.BackgroundColor    = [1 1 1]
        opts.ForegroundColor    (1,3) double = [0 0 0]
        opts.ProgressDialog = matlab.ui.dialog.ProgressDialog.empty()
    end

    setProgressMessage(opts.ProgressDialog,'Preparing linescan plot...');

    W = opts.Width;
    H = opts.Height;
    plotBackgroundColor = resolvePlotBackgroundColor(opts.BackgroundColor);

    screenCenter = matlabx.ui.calibration.getScreenCenter(opts.Units);
    pos = [screenCenter(1) - W/2, screenCenter(2) - H/2, W, H];

    % create new figure
    fig = uifigure(...
        "WindowStyle","normal",...
        "Units",opts.Units,...
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

    % create a PeaksPlotContainer in the figure
    peaksPlotContainer = desmostorm.widgets.PeaksPlotContainer(g, ...
        "Data",plotData(:), ...
        "TitleVisible",opts.TitleVisible, ...
        "RawLineWidth",opts.RawLineWidth, ...
        "RawLineColor",opts.RawLineColor, ...
        "SmoothLineWidth",opts.SmoothLineWidth, ...
        "SmoothLineColor",opts.SmoothLineColor, ...
        "Color",opts.Color, ...
        "Colors",plotColors, ...
        "AnnotationColorMode",char(opts.AnnotationColorMode), ...
        "AnnotationColor",opts.AnnotationColor, ...
        "ColorMode",char(opts.ColorMode), ...
        "AlphaMode",char(opts.AlphaMode), ...
        "BackgroundColor",plotBackgroundColor, ...
        "ForegroundColor",opts.ForegroundColor, ...
        "DistanceAnnotations",opts.DistanceAnnotations, ...
        "DistanceAnnotationsMode",char(opts.DistanceAnnotationsMode), ...
        "WidthAnnotations",opts.WidthAnnotations, ...
        "WidthAnnotationsMode",char(opts.WidthAnnotationsMode), ...
        "XLabel",opts.XLabel, ...
        "YLabel",opts.YLabel);

    % draw and pause briefly for graphics to render
    drawnow
    pause(1)

    % Bring the main figure back to front immediately after the render pass
    % so the export figure disappears
    desmostorm.app.focusMainFigure();

    % --- export plot to specified file location ---
    setProgressMessage(opts.ProgressDialog,'Writing linescan plot...');
    peaksPlotContainer.export(filename, ...
        "BackgroundColor","none", ...
        "Units",opts.Units, ...
        "Height",opts.Height, ...
        "Width",opts.Width);
end

function setProgressMessage(h,msg)
    if ~isempty(h) && isvalid(h)
        h.Message = msg;
        drawnow limitrate
    end
end

function color = resolvePlotBackgroundColor(color)
    if isstring(color) || ischar(color)
        color = [1 1 1];
    end
end

function channels = resolveChannels(region,requested,currentChannel)
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
    if colorSource == "manual"
        colors = repmat(manualColor,numel(channels),1);
        return
    end

    project = region.Project;
    colors = zeros(numel(channels),3);
    for i = 1:numel(channels)
        colorName = project.getChannelColorName(channels(i));
        colors(i,:) = matlabx.colors.names.toRGB(char(colorName),"Palette","MATLAB");
    end
end
