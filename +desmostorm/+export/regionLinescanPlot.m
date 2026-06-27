function regionLinescanPlot(region,filename,opts)
%DESMOSTORM.EXPORT.REGIONLINSCANPLOT  Export linescan plot for the given region
    arguments
        region      (1,1) desmostorm.model.STORMRegion
        filename    (1,:) char
        % plot appearance options
        opts.TitleVisible           (1,1) matlab.lang.OnOffSwitchState = "on"
        opts.DistanceAnnotations    (1,1) matlab.lang.OnOffSwitchState = "on"
        opts.WidthAnnotations       (1,1) matlab.lang.OnOffSwitchState = "on"
        opts.RawLineWidth           (1,1) double = 1
        opts.RawLineColor           (1,3) double = [0.5 0.5 0.5]
        opts.SmoothLineWidth        (1,1) double = 1
        opts.SmoothLineColor        (1,3) double = [0 0 0]
        opts.XLabel                 (1,:) char = ''
        opts.YLabel                 (1,:) char = ''
        % export options
        opts.ContentType        (1,:) char {mustBeMember(opts.ContentType,{'vector','image'})} = 'vector'
        opts.Units              (1,:) char = 'inches'
        opts.Width              (1,1) double = 6.5
        opts.Height             (1,1) double = 3
        opts.BackgroundColor    = 'none'
    end

    W = opts.Width;
    H = opts.Height;

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
    % create a PeaksPlotContainer in the figure
    peaksPlotContainer = desmostorm.widgets.PeaksPlotContainer(g, ...
        "Data",region.LinescanResults(1), ...
        "TitleVisible",opts.TitleVisible, ...
        "RawLineWidth",opts.RawLineWidth, ...
        "RawLineColor",opts.RawLineColor, ...
        "SmoothLineWidth",opts.SmoothLineWidth, ...
        "SmoothLineColor",opts.SmoothLineColor, ...
        "DistanceAnnotations",opts.DistanceAnnotations, ...
        "WidthAnnotations",opts.WidthAnnotations, ...
        "XLabel",opts.XLabel, ...
        "YLabel",opts.YLabel);

    % draw and pause briefly for graphics to render
    drawnow
    pause(1)

    % --- export plot to specified file location ---
    peaksPlotContainer.export(filename, ...
        "BackgroundColor","none", ...
        "Units",opts.Units, ...
        "Height",opts.Height);
end