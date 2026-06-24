function setup()

    % restore default settings
    desmostorm.app.config.Settings.restore();

    % setup MATLAB path
    desmostorm.app.setupSearchPath();

    % setup matlabx
    matlabx.setup();

end