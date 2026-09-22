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

classdef Version
    methods(Static)
        function c = compare(v1,v2)
            a = sscanf(char(v1),'%d.%d.%d');
            b = sscanf(char(v2),'%d.%d.%d');
            a(end+1:3)=0; b(end+1:3)=0;
            c = sign(dot([1 0.01 0.0001], a-b)); % returns -1,0,1
        end
    end
end