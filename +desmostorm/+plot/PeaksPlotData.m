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

classdef PeaksPlotData
%PEAKSPLOTDATA Linescan results and optional channel identity in trace order.

    properties (SetAccess=private)
        Traces (:,1) desmostorm.analysis.PeaksData
        ChannelIDs (:,1) string
        Names (:,1) string
    end

    methods
        function obj = PeaksPlotData(traces,opts)
            arguments
                traces desmostorm.analysis.PeaksData = desmostorm.analysis.PeaksData.empty()
                opts.ChannelIDs string = strings(0,1)
                opts.Names string = strings(0,1)
            end
            assert(isempty(traces) || isvector(traces),'Traces must be a vector.');
            count = numel(traces);
            assert(isempty(opts.ChannelIDs) || numel(opts.ChannelIDs) == count, ...
                'Specify one channel ID per trace.');
            assert(isempty(opts.Names) || numel(opts.Names) == count, ...
                'Specify one name per trace.');
            obj.Traces = traces(:);
            obj.ChannelIDs = opts.ChannelIDs(:);
            if isempty(obj.ChannelIDs), obj.ChannelIDs = strings(count,1); end
            obj.Names = opts.Names(:);
            if isempty(obj.Names)
                obj.Names = "Trace " + (1:count).';
            end
        end
    end
end
