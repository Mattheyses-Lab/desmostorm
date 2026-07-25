function T = imageRegionTable(img)
%IMAGEREGIONTABLE Build export table rows for one image's regions.

arguments
    img (1,1) desmostorm.model.STORMImage
end

regs = img.RegionArray;
if isempty(regs)
    T = table();
    return
end

parts = arrayfun(@(r) struct2table(desmostorm.export.regionRow(r)), ...
    regs, 'UniformOutput', false);
T = vertcat(parts{:});

end
