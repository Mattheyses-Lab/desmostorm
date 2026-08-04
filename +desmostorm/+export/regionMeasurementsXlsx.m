function regionMeasurementsXlsx(project, filename, opts)
%REGIONMEASUREMENTSXLSX Export project region measurements to XLSX.

arguments
    project (1,1) desmostorm.model.STORMProject
    filename {mustBeTextScalar}
    opts.ProgressDialog = matlab.ui.dialog.ProgressDialog.empty()
end

setProgressMessage(opts.ProgressDialog,'Building region measurement table...');
T = desmostorm.export.regionTable(project);

if isempty(T)
    warning('No regions to export.');
    return
end

desc = cellfun(@desmostorm.utils.formatColumnName, ...
    T.Properties.VariableNames, 'UniformOutput', false);
T.Properties.VariableNames = desc;

setProgressMessage(opts.ProgressDialog,'Writing region measurement file...');
writetable(T, filename, ...
    'WriteMode', 'replacefile', ...
    'WriteVariableNames', true);

end

function setProgressMessage(h,msg)
    if ~isempty(h) && isvalid(h)
        h.Message = msg;
        drawnow limitrate
    end
end
