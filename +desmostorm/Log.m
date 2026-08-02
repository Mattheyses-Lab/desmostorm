classdef Log
%DESMOSTORM.LOG  Static facade and singleton accessor for the desmostorm session logger.
%
% Typical use
% -----------
%   desmostorm.Log.INFO("Application started")
%   desmostorm.Log.WARN("Something looks odd")
%
% Get underlying logger handle when needed
% ----------------------------------------
%   log = desmostorm.Log.get();
%   log.setFileSink(logPath, true);
%   log.setUISink(@(lines) appendToTextArea(LogTextArea, lines), true);
%
% Start a GUI session logger
% --------------------------
%   [log, logPath] = desmostorm.Log.startGUISession();
%
% Notes
% -----
% - Lazy-creates a single matlabx.logging.Logger for the current MATLAB session.
% - startGUISession() replaces that logger with a fresh GUI-session logger
%   and attaches a timestamped file sink under the app logs folder.
% - Public wrapper methods preserve explicit Source values; otherwise they
%   infer the first non-desmostorm.Log caller and leave formatting to Logger.
% - clear() removes the stored handle from the facade. If other references exist,
%   the logger object itself will remain alive until those references are released.

    methods (Static)

        function log = get()
        %GET Return the active logger, creating it if needed.
            log = desmostorm.Log.peek_();
            if isempty(log) || ~isvalid(log)
                log = matlabx.logging.Logger();
                desmostorm.Log.store_(log);
            end
        end

        function set(log)
        %SET Replace the active logger.
            arguments
                log (1,1) matlabx.logging.Logger
            end
            desmostorm.Log.store_(log);
        end

        function [log, logPath] = startGUISession(opts)
        %STARTGUISESSION Start a fresh logger for an interactive GUI run.
        %
        %   [LOG, LOGPATH] = STARTGUISESSION() clears any logger currently
        %   owned by the facade, creates a new logger, and attaches a file
        %   sink at a timestamped path under the app-level logs folder.

            arguments
                opts.LogFile (1,1) string = string(desmostorm.Paths.logFile("gui"))
                opts.LoggingConfig (1,1) matlabx.config.Logging = desmostorm.Log.defaultGUIConfig_()
            end

            oldLog = desmostorm.Log.peek_();
            if ~isempty(oldLog) && isvalid(oldLog)
                try oldLog.flush(); catch, end
                delete(oldLog);
            end

            log = matlabx.logging.Logger();
            log.configure(opts.LoggingConfig);
            logPath = opts.LogFile;
            log.setFileSink(char(logPath), true);

            desmostorm.Log.store_(log);
        end

        function clear()
        %CLEAR Clear the stored logger handle from the facade.
            desmostorm.Log.store_([]);
        end

        function tf = exists()
        %EXISTS True if a valid logger is currently stored.
            log = desmostorm.Log.peek_();
            tf = ~isempty(log) && isvalid(log);
        end

        function INFO(msg, varargin)
        %INFO Log an INFO message.
            [log, args] = desmostorm.Log.prepareArgs_(varargin{:});
            log.info(desmostorm.Log.normalizeMsg_(msg), args{:});
        end

        function DEBUG(msg, varargin)
        %DEBUG Log a DEBUG message.
            [log, args] = desmostorm.Log.prepareArgs_(varargin{:});
            log.debug(desmostorm.Log.normalizeMsg_(msg), args{:});
        end

        function WARN(msg, varargin)
        %WARN Log a WARN message.
            [log, args] = desmostorm.Log.prepareArgs_(varargin{:});
            log.warn(desmostorm.Log.normalizeMsg_(msg), args{:});
        end

        function ERROR(msg, varargin)
        %ERROR Log an ERROR message.
            [log, args] = desmostorm.Log.prepareArgs_(varargin{:});
            log.error(desmostorm.Log.normalizeMsg_(msg), args{:});
        end

        function EXCEPTION(ME, varargin)
        %EXCEPTION Log an MException as an error.
            [log, args] = desmostorm.Log.prepareArgs_(varargin{:});
            log.error(ME, args{:});
        end

        function LOG(level, msg, varargin)
        %LOG Generic logging entry point.
            [log, args] = desmostorm.Log.prepareArgs_(varargin{:});
            log.log(level, desmostorm.Log.normalizeMsg_(msg), args{:});
        end

        function flush()
        %FLUSH Flush pending UI/file sink output.
            desmostorm.Log.get().flush();
        end

        function T = asTable()
        %ASTABLE Return stored log entries as a table.
            T = desmostorm.Log.get().asTable();
        end

        function lines = exportText()
        %EXPORTTEXT Return formatted stored log lines.
            lines = desmostorm.Log.get().exportText();
        end

    end

    methods (Static, Access=private)

        function log = peek_()
        %PEEK_ Return stored logger without creating one.
            log = desmostorm.Log.store_();
        end

        function log = store_(newLog)
        %STORE_ Persistent storage owner for the logger handle.
            persistent L
            if nargin > 0
                L = newLog;
            end
            log = L;
        end

        function config = defaultGUIConfig_()
        %DEFAULTGUICONFIG_ Default logging policy for interactive sessions.
            config = matlabx.config.Logging( ...
                "Level","DEBUG", ...
                "Detail","normal", ...
                "SourceDetail","short", ...
                "CommandWindowLevel","INFO", ...
                "CommandWindowDetail","normal", ...
                "UILevel","INFO", ...
                "UIDetail","normal", ...
                "FileLevel","DEBUG", ...
                "FileDetail","debug");
        end

        function [log, args] = prepareArgs_(varargin)
        %PREPAREARGS_ Preserve explicit Source or infer the app caller.
            log = desmostorm.Log.get();
            args = varargin;

            idx = desmostorm.Log.findNameValue_(args, "Source");
            if ~isempty(idx)
                return
            end

            args = [{'Source', desmostorm.Log.detectSource_(log.SourceDetail)}, args];
        end

        function source = detectSource_(sourceDetail)
        %DETECTSOURCE_ Infer the first caller outside the desmostorm facade.
            st = dbstack(1, '-completenames');

            for k = 1:numel(st)
                name = string(st(k).name);
                if startsWith(name, "desmostorm.Log.") || name == "desmostorm.Log"
                    continue
                end

                source = matlabx.logging.formatCallerName( ...
                    name, "Detail", sourceDetail);
                return
            end

            source = "unknown";
        end

        function msg = normalizeMsg_(msg)
            if ~isa(msg, 'MException')
                msg = string(msg);
            end
        end

        function idx = findNameValue_(args, name)
        %FINDNAMEVALUE_ Find a name-value pair position in varargin-like input.
            idx = [];
            for k = 1:2:(numel(args)-1)
                key = args{k};
                if (ischar(key) || isstring(key)) && strcmpi(string(key), string(name))
                    idx = k;
                    return
                end
            end
        end

    end

end
