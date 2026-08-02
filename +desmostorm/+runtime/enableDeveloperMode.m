function enableDeveloperMode(opts)
%ENABLEDEVELOPERMODE Convenience wrapper for setDeveloperMode(true).

arguments
    opts.ApplyLogging (1,1) logical = true
    opts.Verbose (1,1) logical = true
end

desmostorm.runtime.setDeveloperMode(true, ...
    "ApplyLogging", opts.ApplyLogging, ...
    "Verbose", opts.Verbose);

end
