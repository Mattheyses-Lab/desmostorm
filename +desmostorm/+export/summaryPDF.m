function summaryPDF(project, filename, config, opts)
%SUMMARYPDF  Export per-region image, ROI summary, and linescan plots to PDF.

arguments
    project (1,1) desmostorm.model.STORMProject
    filename {mustBeTextScalar}
    config (1,1) desmostorm.config.Settings
    opts.ProgressDialog = matlab.ui.dialog.ProgressDialog.empty()
    opts.ImageChannel (1,1) string = "1"
    opts.ScalingMode (1,1) string {mustBeMember(opts.ScalingMode,["data","auto","user"])} = "data"
    opts.ColorSource (1,1) string {mustBeMember(opts.ColorSource,["channel","manual"])} = "channel"
    opts.Color (1,3) double = [0 0 0]
    opts.AnnotationColorMode (1,1) string {mustBeMember(opts.AnnotationColorMode,["auto","manual"])} = "auto"
    opts.AnnotationColor (1,3) double = [0 0 0]
    opts.BackgroundColor (1,3) double = [1 1 1]
    opts.ForegroundColor (1,3) double = [0 0 0]
    opts.DistanceAnnotations (1,1) matlab.lang.OnOffSwitchState = "on"
    opts.DistanceAnnotationsMode (1,1) string {mustBeMember(opts.DistanceAnnotationsMode,["data","lanes"])} = "lanes"
    opts.WidthAnnotations (1,1) matlab.lang.OnOffSwitchState = "on"
    opts.WidthAnnotationsMode (1,1) string {mustBeMember(opts.WidthAnnotationsMode,["normal","hover"])} = "normal"
    opts.ROIFaceAlpha (1,1) double = 0.1
    opts.RotationAngleVisible (1,1) matlab.lang.OnOffSwitchState = "on"
    opts.RawLineWidth (1,1) double = 1
    opts.SmoothLineWidth (1,1) double = 2
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
    pageWidthPx = opts.PageWidthInches * matlabx.UICal.pixelsPerInch();

    % Keep the page compact and predictable: the export figure is a single
    % row with linescan plot, region image, and per-channel summary text.
    padding = 5;
    spacing = 5;

    % ImageAxes is hosted in a uipanel with a title bar. Include that chrome
    % in the column height so the displayed image area stays square.
    panelTop = matlabx.UICal.uipanelTopChromeHeightPx(fontSizePx);
    usableWidth = pageWidthPx-padding*2-spacing*2;
    plotWidth = usableWidth/2;
    tableWidth = usableWidth/4;
    
    figHeight = pageWidthPx/4;
    gridHeight = figHeight-padding*2;

    imgWidth = gridHeight-panelTop;

    % Initialize temporary files and folder for PDF export
    tempFiles = {};
    tempFolder = char(tempname);
    mkdir(tempFolder);
    cleanupTempFolder = onCleanup(@() removeTempFolder(tempFolder));
    cleanupTemp = onCleanup(@() deleteTempFiles(tempFiles));

    % Expand the requested channel selection into concrete pages. "all"
    % becomes one page per region per available channel.
    pages = collectPages(imgs, opts.ImageChannel);
    if isempty(pages)
        return
    end

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
    
    plotColor = resolvePlotColor(project, channel, opts.Color, opts.ColorSource);

    p = desmostorm.widgets.PeaksPlotContainer(g, ...
        "Data",reg.LinescanResults(channel), ...
        "RawLineWidth",opts.RawLineWidth, ...
        "SmoothLineWidth",opts.SmoothLineWidth, ...
        "Color",plotColor, ...
        "Colors",plotColor, ...
        "ColorMode",'auto', ...
        "AlphaMode",'auto', ...
        "AnnotationColorMode",char(opts.AnnotationColorMode), ...
        "AnnotationColor",opts.AnnotationColor, ...
        "DistanceAnnotations",opts.DistanceAnnotations, ...
        "DistanceAnnotationsMode",char(opts.DistanceAnnotationsMode), ...
        "WidthAnnotations",opts.WidthAnnotations, ...
        "WidthAnnotationsMode",char(opts.WidthAnnotationsMode), ...
        "BackgroundColor",opts.BackgroundColor, ...
        "ForegroundColor",opts.ForegroundColor, ...
        "XLabel",sprintf("Distance (%s)",config.Analysis.PixelSizeUnit), ...
        "YLabel","Normalized Intensity", ...
        "FontSize",fontSizePx);
    p.Layout.Row = 1;
    p.Layout.Column = 1;
    
    ax = matlabx.ui.axes.ImageAxes(g, ...
        'ImageData',regImageData, ...
        'Name','RegionViewer', ...
        'Tools',{'DrawRectangle'}, ...
        'Colormap',project.getChannelColormap(channel), ...
        'ComponentColorMode',config.Display.ChannelColorMode, ...
        'FontSize', fontSizePx);

    ax.Layout.Row = 1;
    ax.Layout.Column = 2;
    applyROISettings(ax.Tools.DrawRectangle,config.ROI,opts,fontSizePx);
    ax.setComponentCLim(imageExportCLim(img,channel,opts.ScalingMode),channel);

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
    
        if ~isempty(opts.ProgressDialog) && isvalid(opts.ProgressDialog)
            opts.ProgressDialog.Message = sprintf('Exporting peak plots (%i/%i): %s | %s | C%i', ...
                pageIdx, numel(pages), img.Name, reg.Name, channel);
        end
    
        % --- Linescan plot ---
        % data
        if channel <= numel(reg.LinescanResults)
            p.Data = reg.LinescanResults(channel);
        else
            p.Data = desmostorm.analysis.PeaksData.empty();
        end
        % title
        p.Title = sprintf("%s | %s | C%i", matlabx.utils.text.texFriendly(img.Name), reg.Name, channel);
        % plot color
        plotColor = resolvePlotColor(project, channel, opts.Color, opts.ColorSource);
        p.Color = plotColor;
        p.Colors = plotColor;

        % ImageAxes handles multi-component images as a cell array and the
        % active component is selected with C. Keep display scaling matched
        % to the channel shown on the current page.
        Icell = img.regionSubimageCell(reg);
        ax.CData = Icell;
        ax.C = channel;

        ax.setComponentCLim(imageExportCLim(img,channel,opts.ScalingMode),channel);

        switch config.Display.ChannelColorMode
            case 'colors'
                ax.setComponentColor(project.getChannelColorName(channel),channel);
            case 'luts'
                ax.setComponentColormap(project.getChannelColormap(channel),channel);
        end
    
        ax.Tools.DrawRectangle.setROIPosition(reg.ROI);
        l.Text = reg.TextSummaryTable(channel);

        tempName = char(fullfile(tempFolder,[matlabx.utils.text.uniqueID("char"),'.pdf']));

        % Give graphics objects a short beat to settle before exportapp
        % snapshots the UI. The first page needs the full component warm-up.
        drawnow
        if pageIdx == 1
            pause(1)
        else
            pause(0.1)
        end
    
        exportapp(f,tempName);
        tempFiles{end+1} = tempName;
    end
    
    if isempty(tempFiles)
        return
    end
    
    closeFigure(f);
    mergeTempPDFs(tempFiles, filename);

end

function mergeTempPDFs(fileNames, filename)
    memSet = org.apache.pdfbox.io.MemoryUsageSetting.setupMainMemoryOnly();
    merger = org.apache.pdfbox.multipdf.PDFMergerUtility;
    
    for i = 1:numel(fileNames)
        merger.addSource(java.io.File(fileNames{i}));
    end
    
    merger.setDestinationFileName(char(filename));
    merger.mergeDocuments(memSet);
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
        elseif channel <= imgs(i).SizeC
            channels = channel;
        else
            channels = [];
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

    colorName = project.getChannelColorName(channel);
    color = matlabx.colors.names.toRGB(char(colorName),"Palette","MATLAB");
end

function applyROISettings(tool,roiConfig,opts,fontSizePx)
    tool.ROIColor = roiConfig.ROIColor;
    tool.ROILineWidth = roiConfig.ROILineWidth;
    tool.ROIFaceAlpha = opts.ROIFaceAlpha;
    tool.ROIMarkerSize = roiConfig.ROIMarkerSize;
    tool.AnnotationLineColor = roiConfig.AnnotationLineColor;
    tool.AnnotationLineWidth = roiConfig.AnnotationLineWidth;
    tool.RotationAngleMode = roiConfig.RotationAngleMode;
    tool.RotationAngleVisible = opts.RotationAngleVisible;
    tool.FontSize = fontSizePx;
    tool.FontColor = roiConfig.FontColor;
end

function clim = imageExportCLim(img,channel,scalingMode)
    switch string(scalingMode)
        case "data"
            clim = img.getDataRange(channel);
        case "auto"
            clim = img.getAutoDisplayRange(channel);
        case "user"
            clim = img.getDisplayRange(channel);
    end

    clim = double(clim);
    if any(~isfinite(clim)) || clim(1) == clim(2)
        v = clim(find(isfinite(clim),1,'first'));
        if isempty(v), v = 0; end
        clim = [v-0.5 v+0.5];
    end
    clim = sort(clim);
end

function deleteTempFiles(fileNames)
    for i = 1:numel(fileNames)
        if isfile(fileNames{i})
            delete(fileNames{i});
        end
    end
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
