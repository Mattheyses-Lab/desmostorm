function run()
%DESMOSTORM.SETUP.RUN  Performs any necessary setup actions prior to launch

% set up search path first so we can use matlabx
desmostorm.setup.setupSearchPath();

% set up matlabx
desmostorm.Log.INFO("Setting up matlabx for desmostorm...");
desmostorm.setup.matlabx();

% create or migrate user settings without overwriting existing preferences
desmostorm.Log.INFO("Loading desmostorm settings...");
desmostorm.config.Settings.load();

end
