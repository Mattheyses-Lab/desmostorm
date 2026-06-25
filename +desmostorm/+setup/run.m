function run()
%DESMOSTORM.SETUP.RUN  Performs any necessary setup actions prior to launch

    % restore default settings
    desmostorm.config.Settings.restore();

    % setup MATLAB path
    desmostorm.setup.setupSearchPath();

    % setup matlabx
    matlabx.setup();

end