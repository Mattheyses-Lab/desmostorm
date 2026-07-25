function T = regionTable(project)
%REGIONTABLE Build project region measurements table for export.

arguments
    project (1,1) desmostorm.model.STORMProject
end

imgs = project.ImageArray;
if isempty(imgs)
    T = table();
    return
end

parts = arrayfun(@(img) desmostorm.export.imageRegionTable(img), ...
    imgs, 'UniformOutput', false);
parts = parts(~cellfun(@isempty, parts));

if isempty(parts)
    T = table();
else
    T = vertcat(parts{:});
end

end
