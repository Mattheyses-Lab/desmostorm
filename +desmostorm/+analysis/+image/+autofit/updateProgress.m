function updateProgress(h,msg,value)
%UPDATEPROGRESS Best-effort progress feedback for GUI callers.
%
% Auto-fit is also used from non-GUI contexts, so progress reporting must be
% optional and failure-tolerant. A stale or closed dialog should never affect
% the analysis result.

if isempty(h), return; end

try
    h.Message = msg;
    if nargin >= 3 && ~isempty(value)
        h.Indeterminate = "off";
        h.Value = value;
    end
    drawnow limitrate
catch
end
end
