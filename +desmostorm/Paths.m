classdef Paths
%% Helper class for locating file paths

    methods(Static)
        function r = root()
            % This file lives in App/+app/Paths.m → go up twice to App/
            here = fileparts(mfilename('fullpath'));
            r = fileparts(here);
        end

        function p = user(varargin)
            p = fullfile(desmostorm.Paths.root(), 'user', varargin{:});
        end

        function p = configDir()
            % per-user writable folder for settings.json
            d = fullfile(prefdir, char(desmostorm.Info.Name));
            if ~exist(d,'dir'), mkdir(d); end
            p = d;
        end

        function p = settingsFile()
            % full path to settings.json
            p = fullfile(desmostorm.Paths.configDir(), 'settings.json');
        end

        function p = assets()
            p = fullfile(desmostorm.Paths.root, 'assets');
        end

        function p = ml()
            p = fullfile(desmostorm.Paths.assets,'ml');
        end

        function p = logs(varargin)
            p = fullfile(desmostorm.Paths.root(), 'logs', varargin{:});
        end

        function p = logFile(stem)
            arguments
                stem (1,1) string = "session"
            end

            timestamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
            fileName = sprintf('desmostorm_%s_%s.log', char(stem), char(timestamp));
            p = desmostorm.Paths.logs(fileName);
        end

        function p = external(varargin)
            p = fullfile(desmostorm.Paths.root(), 'external', varargin{:});
        end

    end

end
