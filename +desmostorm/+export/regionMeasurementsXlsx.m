function regionMeasurementsXlsx(project, filename)
%REGIONMEASUREMENTSXLSX Export project region measurements to XLSX.

arguments
    project (1,1) desmostorm.model.STORMProject
    filename {mustBeTextScalar}
end

T = desmostorm.export.regionTable(project);

if isempty(T)
    warning('No regions to export.');
    return
end

desc = cellfun(@desmostorm.utils.formatColumnName, ...
    T.Properties.VariableNames, 'UniformOutput', false);
T.Properties.VariableNames = desc;

writetable(T, filename, ...
    'WriteMode', 'replacefile', ...
    'WriteVariableNames', true);

end
