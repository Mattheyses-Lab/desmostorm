function run()
%DESMOSTORM.SETUP.RUN  Performs any necessary setup actions prior to launch

    % restore default settings
    desmostorm.app.config.Settings.restore();

    % setup MATLAB path
    desmostorm.app.setupSearchPath();

    % setup matlabx
    matlabx.setup();

end