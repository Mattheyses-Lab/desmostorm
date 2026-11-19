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

function updateProgressDialog(h,msg,value)
%UPDATEPROGRESSDIALOG Report progress to an optional dialog or callback.
%
% ML functions are designed to run from both the GUI and command line. Passing
% [] keeps command-line usage UI-free, while GUI callers can pass a
% uiprogressdlg handle for lightweight stage/batch feedback.

arguments
    h = []
    msg (1,1) string = ""
    value = []
end

desmostorm.runtime.updateProgress(h,msg,value);
end
