classdef Zoom < widgets.ImageAxesTool
% widgets.tools.Zoom
% when Enabled: 
%   left-click to increase zoom 
%   right-click to decrease zoom
%   view box follows cursor when Pan Mode is on (on by default)
%   shift-click to enable/disable Pan
%   can also increase/decrease zoom with scroll wheel

    % properties specific to the zoom tool
    properties
        ZoomLevelIdx (1,1) double = 1
        ZoomLevels (1,:) double = [1 1/2 1/3 1/4 1/5 1/10 1/15 1/20]
        ZoomPanLim (1,2) double = [0.25 0.75]
    end

    properties (SetAccess=private, Dependent)
        ZoomLevel
        ZoomFactor
    end

    % Private properties for internal behavior
    properties (Access=private)
        % 
        lastCursorPosition = []
    end

    methods

        function obj = Zoom(host)
            obj@widgets.ImageAxesTool(host, "Zoom", ...
                'Tooltip','Zoom/Pan', ...
                'Icon',app.Paths.icons('ZoomIcon.png'), ...
                'Priority',1, ...
                'IsExclusive', false, ...
                'CapturesMove', true, ...
                'CapturesDown', true, ...
                'CapturesScroll', true, ...
                'DistractsMove', false, ...
                'DistractsDown', true);
        end

        % Toggled Enabled=true via toolbar button
        function onEnabled(obj)
            obj.Host.setMode('Zoom', true);
            obj.Host.setMode('Pan', true);
        end

        % Toggled Enabled=false via toolbar button
        function onDisabled(obj)
            if isvalid(obj.Host)
                obj.Host.restoreDefaultLimits();
            end
            obj.Host.setMode('Zoom', false);
        end

        % Called AFTER installed from Host, use for any extra required startup actions
        function onInstall(obj)
            obj.Host.addMode('Zoom');
            obj.Host.addMode('Pan');
            obj.Host.setMode('Pan', true); % Pan Mode is On by default
            %fprintf('"%s" tool installed\n',obj.Name)
        end

        % Called AFTER uninstalled from Host, use for any extra required cleanup actions
        function onUninstall(obj)
            obj.Host.removeMode('Zoom');
            obj.Host.removeMode('Pan');
            % fprintf('"%s" tool uninstalled\n',obj.Name)
        end

    end

    %% Active event hooks (only when Enabled==true && IsInterceptor==true)
    methods

        function onDown(obj, ~, ~)

            fprintf('%s.onDown()\n',obj.Name);

            H = obj.Host;
            if isempty(H.cursorPositionStatic)
                return
            end

            switch H.ParentFig.SelectionType
                case 'normal'
                    if H.Mode.Pan
                        obj.ZoomLevelIdx = min(obj.ZoomLevelIdx + 1, numel(obj.ZoomLevels));
                    end
                case 'alt'
                    if H.Mode.Pan
                        obj.ZoomLevelIdx = max(obj.ZoomLevelIdx-1,1);
                    end
                case 'extend'
                    % flip Pan state
                    obj.Host.setMode('Pan', ~H.Mode.Pan);
            end

            obj.onMove();
        end

        function onScroll(obj, evt, ~)
            % keep track of calls to control how many calls = one zoom increment
            % persistent callCount
            persistent callCount

            fprintf('%s.onScroll()\n',obj.Name);

            H = obj.Host;
            if isempty(H.cursorPositionStatic)
                return
            end

            callCount = callCount+1;
            if callCount < 5
                return
            end

            callCount = 0;

            % Adjust zoom level based on scroll direction
            if evt.VerticalScrollCount < 0
                obj.ZoomLevelIdx = min(obj.ZoomLevelIdx + 1, numel(obj.ZoomLevels));
                %H.ZoomLevelIdx = min(H.ZoomLevelIdx - evt.VerticalScrollCount, numel(H.ZoomLevels));
            elseif evt.VerticalScrollCount > 0
                obj.ZoomLevelIdx = max(obj.ZoomLevelIdx - 1, 1);
            end

            %H.applyZoomUnderCursor();
            obj.onMove();
        end

        function onMove(obj, ~, ~)
            fprintf('%s.onMove()\n',obj.Name);

            if ~obj.Host.Mode.Pan
                return
            end

            XY = obj.Host.cursorPositionStatic;

            if ~isempty(XY) && obj.Host.Mode.Zoom && obj.Host.Mode.Pan
                obj.updateLimits(XY);
            end
        end

    end

    %% Passive event hooks (only when Installed==true && IsDistractor==true)
    methods

        function tf = onDistractDown(obj,~,~)
            fprintf('%s.onDistractDown()\n',obj.Name);
            tf = false;
        end

        % function tf = onDistractMove(obj,evt,tgt)
        %     fprintf('%s.onDistractMove()\n',obj.Name);
        %     tf = false;
        % end

    end


    methods

        function z = get.ZoomLevel(obj)
            z = obj.ZoomLevels(obj.ZoomLevelIdx);
        end

        function f = get.ZoomFactor(obj)
            f = 1/obj.ZoomLevel;
        end

        function [XLim,YLim] = getZoomLims(obj,cursorXY)

            W = obj.Host.ImageWidth;
            H = obj.Host.ImageHeight;
            z = obj.ZoomLevel;                % e.g., 0.5 means 2x zoom

            % --- X ---
            XRange = z * W;
            cX = clip(cursorXY(1), obj.Host.defaultXLim(1), obj.Host.defaultXLim(2));
            uX = (cX - 0.5) / W;              % normalized cursor in [0,1] over static axes

            a = obj.ZoomPanLim(1);
            b = obj.ZoomPanLim(2);
            uXc = clip(uX, a, b);             % clamp to pan band
            tX = (uXc - a) / (b - a);         % 0 at left edge of band, 1 at right
            Sx = W - XRange;                  % available travel for the zoomed window
            x1 = 0.5 + tX * Sx;               % linear map across the travel
            XLim = [x1, x1 + XRange];

            % --- Y ---
            YRange = z * H;
            cY = clip(cursorXY(2), obj.Host.defaultYLim(1), obj.Host.defaultYLim(2));
            uY = (cY - 0.5) / H;
            uYc = clip(uY, a, b);
            tY = (uYc - a) / (b - a);
            Sy = H - YRange;
            y1 = 0.5 + tY * Sy;
            YLim = [y1, y1 + YRange];

        end





    end

    %% Host-fired events

    methods

        function onHostCDataChanged(obj,evt)
            if ~obj.Enabled
                return
            end

            oldSize = size(evt.oldCData);
            newSize = size(evt.newCData);

            if isempty(obj.lastCursorPosition)
                return
            end

            oldX = obj.lastCursorPosition(1);
            oldY = obj.lastCursorPosition(2);

            % new image is same size as the previous image
            if isequal(oldSize,newSize)
                % set limits using prior cursor position
                obj.updateLimits([oldX,oldY]);
                return
            end

            % otherwise, re-map previous cursor position to hit the same relative spot in new image
            newY = oldY*(newSize(1)/oldSize(1));
            newX = oldX*(newSize(2)/oldSize(2));

            % set new limits using new cursor position
            obj.updateLimits([newX,newY]);
            
            fprintf('Host CData changed\n')
        end

    end

    %% Host update helpers
    methods

        function pointer = getPreferredPointer(obj)
            if obj.Host.Mode.Zoom
                pointer = 'crosshair';
            else
                pointer = '';
            end
        end

        function updateLimits(obj,XY)
            [XLim,YLim] = obj.getZoomLims(XY);
            set(obj.Host.mainAxes,'XLim',XLim,'YLim',YLim);
            % save last cursor position used to set limits
            obj.lastCursorPosition = XY;
        end

    end



    %% Teardown
    methods (Access = protected)

        % % called at the beginning of superclass delete()
        % function teardown(obj)
        %     % here is where you can perform any cleanup before object deletion
        % end

    end

end