% DesmoSTORM - MATLAB app for desmosomal plaque protein analysis.
% Copyright (C) 2026 William Dean
%
% This program is free software; you can redistribute it and/or modify it
% under the terms of the GNU General Public License as published by the Free
% Software Foundation; either version 2 of the License, or (at your option)
% any later version.
%
% This program is distributed in the hope that it will be useful, but WITHOUT
% ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
% FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
% details.
%
% You should have received a copy of the GNU General Public License along
% with this program; if not, see <https://www.gnu.org/licenses/>.

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
