classdef Info
    properties (Constant)
        Name    string = "desmostorm"   % name of the app
        Version string = "1.1.0"        % application version, major.minor.patch

        % Setup version is intentionally separate from app version. Bump this
        % only when launch should rerun setup work such as path setup, matlabx
        % setup, UI calibration, or preference/settings migration checks.
        RequiredSetupVersion string = "1.1.0"

        % Settings schema version describes the shape/meaning of saved settings
        % files. Schema migration should preserve user intent whenever possible:
        % add missing fields, rename old fields, or normalize old layouts.
        SettingsSchemaVersion string = "1.1.0"

        % Factory defaults version describes the generation of default app
        % settings. Bump this when early-development defaults should be pushed
        % into the app-level settings file. This is more opinionated than schema
        % migration and is not applied to settings embedded in project files.
        FactoryDefaultsVersion string = "1.1.0"
    end
end
