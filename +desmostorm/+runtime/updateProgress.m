% DesmoSTORM - MATLAB app for desmosomal plaque protein analysis.
% Copyright (C) 2026 William Dean
% SPDX-License-Identifier: GPL-2.0-or-later

function updateProgress(sink,message,value,total)
%UPDATEPROGRESS Report progress to an optional dialog or callback.
% Pass a fraction, or completed and total counts. An omitted value changes
% only the message, while [] requests an indeterminate progress indicator.
if isempty(sink), return, end
hasValue = nargin >= 3;
if ~hasValue, value = []; end
if nargin == 4
    if total > 0
        value = value/total;
    else
        value = [];
    end
end

try
    if isa(sink,'function_handle')
        sink(string(message),value);
    elseif isvalid(sink)
        if strlength(string(message)) > 0
            sink.Message = message;
        end
        if hasValue
            sink.Indeterminate = isempty(value);
            if ~isempty(value)
                sink.Value = max(0,min(1,double(value)));
            end
        end
        drawnow limitrate
    end
catch ME
    desmostorm.Log.DEBUG("Progress update failed: " + string(ME.message));
end
end
