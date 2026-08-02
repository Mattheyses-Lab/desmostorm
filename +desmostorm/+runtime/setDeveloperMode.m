function setDeveloperMode(tf, opts)
%SETDEVELOPERMODE Enable or disable developer-oriented runtime behavior.
%
%   desmostorm.runtime.setDeveloperMode(TF) stores the DeveloperMode
%   preference and reapplies logging policy to the active logger, if one
%   exists. For now, developer mode only changes logging defaults.

arguments
    tf (1,1) logical
    opts.ApplyLogging (1,1) logical = true
    opts.Verbose (1,1) logical = true
end

oldValue = desmostorm.runtime.isDeveloperMode();
desmostorm.Preferences.set("DeveloperMode", tf);

if opts.ApplyLogging && desmostorm.Log.exists()
    desmostorm.Log.applyConfigFromPreferences();

    if opts.Verbose && oldValue ~= tf
        state = "disabled";
        if tf
            state = "enabled";
        end
        desmostorm.Log.INFO("Developer mode " + state + ".");
    end
end

end
