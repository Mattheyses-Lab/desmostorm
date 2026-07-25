function launch()
%LAUNCH  Launches the desmostorm GUI

    % --- perform setup actions if necessary ---

    requiredVersion = desmostorm.setup.requiredSetupVersion();
    currentVersion = desmostorm.Preferences.get("SetupVersion","0.0.0");
    
    if desmostorm.Version.compare(currentVersion,requiredVersion) < 0
        desmostorm.setup.run();
        desmostorm.Preferences.set("SetupVersion",requiredVersion);
    end

    % Reuse the existing app window if DesmoSTORM is already open.
    if desmostorm.app.hasMainFigure()
        desmostorm.app.focusMainFigure();
        return
    end

    % start the GUI
    desmostorm.app.GUI;

end
