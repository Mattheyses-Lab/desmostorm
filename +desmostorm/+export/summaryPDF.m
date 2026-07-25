function summaryPDF(project, filename, config, opts)
%SUMMARYPDF  Export per-region image, ROI summary, and linescan plots to PDF.

arguments
    project (1,1) desmostorm.model.STORMProject
    filename {mustBeTextScalar}
    config (1,1) desmostorm.config.Settings
    opts.ProgressDialog = matlab.ui.dialog.ProgressDialog.empty()
    opts.ImageChannel (1,1) string = "1"
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

    % Expand the requested channel selection into concrete pages. "all"
    % becomes one page per region per available channel.
    pages = collectPages(imgs, opts.ImageChannel);
    if isempty(pages)
        return
    end

    % Keep the temporary export figure visible long enough for App Designer
    % components to render sharply. It is hidden after the first render pass;
    % the main GUI is held always-on-top by the caller during export.
    f = uifigure("WindowStyle","normal", ...
        "Visible","on", ...
        "Position",[0 0 pageWidthPx figHeight]);
    cleanupFig = onCleanup(@() closeFigure(f));
    
    movegui(f,'center')
    
    g = uigridlayout(f,[1,3], ...
        "RowHeight",{gridHeight}, ...
        "ColumnWidth",{plotWidth,imgWidth,tableWidth}, ...
        "ColumnSpacing",spacing, ...
        "Padding",repmat(padding,1,4), ...
        "BackgroundColor",[1 1 1]);
    
    p = desmostorm.widgets.PeaksPlotContainer(g, ...
        "RawLineWidth",config.PeaksPlot.RawLineWidth, ...
        "RawLineColor",config.PeaksPlot.RawLineColor, ...
        "SmoothLineWidth",config.PeaksPlot.SmoothLineWidth, ...
        "SmoothLineColor",config.PeaksPlot.SmoothLineColor, ...
        "BackgroundColor",config.PeaksPlot.BackgroundColor, ...
        "ForegroundColor",config.PeaksPlot.ForegroundColor, ...
        "XLabel",sprintf("Distance (%s)",config.Analysis.PixelSizeUnit), ...
        "YLabel","Normalized Intensity", ...
        "FontSize",fontSizePx);
    p.Layout.Row = 1;
    p.Layout.Column = 1;
    
    ax = matlabx.ui.axes.ImageAxes(g, ...
        'Name','RegionViewer', ...
        'ToolBox',{'DrawRectangle'}, ...
        'ToolBelt',{'DrawRectangle'}, ...
        'Colormap',config.Display.Colormap, ...
        'CLim',[0 1], ...
        'CData',[], ...
        'FontSize', fontSizePx);
    ax.Layout.Row = 1;
    ax.Layout.Column = 2;
    ax.Tools.DrawRectangle.RotationAngleMode = 'half-circle';
    ax.Tools.DrawRectangle.enable();
    ax.Tools.DrawRectangle.FontSize = fontSizePx;

    l = uilabel(g, ...
        "Text",'', ...
        "BackgroundColor",[1 1 1], ...
        "FontColor",[0 0 0], ...
        "HorizontalAlignment","left", ...
        "VerticalAlignment","top", ...
        "FontName","courier", ...
        "FontSize",fontSizePx);
    l.Layout.Row = 1;
    l.Layout.Column = 3;

    drawnow
    pause(1)

    % Hiding after the initial draw avoids putting the export figure in the
    % user's way without triggering the blurry first-render export path.
    f.Visible = 'off';

    cleanupTemp = onCleanup(@() deleteTempFiles(tempFiles));

    for pageIdx = 1:numel(pages)
        img = pages(pageIdx).Image;
        reg = pages(pageIdx).Region;
        channel = pages(pageIdx).Channel;
    
        if ~isempty(opts.ProgressDialog) && isvalid(opts.ProgressDialog)
            opts.ProgressDialog.Message = sprintf('Exporting peak plots (%i/%i): %s | %s | C%i', ...
                pageIdx, numel(pages), img.Name, reg.Name, channel);
        end
    
        if channel <= numel(reg.LinescanResults)
            p.Data = reg.LinescanResults(channel);
        else
            p.Data = desmostorm.analysis.PeaksData.empty();
        end
    
        p.Title = sprintf("%s | %s | C%i", ...
            matlabx.utils.text.texFriendly(img.Name), reg.Name, channel);

        % ImageAxes handles multi-component images as a cell array and the
        % active component is selected with C. Keep display scaling matched
        % to the channel shown on the current page.
        Icell = img.regionSubimageCell(reg);
        ax.CData = Icell;
        ax.C = channel;

        switch config.Display.AutoScaleDisplayIntensity
            case true
                ax.setCLim(img.getAutoDisplayRange(channel),channel);
            case false
                ax.setCLim(img.getDisplayRange(channel),channel);
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
