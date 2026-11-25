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
        center = limits(find(isfinite(limits),1));
        if isempty(center), center = 0; end
        limits = center + [-0.5 0.5];
    end
    limits = sort(limits);
end
