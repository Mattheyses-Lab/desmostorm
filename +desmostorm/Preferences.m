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

    end
    
end