function run()
%DESMOSTORM.SETUP.RUN  Performs any necessary setup actions prior to launch

% set up search path first so we can use matlabx
desmostorm.setup.setupSearchPath();

% set up matlabx
desmostorm.Log.INFO("Setting up matlabx for desmostorm...");
desmostorm.setup.matlabx();

% restore default settings
desmostorm.Log.INFO("Restoring default desmostorm settings...");
desmostorm.config.Settings.restore();

end