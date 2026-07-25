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
% Notes
% -----
% - Lazy-creates a single matlabx.logging.Logger for the current MATLAB session.
% - Public wrapper methods auto-populate Source based on the caller if not provided.
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
            [src, args] = desmostorm.Log.resolveSource_(varargin{:});
            desmostorm.Log.get().info(desmostorm.Log.normalizeMsg_(msg), "Source", src, args{:});
        end

        function DEBUG(msg, varargin)
        %DEBUG Log a DEBUG message.
            [src, args] = desmostorm.Log.resolveSource_(varargin{:});
            desmostorm.Log.get().debug(desmostorm.Log.normalizeMsg_(msg), "Source", src, args{:});
        end

        function WARN(msg, varargin)
        %WARN Log a WARN message.
            [src, args] = desmostorm.Log.resolveSource_(varargin{:});
            desmostorm.Log.get().warn(desmostorm.Log.normalizeMsg_(msg), "Source", src, args{:});
        end

        function ERROR(msg, varargin)
        %ERROR Log an ERROR message.
            [src, args] = desmostorm.Log.resolveSource_(varargin{:});
            desmostorm.Log.get().error(desmostorm.Log.normalizeMsg_(msg), "Source", src, args{:});
        end

        function EXCEPTION(ME, varargin)
        %EXCEPTION Log an MException as an error.
            [src, args] = desmostorm.Log.resolveSource_(varargin{:});
            desmostorm.Log.get().error(ME, "Source", src, args{:});
        end

        function LOG(level, msg, varargin)
        %LOG Generic logging entry point.
            [src, args] = desmostorm.Log.resolveSource_(varargin{:});
            desmostorm.Log.get().log(level, desmostorm.Log.normalizeMsg_(msg), "Source", src, args{:});
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

        function [src, args] = resolveSource_(varargin)
            %RESOLVESOURCE_ Use explicit Source if provided, else infer from caller.
            args = varargin;

            idx = desmostorm.Log.findNameValue_(args, "Source");
            if ~isempty(idx)
                src = string(args{idx+1});
                args(idx:idx+1) = [];
                return
            end

            % Stack here is typically:
            % 1 resolveSource_
            % 2 desmostorm.Log.INFO / DEBUG / ...
            % 3 actual caller
            st = dbstack(2, '-completenames');

            if isempty(st)
                src = "unknown";
                return
            end

            src = matlabx.logging.formatCallerName(st(1).name, Detail="short");
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
