function summary = regionSubimagesWithROI(source,folderName,opts)
%REGIONSUBIMAGESWITHROI Batch-export region subimages with ROI overlays.
%
% SOURCE can be a STORMProject, a scalar STORMRegion, or a STORMRegion array.
% The exporter creates one export figure and reuses it by updating image data,
% CLim, and ROI geometry, which keeps active-region and batch exports on the
% same rendering path.

arguments
    source
    folderName                      {mustBeTextScalar}
    opts.Channel                    (1,1) double {mustBeInteger,mustBePositive} = 1
    opts.ScalingMode                (1,1) string {mustBeMember(opts.ScalingMode,["data","auto","user"])} = "data"
    opts.Colormap                   (256,3) double = gray
    opts.Resolution                 (1,1) double = 600
    opts.ROIColor                   (1,3) double = [1 1 1]
    opts.ROILineWidth               (1,1) double = 1
    opts.ROIFaceAlpha               (1,1) double = 0
    opts.ROIMarkerSize              (1,1) double = 8
    opts.AnnotationLineColor        (1,3) double = [1 1 1]
    opts.AnnotationLineWidth        (1,1) double = 0.5
    opts.RotationAngleMode          (1,:) char {mustBeMember(opts.RotationAngleMode,{'full-circle','half-circle'})} = 'half-circle'
    opts.RotationAngleVisible       (1,1) matlab.lang.OnOffSwitchState = "on"
    opts.Size                       (1,1) double = 3
    opts.Units                      (1,:) char = 'inches'
    opts.FontSize                   (1,1) double = 12
    opts.FontColor                  (1,3) double = [1 1 1]
    opts.TiledSummary               (1,1) matlab.lang.OnOffSwitchState = "off"
    opts.ProgressDialog = matlab.ui.dialog.ProgressDialog.empty()
end

matlabx.utils.files.ensureDir(folderName);

regions = collectRegions(source);
summary = struct("Attempted",numel(regions),"Exported",0,"Skipped",0);
if isempty(regions)
    return
end

[firstRegion,firstImage] = firstExportableRegion(regions,opts.Channel);
if isempty(firstRegion)
    desmostorm.Log.WARN(sprintf( ...
        "No regions with valid ROIs and channel %d were available for ROI overlay export.", ...
        opts.Channel));
    summary.Skipped = summary.Attempted;
    return
end

I = getRegionChannelImage(firstRegion,opts.Channel);

[ax,fig] = matlabx.app.quickshow(I, ...
    "Colormap",opts.Colormap, ...
    "Tools",{'DrawRectangle'}, ...
    "WindowStyle","normal", ...
    "Visible","off", ...
    "Size",opts.Size, ...
    "Units",opts.Units);
c = onCleanup(@() delete(fig));

ax.CLim = imageExportCLim(firstImage,opts.Channel,opts.ScalingMode);
ax.Tools.DrawRectangle.ROIColor = opts.ROIColor;
ax.Tools.DrawRectangle.ROILineWidth = opts.ROILineWidth;
ax.Tools.DrawRectangle.ROIMarkerSize = opts.ROIMarkerSize;
ax.Tools.DrawRectangle.AnnotationLineColor = opts.AnnotationLineColor;
ax.Tools.DrawRectangle.AnnotationLineWidth = opts.AnnotationLineWidth;
ax.Tools.DrawRectangle.RotationAngleMode = opts.RotationAngleMode;
ax.Tools.DrawRectangle.RotationAngleVisible = opts.RotationAngleVisible;
ax.Tools.DrawRectangle.FontSize = opts.FontSize;
ax.Tools.DrawRectangle.FontColor = opts.FontColor;
ax.Tools.DrawRectangle.ROIFaceAlpha = opts.ROIFaceAlpha;
ax.Tools.DrawRectangle.setROIPosition(firstRegion.ROI);

% The ImageAxes/export stack renders most reliably after the figure has become
% visible once. Give it the same brief render pass used by summaryPDF, then
% hide it before the export loop so the user only sees a quick flash.
pause(1)
fig.Visible = "on";
drawnow
desmostorm.app.focusMainFigure();
fig.Visible = "off";

exportedFiles = {};
for k = 1:numel(regions)
    region = regions(k);
    img = region.Parent;

    updateProgress(opts.ProgressDialog, ...
        sprintf('Exporting ROI overlay (%d/%d): %s',k,numel(regions),region.Name), ...
        k-1,numel(regions));

    if opts.Channel > img.SizeC
        summary.Skipped = summary.Skipped + 1;
        desmostorm.Log.WARN(sprintf( ...
            "Skipping ROI overlay export for %s: channel %d does not exist.", ...
            region.Name,opts.Channel));
        continue
    end
    if ~hasValidROI(region)
        summary.Skipped = summary.Skipped + 1;
        desmostorm.Log.WARN(sprintf( ...
            "Skipping ROI overlay export for %s: no valid ROI.", ...
            region.Name));
        continue
    end

    ax.CData = getRegionChannelImage(region,opts.Channel);
    ax.CLim = imageExportCLim(img,opts.Channel,opts.ScalingMode);
    ax.Tools.DrawRectangle.setROIPosition(region.ROI);

    drawnow
    if k==1
        pause(1)
    else
        pause(0.1)
    end


    filename = fullfile(folderName,sprintf('%s_%s_C%d_subimage-ROI-overlay.png', ...
        safeFileStem(img.shortName),safeFileStem(region.Name),opts.Channel));

    exportAxesImage(ax.getAxes(),filename, ...
        "HideToolbar",          true, ...
        "PreserveAspectRatio",  'off', ...
        "Resolution",           opts.Resolution, ...
        "Units",                opts.Units, ...
        "Width",                opts.Size, ...
        "Height",               opts.Size);

    summary.Exported = summary.Exported + 1;
    exportedFiles{end+1} = filename; %#ok<AGROW>
end

if opts.TiledSummary == "on" && ~isempty(exportedFiles)
    updateProgress(opts.ProgressDialog, ...
        'Building tiled ROI overlay summary...', ...
        numel(regions),numel(regions));
    summaryFile = fullfile(folderName,sprintf('ROI-overlay-tiled-summary_C%d.png',opts.Channel));
    writeTiledSummary(exportedFiles,summaryFile);
end

updateProgress(opts.ProgressDialog, ...
    sprintf('ROI overlay export complete: %d exported, %d skipped.', ...
    summary.Exported,summary.Skipped), ...
    numel(regions),numel(regions));

end

function regions = collectRegions(source)
    if isa(source,'desmostorm.model.STORMProject')
        regions = desmostorm.model.STORMRegion.empty();
        imgs = source.ImageArray;
        for i = 1:numel(imgs)
            regs = imgs(i).RegionArray;
            if ~isempty(regs)
                regions = [regions; regs(:)]; %#ok<AGROW>
            end
        end
        return
    end

    if isa(source,'desmostorm.model.STORMRegion')
        regions = source(:);
        return
    end

    error('desmostorm:export:regionSubimagesWithROI:InvalidSource', ...
        'Source must be a STORMProject or STORMRegion array.');
end

function [region,img] = firstExportableRegion(regions,channel)
    region = desmostorm.model.STORMRegion.empty();
    img = desmostorm.model.STORMImage.empty();
    for k = 1:numel(regions)
        candidate = regions(k);
        candidateImage = candidate.Parent;
        if channel <= candidateImage.SizeC && hasValidROI(candidate)
            region = candidate;
            img = candidateImage;
            return
        end
    end
end

function tf = hasValidROI(region)
    ROI = region.ROI;
    tf = isstruct(ROI) && ...
        all(isfield(ROI,{'CenterX','CenterY','Width','Height','RotationAngle'})) && ...
        all(isfinite([ROI.CenterX,ROI.CenterY,ROI.Width,ROI.Height,ROI.RotationAngle]));
end

function I = getRegionChannelImage(region,channel)
    Icell = region.Parent.regionSubimageCell(region);
    I = Icell{channel};
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

function stem = safeFileStem(str)
    stem = regexprep(char(str),'[^A-Za-z0-9_.-]','_');
    if isempty(stem)
        stem = 'region';
    end
end

function exportAxesImage(ax,filename,opts)
    arguments
        ax                          (1,1) matlab.ui.control.UIAxes
        filename                    (1,:) char
        opts.Units                  (1,:) char = 'inches'
        opts.Width                  (1,1) double = 3
        opts.Height                 (1,1) double = 3
        opts.BackgroundColor        (1,3) double = [0 0 0]
        opts.PreserveAspectRatio    (1,:) char = 'on'
        opts.Resolution             (1,1) double = 600
        opts.HideToolbar            (1,1) logical = true
    end

    toolbarVisible = ax.Toolbar.Visible;
    toolbarCleanup = onCleanup(@() set(ax.Toolbar,'Visible',toolbarVisible));
    if opts.HideToolbar
        ax.Toolbar.Visible = 'off';
    end

    exportgraphics(ax,filename, ...
        "ContentType","image", ...
        "Units",opts.Units, ...
        "Width",opts.Width, ...
        "Height",opts.Height, ...
        "Colorspace","rgb", ...
        "Padding",0, ...
        "PreserveAspectRatio",opts.PreserveAspectRatio, ...
        "BackgroundColor",opts.BackgroundColor, ...
        "Resolution",opts.Resolution);
end

function writeTiledSummary(fileNames,filename)
    tiles = cell(size(fileNames));
    tileSize = 0;

    for i = 1:numel(fileNames)
        I = ensureRGB(imread(fileNames{i}));
        tiles{i} = I;
        tileSize = max(tileSize,max(size(I,1),size(I,2)));
    end

    n = ceil(sqrt(numel(tiles)));
    canvas = zeros(tileSize*n,tileSize*n,3,'uint8');

    for i = 1:numel(tiles)
        row = floor((i-1)/n) + 1;
        col = mod(i-1,n) + 1;
        tile = padToSquare(tiles{i},tileSize);

        rows = (row-1)*tileSize + (1:tileSize);
        cols = (col-1)*tileSize + (1:tileSize);
        canvas(rows,cols,:) = tile;
    end

    imwrite(canvas,filename);
end

function I = ensureRGB(I)
    if ismatrix(I)
        I = repmat(I,1,1,3);
        return
    end

    if size(I,3) > 3
        I = I(:,:,1:3);
    end
end

function tile = padToSquare(I,tileSize)
    tile = zeros(tileSize,tileSize,3,'like',I);
    row0 = floor((tileSize - size(I,1))/2) + 1;
    col0 = floor((tileSize - size(I,2))/2) + 1;
    rows = row0:(row0 + size(I,1) - 1);
    cols = col0:(col0 + size(I,2) - 1);
    tile(rows,cols,:) = I;
end

function updateProgress(h,msg,idx,total)
    if isempty(h) || ~isvalid(h)
        return
    end

    h.Message = msg;
    if total > 0
        h.Indeterminate = 'off';
        h.Value = idx/total;
    end
    drawnow limitrate
end
