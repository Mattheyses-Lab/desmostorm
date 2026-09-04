function updateProgress(h,msg,value,opts)
%UPDATEPROGRESS Best-effort progress feedback for GUI callers.
%
% Auto-fit is also used from non-GUI contexts, so progress reporting must be
% optional and failure-tolerant. A stale or closed dialog should never affect
% the analysis result.

arguments
    h
    msg (1,1) string
    value = []
    opts.Prefix (1,1) string = ""
    opts.UpdateValue (1,1) logical = true
end

if isempty(h), return; end

try
    if opts.Prefix == ""
        h.Message = msg;
    else
        h.Message = opts.Prefix + newline + msg;
    end
    if opts.UpdateValue && ~isempty(value)
        h.Indeterminate = "off";
        h.Value = value;
    end
    drawnow limitrate
catch
end
end
