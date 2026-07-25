function regionImages(project, folderName)
%REGIONIMAGES Export each region subimage to a TIFF file.

arguments
    project (1,1) desmostorm.model.STORMProject
    folderName {mustBeTextScalar}
end

for i = 1:numel(project.ImageArray)
    img = project.ImageArray(i);

    for j = 1:numel(img.RegionArray)
        reg = img.RegionArray(j);
        fileName = sprintf('%s_%s.tif',img.shortName,reg.Name);
        fullName = fullfile(folderName,fileName);

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
