classdef ImageAxes < matlab.ui.componentcontainer.ComponentContainer
% widgets.ImageAxes - Image viewer with custom tool hosting and figure-level event routing via FigureEventHub

    %% Tool Management

    properties (SetAccess=?widgets.ImageAxesTool)
        % struct() of installed tools, fieldnames match tool Name
        Tools struct = struct()
    end

    properties (Dependent)
        % the set of tools to INSTALL in this ImageAxes (can be changed by user)
        ToolBelt
        % the set of tools to LOAD in this ImageAxes (can be changed by user)
        ToolBox
    end

    properties (Access=private)
        % registry of loaded tools
        ToolList        % containers.Map name->tool
        % registry of installed tools
        ToolRegistry    % containers.Map name->tool
    end

    properties (Access = ?widgets.ImageAxesTool)
        % the currently enabled tool with IsExclusive=true (if it exists)
        ActiveExclusiveTool
        % struct() of ToolbarButtons, fieldnames match tool Name
        ToolbarButtons struct = struct()
    end

    %% Public Parameters
    properties (AbortSet)
        Name (1,1) string = ""
    end

    % Passthroughs
    properties (Dependent)
        ImageVisible
        AxesVisible
        ColorbarVisible
        Colormap (256,3) double = turbo
    end

    %% Public props with private backing
    properties (Dependent,AbortSet)
        CLim (1,2) double
        CData (:,:)
        CLimMode (1,:) char
    end

    properties (Access=private)
        CLim_ (1,2) double = [0 1]
        CData_ (:,:) = widgets.ImageAxes.placeholderImage;
        CLimMode_ (1,:) char {mustBeMember(CLimMode_,{'auto','manual'})} = 'auto'
    end

    properties (Dependent)
        DisplayCData
        CDataClass
    end

    %% UI/Graphics

    % private
    properties (Access = private, Transient, NonCopyable)
        Grid matlab.ui.container.GridLayout
        Panel matlab.ui.container.Panel
        staticAxes matlab.ui.control.UIAxes
        hImage matlab.graphics.primitive.Image
        L event.listener
        Label (1,1) matlab.graphics.primitive.Text

        Colorbar matlab.graphics.illustration.ColorBar
    end

    % tool-accessible
    properties (Access = ?widgets.ImageAxesTool)
        mainAxes matlab.ui.control.UIAxes
    end

    %% Derived properties (accessible to tools)
    properties (Access = ?widgets.ImageAxesTool, Dependent)
        ParentFig
        ImageSize
        ImageWidth
        ImageHeight
        defaultXLim
        defaultYLim
        cursorPosition
        cursorPositionStatic
        activePixel
    end

    %% Tool helper variables
    properties (Access = ?widgets.ImageAxesTool)
        % control XLim and YLim of axes holding the image (if empty, lims will be set to default)
        XLim = []
        YLim = []
    end

    %% Modes for routing
    properties (SetAccess = private)
        % Mode struct = struct('Zoom',false,'Pan',true,'Pick',false,'DragBox',false)
        Mode struct = struct()
    end

    %% Hub registration
    properties (Access=private)
        Hub app.FigureEventHub
        RouterId double = NaN
    end

    %% Events
    events (NotifyAccess = protected)
        CDataChanged
    end

    %% ComponentContainer lifecycle
    methods (Access=protected)
        function setup(obj)

            obj.Interruptible = 'off';
            obj.BusyAction = 'cancel';

            % Main grid
            obj.Grid = uigridlayout(obj,[1,1], ...
                'RowHeight',{'1x'},...
                'ColumnWidth',{'1x'},...
                'RowSpacing',0,...
                'ColumnSpacing',0,...
                'Padding',[0 0 0 0], ...
                'BackgroundColor',[1 1 1]);

            % Panel to hold the axes
            obj.Panel = uipanel(obj.Grid, ...
                'BackgroundColor',[0 0 0],...
                'AutoResizeChildren','off',...
                'BorderWidth',0);

            % Static axes (used for cursor-follow zoom math)
            obj.staticAxes = uiaxes(obj.Panel, ...
                'Units','normalized', ...
                'InnerPosition',[0 0 1 1], ...
                'YDir','reverse', ...
                'YLim',obj.defaultYLim, ...
                'XLim',obj.defaultXLim, ...
                'XTick',[], ...
                'YTick',[], ...
                'Color',[0 0 1], ...
                'XColor','none', ...
                'YColor','none', ...
                'Visible','off', ...
                'PositionConstraint','innerposition', ...
                'HitTest','off', ...
                'PickableParts','none');
            obj.staticAxes.Toolbar = axtoolbar(obj.staticAxes,{});
            obj.staticAxes.Interactions = [];
            disableDefaultInteractivity(obj.staticAxes);
            obj.staticAxes.PlotBoxAspectRatio = [1 1 1];
            obj.staticAxes.DataAspectRatio = [1 1 1];

            % Main axes
            obj.mainAxes = uiaxes(obj.Panel, ...
                'Units','normalized', ...
                'InnerPosition',[0 0 1 1], ...
                'YDir','reverse', ...
                'YLim',obj.defaultYLim, ...
                'XLim',obj.defaultXLim, ...
                'XTick',[], ...
                'YTick',[], ...
                'Color',[0 0 1], ...
                'XColor','none', ...
                'YColor','none', ...
                'Visible','off', ...
                'PositionConstraint','innerposition', ...
                'NextPlot','add', ...
                'HitTest','on', ...
                'PickableParts','all');
            obj.mainAxes.Toolbar = axtoolbar(obj.mainAxes,{});
            obj.mainAxes.Interactions = [];
            disableDefaultInteractivity(obj.mainAxes);

            % setup and store colorbar
            obj.Colorbar = colorbar(obj.mainAxes,"east","Visible","off");

            % initialize registries for loaded and installed tools
            obj.ToolList = containers.Map('KeyType','char','ValueType','any');
            obj.ToolRegistry = containers.Map('KeyType','char','ValueType','any');

            % load all tools in obj.ToolBox
            obj.loadTools(obj.ToolBox);
            % install all tools in obj.ToolBelt
            obj.installTools(obj.ToolBelt);

            % Hub registration (one hub per figure; this instance registers itself)
            obj.Hub = app.FigureEventHub.ensure(obj.ParentFig);
            obj.RouterId = obj.Hub.register(obj, ...
                'Priority', 10, ...
                'CaptureDuringDrag', true);

            % Image
            obj.hImage = image(obj.mainAxes,[],...
                'CDataMapping','scaled',...
                'HitTest','off',...
                'PickableParts','none');

            % Update CLim, PlotBoxAspectRatio, and DataAspectRatio *after* creating image object
            obj.mainAxes.CLim               = [0 1];
            obj.mainAxes.PlotBoxAspectRatio = [1 1 1];
            obj.mainAxes.DataAspectRatio    = [1 1 1];

            % set SizeChangedFcn so we can force visual update upon resizing (AutoResizeChildren of parent must be Off)
            obj.SizeChangedFcn = @(~,~) obj.updateOnResize();

            obj.Label = text('Parent',obj.mainAxes,...
                'Units','normalized',...
                'Position',[0 0],...
                'Color',[1 1 1],...
                'String','',...
                'HorizontalAlignment','left',...
                'VerticalAlignment','bottom');

            % set default colormap
            obj.Colormap = turbo;

        end

        function update(obj)
            % set the Tag property of the mainAxes
            obj.mainAxes.Tag = obj.Name;

            % set BackgroundColor
            obj.Grid.BackgroundColor = obj.BackgroundColor;
            obj.Panel.BackgroundColor = obj.BackgroundColor;
        end

    end

    %% Update helpers (private)
    methods (Access=private)

        function updateOnResize(obj)
            if ~isvalid(obj); return; end
            drawnow;  % keep label positioning accurate during live resizes
            obj.update();
        end

        function updateLabelText(obj)

            px = obj.activePixel;

            if isempty(px), obj.Label.String ='Hover over image to interact'; return; end

            posStr = sprintf(' (X, Y)=(%0.f, %0.f)',px(1),px(2));
            valStr = sprintf('Val: %0.2f',obj.CData(px(2),px(1)));

            % get cell array of installed tools, sorted by priority
            tools = obj.prioritySortTools(obj.ToolRegistry);

            % preallocate cell of info label char vectors
            txt = cell(1,numel(tools));


            for i = 1:numel(tools)
                % get info label for each tool
                txt{i} = tools{i}.getLabelString();
            end

            txt = [posStr,valStr,txt];

            % remove empty entries
            txt(ismember(txt,'')) = [];

            % join each fragment with spaced pipe
            txt = strjoin(txt,' | ');

            obj.Label.String = txt;
        end

        function updatePointer(obj)

            % invalid pixel, set pointer to 'arrow'
            if isempty(obj.activePixel), obj.ParentFig.Pointer = 'arrow'; return; end

            % get cell array of installed tools, sorted by priority
            tools = obj.prioritySortTools(obj.ToolRegistry);

            % no tools found, set pointer to 'arrow'
            if isempty(tools), obj.ParentFig.Pointer = 'arrow'; return; end

            for i = 1:numel(tools)
                pointer = tools{i}.getPreferredPointer();

                if isempty(pointer)
                    continue
                end

                switch pointer
                    case 'default'
                        % do nothing (let the pointer be set normally)
                        return
                    otherwise
                        % a valid pointer is returned, set it and return
                        obj.ParentFig.Pointer = pointer;
                        return
                end

            end

            % no valid pointer was returned, set pointer to 'arrow'
            obj.ParentFig.Pointer = 'arrow';

        end

        function updateImageCData(obj)
            obj.hImage.CData = obj.DisplayCData;

            % --- testing - update colorbar ---
            obj.updateColorbar();
        end

        function updateColorbar(obj)
            clim = obj.CLim;
            %tickLabelValues = linspace(clim(1),clim(2),11);
            %tickLabels = arrayfun(@(v) sprintf('%f',v),linspace(clim(1),clim(2),11));

            % obj.Colorbar.TickLabels = arrayfun(@(v) sprintf('%f',v),linspace(clim(1),clim(2),11),'UniformOutput',false);

            switch obj.CDataClass
                case 'logical'
                    labels = arrayfun(@(v) '',1:11,'UniformOutput',false);
                case 'double'
                    labels = arrayfun(@(v) sprintf('%.2f',v),linspace(clim(1),clim(2),11),'UniformOutput',false);
                case {'uint16','uint8'}
                    labels = arrayfun(@(v) sprintf('%i',v),round(linspace(clim(1),clim(2),11)),'UniformOutput',false);
            end

            obj.Colorbar.TickLabels = labels;
        end

    end

    % Tool-accessible helpers
    methods (Access = ?widgets.ImageAxesTool, Hidden = true)
        
        function setMode(obj, modeName, modeState)
            % if mode does not exist
            if ~isfield(obj.Mode,modeName)
                % warn and return
                warning('Could not remove mode. "%s" mode does not exist.',modeName)
                return
            end
            % set the mode state
            obj.Mode.(modeName) = logical(modeState);
        end

        function addMode(obj, modeName)
            % if mode already exists
            if isfield(obj.Mode,modeName)
                % warn and return
                warning('Could not add mode. "%s" mode already exists',modeName)
                return
            end
            % add the mode (false by default)
            obj.Mode.(modeName) = false;
        end

        function removeMode(obj, modeName)
            % if mode does not exist
            if ~isfield(obj.Mode,modeName)
                % warn and return
                warning('Could not remove mode. "%s" mode does not exist.',modeName)
                return
            end
            % remove the mode
            obj.Mode = rmfield(obj.Mode,modeName);
        end

        function updateFromTool(obj)
            obj.updateLabelText();
            obj.updatePointer();
        end

        function restoreDefaultLimits(obj)
            obj.staticAxes.XLim = obj.defaultXLim;  
            obj.staticAxes.YLim = obj.defaultYLim;
            obj.mainAxes.XLim = obj.defaultXLim;  
            obj.mainAxes.YLim = obj.defaultYLim;
        end

    end

    %% Derived getters and setters
    methods
        function cursorPosition = get.cursorPosition(obj)
            cursorPosition = obj.mainAxes.CurrentPoint(1,[1,2]);
            % return empty if outside limits
            if ~obj.isInLimits(cursorPosition,obj.mainAxes.XLim,obj.mainAxes.YLim)
                cursorPosition = [];
            end
        end

        function cursorPositionStatic = get.cursorPositionStatic(obj)
            cursorPositionStatic = obj.staticAxes.CurrentPoint(1,[1,2]);
            % return empty if outside limits
            if ~obj.isInLimits(cursorPositionStatic,obj.staticAxes.XLim,obj.staticAxes.YLim)
                cursorPositionStatic = [];
            end
        end

        function px = get.activePixel(obj)

            XY = obj.cursorPosition;

            if isempty(XY)
                px = [];
                return
            end

            px = [clip(round(XY(1)),1,obj.ImageWidth), ...
                  clip(round(XY(2)),1,obj.ImageHeight)];

        end

        function s = get.ImageSize(obj),    s = size(obj.CData); end
        function h = get.ImageHeight(obj),  h = size(obj.CData,1); end
        function w = get.ImageWidth(obj),   w = size(obj.CData,2); end
        function f = get.ParentFig(obj),    f = ancestor(obj,'Figure'); end
        
        function x = get.defaultXLim(obj),  x = [0 obj.ImageWidth] + 0.5; end
        function y = get.defaultYLim(obj),  y = [0 obj.ImageHeight] + 0.5; end

        % passthroughs

        % Colormap
        function v = get.Colormap(obj),        v = obj.mainAxes.Colormap; end
        function set.Colormap(obj,val),        obj.mainAxes.Colormap = val; end
        % ImageVisible
        function v = get.ImageVisible(obj),v = obj.hImage.Visible; end
        function set.ImageVisible(obj,val),obj.hImage.Visible = val; end
        % AxesVisible
        function v = get.AxesVisible(obj), v = obj.mainAxes.Visible; end
        function set.AxesVisible(obj,val), obj.mainAxes.Visible = val; end
        % ColorbarVisible
        function v = get.ColorbarVisible(obj), v = obj.Colorbar.Visible; end
        function set.ColorbarVisible(obj,val), obj.Colorbar.Visible = val; end



        % axes handle
        function ax = getAxes(obj), ax = obj.mainAxes; end

    end

    %% Hub-facing event handlers (matches / onDown / onMove / onUp / onScroll / onEnter / onLeave)
    methods

        % determine whether this instance should claim event from FigureEventHub
        function tf = matches(obj, tgt, kind, ~)
            % tf = matches(obj, tgt, kind, evt)
            % obj: this component
            % tgt: hittest result from FigureEventHub that we are checking for a match to this component
            % kind: the specific kind of mouse event (i.e. 'move', 'down', 'up', or 'scroll')
            % evt: event data associated with the event

            % % skip toolbar buttons
            % if ~isempty(ancestor(tgt,'matlab.ui.container.Toolbar')) || isa(tgt,'matlab.graphics.shape.internal.Button')
            %     tf = false;
            %     return
            % end


            % get the ancestor axes
            ancestorAx = ancestor(tgt,'matlab.ui.control.UIAxes');

            if isempty(ancestorAx)
                tf = false; return
            end

            % make sure ancestor axes Tag matches Name of this ImageAxes, if not -> return false
            if ~strcmp(ancestorAx.Tag,obj.Name)
                tf = false; return
            end


            % skip toolbar buttons
            if ~isempty(ancestor(tgt,'matlab.ui.controls.AxesToolbar')) % if event hits the toolbar
                % get the corresponding button
                btn = ancestor(tgt,'matlab.ui.controls.ToolbarStateButton');
                % % set the info label string to the Tooltip of the button under cursor
                % obj.Label.String = btn.Tooltip;

                if ~isempty(btn) && strcmp(kind,'move')
                    tf = true;
                else
                    tf = false;
                end

                return
            end


            % accept anything else that belongs to *this* ImageAxes instance
            ia = ancestor(tgt,'widgets.ImageAxes');
            tf = (ia == obj);
        end


        function onDown(obj, evt, tgt)
            skipInterceptor = obj.routeToDistractors(evt,tgt,'Down');
            if skipInterceptor, return; end

            % get highest priority DownInterceptor
            t = obj.getPriorityInterceptor('Down');
            % if tool exists, forward this event to the tool
            if ~isempty(t), t.onDown(evt, tgt); end
        end

        function onMove(obj, evt, tgt)
            % get the ancestor toolbar button clicked, if it exists
            btn = ancestor(tgt,'matlab.ui.controls.ToolbarStateButton');
            if ~isempty(btn) % if it exists
                % set image info label to display button tooltip, return
                obj.Label.String = sprintf(' %s',btn.Tooltip); return
            end

            skipInterceptor = obj.routeToDistractors(evt,tgt,'Move');
            if skipInterceptor, return; end

            % get highest priority MoveInterceptor
            t = obj.getPriorityInterceptor('Move');
            % if tool exists, forward this event to the tool
            if ~isempty(t), t.onMove(evt, tgt); end
            % Host maintenance (update label/pointer/etc. on move if desired)
            obj.onMouseMove();
        end

        function onUp(obj, evt, tgt)
            skipInterceptor = obj.routeToDistractors(evt,tgt,'Up');
            if skipInterceptor, return; end

            % get highest priority UpInterceptor
            t = obj.getPriorityInterceptor('Up');
            % if tool exists, forward this event to the tool
            if ~isempty(t), t.onUp(evt, tgt); end
        end

        function onScroll(obj, evt, tgt)
            skipInterceptor = obj.routeToDistractors(evt,tgt,'Scroll');
            if skipInterceptor, return; end

            % get highest priority ScrollInterceptor
            t = obj.getPriorityInterceptor('Scroll');
            % if tool exists, forward this event to the tool
            if ~isempty(t), t.onScroll(evt, tgt); end
        end

        function onEnter(obj,~,~)
            obj.Label.Visible = "on";
            % no-op to tools by default
        end

        function onLeave(obj,~,~)
            % hide label
            obj.Label.Visible = "off";
            % reset pointer to arrow
            if isvalid(obj.ParentFig)
                obj.ParentFig.Pointer = 'arrow';
            end
        end

    end

    %% Internal behaviors
    methods (Access = private)

        % executes on mouse move after Distractors/Interceptors
        function onMouseMove(obj)
            obj.updateLabelText();
            obj.updatePointer();
        end

    end

    %% Tool event routing
    methods

        function tf = routeToDistractors(obj,evt,tgt,eventType)
        % eventType: 'Move' | 'Down' | 'Up' | 'Scroll

            % cell array of Distractors for this eventType, sorted by Priority
            distractors = obj.getPriorityDistractors(eventType);

            % whether to bypass the active Interceptor after Distraction event
            tf = false;

            % no Distractors for this eventType, return early
            if isempty(distractors), return; end

            for i = 1:numel(distractors)
                tf = distractors{i}.(['onDistract',eventType])(evt,tgt) | tf;
            end

        end

    end

    %% Tool management (register/unregister, load/unload, install/uninstall, find by name)
    methods

        % register a tool (add it to the installed tool registry) - tools call this themselves
        function registerTool(obj, tool)
            if ~isvalid(tool)
                warning('Failed to register tool. Invalid handle.')
                return
            end

            % add toolbar button
            obj.addToolbarButton(tool);
            % add to installed tools struct
            obj.Tools.(tool.Name) = tool;

            % add to registry
            obj.ToolRegistry(char(tool.Name)) = tool;
        end

        % remove tool from installed tool registry - it remains loaded
        function unregisterTool(obj, tool)
            % if tool is not registered
            if ~obj.ToolRegistry.isKey(char(tool.Name))
                warning('Failed to unregister tool. "%s" tool is not currently registered.',tool.Name)
                return
            end

            % remove toolbar button
            obj.removeToolbarButton(tool);
            % remove from installed tools struct
            obj.Tools = rmfield(obj.Tools,tool.Name);

            % remove from registry
            obj.ToolRegistry.remove(char(tool.Name));
        end

        % load all tools in widgets.tools
        function loadAllTools(obj)
            % cell array of tool names
            toolNames = obj.getToolNames();
            % return if no tools found
            if isempty(toolNames), return; end
            % load each tool
            for i = 1:numel(toolNames), obj.loadTool(toolNames{i}); end
        end

        % unload all currently loaded tools
        function unloadAllTools(obj)
            % cell array of tool names
            toolNames = obj.ToolList.keys;
            % return if no tools are currently loaded
            if isempty(toolNames), return; end
            % unload each tool
            for i = 1:numel(toolNames), obj.unloadTool(toolNames{i}); end
        end

        % load tools specified by toolNames (cell array of char vectors)
        function loadTools(obj,toolNames)
            % return if no tools found
            if isempty(toolNames), return; end
            % load each tool
            for i = 1:numel(toolNames), obj.loadTool(toolNames{i}); end
        end

        % load tool specified by name
        function loadTool(obj, name)
            if obj.ToolList.isKey(char(name))
                warning('Failed to load tool. "%s" tool already loaded.',name)
                return
            end
            % add to loaded Tools registry
            obj.ToolList(char(name)) = widgets.tools.(char(name))(obj);
        end

        % unload tool specified by name
        function unloadTool(obj, name)
            if ~obj.ToolList.isKey(char(name))
                warning('Failed to unload tool. "%s" tool is not loaded.',name)
                return
            end
            % get from loaded tools registry
            tool = obj.getLoadedTool(name);
            % if tool is installed, uninstall before unloading
            if tool.Installed, obj.uninstallTool(tool.Name); end

            % delete the tool (it will perform teardown tasks)
            delete(tool)
            % remove from loaded Tools registry
            obj.ToolList.remove(char(name));
        end

        % install tools specified by toolNames (cell array of char vectors)
        function installTools(obj,toolNames)
            % return if empty
            if isempty(toolNames), return; end
            % install each tool
            for i = 1:numel(toolNames), obj.installTool(toolNames{i}); end
        end

        % install tool specified by name
        function installTool(obj,name)
            thisTool = obj.getLoadedTool(name);
            % if no tool with this name found in tool list
            if isempty(thisTool)
                warning('Failed to install tool. "%s" tool is not loaded.',name)
                return
            end
            % check if tool is already registered
            if obj.ToolRegistry.isKey(char(thisTool.Name))
                warning('Failed to install tool. "%s" tool is already installed.',name)
                return
            end
            % call the tool's install() method, it will register itself and perform startup tasks
            thisTool.install();
        end

        % uninstall tool specified by name
        function uninstallTool(obj,name)
            thisTool = obj.getLoadedTool(name);
            % if no tool with this name found in tool list
            if isempty(thisTool)
                warning('Failed to uninstall tool. "%s" tool is not loaded.',name)
                return
            end
            % if no tool with this name is currently installed
            if ~obj.ToolRegistry.isKey(char(thisTool.Name))
                warning('Failed to uninstall tool. "%s" tool is already uninstalled.',name)
                return
            end
            % call the tool's uninstall() method, it will remove itself from the registry and perform cleanup tasks
            thisTool.uninstall();
        end

    end

    %% Toolbar management (add, remove, reorder toolbar buttons)
    methods

        % add a toolbar button for the tool (tool calls this on install)
        function addToolbarButton(obj, tool)
            obj.ToolbarButtons.(tool.Name) = axtoolbarbtn(obj.mainAxes.Toolbar,'state',...
                'Tooltip',tool.Tooltip,...
                'Icon',tool.Icon,...
                'ValueChangedFcn',@(btn,~) onToolToggle(obj, btn.Value, tool.Name));
            % reset the toolbar (it will disappear on hover otherwise)
            obj.mainAxes.Toolbar.reset;
        end

        % add a toolbar button for the tool (tool calls this on uninstall)
        function removeToolbarButton(obj, tool)
            % tool name not found in obj.ToolbarButtons struct, exit early
            if ~isfield(obj.ToolbarButtons,tool.Name), return; end
            % toolbar button linked to this tool
            tbButton = obj.ToolbarButtons.(tool.Name);
            % button is not valid, exit early
            if ~isvalid(tbButton), return; end
            % delete the toolbar button
            delete(tbButton)
            % delete the corresponding field in obj.ToolbarButtons struct
            obj.ToolbarButtons = rmfield(obj.ToolbarButtons,tool.Name);
            % reset the toolbar (it will disappear on hover otherwise)
            obj.mainAxes.Toolbar.reset;
        end

    end

    %% Toggle/query tool states
    methods

        % enable installed tool specified by name
        function enableTool(obj, name)
            t = obj.getInstalledTool(name); 
            if isempty(t), return; end
            t.enable();
        end

        % disable installed tool specified by name
        function disableTool(obj, name)
            t = obj.getInstalledTool(name);
            if isempty(t), return; end
            t.disable();
        end

        % query Enabled state of tool specified by name
        function tf = toolEnabled(obj, name)
            t = obj.getInstalledTool(name);
            tf = ~isempty(t) && isvalid(t) && t.Enabled;
        end

        % toggle Enabled state of tool specified by name (toolbar button ValueChangedFcn)
        function onToolToggle(obj,toolState,name)
            switch toolState
                case true
                    obj.enableTool(name);
                case false
                    obj.disableTool(name);
            end
        end

        % disable ActiveExclusiveTool if it exists
        function disableActiveExclusive(obj)
            % get the existing exclusive tool
            existingExclusive = obj.ActiveExclusiveTool;
            % exit if none found
            if isempty(existingExclusive), return; end
            % otherwise disable it
            obj.disableTool(existingExclusive.Name);
        end

    end

    %% Retrieve/sort tools
    methods

        % get installed tool specified by name
        function t = getInstalledTool(obj, name)
            t = [];
            if ~isempty(obj.ToolRegistry) && isKey(obj.ToolRegistry, char(name))
                t = obj.ToolRegistry(char(name));
            end
        end

        % get loaded tool specified by name
        function t = getLoadedTool(obj, name)
            t = [];
            if ~isempty(obj.ToolList) && isKey(obj.ToolList, char(name))
                t = obj.ToolList(char(name));
            end
        end

        % get the highest Priority Interceptor for the specified eventType
        function tool = getPriorityInterceptor(obj,eventType)
            % cell array of Installed tools
            toolsCell = obj.ToolRegistry.values;
            % no Installed tools, exit early
            if isempty(toolsCell), tool = []; return; end
            % get logical idx of Installed, Enabled tools that can Intercept the given eventType
            idx = cellfun(@(t) t.Enabled & t.(['Captures',eventType]) ,toolsCell,'UniformOutput',true);
            % no matching tools, exit early
            if ~any(idx), tool = []; return; end
            % sort the tools by priority (descending order)
            tools = obj.prioritySortToolsCell(toolsCell(idx));
            % return the first element (highest priority)
            tool = tools{1};
        end

        % get cell array of Distractors for the specified eventType, sorted by descending Priority
        function toolsCell = getPriorityDistractors(obj,eventType)
            % cell array of Installed tools
            toolsCell = obj.ToolRegistry.values;
            % no Installed tools, exit early
            if isempty(toolsCell), return; end
            % get logical idx of Installed tools that can Distract the given eventType
            idx = cellfun(@(t) t.(['Distracts',eventType]),toolsCell,'UniformOutput',true);
            % no matching tools, exit early
            if ~any(idx), toolsCell = {}; return; end
            % sort the tools by priority (descending order)
            toolsCell = obj.prioritySortToolsCell(toolsCell(idx));
        end

        % given a containers.Map of tools, return cell array of tools sorted by descending Priority
        function toolsCell = prioritySortTools(obj,toolsMap)
            % sort toolsMap.values by priority in descending order
            toolsCell = obj.prioritySortToolsCell(toolsMap.values);
        end

        % given a cell array of tools, return the same cell array sorted by descending Priority
        function toolsCell = prioritySortToolsCell(~,toolsCell)
            % empty cell, exit early
            if isempty(toolsCell), return; end
            % array of (sorted) Priority values for each tool
            priority = cellfun(@(t) t.Priority,toolsCell,'UniformOutput',true);
            [~,sortIdx] = sort(priority,'descend');
            % sort using the idxs returned by sort
            toolsCell = toolsCell(sortIdx);
        end

    end

    %% Tool Management (user-facing set/get methods to change loaded/installed tools)
    methods

        % get loaded tool names
        function ToolBox = get.ToolBox(obj)
            ToolBox = obj.ToolList.keys;
        end

        % set loaded tools
        function set.ToolBox(obj,newToolBox)
            % cell array of currently loaded tool names
            oldToolBox = obj.ToolBox;
            % tools in newToolBox that are not in oldToolBox (need to load them)
            toolsToAdd = setdiff(newToolBox,oldToolBox,'stable');
            % tools in oldToolBox that are not in newToolBox (need to unload them)
            toolsToRemove = setdiff(oldToolBox,newToolBox,'stable');
            % load all new tools in newToolBox
            if ~isempty(toolsToAdd)
                for i = 1:numel(toolsToAdd)
                    % load the tool
                    obj.loadTool(toolsToAdd{i});
                end
            end
            % unload any loaded tools not in newToolBox
            if ~isempty(toolsToRemove)
                for i = 1:numel(toolsToRemove)
                    % unload the tool
                    obj.unloadTool(toolsToRemove{i});
                end
            end
        end

        % get installed tool names
        function ToolBelt = get.ToolBelt(obj)
            ToolBelt = obj.ToolRegistry.keys;
        end

        % set installed tools (load first if necessary)
        function set.ToolBelt(obj,newToolBelt)
            % cell array of currently installed tool names
            oldToolBelt = obj.ToolBelt;
            % tools in newToolBelt that are not in oldToolBelt (need to install them)
            toolsToAdd = setdiff(newToolBelt,oldToolBelt,'stable');
            % tools in oldToolBelt that are not in newToolBelt (need to uninstall them)
            toolsToRemove = setdiff(oldToolBelt,newToolBelt,'stable');
            % install all uninstalled tools in newToolBelt (load first if necessary)
            if ~isempty(toolsToAdd)
                for i = 1:numel(toolsToAdd)
                    % tool is not already loaded, load it before installing
                    if ~obj.ToolList.isKey(toolsToAdd{i})
                        obj.loadTool(toolsToAdd{i});
                    end
                    % install the tool
                    obj.installTool(toolsToAdd{i});
                end
            end
            % uninstall any installed tools not in newToolBelt (do not unload)
            if ~isempty(toolsToRemove)
                for i = 1:numel(toolsToRemove)
                    % uninstall the tool
                    obj.uninstallTool(toolsToRemove{i});
                end
            end
        end

    end

    %% CData/CLim
    methods

        % CLim
        function v = get.CLim(obj)
            v = obj.CLim_;
        end

        function set.CLim(obj,val)
            % update private backing
            obj.CLim_ = val;
            % setting the CLim switches CLim mode to manual
            obj.CLimMode_ = 'manual';
            % update the CData on the actual image object (do not emit CDataChanged)
            obj.updateImageCData();
        end

        % CData
        function v = get.CData(obj)
            v = obj.CData_;
        end

        function set.CData(obj,val)

            placeholder = false;

            if isempty(val)
                val = widgets.ImageAxes.placeholderImage();
                placeholder = true;
            end

            % create event data payload before setting new CData and emitting CDataChanged event
            evtData = widgets.events.CDataChangedEventData(obj.CData_,val);
            % update private backing
            obj.CData_ = val;

            % if CLimMode set to 'auto'
            if strcmp(obj.CLimMode_,'auto')
                if placeholder
                    obj.CLim_ = [0 1];
                else
                    % set private CLim backing to match min/max of CData
                    obj.CLim_ = [min(min(obj.CData_)) max(max(obj.CData_))];
                end
            end
            % update the CData on the actual image object
            obj.updateImageCData();
            % update axes limits
            obj.restoreDefaultLimits();
            % emit event, send payload
            notify(obj,'CDataChanged',evtData);
        end

        % CLimMode
        function v = get.CLimMode(obj)
            v = obj.CLimMode_;
        end

        function set.CLimMode(obj,val)
            % update private backing
            obj.CLimMode_ = val;
            % update the CData on the actual image object
            obj.updateImageCData();
        end

        % DisplayCData
        function v = get.DisplayCData(obj)
            v = utils.rescaleLinear(obj.CData,obj.CLim);
        end

        % CDataClass
        function v = get.CDataClass(obj)
            v = class(obj.CData);
        end

    end

    %% Utils
    methods (Static, Access=private)

        function y = clip(x,a,b), y = max(a, min(b, x)); end

        % check if the point, XY, is within limits, XLim and YLim
        function tf = isInLimits(XY,XLim,YLim)
            x = XY(1); y = XY(2);
            tf = x >= XLim(1) && x <= XLim(2) && y >= YLim(1) && y <= YLim(2);
        end

        % return a placeholder image for startup
        function I = placeholderImage()
            %I = repmat(linspace(0,1,256),256,1);
            I = zeros(256);
        end

    end

    methods (Static)

        % return names of all classes in widgets.tools
        function names = getToolClassNames()
            % get list of tool class names in widgets.tools using matlab.metadata.Namespace

            % string array
            % names = string({matlab.metadata.Namespace.fromName("widgets.tools").ClassList.Name})';

            % cell array of char vectors
            names = {matlab.metadata.Namespace.fromName("widgets.tools").ClassList.Name}';
        end

        % return names of all tool classes (just the last part)
        function names = getToolNames()

            classNames = widgets.ImageAxes.getToolClassNames();
            if numel(classNames)==0
                names = {};
                return
            else
                names = cell(1,numel(classNames));
                for i = 1:numel(classNames)
                    % split name with '.' delimeter
                    temp = strsplit(classNames{i},'.');
                    % tool name is after the final '.'
                    names(i) = temp(end);
                end
            end

        end

        function ax = demo()

            fig = uifigure("WindowStyle","alwaysontop",...
                "Position",[0 0 500 500],...
                "Visible","off");

            ax = widgets.ImageAxes(fig,...
                "ToolBox",{'Zoom'},...
                "ToolBelt",{'Zoom'},...
                "Units","normalized",...
                "Position",[0 0 1 1],...
                "CData",imread("rice.png"));

            movegui(fig,"center")

            fig.Visible = "on";

        end

    end

    %% Teardown
    methods

        function delete(obj)

            % remove listeners first
            if ~isempty(obj.L), delete(obj.L(isvalid(obj.L))); end
            % replace listener property with empty array of event.listener
            obj.L = event.listener.empty;


            % Unregister from hub (safe if figure already gone)
            try
                if ~isempty(obj.Hub) && isvalid(obj.Hub) && ~isnan(obj.RouterId)
                    obj.Hub.unregister(obj.RouterId);
                end
            catch
            end

            % unload (delete) all tools before deleting ImageAxes
            obj.unloadAllTools();

        end

    end

end
