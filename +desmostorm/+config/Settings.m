% DesmoSTORM - MATLAB app for desmosomal plaque protein analysis.
% Copyright (C) 2026 William Dean
%
% This program is free software; you can redistribute it and/or modify it
% under the terms of the GNU General Public License as published by the Free
% Software Foundation; either version 2 of the License, or (at your option)
% any later version.
%
% This program is distributed in the hope that it will be useful, but WITHOUT
% ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
% FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
% details.
%
% You should have received a copy of the GNU General Public License along
% with this program; if not, see <https://www.gnu.org/licenses/>.

classdef Settings < handle
    % Orchestrates sub-settings. Observable; bubbles child changes.
    properties (SetAccess=public)
        Analysis  desmostorm.config.Analysis   % analysis settings
        Display   desmostorm.config.Display    % general display settings
        IO        desmostorm.config.IO         % import/export settings
        PeaksPlot desmostorm.config.PeaksPlot  % PeaksPlot appearance settings
        ROI       desmostorm.config.ROI        % RegionViewer ROI appearance settings
        Box       desmostorm.config.Box        % region selection box settings
    end

    events
        Changed             % fired whenever any sub-setting changes

        AnalysisChanged
        DisplayChanged
        IOChanged
        PeaksPlotChanged
        ROIChanged
        BoxChanged
    end

    methods
        function this = Settings()
            this.Analysis   = desmostorm.config.Analysis();
            this.Display    = desmostorm.config.Display();
            this.IO         = desmostorm.config.IO();
            this.PeaksPlot  = desmostorm.config.PeaksPlot();
            this.ROI        = desmostorm.config.ROI();
            this.Box        = desmostorm.config.Box();

            % Bubble domain-specific change events up to Settings.Changed
            addlistener(this.Analysis,  'AnalysisChanged',  @(s,e) notify(this,'AnalysisChanged',e));
            addlistener(this.Display,   'DisplayChanged',   @(s,e) notify(this,'DisplayChanged',e));
            addlistener(this.IO,        'IOChanged',        @(s,e) notify(this,'IOChanged',e));
            addlistener(this.PeaksPlot, 'PeaksPlotChanged', @(s,e) notify(this,'PeaksPlotChanged',e));
            addlistener(this.ROI,       'ROIChanged',       @(s,e) notify(this,'ROIChanged',e));
            addlistener(this.Box,       'BoxChanged',       @(s,e) notify(this,'BoxChanged',e));

            % Also bubble generic change events up to Settings.Changed
            addlistener(this.Analysis,      'Changed', @(s,e) notify(this,'Changed',e));
            addlistener(this.Display,       'Changed', @(s,e) notify(this,'Changed',e));
            addlistener(this.IO,            'Changed', @(s,e) notify(this,'Changed',e));
            addlistener(this.PeaksPlot,     'Changed', @(s,e) notify(this,'Changed',e));
            addlistener(this.ROI,           'Changed', @(s,e) notify(this,'Changed',e));
            addlistener(this.Box,           'Changed', @(s,e) notify(this,'Changed',e));
        end

        function save(this, file)
            if nargin < 2
                file = desmostorm.config.Settings.defaultFile();
            end

            % Version is retained for older project/settings readers. The two
            % explicit settings versions below are the authoritative values for
            % migration decisions going forward.
            S.Version = char(desmostorm.Info.Version);
            S.SettingsSchemaVersion = char(desmostorm.Info.SettingsSchemaVersion);
            S.FactoryDefaultsVersion = char(desmostorm.Info.FactoryDefaultsVersion);
            S.Analysis = this.Analysis.toStruct();
            S.Display  = this.Display.toStruct();
            S.IO       = this.IO.toStruct();

            S.PeaksPlot = this.PeaksPlot.toStruct();
            S.ROI       = this.ROI.toStruct();
            S.Box       = this.Box.toStruct();

            json = jsonencode(S, 'PrettyPrint', true);

            folder = fileparts(file); 
            if ~exist(folder, 'dir')
                mkdir(folder);
            end

            fid = fopen(file,'w'); 
            assert(fid>0, 'Cannot open settings file for write.');
            fwrite(fid, json, 'char'); 
            fclose(fid);
        end


        function S = toStruct(obj)
            S.Version = char(desmostorm.Info.Version);
            S.SettingsSchemaVersion = char(desmostorm.Info.SettingsSchemaVersion);
            S.FactoryDefaultsVersion = char(desmostorm.Info.FactoryDefaultsVersion);
            S.Analysis  = obj.Analysis.toStruct();
            S.Display   = obj.Display.toStruct();
            S.IO        = obj.IO.toStruct();
            S.PeaksPlot = obj.PeaksPlot.toStruct();
            S.ROI       = obj.ROI.toStruct();
            S.Box       = obj.Box.toStruct();
        end

        function fromStruct(obj,S)
            % Project files carry a settings snapshot so old projects remain
            % readable. Only schema migration is applied here; factory-default
            % migration is intentionally limited to the app-level settings file.
            [S,~] = desmostorm.config.Settings.migrate(S, ...
                "ApplyFactoryDefaults",false);
            obj.Analysis.fromStruct(S.Analysis);
            obj.Display.fromStruct(S.Display);
            obj.IO.fromStruct(S.IO);
            obj.PeaksPlot.fromStruct(S.PeaksPlot);
            obj.ROI.fromStruct(S.ROI);
            obj.Box.fromStruct(S.Box);
        end

    end

    methods (Static)

        function obj = load(file)
            if nargin < 1
                file = desmostorm.config.Settings.defaultFile();
            end

            % create the settings object
            obj = desmostorm.config.Settings();

            if isfile(file)
                txt = fileread(file);
                S = jsondecode(txt);

                % App-level settings get both migrations:
                %   - schema migration keeps old files readable
                %   - factory-default migration may intentionally update defaults
                [S,migrated] = desmostorm.config.Settings.migrate(S, ...
                    "ApplyFactoryDefaults",true);

                obj.Analysis.fromStruct(S.Analysis);
                obj.Display.fromStruct(S.Display);
                obj.IO.fromStruct(S.IO);
                
                obj.PeaksPlot.fromStruct(S.PeaksPlot);
                obj.ROI.fromStruct(S.ROI);
                obj.Box.fromStruct(S.Box);

                % if the settings file was migrated to current version
                if migrated
                    % save it
                    obj.save(file);
                end
            else
                % First run: create file with defaults
                desmostorm.Log.INFO(sprintf( ...
                    "Creating desmostorm settings file: %s",file));
                obj.save(file);
            end
        end

        function p = defaultFile()
            % get full path to default settings file
            p = desmostorm.Paths.settingsFile();
        end

        function [S, migrated] = migrate(S, opts)
        %MIGRATE Update a saved settings struct to the versions required now.
        %
        % There are two deliberately separate migration concepts:
        %
        %   Schema migration:
        %       Makes old settings readable by the current code. This should
        %       preserve user intent whenever possible and is safe for both the
        %       app-level settings file and settings embedded in project files.
        %
        %   Factory-default migration:
        %       Refreshes the app-level settings file to a newer generation of
        %       preferred defaults. This is useful during early development, but
        %       it is more opinionated, so it is never applied to project files.
            arguments
                S
                opts.ApplyFactoryDefaults (1,1) logical = false
            end

            migrated = false;

            [S,schemaMigrated] = desmostorm.config.Settings.migrateSchema_(S);
            migrated = migrated || schemaMigrated;

            if opts.ApplyFactoryDefaults
                [S,defaultsMigrated] = desmostorm.config.Settings.migrateFactoryDefaults_(S);
                migrated = migrated || defaultsMigrated;
            end
        end

        function restore()
            % get default settings file location
            file = desmostorm.config.Settings.defaultFile();
            % create the settings object using default values
            obj = desmostorm.config.Settings();
            % save the new file (will overwrite current settings if it exists)
            obj.save(file);
        end
        
    end

    methods (Static, Access=private)

        function [S,migrated] = migrateSchema_(S)
        %MIGRATESCHEMA_ Preserve old settings behavior under the current schema.
            migrated = false;
            old = desmostorm.config.Settings.schemaVersion_(S);
            target = desmostorm.Info.SettingsSchemaVersion;

            S = desmostorm.config.Settings.ensureVersionFields_(S);
            S = desmostorm.config.Settings.ensureSettingCategories_(S);

            if desmostorm.Version.compare(old, "1.1.0") < 0
                desmostorm.Log.WARN(sprintf( ...
                    "Migrating settings schema from %s to 1.1.0.",old));

                % Box settings: old files used BoxFaceColor/BoxEdgeColor.
                defaultBox = desmostorm.config.Box;
                if isfield(S.Box,'BoxFaceColor') && ~isfield(S.Box,'FaceColor')
                    S.Box.FaceColor = S.Box.BoxFaceColor;
                end
                if isfield(S.Box,'BoxEdgeColor') && ~isfield(S.Box,'EdgeColor')
                    S.Box.EdgeColor = S.Box.BoxEdgeColor;
                end
                if ~isfield(S.Box,'ShowTitle'), S.Box.ShowTitle = defaultBox.ShowTitle; end
                if ~isfield(S.Box,'TitleContent'), S.Box.TitleContent = defaultBox.TitleContent; end

                % Analysis settings gained normalization and prominence fields.
                defaultAnalysis = desmostorm.config.Analysis;
                if ~isfield(S.Analysis,'Normalize')
                    S.Analysis.Normalize = defaultAnalysis.Normalize;
                end
                if ~isfield(S.Analysis,'MinPeakProminence')
                    S.Analysis.MinPeakProminence = defaultAnalysis.MinPeakProminence;
                end

                % Display settings gained intensity scaling and channel mode.
                defaultDisplay = desmostorm.config.Display;
                if ~isfield(S.Display,'AutoScaleDisplayIntensity')
                    S.Display.AutoScaleDisplayIntensity = defaultDisplay.AutoScaleDisplayIntensity;
                end
                if ~isfield(S.Display,'ChannelColorMode')
                    S.Display.ChannelColorMode = defaultDisplay.ChannelColorMode;
                end

                % PeaksPlot was expanded for multi-channel and annotation modes.
                defaultPeaksPlot = desmostorm.config.PeaksPlot;
                newPeaksPlotFields = [
                    "ShownPlots"
                    "ColorSource"
                    "Color"
                    "AnnotationColorMode"
                    "AnnotationColor"
                    "DistanceAnnotations"
                    "DistanceAnnotationsMode"
                    "WidthAnnotations"
                    "WidthAnnotationsMode"];
                for i = 1:numel(newPeaksPlotFields)
                    f = char(newPeaksPlotFields(i));
                    if ~isfield(S.PeaksPlot,f)
                        S.PeaksPlot.(f) = defaultPeaksPlot.(f);
                    end
                end

                % ROI is a new settings category for DrawRectangle appearance.
                if ~isfield(S,'ROI') || isempty(S.ROI)
                    defaultROI = desmostorm.config.ROI;
                    S.ROI = defaultROI.toStruct();
                end

                migrated = true;
            end

            if ~isfield(S,'ROI') || isempty(S.ROI)
                defaultROI = desmostorm.config.ROI;
                S.ROI = defaultROI.toStruct();
                migrated = true;
            end

            if string(S.SettingsSchemaVersion) ~= target
                S.SettingsSchemaVersion = char(target);
                migrated = true;
            end
        end

        function [S,migrated] = migrateFactoryDefaults_(S)
        %MIGRATEFACTORYDEFAULTS_ Apply intentional app-level default updates.
        %
        % Bump desmostorm.Info.FactoryDefaultsVersion when current installed app
        % settings should adopt a newer default behavior. Unlike schema
        % migration, this may overwrite existing app-level settings. It is not
        % used for project-embedded settings snapshots.
            migrated = false;
            old = desmostorm.config.Settings.factoryDefaultsVersion_(S);
            target = desmostorm.Info.FactoryDefaultsVersion;

            if desmostorm.Version.compare(old,target) >= 0
                return
            end

            defaults = desmostorm.config.Settings();
            desmostorm.Log.WARN(sprintf( ...
                "Updating app settings factory defaults from %s to %s.",old,target));

            if desmostorm.Version.compare(old,"1.1.0") < 0
                % First explicit factory-default generation. Refresh the app's
                % tunable defaults to the current class defaults. Keep
                % IO.DefaultFolder because it is a user/machine path, not really
                % an analysis/display default.
                oldDefaultFolder = "";
                if isfield(S,'IO') && isfield(S.IO,'DefaultFolder')
                    oldDefaultFolder = string(S.IO.DefaultFolder);
                end

                S.Analysis = defaults.Analysis.toStruct();
                S.Display = defaults.Display.toStruct();
                S.PeaksPlot = defaults.PeaksPlot.toStruct();
                S.ROI = defaults.ROI.toStruct();
                S.Box = defaults.Box.toStruct();
                S.IO = defaults.IO.toStruct();

                if oldDefaultFolder ~= ""
                    S.IO.DefaultFolder = oldDefaultFolder;
                end
            end

            S.FactoryDefaultsVersion = char(target);
            migrated = true;
        end

        function S = ensureVersionFields_(S)
        %ENSUREVERSIONFIELDS_ Normalize old single-version settings files.
            if ~isfield(S,'Version') || isempty(S.Version)
                S.Version = '0.0.0';
            end
            if ~isfield(S,'SettingsSchemaVersion') || isempty(S.SettingsSchemaVersion)
                % Old files used Version for both app and settings layout.
                S.SettingsSchemaVersion = S.Version;
            end
            if ~isfield(S,'FactoryDefaultsVersion') || isempty(S.FactoryDefaultsVersion)
                S.FactoryDefaultsVersion = '0.0.0';
            end
        end

        function S = ensureSettingCategories_(S)
        %ENSURESETTINGCATEGORIES_ Add missing category structs before field migration.
            defaults = desmostorm.config.Settings();
            categories = ["Analysis","Display","IO","PeaksPlot","ROI","Box"];
            for i = 1:numel(categories)
                f = char(categories(i));
                if ~isfield(S,f) || isempty(S.(f))
                    defaultsCategory = defaults.(f);
                    S.(f) = defaultsCategory.toStruct();
                end
            end
        end

        function v = schemaVersion_(S)
        %SCHEMAVERSION_ Return the saved settings schema version.
            if isfield(S,'SettingsSchemaVersion') && ~isempty(S.SettingsSchemaVersion)
                v = string(S.SettingsSchemaVersion);
            elseif isfield(S,'Version') && ~isempty(S.Version)
                v = string(S.Version);
            else
                v = "0.0.0";
            end
        end

        function v = factoryDefaultsVersion_(S)
        %FACTORYDEFAULTSVERSION_ Return the saved factory-default generation.
            if isfield(S,'FactoryDefaultsVersion') && ~isempty(S.FactoryDefaultsVersion)
                v = string(S.FactoryDefaultsVersion);
            else
                v = "0.0.0";
            end
        end
    end
end
