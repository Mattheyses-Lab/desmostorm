function updateProgressDialog(h,msg,value)
%UPDATEPROGRESSDIALOG Safely update an optional GUI progress dialog.
%
% ML functions are designed to run from both the GUI and command line. Passing
% [] keeps command-line usage UI-free, while GUI callers can pass a
% uiprogressdlg handle for lightweight stage/batch feedback.

arguments
    h = []
    msg (1,1) string = ""
    value = []
end

if isempty(h)
    return
end

try
    if ~isvalid(h)
        return
    end

    if strlength(msg) > 0
        h.Message = char(msg);
    end

    if isempty(value)
        h.Indeterminate = "on";
    else
        h.Indeterminate = "off";
        h.Value = max(0,min(1,double(value)));
    end

    drawnow limitrate
catch
    % Progress feedback should never make command-line or batch ML workflows
    % fail. The logger still records the substantive pipeline state.
end

end
