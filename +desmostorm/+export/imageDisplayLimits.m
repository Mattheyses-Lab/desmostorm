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

function limits = imageDisplayLimits(img,channel,mode,displaySettings,autoMethod)
%IMAGEDISPLAYLIMITS Resolve image limits for the source channel being exported.
    if nargin < 5, autoMethod = ""; end
    switch mode
        case "auto"
            policy = displaySettings.channelPolicy(img.ChannelIDs(channel));
            if autoMethod ~= ""
                mustBeMember(autoMethod,desmostorm.config.Display.AutoMethods);
                policy.Method = autoMethod;
            end
            policy.KeepAuto = true;
            limits = img.displayLimits(channel,policy);
        case "user"
            limits = img.getDisplayRange(channel);
        case "data"
            limits = img.getDataRange(channel);
    end

    limits = double(limits);
    if any(~isfinite(limits)) || limits(1) == limits(2)
        % Center position for the current geometry or range.
        center = limits(find(isfinite(limits),1));
        if isempty(center), center = 0; end
        limits = center + [-0.5 0.5];
    end
    limits = sort(limits);
end
