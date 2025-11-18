classdef Settings < handle
    % Orchestrates sub-settings. Observable; bubbles child changes.
    properties (SetAccess=public)
        Analysis  app.config.Analysis
        Display   app.config.Display
        IO        app.config.IO
    end

    events
        Changed   % fired whenever any sub-setting changes
        AnalysisChanged
        DisplayChanged
        IOChanged
    end

    methods
        function this = Settings()
            this.Analysis = app.config.Analysis();
            this.Display  = app.config.Display();
            this.IO       = app.config.IO();

            % Bubble domain-specific change events up to Settings.Changed
            addlistener(this.Analysis, 'AnalysisChanged', @(s,e) notify(this,'AnalysisChanged',e));
            addlistener(this.Display,  'DisplayChanged', @(s,e) notify(this,'DisplayChanged',e));
            addlistener(this.IO,       'IOChanged', @(s,e) notify(this,'IOChanged',e));

            % Also bubble generic change events up to Settings.Changed
            addlistener(this.Analysis, 'Changed', @(s,e) notify(this,'Changed',e));
            addlistener(this.Display,  'Changed', @(s,e) notify(this,'Changed',e));
            addlistener(this.IO,       'Changed', @(s,e) notify(this,'Changed',e));
        end

        function save(this, file)
            if nargin < 2
                file = app.config.Settings.defaultFile();
            end

            S.Version  = char(app.Info.Version);
            S.Analysis = this.Analysis.toStruct();
            S.Display  = this.Display.toStruct();
            S.IO       = this.IO.toStruct();
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
    end

    methods (Static)

        function obj = load(file)
            if nargin < 1
                file = app.config.Settings.defaultFile();
            end

            % create the settings object
            obj = app.config.Settings();

            if isfile(file)
                txt = fileread(file);
                S = jsondecode(txt);
                if ~isfield(S,'Version')
                    S.Version = '0.0.0';
                end

                % upgrade version if needed
                [S,migrated] = app.config.Settings.migrate(S);

                obj.Analysis.fromStruct(S.Analysis);
                obj.Display.fromStruct(S.Display);
                obj.IO.fromStruct(S.IO);

                % if the settings file was migrated to current version
                if migrated
                    % save it
                    obj.save(file);
                end
            else
                % First run: create file with defaults
                obj.save(file);
            end
        end

        function p = defaultFile()
            % get full path to default settings file
            p = app.Paths.settingsFile();
        end

        function [S, migrated] = migrate(S)
            migrated = false;
            
            % old = string(S.Version);

            % --- Example migration ---
            % From any version older than 1.0.0: add IO.AutoSave
            % if app.Version.compare(old, "1.0.0") < 0
            %     warning('Migrating settings to v1.0.0...')
            %     if ~isfield(S,'IO') || ~isfield(S.IO,'AutoSave')
            %         S.IO.AutoSave = true;
            %         migrated = true;
            %     end
            % end

        end



    end
end