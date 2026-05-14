function setup()

    % restore default settings
    app.config.Settings.restore();

    % setup MATLAB path
    app.setupSearchPath();

    % setup matlabx
    matlabx.setup();

end