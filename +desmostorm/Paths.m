classdef Paths
%% Helper class for locating file paths

    methods(Static)
        function r = root()
            % This file lives in App/+app/Paths.m → go up twice to App/
            here = fileparts(mfilename('fullpath'));
            r = fileparts(fileparts(here));
        end

        function p = user(varargin)
            p = fullfile(desmostorm.app.Paths.root(), 'user', varargin{:});
        end

        function p = configDir()
            % per-user writable folder for settings.json
            d = fullfile(prefdir, char(desmostorm.app.Info.Name));
            if ~exist(d,'dir'), mkdir(d); end
            p = d;
        end

        function p = settingsFile()
            % full path to settings.json
            p = fullfile(desmostorm.app.Paths.configDir(), 'settings.json');
        end

        function p = assets()
            p = fullfile(desmostorm.app.Paths.root, 'assets');
        end

        function p = ml()
            p = fullfile(desmostorm.app.Paths.assets,'ml');
        end

        function p = external()
            p = fullfile(desmostorm.app.Paths.root(), 'external');
        end

    end

end