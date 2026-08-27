function regionImages(project, folderName, opts)
%REGIONIMAGES Export each region subimage to a TIFF file.

arguments
    project (1,1) desmostorm.model.STORMProject
    folderName {mustBeTextScalar}
    opts.Channel (1,1) double {mustBeInteger,mustBePositive} = 1
    opts.ScalingMode (1,1) string {mustBeMember(opts.ScalingMode,["data","auto","user"])} = "data"
    opts.ProgressDialog = matlab.ui.dialog.ProgressDialog.empty()
end

regionsTotal = 0;
for i = 1:numel(project.ImageArray)
    regionsTotal = regionsTotal + numel(project.ImageArray(i).RegionArray);
end

regionsDone = 0;
for i = 1:numel(project.ImageArray)
    img = project.ImageArray(i);

    for j = 1:numel(img.RegionArray)
        reg = img.RegionArray(j);
        fileName = sprintf('%s_%s_C%d.tif',img.shortName,reg.Name,opts.Channel);
        fullName = fullfile(folderName,fileName);

        regionsDone = regionsDone + 1;
        updateProgress(opts.ProgressDialog, ...
            sprintf('Exporting region image (%d/%d): %s',regionsDone,regionsTotal,reg.Name), ...
            regionsDone, regionsTotal);

        if opts.Channel > img.SizeC
            desmostorm.Log.WARN(sprintf( ...
                "Skipping region image export for %s: channel %d does not exist.", ...
                reg.Name,opts.Channel));
            continue
        end

        Icell = img.regionSubimageCell(reg);
        I = Icell{opts.Channel};
        clim = imageExportCLim(img,opts.Channel,opts.ScalingMode);
        matlabx.image.io.write16BitTiff(scaleFor16BitExport(I,clim),fullName);
    end
end

end

function Iout = scaleFor16BitExport(I,clim)
    I = double(I);
    I = (I - clim(1)) ./ diff(clim);
    I = min(max(I,0),1);
    Iout = uint16(round(I * double(intmax('uint16'))));
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
