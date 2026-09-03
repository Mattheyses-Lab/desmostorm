function summary = regionImages(project, folderName, opts)
%REGIONIMAGES Export each region subimage to a TIFF file.

arguments
    project (1,1) desmostorm.model.STORMProject
    folderName {mustBeTextScalar}
    opts.Channel (1,1) double {mustBeInteger,mustBePositive} = 1
    opts.ScalingMode (1,1) string {mustBeMember(opts.ScalingMode,["data","auto","user"])} = "data"
    opts.OutputFormat (1,1) string {mustBeMember(opts.OutputFormat,["grayscale TIFF","RGB PNG"])} = "grayscale TIFF"
    opts.ChannelColorMode (1,1) string {mustBeMember(opts.ChannelColorMode,["colors","luts"])} = "colors"
    opts.TiledSummary (1,1) matlab.lang.OnOffSwitchState = "off"
    opts.ProgressDialog = matlab.ui.dialog.ProgressDialog.empty()
end

matlabx.utils.files.ensureDir(folderName);

regionsTotal = 0;
for i = 1:numel(project.ImageArray)
    regionsTotal = regionsTotal + numel(project.ImageArray(i).RegionArray);
end

summary = struct("Attempted",regionsTotal,"Exported",0,"Skipped",0);
regionsDone = 0;
exportedFiles = {};
for i = 1:numel(project.ImageArray)
    img = project.ImageArray(i);

    for j = 1:numel(img.RegionArray)
        reg = img.RegionArray(j);
        fileName = regionImageFileName(img,reg,opts.Channel,opts.OutputFormat);
        fullName = fullfile(folderName,fileName);

        regionsDone = regionsDone + 1;
        updateProgress(opts.ProgressDialog, ...
            sprintf('Exporting region image (%d/%d): %s',regionsDone,regionsTotal,reg.Name), ...
            regionsDone, regionsTotal);

        if opts.Channel > img.SizeC
            summary.Skipped = summary.Skipped + 1;
            desmostorm.Log.WARN(sprintf( ...
                "Skipping region image export for %s: channel %d does not exist.", ...
                reg.Name,opts.Channel));
            continue
        end

        Icell = img.regionSubimageCell(reg);
        I = Icell{opts.Channel};
        clim = imageExportCLim(img,opts.Channel,opts.ScalingMode);
        switch opts.OutputFormat
            case "grayscale TIFF"
                matlabx.image.io.write16BitTiff(scaleFor16BitExport(I,clim),fullName);
            case "RGB PNG"
                imwrite(renderRegionRGB(I,project,opts.Channel,clim,opts.ChannelColorMode),fullName);
        end
        summary.Exported = summary.Exported + 1;
        exportedFiles{end+1} = fullName; %#ok<AGROW>
    end
end

if opts.TiledSummary == "on" && ~isempty(exportedFiles)
    updateProgress(opts.ProgressDialog, ...
        'Building tiled region image summary...', ...
        regionsTotal, regionsTotal);
    summaryFile = fullfile(folderName,tiledSummaryFileName(opts.Channel,opts.OutputFormat));
    writeTiledSummary(exportedFiles,summaryFile);
end

updateProgress(opts.ProgressDialog, ...
    sprintf('Region image export complete: %d exported, %d skipped.', ...
    summary.Exported,summary.Skipped), ...
    regionsTotal, regionsTotal);

end

function Iout = scaleFor16BitExport(I,clim)
    I = double(I);
    I = (I - clim(1)) ./ diff(clim);
    I = min(max(I,0),1);
    Iout = uint16(round(I * double(intmax('uint16'))));
end

function Iout = scaleFor8BitExport(I,clim)
    I = double(I);
    I = (I - clim(1)) ./ diff(clim);
    I = min(max(I,0),1);
    Iout = uint8(round(I * double(intmax('uint8'))));
end

function RGB = renderRegionRGB(I,project,channel,clim,channelColorMode)
    A = double(scaleFor8BitExport(I,clim)) ./ double(intmax('uint8'));

    switch string(channelColorMode)
        case "colors"
            colorName = project.getChannelColorName(channel);
            color = matlabx.colors.names.toRGB(char(colorName),"Palette","MATLAB");
            RGB = uint8(round(255 * A .* reshape(color,1,1,3)));

        case "luts"
            cmap = project.getChannelColormap(channel);
            idx = max(1,min(size(cmap,1),round(A * (size(cmap,1)-1)) + 1));
            RGB = reshape(cmap(idx(:),:),size(A,1),size(A,2),3);
            RGB = uint8(round(255 * RGB));
    end
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

function fileName = regionImageFileName(img,reg,channel,outputFormat)
    switch string(outputFormat)
        case "grayscale TIFF"
            ext = ".tif";
        case "RGB PNG"
            ext = ".png";
    end

    fileName = sprintf('%s_%s_C%d%s', ...
        safeFileStem(img.shortName), ...
        safeFileStem(reg.Name), ...
        channel, ...
        ext);
end

function fileName = tiledSummaryFileName(channel,outputFormat)
    switch string(outputFormat)
        case "grayscale TIFF"
            suffix = "grayscale";
        case "RGB PNG"
            suffix = "rgb";
    end

    fileName = sprintf('region-images-tiled-summary_C%d_%s.png',channel,suffix);
end

function stem = safeFileStem(str)
    stem = regexprep(char(str),'[^A-Za-z0-9_.-]','_');
    if isempty(stem)
        stem = 'region';
    end
end

function writeTiledSummary(fileNames,filename)
    tiles = cell(size(fileNames));
    tileSize = 0;
    isRGB = false;

    for i = 1:numel(fileNames)
        I = imread(fileNames{i});
        tiles{i} = I;
        isRGB = isRGB || ndims(I) == 3;
        tileSize = max(tileSize,max(size(I,1),size(I,2)));
    end

    n = ceil(sqrt(numel(tiles)));
    if isRGB
        canvas = zeros(tileSize*n,tileSize*n,3,'uint8');
    else
        canvas = zeros(tileSize*n,tileSize*n,'uint16');
    end

    for i = 1:numel(tiles)
        row = floor((i-1)/n) + 1;
        col = mod(i-1,n) + 1;
        tile = padToSquare(tiles{i},tileSize,isRGB);

        rows = (row-1)*tileSize + (1:tileSize);
        cols = (col-1)*tileSize + (1:tileSize);
        if isRGB
            canvas(rows,cols,:) = tile;
        else
            canvas(rows,cols) = tile;
        end
    end

    imwrite(canvas,filename);
end

function tile = padToSquare(I,tileSize,isRGB)
    if isRGB
        I = ensureRGB8(I);
        tile = zeros(tileSize,tileSize,3,'uint8');
    else
        tile = zeros(tileSize,tileSize,'like',I);
    end

    row0 = floor((tileSize - size(I,1))/2) + 1;
    col0 = floor((tileSize - size(I,2))/2) + 1;
    rows = row0:(row0 + size(I,1) - 1);
    cols = col0:(col0 + size(I,2) - 1);
    if isRGB
        tile(rows,cols,:) = I;
    else
        tile(rows,cols) = I;
    end
end

function I = ensureRGB8(I)
    if ismatrix(I)
        I = im2uint8(I);
        I = repmat(I,1,1,3);
        return
    end

    if size(I,3) > 3
        I = I(:,:,1:3);
    end
    if ~isa(I,'uint8')
        I = im2uint8(I);
    end
end
