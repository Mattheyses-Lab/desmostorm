classdef Preferences
%PREFERENCES  Facade for persistent application preferences.
%
%   Wraps MATLAB's GETPREF/SETPREF APIs behind a desmostorm-specific
%   interface. Intended for storing persistent application state that
%   should survive between MATLAB sessions, such as setup versions,
%   migration status, accepted notices, etc.
%
%   This class is not intended for user-configurable settings. Those
%   belong in the desmostorm.config.Settings system.

    properties (Constant, Access = private)
    %GROUP  MATLAB preference group name.
    %
    %   All preferences managed by this class are stored under this
    %   group to avoid collisions with other applications.
        Group = 'desmostorm'
    end

    methods (Static)

        function value = get(name, defaultValue)
        %GET  Retrieve a preference value.
        %
        %   VALUE = GET(NAME, DEFAULTVALUE) returns the stored
        %   preference value if it exists. Otherwise, DEFAULTVALUE is
        %   returned.
        %
        %   Example:
        %       v = desmostorm.Preferences.get( ...
        %           "SetupVersion", 0);

            if ispref(desmostorm.Preferences.Group, name)
                value = getpref(desmostorm.Preferences.Group, name);
            else
                value = defaultValue;
            end
        end

        function set(name, value)
        %SET  Store a preference value.
        %
        %   SET(NAME, VALUE) stores VALUE under the specified
        %   preference name.
        %
        %   Example:
        %       desmostorm.Preferences.set( ...
        %           "SetupVersion", 1);

            setpref(desmostorm.Preferences.Group, name, value);
        end

        function tf = has(name)
        %HAS  Determine whether a preference exists.
        %
        %   TF = HAS(NAME) returns true if the specified preference
        %   exists and false otherwise.
        %
        %   Example:
        %       if desmostorm.Preferences.has("SetupVersion")

            tf = ispref(desmostorm.Preferences.Group, name);
        end

        function remove(name)
        %REMOVE  Remove a preference.
        %
        %   REMOVE(NAME) deletes the specified preference if it exists.
        %
        %   Example:
        %       desmostorm.Preferences.remove("SetupVersion");

            if desmostorm.Preferences.has(name)
                rmpref(desmostorm.Preferences.Group, name);
            end
        end

        function prefs = print()
        %PRINT  Print all desmostorm preferences.
        %
        %   PRINT() lists every stored preference in the desmostorm
        %   preference group.
        %
        %   PREFS = PRINT() also returns the preferences as a struct.

            group = desmostorm.Preferences.Group;

            if ~ispref(group)
                prefs = struct();
                fprintf('No desmostorm preferences found.\n');
                return
            end

            prefs = getpref(group);
            names = fieldnames(prefs);

            if isempty(names)
                fprintf('No desmostorm preferences found.\n');
                return
            end

            matlabx.struct.prettyPrint(prefs);
        end

        function names = names()
        %NAMES  Return known desmostorm preference names.
        %
        %   NAMES = desmostorm.Preferences.names() returns the names of
        %   preferences currently understood by desmostorm. A preference
        %   can be known even when it has not been explicitly stored.

            catalog = desmostorm.Preferences.catalog_();
            names = string({catalog.Name})';
        end

        function T = describe()
        %DESCRIBE  Describe known desmostorm preferences.
        %
        %   DESCRIBE() prints a table containing known preference names,
        %   dynamic defaults, current effective values, whether each value
        %   is explicitly stored, and a short description.
        %
        %   T = DESCRIBE() returns the same information as a table.

            catalog = desmostorm.Preferences.catalog_();
            defaults = desmostorm.Preferences.defaultValues_();

            n = numel(catalog);
            Name = strings(n,1);
            Category = strings(n,1);
            Default = strings(n,1);
            Effective = strings(n,1);
            Explicit = false(n,1);
            Description = strings(n,1);

            for k = 1:n
                name = string(catalog(k).Name);
                defaultValue = defaults.(name);
                effectiveValue = desmostorm.Preferences.get(name, defaultValue);

                Name(k) = name;
                Category(k) = string(catalog(k).Category);
                Default(k) = desmostorm.Preferences.valueToString_(defaultValue);
                Effective(k) = desmostorm.Preferences.valueToString_(effectiveValue);
                Explicit(k) = desmostorm.Preferences.has(name);
                Description(k) = string(catalog(k).Description);
            end

            T = table(Name, Category, Default, Effective, Explicit, Description);

            if nargout == 0
                disp(T);
                clear T
            end
        end

    end

    methods (Static, Access=private)

        function catalog = catalog_()
        %CATALOG_ Preference metadata for command-line discovery.
            catalog = [
                desmostorm.Preferences.entry_("SetupVersion", "Setup", ...
                    "Last desmostorm setup version applied to this MATLAB preferences group.")
                desmostorm.Preferences.entry_("DeveloperMode", "Runtime", ...
                    "Use developer-oriented runtime defaults, currently focused on logging.")
                desmostorm.Preferences.entry_("AnalysisDebugOutput", "Analysis", ...
                    "Show developer-oriented analysis diagnostics for experimental fitting routines.")
                desmostorm.Preferences.entry_("LoggingLevel", "Logging", ...
                    "Global minimum log level used by sinks that do not define their own level.")
                desmostorm.Preferences.entry_("LoggingDetail", "Logging", ...
                    "Global log formatting detail used by sinks that do not define their own detail.")
                desmostorm.Preferences.entry_("LoggingSourceDetail", "Logging", ...
                    "Source formatting detail: short class/function names or full call paths.")
                desmostorm.Preferences.entry_("LoggingCommandWindowLevel", "Logging", ...
                    "Minimum log level printed to the MATLAB Command Window.")
                desmostorm.Preferences.entry_("LoggingCommandWindowDetail", "Logging", ...
                    "Log formatting detail used for MATLAB Command Window output.")
                desmostorm.Preferences.entry_("LoggingUILevel", "Logging", ...
                    "Minimum log level shown in the GUI log window.")
                desmostorm.Preferences.entry_("LoggingUIDetail", "Logging", ...
                    "Log formatting detail used for the GUI log window.")
                desmostorm.Preferences.entry_("LoggingFileLevel", "Logging", ...
                    "Minimum log level written to the GUI session log file.")
                desmostorm.Preferences.entry_("LoggingFileDetail", "Logging", ...
                    "Log formatting detail written to the GUI session log file.")
                ];
        end

        function entry = entry_(name, category, description)
        %ENTRY_ Construct one catalog entry.
            entry = struct( ...
                "Name", string(name), ...
                "Category", string(category), ...
                "Description", string(description));
        end

        function defaults = defaultValues_()
        %DEFAULTVALUES_ Dynamic defaults for known preferences.
            devMode = logical(desmostorm.Preferences.get("DeveloperMode", false));
            logging = desmostorm.Log.preferenceDefaults(devMode);

            defaults = struct( ...
                "SetupVersion", "0.0.0", ...
                "DeveloperMode", false, ...
                "AnalysisDebugOutput", devMode, ...
                "LoggingLevel", logging.Level, ...
                "LoggingDetail", logging.Detail, ...
                "LoggingSourceDetail", logging.SourceDetail, ...
                "LoggingCommandWindowLevel", logging.CommandWindowLevel, ...
                "LoggingCommandWindowDetail", logging.CommandWindowDetail, ...
                "LoggingUILevel", logging.UILevel, ...
                "LoggingUIDetail", logging.UIDetail, ...
                "LoggingFileLevel", logging.FileLevel, ...
                "LoggingFileDetail", logging.FileDetail);
        end

        function s = valueToString_(value)
        %VALUETOSTRING_ Format mixed MATLAB preference values for a table.
            if isstring(value)
                s = strjoin(value, ", ");
            elseif ischar(value)
                s = string(value);
            elseif isnumeric(value) || islogical(value)
                s = string(mat2str(value));
            else
                try
                    s = string(jsonencode(value));
                catch
                    s = strtrim(string(evalc('disp(value)')));
                end
            end
        end

    end

end
