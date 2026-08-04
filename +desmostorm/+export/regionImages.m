function regionImages(project, folderName, opts)
%REGIONIMAGES Export each region subimage to a TIFF file.

arguments
    project (1,1) desmostorm.model.STORMProject
    folderName {mustBeTextScalar}
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
        fileName = sprintf('%s_%s.tif',img.shortName,reg.Name);
        fullName = fullfile(folderName,fileName);

        regionsDone = regionsDone + 1;
        updateProgress(opts.ProgressDialog, ...
            sprintf('Exporting region image (%d/%d): %s',regionsDone,regionsTotal,reg.Name), ...
            regionsDone, regionsTotal);

        switch img.CDataClass
            case 'uint16'
                matlabx.image.io.write16BitTiff(img.regionSubimage(reg),fullName);
            otherwise
                error('desmostorm:export:regionImages:UnsupportedImageClass', ...
                    'Cannot export region images for image class: %s', img.CDataClass);
        end
    end
end

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
