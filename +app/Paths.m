classdef Paths
%% Helper class for locating file paths

    methods(Static)
        function r = root()
            % This file lives in App/+app/Paths.m → go up twice to App/
            here = fileparts(mfilename('fullpath'));
            r = fileparts(here);
        end
        function p = user(varargin)
            p = fullfile(app.Paths.root(), 'user', varargin{:});
        end
        function p = configDir()
            % per-user writable folder for settings.json
            d = fullfile(prefdir, char(app.Info.Name));
            if ~exist(d,'dir'), mkdir(d); end
            p = d;
        end
        function p = settingsFile()
            % full path to settings.json
            p = fullfile(app.Paths.configDir(), 'settings.json');
        end
        function p = assets()
            p = fullfile(app.Paths.root, 'assets');
        end
        function p = ml()
            p = fullfile(app.Paths.assets,'ml');
        end
    end

end