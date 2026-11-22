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

function summaryPDF(project, filename, config, opts)
%SUMMARYPDF  Export per-region image, ROI summary, and linescan plots to PDF.

arguments
    project (1,1) desmostorm.model.STORMProject
    filename {mustBeTextScalar}
    config (1,1) desmostorm.config.Settings
    opts.ProgressDialog = matlab.ui.dialog.ProgressDialog.empty()
    opts.ImageChannel (1,1) string = "1"
    opts.ScalingMode (1,1) string {mustBeMember(opts.ScalingMode,["data","auto","user"])} = "data"
    opts.ColorSource (1,1) string {mustBeMember(opts.ColorSource,["channel","manual"])} = "manual"
    opts.Color (1,3) double = [0 0 0]
    opts.AnnotationColorMode (1,1) string {mustBeMember(opts.AnnotationColorMode,["auto","manual"])} = "auto"
    opts.AnnotationColor (1,3) double = [0 0 0]
    opts.BackgroundColor (1,3) double = [1 1 1]
    opts.ForegroundColor (1,3) double = [0 0 0]
    opts.DistanceAnnotations (1,1) matlab.lang.OnOffSwitchState = "on"
    opts.DistanceAnnotationsMode (1,1) string {mustBeMember(opts.DistanceAnnotationsMode,["data","lanes"])} = "data"
    opts.WidthAnnotations (1,1) matlab.lang.OnOffSwitchState = "on"
    opts.WidthAnnotationsMode (1,1) string {mustBeMember(opts.WidthAnnotationsMode,["normal","hover"])} = "normal"
    opts.ROIFaceAlpha (1,1) double = 0
    opts.RotationAngleVisible (1,1) matlab.lang.OnOffSwitchState = "on"
    opts.AngleLabelFontSize (1,1) double {mustBePositive,mustBeFinite} = config.ROI.FontSize
    opts.RawLineWidth (1,1) double = 0.5
    opts.SmoothLineWidth (1,1) double = 2
    opts.AnnotationLineWidth (1,1) double {mustBePositive,mustBeFinite} = 0.5
    opts.AnnotationFontSize (1,1) double {mustBePositive,mustBeFinite} = 10
    opts.TitleVisible (1,1) matlab.lang.OnOffSwitchState = "off"
    opts.TitleFontSizeMultiplier (1,1) double {mustBePositive,mustBeFinite} = 1
    opts.LabelFontSizeMultiplier (1,1) double {mustBePositive,mustBeFinite} = 1
    opts.ContentType (1,1) string {mustBeMember(opts.ContentType,["vector","image"])} = "vector"
    opts.ImageResolution (1,1) double {mustBePositive,mustBeFinite} = 600
    opts.Resolution (1,1) double {mustBePositive,mustBeFinite} = 300
    opts.StyleSizing (1,1) string {mustBeMember(opts.StyleSizing,["physical","scale"])} = "physical"
    opts.PlotFontSize (1,1) double {mustBePositive,mustBeFinite} = config.PeaksPlot.FontSize
    opts.PageWidthInches (1,1) double = 11
    opts.FontSizePoints (1,1) double = 8
end

    imgs = project.ImageArray;
    if isempty(imgs)
        return
    end

    % Convert page and text settings to pixels because uifigure layout uses
    % screen units, while the export dialog exposes print-oriented units.
    fontSizePx = matlabx.UICal.pt2px(opts.FontSizePoints);
    layoutWidth = opts.PageWidthInches;
    if opts.StyleSizing == "scale", layoutWidth = 11; end
    pageWidthPx = layoutWidth * matlabx.UICal.pixelsPerInch();

    % Keep the page compact and predictable: the export figure is a single
    % row with linescan plot, region image, and per-channel summary text.
    padding = 5;
    spacing = 5;

    figHeight = pageWidthPx/4;
    gridHeight = figHeight-padding*2;

    % The embedded image contains only the axes view and fills a square.
    imgWidth = gridHeight;
    remainingWidth = pageWidthPx-2*padding-2*spacing-imgWidth;
    if imgWidth <= 0 || remainingWidth <= 0
        error('desmostorm:export:summaryPDF:PageTooSmall','Increase the page width.');
    end
    plotWidth = 2*remainingWidth/3;
    tableWidth = remainingWidth-plotWidth;

    % Initialize temporary files and folder for PDF export
    tempFolder = char(tempname);
    mkdir(tempFolder);
    cleanupTempFolder = onCleanup(@() removeTempFolder(tempFolder));

    % Expand the requested channel selection into concrete pages. "all"
    % becomes one page per region per available channel.
    pages = collectPages(imgs, opts.ImageChannel);
    if isempty(pages)
        return
    end

    layoutSize = [pageWidthPx figHeight];
    pageSize = 72 * opts.PageWidthInches * [1 figHeight/pageWidthPx];
    plotRect = [padding padding plotWidth gridHeight];
    imageRect = [padding+plotWidth+spacing padding imgWidth imgWidth];
    pointScale = [pageSize./layoutSize pageSize./layoutSize];
    pdfCommand = summaryPDFCommand(tempFolder,numel(pages),pageSize, ...
        plotRect .* pointScale,imageRect .* pointScale);

    % Use first page content to initialize graphics components
    img = pages(1).Image;
    reg = pages(1).Region;
    channel = pages(1).Channel;
    regImageData = matlabx.image.Image5D.fromComponents(img.regionSubimageCell(reg));


    % Build the temporary export figure hidden, then briefly show it below
    % after the components exist. That visible render pass prevents blurry
    % ROI overlays while limiting the export figure to a quick flash.
    f = uifigure("WindowStyle","normal", ...
        "Visible","off", ...
        "Position",[0 0 pageWidthPx figHeight]);
    cleanupFig = onCleanup(@() closeFigure(f));
    
    movegui(f,'center')
    
    g = uigridlayout(f,[1,3], ...
        "RowHeight",{gridHeight}, ...
        "ColumnWidth",{plotWidth,imgWidth,tableWidth}, ...
        "ColumnSpacing",spacing, ...
        "Padding",repmat(padding,1,4), ...
        "BackgroundColor",[1 1 1]);
    
    annotationColors = zeros(0,3);
    if opts.AnnotationColorMode == "manual", annotationColors = opts.AnnotationColor; end
    style = desmostorm.plot.PeaksPlotStyle( ...
        AnnotationColors=annotationColors,RawLineWidth=opts.RawLineWidth, ...
        SmoothLineWidth=opts.SmoothLineWidth,AnnotationLineWidth=opts.AnnotationLineWidth, ...
        AnnotationsFontSize=opts.AnnotationFontSize, ...
        BackgroundColor=opts.BackgroundColor,ForegroundColor=opts.ForegroundColor, ...
        DistanceAnnotations=opts.DistanceAnnotations,DistanceAnnotationsMode=opts.DistanceAnnotationsMode, ...
        WidthAnnotations=opts.WidthAnnotations,WidthAnnotationsMode=opts.WidthAnnotationsMode);
    p = matlabx.ui.axes.PlotAxes(g,FontName="Arial",FontSize=opts.PlotFontSize, ...
        FontUnits="points",TitleVisible=opts.TitleVisible,ToolbarVisible="off", ...
        TitleFontSizeMultiplier=opts.TitleFontSizeMultiplier,LabelFontSizeMultiplier=opts.LabelFontSizeMultiplier);
    p.Layout.Row = 1;
    p.Layout.Column = 1;
    renderer = desmostorm.plot.PeaksPlotRenderer();
    cleanupRenderer = onCleanup(@() delete(renderer));
    renderer.update(desmostorm.plot.PeaksPlotData(),style);
    p.mount(renderer);
    yLabel = "Intensity";
    if config.Analysis.Normalize, yLabel = "Normalized intensity"; end
    ylabel(p.Axes,yLabel);

    ax = matlabx.ui.axes.ImageAxes(g, ...
        'ImageData',regImageData, ...
        'Name','RegionViewer', ...
        'Tools',{'DrawRectangle'}, ...
        'Colormap',project.getChannelColormap(img.ChannelIDs(channel)), ...
        'ComponentColorMode',config.Display.ChannelColorMode, ...
        'FontSize', fontSizePx);

    ax.Layout.Row = 1;
    ax.Layout.Column = 2;
    applyROISettings(ax.Tools.DrawRectangle,config.ROI,opts);
    ax.setComponentCLim(desmostorm.export.imageDisplayLimits(img,channel,opts.ScalingMode,config.Display),channel);

    ax.Tools.DrawRectangle.setROIPosition(reg.ROI);

    l = uilabel(g, ...
        "Text",reg.TextSummaryTable(channel), ...
        "BackgroundColor",[1 1 1], ...
        "FontColor",[0 0 0], ...
        "HorizontalAlignment","left", ...
        "VerticalAlignment","top", ...
        "FontName","courier", ...
        "FontSize",fontSizePx);
    l.Layout.Row = 1;
    l.Layout.Column = 3;

    % pause BEFORE draw or ROI will not render correctly
    pause(1)
    f.Visible = 'on';
    drawnow

    % Bring the main figure back to front immediately after the render pass
    % so the export figure disappears before the page loop starts.
    desmostorm.app.focusMainFigure();

    % Hiding after the initial draw avoids putting the export figure in the
    % user's way without triggering the blurry first-render export path.
    f.Visible = 'off';

    for pageIdx = 1:numel(pages)
        img = pages(pageIdx).Image;
        reg = pages(pageIdx).Region;
        channel = pages(pageIdx).Channel;
    
        desmostorm.runtime.updateProgress(opts.ProgressDialog, ...
            sprintf('Exporting peak plots (%i/%i): %s | %s | C%i', ...
            pageIdx,numel(pages),img.Name,reg.Name,channel),pageIdx-1,numel(pages));

        % --- Linescan plot ---
        % data
        if channel <= numel(reg.LinescanResults)
            data = desmostorm.plot.PeaksPlotData(reg.LinescanResults(channel), ...
                ChannelIDs=img.ChannelIDs(channel),Names=img.channelName(channel));
        else
            data = desmostorm.plot.PeaksPlotData();
        end

        title(p.Axes,sprintf("%s | %s | %s",matlabx.utils.text.texFriendly(img.Name), ...
            matlabx.utils.text.texFriendly(reg.Name),matlabx.utils.text.texFriendly(img.channelName(channel))));
        xlabel(p.Axes,"Distance (" + img.PixelSize.Unit + ")");
        style.Colors = resolvePlotColor(project,img.ChannelIDs(channel),opts.Color,opts.ColorSource);
        renderer.update(data,style);

        % ImageAxes handles multi-component images as a cell array and the
        % active component is selected with C. Keep display scaling matched
        % to the channel shown on the current page.
        Icell = img.regionSubimageCell(reg);
        ax.CData = Icell;
        ax.C = channel;

        ax.setComponentCLim(desmostorm.export.imageDisplayLimits(img,channel,opts.ScalingMode,config.Display),channel);

        switch config.Display.ChannelColorMode
            case 'colors'
                ax.setComponentColor(project.getChannelColorName(img.ChannelIDs(channel)),channel);
            case 'luts'
                ax.setComponentColormap(project.getChannelColormap(img.ChannelIDs(channel)),channel);
        end
    
        ax.Tools.DrawRectangle.setROIPosition(reg.ROI);
        l.Text = reg.TextSummaryTable(channel);

        % Give graphics objects a short beat to settle before exportapp
        % snapshots the UI. The first page needs the full component warm-up.
        drawnow
        if pageIdx == 1
            pause(1)
        else
            pause(0.1)
        end
    
        % Export the plot independently so a vector plot remains vector
        % when placed alongside the captured image and summary text.
        plotInches = plotRect(3:4) ./ layoutSize .* (pageSize / 72);
        renderInches = plotRect(3:4) / matlabx.UICal.pixelsPerInch();
        plotDPI = opts.Resolution * plotInches(1) / renderInches(1);
        plotFile = fullfile(tempFolder,sprintf('plot-%d.pdf',pageIdx));
        baseFile = fullfile(tempFolder,sprintf('layout-%d.pdf',pageIdx));
        p.exportPlot(plotFile,ContentType=opts.ContentType, ...
            Units="inches",Width=renderInches(1),Height=renderInches(2), ...
            Resolution=plotDPI,BackgroundColor=opts.BackgroundColor,StyleSizing=opts.StyleSizing);
        % Render the region image and ROI directly from the image axes.
        % Render at the layout size and adjust DPI for the final PDF scale.
        imageInches = imgWidth / matlabx.UICal.pixelsPerInch();
        imageDPI = opts.ImageResolution * opts.PageWidthInches / layoutWidth;
        imageFile = fullfile(tempFolder,sprintf('image-%d.png',pageIdx));
        ax.exportView(imageFile,Units="inches",Width=imageInches,Height=imageInches, ...
            Resolution=imageDPI,PreserveAspectRatio="on",OverlaySizing=opts.StyleSizing);
        p.Visible = "off";
        ax.Visible = "off";
        drawnow
        exportapp(f,baseFile);
        ax.Visible = "on";
        p.Visible = "on";

    end

    closeFigure(f);
    desmostorm.runtime.updateProgress(opts.ProgressDialog,"Assembling summary PDF...");
    logFile = fullfile(tempFolder,'pdfbox.log');
    pdfCommand.redirectErrorStream(true);
    pdfCommand.redirectOutput(java.io.File(logFile));
    try
        process = pdfCommand.start();
    catch cause
        failure = MException('desmostorm:export:summaryPDF:JavaLaunchFailed', ...
            'Could not start Java for Summary PDF export. %s',cause.message);
        throw(addCause(failure,cause));
    end
    if process.waitFor() ~= 0
        error('desmostorm:export:summaryPDF:AssemblyFailed', ...
            'PDFBox could not assemble the summary PDF. %s',strtrim(fileread(logFile)));
    end
    output = fullfile(tempFolder,'summary.pdf');
    [ok,message] = movefile(output,filename,'f');
    if ~ok, error('desmostorm:export:summaryPDF:WriteFailed','%s',message); end
    desmostorm.runtime.updateProgress(opts.ProgressDialog,"Summary PDF complete.",1);
end

function command = summaryPDFCommand(folder,pageCount,pageSize,plotRect,imageRect)
    appRoot = fileparts(fileparts(fileparts(which('desmostorm.export.summaryPDF'))));
    dependencyFolder = fullfile(appRoot,'external','pdfbox');
    jars = fullfile(dependencyFolder,["pdfbox-app-3.0.8.jar","desmostorm-summary-pdf.jar"]);
    if ~all(isfile(jars))
        error('desmostorm:export:summaryPDF:MissingPDFBox', ...
            'Summary PDF export is missing a bundled JAR in %s.',dependencyFolder);
    end
    if ~usejava('jvm')
        error('desmostorm:export:summaryPDF:JavaUnavailable', ...
            'Summary PDF export requires MATLAB to run with Java enabled.');
    end
    executable = "java";
    if ispc, executable = "java.exe"; end
    javaHome = char(javaMethod('getProperty','java.lang.System','java.home'));
    launcher = fullfile(javaHome,"bin",executable);
    if ~isfile(launcher), launcher = executable; end

    values = compose("%.17g",[pageCount pageSize plotRect imageRect]);
    args = [launcher,"-Djava.awt.headless=true","-cp",join(jars,pathsep), ...
        "SummaryPDF",string(folder),values];
    commandArgs = java.util.ArrayList();
    for i = 1:numel(args)
        commandArgs.add(java.lang.String(char(args(i))));
    end
    command = javaObject('java.lang.ProcessBuilder',commandArgs);
end

function pages = collectPages(imgs, imageChannel)
    pages = struct('Image',{},'Region',{},'Channel',{});
    exportAll = strcmpi(imageChannel, "all");
    
    if ~exportAll
        channel = str2double(imageChannel);
        if isnan(channel) || channel < 1 || channel ~= round(channel)
            error('desmostorm:export:summaryPDF:InvalidImageChannel', ...
                'ImageChannel must be a positive integer or "all".');
        end
    end
    
    for i = 1:numel(imgs)
        regs = imgs(i).RegionArray;
        if isempty(regs)
            continue
        end
    
        if exportAll
            channels = 1:imgs(i).SizeC;
        else
            channels = imgs(i).sourceChannelIndex(channel);
        end
    
        for j = 1:numel(regs)
            for c = channels
                pages(end+1).Image = imgs(i);
                pages(end).Region = regs(j);
                pages(end).Channel = c;
            end
        end
    end
end

function color = resolvePlotColor(project,channel,manualColor,colorSource)
    if colorSource == "manual"
        color = manualColor;
        return
    end

    color = project.getChannelRGB(channel);
end

function applyROISettings(tool,roiConfig,opts)
    tool.ROIColor = roiConfig.ROIColor;
    tool.ROILineWidth = roiConfig.ROILineWidth;
    tool.ROIFaceAlpha = opts.ROIFaceAlpha;
    tool.ROIMarkerSize = roiConfig.ROIMarkerSize;
    tool.AnnotationLineColor = roiConfig.AnnotationLineColor;
    tool.AnnotationLineWidth = roiConfig.AnnotationLineWidth;
    tool.RotationAngleMode = roiConfig.RotationAngleMode;
    tool.RotationAngleVisible = opts.RotationAngleVisible;
    tool.FontSize = opts.AngleLabelFontSize;
    tool.FontColor = roiConfig.FontColor;
end

function closeFigure(f)
    if ~isempty(f) && isvalid(f)
        delete(f);
        drawnow
    end
end

function removeTempFolder(folderName)
    if isfolder(folderName)
        rmdir(folderName,'s');
    end
end
