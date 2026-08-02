function tf = isDeveloperMode()
%ISDEVELOPERMODE True when the current app session should use developer defaults.
%
%   TF = desmostorm.runtime.isDeveloperMode() reads the persistent
%   DeveloperMode preference. Runtime helpers interpret this preference,
%   while Preferences remains the storage layer.

tf = logical(desmostorm.Preferences.get("DeveloperMode", false));

end
