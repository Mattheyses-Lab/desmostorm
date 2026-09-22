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

function [Iout,info] = preprocessForAutofit(I,debugOutput)
%PREPROCESSFORAUTOFIT Return the image used by angle/extent fitting.
%
% This helper is intentionally small so alternative cleanup approaches
% (foreground masks, morphology, cluster-guided filtering) can be swapped in
% without disturbing the fitting code.

arguments
    I
    debugOutput (1,1) logical = false
end

info = struct("Methods",["removeIsolatedPuncta","removeEdgeClusters"]);

Iout = desmostorm.analysis.image.removeIsolatedPuncta(I, ...
    "DebugOutput",debugOutput);

Iout = desmostorm.analysis.image.removeEdgeClusters(Iout, ...
    "DebugOutput",debugOutput);
end
