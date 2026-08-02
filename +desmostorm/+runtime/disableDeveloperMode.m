function disableDeveloperMode(opts)
%DISABLEDEVELOPERMODE Convenience wrapper for setDeveloperMode(false).

arguments
    opts.ApplyLogging (1,1) logical = true
    opts.Verbose (1,1) logical = true
end

desmostorm.runtime.setDeveloperMode(false, ...
    "ApplyLogging", opts.ApplyLogging, ...
    "Verbose", opts.Verbose);

end
