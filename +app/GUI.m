classdef GUI < handle
% app.GUI - GUI controller

    % add Transient and NonCopyable attributes?
    properties (Access=private)
        % --- window and main grids ---
        Fig matlab.ui.Figure
        Grid matlab.ui.container.GridLayout
        LeftPane matlab.ui.container.GridLayout
        RegionGrid matlab.ui.container.GridLayout

        % --- listbox/settings accordion ---
        SettingsAccordion matlabx.ui.widgets.uiaccordion

        % --- listboxes ---
        % images
        ImageListBoxPanel matlab.ui.container.Panel
        ImageListBoxPanelGrid matlab.ui.container.GridLayout
        ImageListBox matlab.ui.control.ListBox
        % regions
        RegionListBoxPanel matlab.ui.container.Panel
        RegionListBoxPanelGrid matlab.ui.container.GridLayout
        RegionListBox matlab.ui.control.ListBox

        % --- viewers ---
        % ImageViewer
        ImageViewerPanel matlab.ui.container.Panel
        ImageViewerPanelGrid matlab.ui.container.GridLayout
        Ax matlabx.ui.widgets.ImageAxes
        % RegionViewer
        RegionViewerPanel matlab.ui.container.Panel
        RegionViewerPanelGrid matlab.ui.container.GridLayout
        RegionViewer matlabx.ui.widgets.ImageAxes

        % --- region table ---
        RegionSummaryPanel matlab.ui.container.Panel
        RegionSummaryPanelGrid matlab.ui.container.GridLayout
        RegionSummaryTable matlab.ui.control.Table

        % --- linescan plot ---
        RegionLinescanPanel matlab.ui.container.Panel
        RegionLinescanPanelGrid matlab.ui.container.GridLayout
        RegionLinescanPlot widgets.PeaksPlotContainer % custom plot
    end

    % Settings-related graphics components
    properties (Access=private)
        ExampleColormapPanel matlab.ui.container.Panel
        ExampleColormapAxes matlab.ui.control.UIAxes
        ExampleColormapImage matlab.graphics.primitive.Image
        ColormapTree matlab.ui.container.Tree
        IntensitySlider matlabx.ui.widgets.uirangeslidereditfield
    end

    % Extra graphics handles, stored as struct to reduce clutter
    properties (Access=private)
        MenubarUI struct
        SettingsUI struct
    end

    % listeners
    properties (Access=private)
        % L event.listener

        settingsL event.listener
        projectL event.listener
    end

    % Derived properties for specific component groups to reduce clutter
    properties (Access=private,Dependent=true)
        RegionLinescanPlotAnnotations
    end


    properties (Access=private)
        LabelsTree matlab.ui.container.Tree
        LabelsUI struct
        IsSyncingSelection (1,1) logical = false

        CommandRouter matlabx.ui.control.CommandRouter
    end

    %% Logging
    properties
        Log (1,1) matlabx.logging.Logger
    end


    %% Public properties

    % Model (Project), processing settings
    properties
        Project model.STORMProject
        Settings app.config.Settings
    end

    %% Constructor/Destructor
    methods

        function obj = GUI()

            % --- Log ---
            obj.Log = app.Log.get();

            app.Log.INFO("Starting DesmoSTORM...");

            % --- Settings ---
            app.Log.INFO("Loading settings...");
            try
                obj.Settings = app.config.Settings.load();
            catch ME
                app.Log.ERROR(ME); rethrow(ME);
            end

            % --- Build GUI ---
            app.Log.INFO("Building GUI...");
            try obj.buildGUI(); catch ME, app.Log.ERROR(ME); rethrow(ME); end

            % --- Initial UI sync ---
            app.Log.INFO("Refreshing UI...");
            try obj.refreshUI(); catch ME, app.Log.ERROR(ME); rethrow(ME); end

            % --- Show figure ---
            app.Log.INFO("Opening...");
            obj.Fig.Visible = 'on';

        end

        function buildGUI(obj)
            % --- Figure ---
            app.Log.INFO("Setting up main figure window...");
            try obj.setupFigure(); catch ME, app.Log.ERROR(ME); rethrow(ME); end

            % --- CommandRouter ---
            app.Log.INFO("Setting up CommandRouter...");
            try obj.setupCommandRouter(); catch ME, app.Log.ERROR(ME); rethrow(ME); end

            % --- Menubar ---
            app.Log.INFO("Setting up Menubar...");
            try obj.setupMenubar(); catch ME, app.Log.ERROR(ME); rethrow(ME); end

            % --- Grids ---
            app.Log.INFO("Setting up main grid layout managers...");
            try obj.setupGrids(); catch ME, app.Log.ERROR(ME); rethrow(ME); end

            % --- Settings controllers ---
            app.Log.INFO("Setting up settings controllers...");
            try obj.setupSettingsControllers(); catch ME, app.Log.ERROR(ME); rethrow(ME); end

            % --- ImageViewer ---
            app.Log.INFO("Setting up ImageViewer...");
            try obj.setupImageViewer(); catch ME, app.Log.ERROR(ME); rethrow(ME); end

            % --- RegionViewer ---
            app.Log.INFO("Setting up RegionViewer...");
            try obj.setupRegionViewer(); catch ME, app.Log.ERROR(ME); rethrow(ME); end

            % --- RegionSummaryTable ---
            app.Log.INFO("Setting up RegionSummaryTable...");
            try obj.setupRegionSummaryTable(); catch ME, app.Log.ERROR(ME); rethrow(ME); end

            % --- RegionLinescanPlot ---
            app.Log.INFO("Setting up RegionSummaryTable...");
            try obj.setupRegionLinescanPlot(); catch ME, app.Log.ERROR(ME); rethrow(ME); end

            % center the GUI after defining all graphics components
            movegui(obj.Fig,"center");
        end

        function setupFigure(obj)
            % need to add a more elegant way to set window size once app components are finalized
            s = matlabx.ui.calibration.getScreenSize();
            %s(4) = 0.45*s(3);
            obj.Fig = uifigure('Name','DesmoSTORM',...
                'Color',[0 0 0],...
                'OuterPosition',s(1,:),...
                'WindowStyle','alwaysontop',...
                'Visible','off',...
                'Theme','dark',...
                'HandleVisibility','on',...
                'Tag',app.Info.Name);
        end

        function setupCommandRouter(obj)
            obj.CommandRouter = matlabx.ui.control.CommandRouter('Parent',obj.Fig);
        end

        function setupMenubar(obj)
            % Set up MenubarUI struct
            obj.MenubarUI = struct(...
                "File",struct(),...
                "Run",struct());

            % --- File ---
            obj.MenubarUI.File       = uimenu(obj.Fig,'Text','File');
            obj.MenubarUI.File_New   = uimenu(obj.MenubarUI.File,'Text','New',  'MenuSelectedFcn',@(~,~) obj.onNew());
            obj.MenubarUI.File_Open  = uimenu(obj.MenubarUI.File,'Text','Open', 'MenuSelectedFcn',@(~,~) obj.onOpen());
            obj.MenubarUI.File_Close = uimenu(obj.MenubarUI.File,'Text','Close','MenuSelectedFcn',@(~,~) obj.onClose());
            obj.MenubarUI.File_Save  = uimenu(obj.MenubarUI.File,'Text','Save', 'MenuSelectedFcn',@(~,~) obj.onSave(),'Separator','on');
            % --- separator ---
            obj.MenubarUI.File_SaveSettings = uimenu(obj.MenubarUI.File,'Text','Save Settings','MenuSelectedFcn',@(~,~) obj.onSaveSettings(),'Separator','on');
            % --- separator ---
            obj.MenubarUI.File_LoadImages = uimenu(obj.MenubarUI.File,'Text','Load Images','MenuSelectedFcn',@(~,~) obj.onLoadImages());
            % --- File -> Export ---
            obj.MenubarUI.File_Export = uimenu(obj.MenubarUI.File,'Text','Export');
            obj.MenubarUI.File_Export_Measurements = uimenu(obj.MenubarUI.File_Export,'Text','Measurements (.xlsx)', 'MenuSelectedFcn',@(~,~) obj.onExportMeasurements());
            obj.MenubarUI.File_Export_PeakPlots    = uimenu(obj.MenubarUI.File_Export,'Text','Peak Plots (.pdf)',    'MenuSelectedFcn',@(~,~) obj.onExportPeakPlots());
            obj.MenubarUI.File_Export_RegionImages = uimenu(obj.MenubarUI.File_Export,'Text','Region Images (.tif)', 'MenuSelectedFcn',@(~,~) obj.onExportRegionImages());

            % --- Run ---
            obj.MenubarUI.Run = uimenu(obj.Fig,'Text','Run');
            %obj.MenubarUI.Run_Autopick = uimenu(obj.MenubarUI.Run,'Text','Auto-pick Regions (experimental)...','MenuSelectedFcn',@(~,~) obj.onAutopickRegions());

            obj.MenubarUI.Run_Classifier = uimenu(obj.MenubarUI.Run,'Text','Run classifier...','MenuSelectedFcn',@(~,~) obj.onRunClassifier());

            obj.MenubarUI.Run_TrainNewClassifier = uimenu(obj.MenubarUI.Run,'Text','Train new classifier...','MenuSelectedFcn',@(~,~) obj.onTrainNewClassifier());
            obj.MenubarUI.Run_ContinueTrainingClassifier = uimenu(obj.MenubarUI.Run,'Text','Continue training existing classifier...','MenuSelectedFcn',@(~,~) obj.onContinueTrainingClassifier());
        end

        function setupGrids(obj)
            % Main Grid
            obj.Grid = uigridlayout(obj.Fig,[2 3], ...
                'ColumnWidth',{'fit','1x'}, ...
                'RowHeight',{'1x'}, ...
                'ColumnSpacing',5, ...
                'RowSpacing',5, ...
                'Padding',[5 5 5 5],...
                'BackgroundColor',[0.12 0.12 0.12]);
            % Left Pane Grid (ListBoxes and settings)
            obj.LeftPane = uigridlayout(obj.Grid,[1 1],...
                "RowHeight",{'fit'},...
                "ColumnWidth",300,...
                "Padding",[0 0 0 0],...
                "BackgroundColor",[.12 .12 .12],...
                "Scrollable","on");
            obj.LeftPane.Layout.Row = [1 2];
            obj.LeftPane.Layout.Column = 1;
        end

        function setupSettingsControllers(obj)
            % create the accordion and parent it to the grid
            obj.SettingsAccordion = matlabx.ui.widgets.uiaccordion(obj.LeftPane,...
                'ItemSpacing',5,...
                'BorderWidth',0,...
                'BorderColor',[.18 .18 .18],...
                'Padding',0,...
                'BackgroundColor',[.12 .12 .12]);

            % add Images accordion item
            obj.SettingsAccordion.addItem("Title","Images",...
                "BorderColor",[0.49 0.49 0.49],...
                "TitleBackgroundColor",[.12 .12 .12],...
                "HoverTitleBackgroundColor",[.3 .3 .3],...
                "PaneBackgroundColor",[.18 .18 .18],...
                "FontColor",[0.85 0.85 0.85],...
                "BorderWidth",1,...
                "ExpandedBorderWidth",1,...
                "TitlePadding",1);
            % set size and spacing of pane grid
            set(obj.SettingsAccordion.Items(1).Pane,...
                "RowHeight",{200},...
                "ColumnWidth",{'1x'},...
                "Padding",[0 0 0 0]);

            % Image selection listbox
            obj.ImageListBox = uilistbox(obj.SettingsAccordion.Items(1).Pane, ...
                'Items',string.empty(1,0),...
                'ItemsData',string.empty(1,0),...
                'Value',string.empty(1,0),...
                'ValueChangedFcn',@(lb,~) obj.onSelectImage(lb.Value),...
                'BackgroundColor',[.18 .18 .18],...
                'FontColor',[.9 .9 .9]);

            % add Regions accordion item
            obj.SettingsAccordion.addItem("Title","Regions",...
                "BorderColor",[0.49 0.49 0.49],...
                "TitleBackgroundColor",[.12 .12 .12],...
                "HoverTitleBackgroundColor",[.3 .3 .3],...
                "PaneBackgroundColor",[.18 .18 .18],...
                "FontColor",[0.85 0.85 0.85],...
                "BorderWidth",1,...
                "ExpandedBorderWidth",1,...
                "TitlePadding",1);
            % set size and spacing of pane grid
            set(obj.SettingsAccordion.Items(2).Pane,...
                "RowHeight",{200},...
                "ColumnWidth",{'1x'},...
                "Padding",[0 0 0 0]);

            % Region selection listbox
            obj.RegionListBox = uilistbox(obj.SettingsAccordion.Items(2).Pane, ...
                'Items',{},...
                'ItemsData',{},...
                'Multiselect','on',...
                'Value',{},...
                'ValueChangedFcn',@(lb,evt) obj.onSelectRegion(lb,evt),...
                'BackgroundColor',[.18 .18 .18],...
                'FontColor',[.9 .9 .9]);

            % Set up SettingsUI struct
            obj.SettingsUI = struct(...
                "Display",struct(),...
                "Analysis",struct(),...
                "PeaksPlot",struct(),...
                "Box",struct());

            % add Colormap accordion item
            obj.SettingsAccordion.addItem("Title","Colormap",...
                "BorderColor",[0.49 0.49 0.49],...
                "TitleBackgroundColor",[.12 .12 .12],...
                "HoverTitleBackgroundColor",[.3 .3 .3],...
                "PaneBackgroundColor",[.18 .18 .18],...
                "FontColor",[0.85 0.85 0.85],...
                "BorderWidth",1,...
                "ExpandedBorderWidth",1,...
                "TitlePadding",1);
            % set size and spacing of pane grid
            set(obj.SettingsAccordion.Items(3).Pane,"RowHeight",{30,'1x'},...
                "ColumnWidth",{'1x'},...
                "RowSpacing",5,...
                "ColumnSpacing",5);

            % panel to hold example colormap axes
            obj.ExampleColormapPanel = uipanel(obj.SettingsAccordion.Items(3).Pane);
            obj.ExampleColormapPanel.Layout.Row = 1;
            obj.ExampleColormapPanel.Layout.Column = 1;

            % axes to hold example colorbar
            obj.ExampleColormapAxes = uiaxes(obj.ExampleColormapPanel,...
                'Visible','Off',...
                'XTick',[],...
                'YTick',[],...
                'Units','Normalized',...
                'InnerPosition',[0 0 1 1]);
            obj.ExampleColormapAxes.Toolbar.Visible = 'Off';
            disableDefaultInteractivity(obj.ExampleColormapAxes);

            % create image to show example colorbar for colormap switching
            obj.ExampleColormapImage = image(obj.ExampleColormapAxes,...
                'CData',repmat(1:256,50,1),...
                'CDataMapping','direct');
            % set axes limits so that colorbar image fills axes area
            set(obj.ExampleColormapAxes,"YLim",[0.5 50.5],"XLim",[0.5 256.5]);


            % uitree for colormap selection
            obj.ColormapTree = uitree(...
                "Parent",obj.SettingsAccordion.Items(3).Pane,...
                "SelectionChangedFcn",@(~,e) obj.ColormapSelectionChanged(e));
            obj.ColormapTree.Layout.Row = 2;
            obj.ColormapTree.Layout.Column = 1;

            % populate tree with colormap categories
            categories = matlabx.colors.maps.Registry.categories;

            for i = 1:numel(categories)
                thisCategory = categories(i);
                catNode = uitreenode("Parent",obj.ColormapTree,"Text",thisCategory);

                names = matlabx.colors.maps.Registry.names(thisCategory);

                for j = 1:numel(names)
                    uitreenode("Parent",catNode,"Text",names(j),"NodeData",names(j));
                end
            end

            % get the current active colormap name
            colormapName = obj.Settings.Display.ColormapName;
            % select it in the tree
            obj.ColormapTree.SelectedNodes = obj.ColormapTree.findobj("NodeData",colormapName);
            % and set it as the colormap of the example colormap image
            obj.ExampleColormapAxes.Colormap = obj.Settings.Display.Colormap;

            % add Analysis accordion item
            obj.SettingsAccordion.addItem("Title","Analysis",...
                "BorderColor",[0.49 0.49 0.49],...
                "TitleBackgroundColor",[.12 .12 .12],...
                "HoverTitleBackgroundColor",[.3 .3 .3],...
                "PaneBackgroundColor",[.18 .18 .18],...
                "FontColor",[0.85 0.85 0.85],...
                "BorderWidth",1,...
                "ExpandedBorderWidth",1,...
                "TitlePadding",1);
            % set size and spacing of pane grid
            set(obj.SettingsAccordion.Items(4).Pane,...
                "RowHeight",repmat({'fit'},1,4),...
                "ColumnWidth",{'fit','1x'},...
                "RowSpacing",5,...
                "ColumnSpacing",5);


            uilabel(obj.SettingsAccordion.Items(4).Pane,"Text","Box Size","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.Analysis.BoxSizeEditField = uieditfield(...
                obj.SettingsAccordion.Items(4).Pane,...
                "numeric",...
                "ValueChangedFcn",@(o,~) obj.AnalysisSettingsChanged(o,"BoxSize"),...
                "Value",obj.Settings.Analysis.BoxSize);

            uilabel(obj.SettingsAccordion.Items(4).Pane,"Text","Minimum Peak Distance","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.Analysis.MinPeakDistanceEditField = uieditfield(...
                obj.SettingsAccordion.Items(4).Pane,...
                "numeric",...
                "ValueChangedFcn",@(o,~) obj.AnalysisSettingsChanged(o,"MinPeakDistance"),...
                "Value",obj.Settings.Analysis.MinPeakDistance);

            uilabel(obj.SettingsAccordion.Items(4).Pane,"Text","Minimum Peak Height","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.Analysis.MinPeakHeightEditField = uieditfield(...
                obj.SettingsAccordion.Items(4).Pane,...
                "numeric",...
                "ValueChangedFcn",@(o,~) obj.AnalysisSettingsChanged(o,"MinPeakHeight"),...
                "Value",obj.Settings.Analysis.MinPeakHeight);

            uilabel(obj.SettingsAccordion.Items(4).Pane,"Text","Peak Smoothing","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.Analysis.PeakSmoothingEditField = uieditfield(...
                obj.SettingsAccordion.Items(4).Pane,...
                "numeric",...
                "ValueChangedFcn",@(o,~) obj.AnalysisSettingsChanged(o,"PeakSmoothing"),...
                "Value",obj.Settings.Analysis.PeakSmoothing);

            uilabel(obj.SettingsAccordion.Items(4).Pane,"Text","Pixel Size Value","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.Analysis.PixelSizeValueEditField = uieditfield(...
                obj.SettingsAccordion.Items(4).Pane,...
                "numeric",...
                "ValueChangedFcn",@(o,~) obj.AnalysisSettingsChanged(o,"PixelSizeValue"),...
                "Value",obj.Settings.Analysis.PixelSizeValue);

            uilabel(obj.SettingsAccordion.Items(4).Pane,"Text","Pixel Size Unit","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.Analysis.PixelSizeUnitDropDown = uidropdown(...
                obj.SettingsAccordion.Items(4).Pane,...
                "Items", {'px', 'nm', 'µm'}, ...
                "ValueChangedFcn",@(o,~) obj.AnalysisSettingsChanged(o,"PixelSizeUnit"),...
                "Value",obj.Settings.Analysis.PixelSizeUnit);



            % add Image Display accordion item
            obj.SettingsAccordion.addItem("Title","Image Display",...
                "BorderColor",[0.49 0.49 0.49],...
                "TitleBackgroundColor",[.12 .12 .12],...
                "HoverTitleBackgroundColor",[.3 .3 .3],...
                "PaneBackgroundColor",[.18 .18 .18],...
                "FontColor",[0.85 0.85 0.85],...
                "BorderWidth",1,...
                "ExpandedBorderWidth",1,...
                "TitlePadding",1);
            % set size and spacing of pane grid
            set(obj.SettingsAccordion.Items(5).Pane,...
                "RowHeight",{'fit','fit'},...
                "ColumnWidth",{'1x'},...
                "RowSpacing",5,...
                "ColumnSpacing",5);

            obj.SettingsUI.Display.AutoScaleDisplayIntensityCheckBox = uicheckbox(obj.SettingsAccordion.Items(5).Pane,...
                "Value",obj.Settings.Display.AutoScaleDisplayIntensity,...
                "ValueChangedFcn",@(o,~) obj.DisplaySettingsChanged(o,"AutoScaleDisplayIntensity"),...
                "Text","Auto-scale display intensity");

            obj.IntensitySlider = matlabx.ui.widgets.uirangeslidereditfield(obj.SettingsAccordion.Items(5).Pane,...
                "Title",'Adjust display limits',...
                "FontColor",[1 1 1],...
                "BackgroundColor",[.18 .18 .18],...
                "Limits",[0 1],...
                "Value",[0 1],...
                "RoundValues","on",...
                "RoundDigits",0,...
                "ValueChangingFcn",@(~,evt) obj.onIntensitySliderChanging(evt),...
                "ValueChangedFcn",@(~,evt) obj.onIntensitySliderChanged(evt));

            % add Peaks Plot accordion item
            obj.SettingsAccordion.addItem("Title","Peaks Plot",...
                "BorderColor",[0.49 0.49 0.49],...
                "TitleBackgroundColor",[.12 .12 .12],...
                "HoverTitleBackgroundColor",[.3 .3 .3],...
                "PaneBackgroundColor",[.18 .18 .18],...
                "FontColor",[0.85 0.85 0.85],...
                "BorderWidth",1,...
                "ExpandedBorderWidth",1,...
                "TitlePadding",1);
            % set size and spacing of pane grid
            set(obj.SettingsAccordion.Items(6).Pane,...
                "RowHeight",repmat({'fit'},1,6),...
                "ColumnWidth",{'fit','1x'},...
                "RowSpacing",5,...
                "ColumnSpacing",5);

            uilabel(obj.SettingsAccordion.Items(6).Pane,"Text","Raw Line Color","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.PeaksPlot.RawLineColorPicker = uicolorpicker(...
                'Parent',obj.SettingsAccordion.Items(6).Pane,...
                'Value',obj.Settings.PeaksPlot.RawLineColor,...
                'ValueChangedFcn',@(o,~) obj.PeaksPlotSettingsChanged(o,"RawLineColor"));

            uilabel(obj.SettingsAccordion.Items(6).Pane,"Text","Raw Line Width","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.PeaksPlot.RawLineWidthEditField = uieditfield(...
                obj.SettingsAccordion.Items(6).Pane,...
                "numeric",...
                "ValueChangedFcn",@(o,~) obj.PeaksPlotSettingsChanged(o,"RawLineWidth"),...
                "Value",obj.Settings.PeaksPlot.RawLineWidth);

            uilabel(obj.SettingsAccordion.Items(6).Pane,"Text","Smooth Line Color","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.PeaksPlot.SmoothLineColorPicker = uicolorpicker(...
                'Parent',obj.SettingsAccordion.Items(6).Pane,...
                'Value',obj.Settings.PeaksPlot.SmoothLineColor,...
                'ValueChangedFcn',@(o,~) obj.PeaksPlotSettingsChanged(o,"SmoothLineColor"));

            uilabel(obj.SettingsAccordion.Items(6).Pane,"Text","Smooth Line Width","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.PeaksPlot.SmoothLineWidthEditField = uieditfield(...
                obj.SettingsAccordion.Items(6).Pane,...
                "numeric",...
                "ValueChangedFcn",@(o,~) obj.PeaksPlotSettingsChanged(o,"SmoothLineWidth"),...
                "Value",obj.Settings.PeaksPlot.SmoothLineWidth);

            uilabel(obj.SettingsAccordion.Items(6).Pane,"Text","Background Color","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.PeaksPlot.BackgroundColorPicker = uicolorpicker(...
                'Parent',obj.SettingsAccordion.Items(6).Pane,...
                'Value',obj.Settings.PeaksPlot.BackgroundColor,...
                'ValueChangedFcn',@(o,~) obj.PeaksPlotSettingsChanged(o,"BackgroundColor"));

            uilabel(obj.SettingsAccordion.Items(6).Pane,"Text","Foreground Color","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.PeaksPlot.ForegroundColorPicker = uicolorpicker(...
                'Parent',obj.SettingsAccordion.Items(6).Pane,...
                'Value',obj.Settings.PeaksPlot.ForegroundColor,...
                'ValueChangedFcn',@(o,~) obj.PeaksPlotSettingsChanged(o,"ForegroundColor"));


            % add Labels accordion item
            obj.SettingsAccordion.addItem("Title","Labels",...
                "BorderColor",[0.49 0.49 0.49],...
                "TitleBackgroundColor",[.12 .12 .12],...
                "HoverTitleBackgroundColor",[.3 .3 .3],...
                "PaneBackgroundColor",[.18 .18 .18],...
                "FontColor",[0.85 0.85 0.85],...
                "BorderWidth",1,...
                "ExpandedBorderWidth",1,...
                "TitlePadding",1);
            % set size and spacing of pane grid
            set(obj.SettingsAccordion.Items(end).Pane,...
                "RowHeight",{'1x'},...
                "ColumnWidth",{'1x'},...
                "Padding",[0 0 0 0]);

            obj.LabelsTree = uitree(...
                "Parent",obj.SettingsAccordion.Items(end).Pane,...
                "SelectionChangedFcn",@(~,e) obj.onSelectLabel(e));



            % Expand Image and Region listbox accordion items
            obj.SettingsAccordion.Items(1).expand();
            obj.SettingsAccordion.Items(2).expand();
        end

        function setupImageViewer(obj)
            % uipanel to hold the viewer
            obj.ImageViewerPanel = uipanel(obj.Grid,'Title','Image Viewer','BackgroundColor',[0.12 0.12 0.12]);
            obj.ImageViewerPanel.Layout.Column = 2;
            obj.ImageViewerPanel.Layout.Row = [1 2];

            obj.ImageViewerPanelGrid = uigridlayout(obj.ImageViewerPanel,[1 1],...
                "ColumnWidth",{'1x'},...
                "RowHeight",{'1x'},...
                "Padding",[0 0 0 0]);

            % ImageAxes to view active image CData, select Regions
            obj.Ax = matlabx.ui.widgets.ImageAxes(obj.ImageViewerPanelGrid,...
                'Name','ImageViewer',...
                'CData',[],...
                'ToolBelt',{'Zoom','Pick','Colorbar'},...
                'Colormap',obj.Settings.Display.Colormap,...
                'CLim',[0 1]);

            % wire the optimistic callbacks for ImageViewer Pick tool
            obj.Ax.Tools.Pick.BoxCreatedFcn          = @(~,d) obj.onBoxCreated(d);
            obj.Ax.Tools.Pick.BoxMoveStartedFcn      = @(~,d) obj.onBoxMoveStarted(d);
            obj.Ax.Tools.Pick.BoxPreviewMovedFcn     = @(~,d) obj.onBoxPreviewMoved(d);
            obj.Ax.Tools.Pick.BoxMoveCommittedFcn    = @(~,d) obj.onBoxMoveCommitted(d);
            obj.Ax.Tools.Pick.BoxDeletedFcn          = @(~,d) obj.onBoxDeleted(d);
            obj.Ax.Tools.Pick.BoxActivatedFcn        = @(~,d) obj.onBoxActivated(d);
            obj.Ax.Tools.Pick.BoxSelectionChangedFcn = @(~,d) obj.onBoxSelectionChanged(d);

            % set the box size for Pick tool
            obj.Ax.Tools.Pick.BoxSize = obj.Settings.Analysis.BoxSize;
        end

        function setupRegionViewer(obj)
            % separate gridlayout object for the Region area
            obj.RegionGrid = uigridlayout(obj.Grid,[1 1],...
                "ColumnWidth",{'1x'},...
                "RowHeight",{'1x'},...
                "Padding",[0 0 0 0],...
                "ColumnSpacing",5,...
                "RowSpacing",5);
            obj.RegionGrid.Layout.Column = 3;
            obj.RegionGrid.Layout.Row = [1 2];

            % uipanel to hold the RegionViewer
            obj.RegionViewerPanel = uipanel(obj.RegionGrid,...
                'Title','Region Viewer',...
                'BackgroundColor',[0.12 0.12 0.12]);
            obj.RegionViewerPanel.Layout.Column = 1;
            obj.RegionViewerPanel.Layout.Row = 1;

            obj.RegionViewerPanelGrid = uigridlayout(obj.RegionViewerPanel,[1 1],...
                "ColumnWidth",{'1x'},...
                "RowHeight",{'1x'},...
                "Padding",[0 0 0 0]);

            % ImageAxes to show active region CData, make region measurements
            obj.RegionViewer = matlabx.ui.widgets.ImageAxes(obj.RegionViewerPanelGrid,...
                'Name','RegionViewer',...
                'CData',[],...
                'ToolBelt',{'DrawRectangle'},...
                'Colormap',obj.Settings.Display.Colormap,...
                'CLim',[0 1]);

            % wire the callbacks for RegionViewer DrawRectangle tool
            obj.RegionViewer.Tools.DrawRectangle.ROIPreviewMovedFcn    = @(~,d) obj.onROIPreviewMoved(d);
            obj.RegionViewer.Tools.DrawRectangle.ROIMoveCommittedFcn   = @(~,d) obj.onROIMoveCommitted(d);
            obj.RegionViewer.Tools.DrawRectangle.ROIDeletedFcn         = @(~,~) obj.onROIDeleted();
            % set options for RegionViewer DrawRectangle tool
            obj.RegionViewer.Tools.DrawRectangle.RotationAngleMode = 'half-circle';
        end

        function setupRegionSummaryTable(obj)
            obj.RegionSummaryPanel = uipanel(obj.RegionGrid,...
                'Title','Region Summary',...
                'BackgroundColor',[.12 .12 .12]);
            obj.RegionSummaryPanel.Layout.Row = 1;
            obj.RegionSummaryPanel.Layout.Column = 2;

            obj.RegionSummaryPanelGrid = uigridlayout(obj.RegionSummaryPanel,[1,1],...
                "ColumnWidth",{'1x'},...
                "RowHeight",{'1x'},...
                "Padding",[0 0 0 0]);

            obj.RegionSummaryTable = uitable(obj.RegionSummaryPanelGrid,...
                "ColumnName",{});
            obj.RegionSummaryTable.Layout.Row = 1;
            obj.RegionSummaryTable.Layout.Column = 1;
        end

        function setupRegionLinescanPlot(obj)
            obj.RegionLinescanPanel = uipanel(obj.RegionGrid,...
                'Title','Region Linescan',...
                'BackgroundColor',[.12 .12 .12]);
            obj.RegionLinescanPanel.Layout.Row = 2;
            obj.RegionLinescanPanel.Layout.Column = [1 2];

            obj.RegionLinescanPanelGrid = uigridlayout(obj.RegionLinescanPanel,[1,1],...
                "ColumnWidth",{'1x'},...
                "RowHeight",{'1x'},...
                "Padding",[5 5 5 5]);

            obj.RegionLinescanPlot = widgets.PeaksPlotContainer(obj.RegionLinescanPanelGrid,...
                "RawLineWidth",obj.Settings.PeaksPlot.RawLineWidth, ...
                "RawLineColor",obj.Settings.PeaksPlot.RawLineColor, ...
                "SmoothLineWidth",obj.Settings.PeaksPlot.SmoothLineWidth, ...
                "SmoothLineColor",obj.Settings.PeaksPlot.SmoothLineColor, ...
                "BackgroundColor",obj.Settings.PeaksPlot.BackgroundColor, ...
                "ForegroundColor",obj.Settings.PeaksPlot.ForegroundColor, ...
                "XLabel",sprintf("Distance (%s)",obj.Settings.Analysis.PixelSizeUnit), ...
                "YLabel","Normalized Intensity");
        end




        function delete(obj)
            % if ~isempty(obj.L), delete(obj.L(isvalid(obj.L))); end
            if ~isempty(obj.projectL), delete(obj.projectL(isvalid(obj.projectL))); end
            if ~isempty(obj.settingsL), delete(obj.settingsL(isvalid(obj.settingsL))); end
            if ~isempty(obj.Ax) && isvalid(obj.Ax), delete(obj.Ax); end
            if ~isempty(obj.RegionViewer) && isvalid(obj.RegionViewer), delete(obj.RegionViewer); end
            if ~isempty(obj.Grid) && isvalid(obj.Grid), delete(obj.Grid); end
            if ~isempty(obj.Fig)  && isvalid(obj.Fig),  delete(obj.Fig);  end
        end

    end

    %% Global UI sync
    methods (Access=private)

        function refreshUI(obj)

            % empty project -> clear out UI
            if isempty(obj.Project)
                obj.clearUI();
                obj.Grid.Visible = "off";
                return
            else
                obj.Grid.Visible = "on";
            end

            % menubar
            obj.refreshMenubar();

            % window name
            obj.refreshWindowName();

            % settings controllers
            obj.refreshSettingsControllers();

            % images
            obj.refreshImageList();
            obj.syncActiveImageToView();

            % regions
            obj.refreshRegionList();
            obj.syncActiveRegionToView();

            % labels
            obj.refreshLabelsTree()

        end

        function clearUI(obj)

            str = string.empty(1,0);

            % menubar
            obj.refreshMenubar();

            % window name
            obj.Fig.Name = sprintf("%s (%s)",app.Info.Name,app.Info.Version);

            % ImageListBox
            set(obj.ImageListBox,...
                "Items",str,...
                "ItemsData",str,...
                "Value",str);

            % ImageViewer
            obj.Ax.CData = [];
            obj.Ax.Tools.Pick.clearBoxes();

            % RegionListBox
            set(obj.RegionListBox,...
                "Items",{},...
                "ItemsData",{},...
                "Value",{});

            % RegionViewer
            obj.RegionViewer.CData = [];
            obj.RegionViewer.Tools.DrawRectangle.setROIPosition(model.STORMRegion.LinescanTemplate);

            % RegionLinescanPlot
            obj.RegionLinescanPlot.Data = model.analysis.PeaksData.empty();
            obj.RegionLinescanPlot.Title = '';

            % RegionSummaryTable
            obj.RegionSummaryTable.Data = [];

            % LabelsTree
            obj.clearLabelsTree();

        end

        function refreshSettingsControllers(obj)
            S = obj.Settings;
            % Colormap
            cmap = S.Display.Colormap;
            cmapName = obj.Settings.Display.ColormapName;
            obj.ColormapTree.SelectedNodes = obj.ColormapTree.findobj("NodeData",cmapName);
            obj.ExampleColormapAxes.Colormap = cmap;
            obj.Ax.Colormap = cmap;
            obj.RegionViewer.Colormap = cmap;
            % set axes limits so that colorbar image fills axes area
            set(obj.ExampleColormapAxes,"YLim",[0.5 50.5],"XLim",[0.5 256.5]);
            % Analysis
            obj.SettingsUI.Analysis.BoxSizeEditField.Value = S.Analysis.BoxSize;
            obj.SettingsUI.Analysis.MinPeakDistanceEditField.Value = S.Analysis.MinPeakDistance;
            obj.SettingsUI.Analysis.MinPeakHeightEditField.Value = S.Analysis.MinPeakHeight;
            obj.SettingsUI.Analysis.PeakSmoothingEditField.Value = S.Analysis.PeakSmoothing;
            obj.SettingsUI.Analysis.PixelSizeValueEditField.Value = S.Analysis.PixelSizeValue;
            obj.SettingsUI.Analysis.PixelSizeUnitDropDown.Value = S.Analysis.PixelSizeUnit;
            % PeaksPlot
            obj.SettingsUI.PeaksPlot.RawLineColorPicker.Value = S.PeaksPlot.RawLineColor;
            obj.SettingsUI.PeaksPlot.RawLineWidthEditField.Value = S.PeaksPlot.RawLineWidth;
            obj.SettingsUI.PeaksPlot.SmoothLineColorPicker.Value = S.PeaksPlot.SmoothLineColor;
            obj.SettingsUI.PeaksPlot.SmoothLineWidthEditField.Value = S.PeaksPlot.SmoothLineWidth;
            obj.SettingsUI.PeaksPlot.BackgroundColorPicker.Value = S.PeaksPlot.BackgroundColor;
            obj.SettingsUI.PeaksPlot.ForegroundColorPicker.Value = S.PeaksPlot.ForegroundColor;
            % Display
            obj.SettingsUI.Display.AutoScaleDisplayIntensityCheckBox.Value = S.Display.AutoScaleDisplayIntensity;
            % Sliders
            set(obj.IntensitySlider,'Limits',[0 1],'Value',[0 1]);
        end

        function refreshWindowName(obj)
            if isempty(obj.Project)
                obj.Fig.Name = sprintf("%s (%s)",app.Info.Name,app.Info.Version);
            else
                obj.Fig.Name = sprintf("%s (%s) - %s",app.Info.Name,app.Info.Version,obj.Project.Name);
            end
        end

        function refreshMenubar(obj)

            if isempty(obj.Project)
                % disable all menubar options
                names = fieldnames(obj.MenubarUI);
                for i = 1:numel(names)
                    obj.MenubarUI.(names{i}).Enable = "off";
                end
                % re-enable only File, File->New, and File->Open
                set([obj.MenubarUI.File,obj.MenubarUI.File_New,obj.MenubarUI.File_Open],'Enable','on');
            else
                % enable all menubar options
                names = fieldnames(obj.MenubarUI);
                for i = 1:numel(names)
                    obj.MenubarUI.(names{i}).Enable = "on";
                end
            end

        end

    end

    %% Helpers
    methods (Access=private)

        function detatchListeners(obj)
            % project
            if ~isempty(obj.projectL), delete(obj.projectL(isvalid(obj.projectL))); end
            obj.projectL = event.listener.empty();
            % settings
            if ~isempty(obj.settingsL), delete(obj.settingsL(isvalid(obj.settingsL))); end
            obj.settingsL = event.listener.empty();
        end

        function refreshListeners(obj)
            if ~isempty(obj.Project)
                obj.projectL(1) = addlistener(obj.Project,'ImageAdded',             @(~,~) obj.refreshImageList());
                obj.projectL(2) = addlistener(obj.Project,'ImageRemoved',           @(~,~) obj.refreshImageList());
                obj.projectL(3) = addlistener(obj.Project,'ActiveImageChanged',     @(~,~) obj.syncActiveImageToView());
                obj.projectL(4) = addlistener(obj.Project,'RegionAdded',            @(~,~) obj.onRegionAdded());
                obj.projectL(5) = addlistener(obj.Project,'RegionRemoved',          @(~,~) obj.refreshRegionList());
                obj.projectL(6) = addlistener(obj.Project,'ActiveRegionChanged',    @(~,~) obj.syncActiveRegionToView());
                obj.projectL(7) = addlistener(obj.Project,'RegionSelectionChanged', @(~,~) obj.onRegionSelectionChanged());
                obj.projectL(8) = addlistener(obj.Project,'LabelsChanged',          @(~,~) obj.onLabelsChanged());
            end

            obj.settingsL(1) = addlistener(obj.Settings,'DisplayChanged',   @(~,e) obj.onDisplayChanged(e));
            obj.settingsL(2) = addlistener(obj.Settings,'AnalysisChanged',  @(~,e) obj.onAnalysisChanged(e));
            obj.settingsL(3) = addlistener(obj.Settings,'IOChanged',        @(~,e) obj.onIOChanged(e));
            obj.settingsL(4) = addlistener(obj.Settings,'PeaksPlotChanged', @(~,e) obj.onPeaksPlotChanged(e));
            obj.settingsL(5) = addlistener(obj.Settings,'BoxChanged',       @(~,e) obj.onBoxChanged(e));
        end

        function refreshHotkeys(obj)
            % refresh hotkeys for label selection
            obj.onLabelsChanged();
        end

    end

    %% Callbacks / UI sync (Images)
    methods (Access=private)

        % uimenu callback (File -> Load Images...)
        function onLoadImages(obj)
            % hide figure to show file selection dialog
            obj.Fig.Visible = 'off';
            % file selection dialog
            [files, path] = uigetfile( ...
                {'*.tif;*.tiff;*.png;*.jpg;*.jpeg;*.bmp','Image Files'; '*.*','All Files'}, ...
                'Select reconstructed dSTORM images', ...
                'MultiSelect','on');
            % show figure
            obj.Fig.Visible = 'on';
            % if cancelled or no files selected
            if isequal(files,0)
                return
            end
            % if char, convert to cell
            if ischar(files), files = {files}; end
            % get full filenames
            fullpaths = fullfile(path, files);
            % add new STORMImages
            obj.Project.addImagesFromPaths(fullpaths);
        end

        % fired on ImageAdded and ImageRemoved events
        function refreshImageList(obj)
            % string array of image IDs
            %ids = obj.Project.ImageOrder;

            ids = obj.Project.ImageIDs;

            if isempty(ids)
                obj.ImageListBox.Items = string.empty(1,0);
                obj.ImageListBox.ItemsData = string.empty(1,0);
                obj.ImageListBox.Value = string.empty(1,0);
                return
            end

            % string array of image names
            names = obj.Project.ImageNames;     

            % update ImageListBox Items and ItemsData
            obj.ImageListBox.Items     = names;
            obj.ImageListBox.ItemsData = ids;


            img = obj.Project.ActiveImage;

            if ~isempty(img)
                obj.ImageListBox.Value = img.ID;
            else
                obj.ImageListBox.Value = ids(1);
            end

            % forward value to ValueChangedFcn of ImageListBox
            obj.onSelectImage(obj.ImageListBox.Value);
        end

        % ValueChangedFcn callback for ImageListBox (imageID is from the uilistbox Value property)
        function onSelectImage(obj, imageID)
            if isempty(imageID), return; end
            obj.Project.setActiveImage(imageID);
        end

        % fired on ActiveImageChanged event
        function syncActiveImageToView(obj)
            % refresh ImageViewer CData and CLim
            obj.refreshImageViewer();

            % refresh RegionListBox
            obj.refreshRegionList();
            % refresh region boxes
            obj.refreshRegionBoxes();

            obj.syncActiveRegionToView();
        end

        function refreshImageViewer(obj)
            % refresh ImageViewer CData and CLim
            % get the active image
            img = obj.Project.ActiveImage;
            % if empty, clear view and return
            if isempty(img), obj.Ax.CData = []; return, end
            % get CData
            cdata = img.CData;
            % get CLim
            switch obj.Settings.Display.AutoScaleDisplayIntensity
                case true
                    clim = img.AutoDisplayCLim;
                case false
                    clim = img.DisplayCLim;
            end

            % update ImageViewer CData and CLim
            set(obj.Ax,'CData',cdata,'CLim',clim);
            % update IntensitySlider Limits and Value
            set(obj.IntensitySlider,'Limits',img.CDataRange,'Value',clim);
        end

    end

    %% Callbacks / UI sync (Regions)
    methods (Access=private)

        function onRegionAdded(obj)
            obj.refreshRegionList();
            app.Log.INFO("Region added.")
        end

        function onRegionSelectionChanged(obj)
            obj.refreshRegionList();
        end

        function refreshRegionList(obj)

            img = obj.Project.ActiveImage;
            if isempty(img) || isempty(img.RegionOrder)
                obj.clearRegionListBox();
                return
            end

            % --- multi-select ---
            set(obj.RegionListBox,"Items",img.RegionNames,"ItemsData",img.RegionOrder,"Value",img.SelectedRegionIDs);

        end

        function clearRegionListBox(obj), set(obj.RegionListBox,"Items",{},"ItemsData",{},"Value",{}); end

        function refreshRegionBoxes(obj)
            obj.Ax.Tools.Pick.clearBoxes();

            img = obj.Project.ActiveImage;

            if isempty(img) || isempty(img.RegionArray)
                return
            end

            % add a box for each region, colored according to its label
            for r = img.RegionArray
                boxColor = obj.Project.LabelBank.getByID(r.LabelID).Color;
                obj.Ax.Tools.Pick.addBox(r.ID, r.Center, r.BoxSize, ...
                    "EdgeColor", boxColor, "FaceColor", boxColor, "Label", r.Name);
            end

            % apply selection status to region boxes
            obj.Ax.Tools.Pick.setSelectedBoxIDs(img.SelectedRegionIDs);

            % set active box
            obj.Ax.Tools.Pick.setActiveBoxID(img.ActiveRegionID);

        end

        % RegionListBox ValueChangedFcn
        function onSelectRegion(obj, ~, evt)

            img = obj.Project.ActiveImage;
            if isempty(img), return; end

            regionIDs = evt.Value;

            ids = string(regionIDs);
            ids = ids(strlength(ids)>0);

            % set active/selected region
            if ~isempty(ids)
                obj.Ax.Tools.Pick.setSelectedBoxIDs(ids);
                obj.Ax.Tools.Pick.setActiveBoxID(ids(1));
                img.setRegionSelection(ids);
                img.setActiveRegion(ids(1));
            else
                obj.Ax.Tools.Pick.clearBoxSelection();
                obj.Ax.Tools.Pick.setActiveBoxID("");
                obj.Ax.Tools.Pick.clearBoxSelection();
                img.setActiveRegion("");
            end

        end

        % function regionListBoxClicked(obj,src,evt)
        % 
        %     disp('listbox clicked')
        % 
        %     % img = obj.Project.ActiveImage;
        %     % if isempty(img), return; end
        %     % 
        %     % itemIdx = evt.InteractionInformation.Item;
        %     % 
        %     % if isempty(itemIdx)
        %     %     obj.Ax.Tools.Pick.setActiveBoxID("");
        %     %     img.setActiveRegion("");
        %     %     return
        %     % end
        %     % 
        %     % regionID = src.ItemsData(itemIdx);
        %     % 
        %     % obj.Ax.Tools.Pick.setActiveBoxID(regionID);
        %     % img.setActiveRegion(regionID);
        % 
        % end

        function syncActiveRegionToView(obj)
            % refresh RegionViewer CData and CLim
            obj.refreshRegionViewer();
            % update RegionSummaryTable
            obj.refreshRegionSummaryTable();
            % update linescan
            obj.refreshRegionLinescanROI();
            obj.refreshRegionLinescanPlot();
        end

        function refreshRegionViewer(obj)
            img = obj.Project.ActiveImage;
            % if empty, clear view and return
            if isempty(img) || isempty(img.ActiveRegion)
                obj.RegionViewer.CData = []; return
            end
            % update ImageViewer CData and CLim
            switch obj.Settings.Display.AutoScaleDisplayIntensity
                case true
                    set(obj.RegionViewer,'CData',img.regionSubimage(img.ActiveRegion),'CLim',img.AutoDisplayCLim);
                case false
                    set(obj.RegionViewer,'CData',img.regionSubimage(img.ActiveRegion),'CLim',img.DisplayCLim);
            end
        end

        function refreshRegionSummaryTable(obj)
            if isempty(obj.Project.ActiveImage) || isempty(obj.Project.ActiveImage.ActiveRegion)
                obj.RegionSummaryTable.Data = [];
            else
                obj.RegionSummaryTable.Data = obj.Project.ActiveImage.ActiveRegion.SummaryTable;
            end
        end

        function refreshRegionLinescanPlot(obj)
            img = obj.Project.ActiveImage;
            % if empty, clear plot and return
            if isempty(img) || isempty(img.ActiveRegion)
                obj.RegionLinescanPlot.Data = model.analysis.PeaksData.empty();
                obj.RegionLinescanPlot.Title = '';
                return
            end
            reg = img.ActiveRegion;
            % update plot data and labels
            obj.RegionLinescanPlot.XLabel = sprintf("Distance (%s)",img.PixelSize.Unit);
            obj.RegionLinescanPlot.Data = reg.LinescanResults;
            obj.RegionLinescanPlot.Title = matlabx.utils.text.texFriendly(img.Name) + " | " + reg.Name;
        end

        function refreshRegionLinescanROI(obj)
            img = obj.Project.ActiveImage;
            % if empty, clear linescan position and return
            if isempty(img) || isempty(img.ActiveRegion)
                obj.RegionViewer.Tools.DrawRectangle.setROIPosition(model.STORMRegion.LinescanTemplate);
                return
            end
            % update linescan ROI position
            obj.RegionViewer.Tools.DrawRectangle.setROIPosition(img.ActiveRegion.Linescan);
        end

    end

    %% Callbacks / UI sync (Labels)
    methods (Access=private)

        function onLabelsChanged(obj)

            labels = obj.Project.LabelBank.labels;

            for i = 1:numel(labels)
                % add a hotkey for each label
                obj.CommandRouter.addHotkey(labels(i).Hotkey,@(~,k) obj.onLabelHotkeyPressed(k));
            end
        end

        function onLabelHotkeyPressed(obj,key)
            if isempty(obj.Project), return; end

            % get label matching hotkey
            L = obj.Project.LabelBank.getByHotkey(key);

            % no match -> return
            if isempty(L), return; end

            % set it as active
            obj.Project.LabelBank.setActiveByID(L.ID);

            % reflect in tree selection if present
            if ~isempty(obj.LabelsTree) && isvalid(obj.LabelsTree)
                n = obj.LabelsTree.findobj("NodeData", L.ID);
                if ~isempty(n), obj.LabelsTree.SelectedNodes = n(1); end
            end

            obj.applyActiveLabelToSelection();
            return

        end

        function refreshLabelsTree(obj)
            if isempty(obj.Project) || isempty(obj.LabelsTree) || ~isvalid(obj.LabelsTree)
                return
            end

            delete(obj.LabelsTree.Children);

            bank = obj.Project.LabelBank;
            arr = bank.labels();

            for k = 1:numel(arr)
                L = arr(k);
                txt = string(L.Name);
                if strlength(L.Hotkey) > 0
                    txt = txt + "  [" + L.Hotkey + "]";
                end
                uitreenode("Parent",obj.LabelsTree,...
                    "Text",txt,...
                    "NodeData",L.ID);
            end

            % select active label node if possible
            if strlength(bank.ActiveLabelID) > 0
                n = obj.LabelsTree.findobj("NodeData", bank.ActiveLabelID);
                if ~isempty(n)
                    obj.LabelsTree.SelectedNodes = n(1);
                end
            end
        end

        function clearLabelsTree(obj)
            delete(obj.LabelsTree.Children);
        end

        function onSelectLabel(obj, evt)
            if isempty(obj.Project), return; end
            node = evt.SelectedNodes;
            if isempty(node) || isempty(node.NodeData)
                return
            end
            obj.Project.LabelBank.setActiveByID(string(node.NodeData));
        end

        function applyActiveLabelToSelection(obj)
            img = obj.Project.ActiveImage;
            if isempty(img), return; end

            ids = obj.Ax.Tools.Pick.getSelectedBoxIDs();
            if isempty(ids), return; end

            bank = obj.Project.LabelBank;
            L = bank.active();
            if isempty(L), return; end

            for i = 1:numel(ids)
                r = img.getRegion(ids(i));
                if ~isempty(r)
                    r.LabelID = L.ID;
                    r.LabelSource = "user";
                end
            end

            % recolor overlays
            obj.Ax.Tools.Pick.setBoxesColorByIDs(ids, L.Color);
        end

        function clearLabelOnSelection(obj)
            img = obj.Project.ActiveImage;
            if isempty(img), return; end

            ids = obj.Ax.Tools.Pick.getSelectedBoxIDs();
            if isempty(ids), return; end

            for i = 1:numel(ids)
                r = img.getRegion(ids(i));
                if ~isempty(r)
                    r.LabelID = "";
                end
            end

            obj.Ax.Tools.Pick.setBoxesEdgeColorByIDs(ids, 'w');
        end



    end

    %% Callbacks / UI sync (Settings)
    methods (Access=private)

        function onDisplayChanged(obj,e)
            switch e.Name
                case "Colormap"
                    obj.ExampleColormapAxes.Colormap = obj.Settings.Display.Colormap;
                    obj.Ax.Colormap = obj.Settings.Display.Colormap;
                    obj.RegionViewer.Colormap = obj.Settings.Display.Colormap;
                case "BoxFaceColor"
                    %set(obj.ROI, 'FaceColor', obj.Settings.Display.BoxFaceColor);
                case "BoxEdgeColor"
                    %set(obj.ROI, 'EdgeColor', obj.Settings.Display.BoxEdgeColor);
                case "AutoScaleDisplayIntensity"
                    % make sure checked/unchecked state matches settings
                    obj.SettingsUI.Display.AutoScaleDisplayIntensityCheckBox.Value = e.NewValue;
                    % refresh image view
                    obj.refreshImageViewer();
                    % refresh region view
                    obj.refreshRegionViewer();
            end
        end

        function onPeaksPlotChanged(obj,e)
            obj.RegionLinescanPlot.(e.Name) = obj.Settings.PeaksPlot.(e.Name);
        end

        function onBoxChanged(obj,e)
            % do something
        end

        function onAnalysisChanged(obj,e)
            switch e.Name
                case {"MinPeakDistance","MinPeakHeight","PeakSmoothing"}
                    % immediately re-process all existing regions when analysis settings change
                    obj.processAllRegions();
                case "BoxSize"
                    % delete all existing Regions
                    obj.Project.removeAllRegions();
                    % refresh the display for the current image
                    obj.syncActiveImageToView();
                    obj.refreshRegionLinescanROI();
                    obj.refreshRegionLinescanPlot();
                    % update BoxSize for Pick tool
                    obj.Ax.Tools.Pick.BoxSize = obj.Settings.Analysis.BoxSize;
                case {"PixelSizeValue","PixelSizeUnit"}
                    obj.Project.setDefaultPixelSize(obj.Settings.Analysis.getDefaultPixelSize);
                    % re-process all existing regions to reflect new pixel size
                    obj.processAllRegions();
                    % refresh the region linescan plot
                    obj.refreshRegionLinescanPlot();
            end
        end

        function onIOChanged(obj,e)
            if e.Name=="DefaultFolder"
                % do something
            end
        end

        function ColormapSelectionChanged(obj,evt)
            % get the newly selected node
            node = evt.SelectedNodes;
            % get colormap name from NodeData property
            colormapName = node.NodeData;
            % if empty -> user selected a category node, reset previous selection
            if isempty(colormapName)
                %evt.Source.SelectedNodes = evt.PreviousSelectedNodes;
                return
            end
            % get category from Text property of Parent node
            categoryName = node.Parent.Text;
            % update settings
            obj.Settings.Display.setColormap(colormapName,categoryName);
        end

        function AnalysisSettingsChanged(obj,src,stgName)
            % for certain settings, prompt for confirmation before updating
            switch stgName
                case {"MinPeakDistance","MinPeakHeight","PeakSmoothing"}
                    msg1 = sprintf('New %s value will be applied to all regions. Continue?',stgName);
                    msg2 = sprintf('Confirm %s Change',stgName);
                    selection = uiconfirm(obj.Fig, ...
                        msg1, ...
                        msg2, "Icon","warning", "Options", {'OK', 'Cancel'});
                case 'BoxSize'
                    selection = uiconfirm(obj.Fig, ...
                        "Changing the BoxSize will delete any existing regions. Continue?",...
                        "Confirm BoxSize Change", "Icon","warning", "Options", {'OK', 'Cancel'});
                case {'PixelSizeValue','PixelSizeUnit'}
                    selection = uiconfirm(obj.Fig, ...
                        "New pixel size will be applied to all images. Continue?",...
                        "Confirm Pixel Size Change", "Icon","warning", "Options", {'OK', 'Cancel'});
                otherwise
                    selection = 'OK';
            end
            switch selection
                case 'Cancel'
                    src.Value = obj.Settings.Analysis.(stgName); % restore previous value from existing settings
                case 'OK'
                    obj.Settings.Analysis.(stgName) = src.Value; % update settings
            end
        end

        function PeaksPlotSettingsChanged(obj,src,stgName)
            % apply the specified setting
            obj.Settings.PeaksPlot.(stgName) = src.Value;
        end

        function DisplaySettingsChanged(obj,src,stgName)
            % apply the specified setting
            obj.Settings.Display.(stgName) = src.Value;
        end

    end

    %% Callbacks - Menubar
    methods (Access=private)

        function onNew(obj)
            % START NEW PROJECT

            % --- cleanup before starting new ---
            % delete project
            obj.Project.delete();
            % delete settings
            obj.Settings.delete();
            % detach listeners
            obj.detatchListeners();

            % --- Settings ---
            obj.Settings = app.config.Settings.load();
            % --- Model ---
            obj.Project = model.STORMProject("untitled");
            obj.Project.DefaultPixelSize = obj.Settings.Analysis.getDefaultPixelSize();

            % refresh hotkeys
            obj.refreshHotkeys();
            % refresh UI
            obj.refreshUI();
            % refresh listeners
            obj.refreshListeners();
        end

        function onOpen(obj)
            % OPEN EXISTING PROJECT

            % --- get project file ---
            % hide figure -> show file selection dialog -> show figure
            obj.Fig.Visible = 'off';
            [file, path] = uigetfile('*.mat','Select project file (.mat)','MultiSelect','off');
            obj.Fig.Visible = 'on';
            if isequal(file,0), return; end % cancelled | no files selected -> return
            % get full file name
            fname = fullfile(path, file);

            % --- set up progress dialog ---
            msg = sprintf('Loading project:\n%s',fname);
            h = uiprogressdlg(obj.Fig,"Message",msg,'Indeterminate','on');

            % --- cleanup before loading ---
            obj.Project.delete();   % delete project
            obj.Settings.delete();  % delete settings
            obj.detatchListeners(); % detach listeners

            % --- load Project and Settings ---
            [proj,stgs] = model.STORMProject.load(fname);

            % valid output from load -> assign and process
            if ~isempty(proj) && ~isempty(stgs)
                obj.Project = proj;
                obj.Settings = stgs;
                obj.processAllRegions(); % run region analysis
            else
                obj.Project = model.STORMProject.empty(); % empty project
                obj.Settings = app.config.Settings.load(); % default settings
            end

            % --- refresh hotkeys/UI/listeners ---
            obj.refreshHotkeys();
            obj.refreshUI();
            obj.refreshListeners();

            % close progress dialog
            close(h);
        end

        function onClose(obj)
            % CLOSE CURRENT PROJECT
            % no project -> return
            if isempty(obj.Project), return; end
            % --- delete project, detach listeners, refresh UI ---
            obj.Project.delete(); 
            obj.Project = model.STORMProject.empty(); % set empty so we do not store old handle
            obj.detatchListeners();
            obj.refreshUI();
        end

        function onSave(obj)
            % SAVE CURRENT PROJECT
            obj.Fig.Visible = 'off';

            if obj.Project.isOnDisk
                defaultName = obj.Project.SourcePath;
            else
                defaultName = fullfile(obj.Settings.IO.DefaultFolder, obj.Project.Name + '.mat');
            end

            [file, path] = uiputfile('*.mat','Save project', defaultName);

            obj.Fig.Visible = 'on';

            if isequal(file,0)
                return;  % user cancelled
            end

            % get full file name
            fname = fullfile(path, file);

            % create progress dialog
            msg = sprintf('Saving project:\n%s',fname);
            h = uiprogressdlg(obj.Fig,"Message",msg,'Indeterminate','on');

            % save the project
            obj.Project.save(fname,obj.Settings);

            % refresh the window name
            obj.refreshWindowName();

            % clost progress dialog
            close(h);
        end

        function onSaveSettings(obj)
            obj.Settings.save(); % save current settings to default file
        end

    end

    %% Per-image settings
    methods (Access=private)

        function onIntensitySliderChanging(obj,~)
            % get the active image
            img = obj.Project.ActiveImage;
            if isempty(img), return; end

            % set MaxRenderedResolution for smoother updates in ImageViewer, RegionViewer
            obj.Ax.MaxRenderedResolution = obj.Ax.CDataSize(1)/4;
            obj.RegionViewer.MaxRenderedResolution = obj.Settings.Analysis.BoxSize/4;

            % set the new CLim for both axes
            set([obj.Ax,obj.RegionViewer],'CLim',obj.IntensitySlider.Value);
        end

        function onIntensitySliderChanged(obj,~)
            % get the active image
            img = obj.Project.ActiveImage;
            if isempty(img), return; end

            % newVal = evt.Source.Value;
            newVal = obj.IntensitySlider.Value;

            % update model
            img.DisplayCLim = newVal;

            % update view
            obj.Ax.CLim = newVal;
            obj.RegionViewer.CLim = newVal;

            % disable AutoScaleDisplayIntensity if enabled
            if obj.Settings.Display.AutoScaleDisplayIntensity
                obj.Settings.Display.AutoScaleDisplayIntensity = false;
            end

            % reset MaxRenderedResolution
            obj.Ax.MaxRenderedResolution = 'none';
            obj.RegionViewer.MaxRenderedResolution = 'none';
        end

    end

    %% Processing hooks
    methods (Access=private)

        function processActiveRegion(obj)
            % get the ActiveImage, exit if empty
            img = obj.Project.ActiveImage; if isempty(img), return; end
            % get the ActiveRegion, exit if empty
            reg = img.ActiveRegion; if isempty(reg), return; end
            % process the linescan for this region
            img.processRegionLinescan(reg,app.config.RunConfig.fromSettings(obj.Settings));
            % update the region linescan plot
            obj.refreshRegionLinescanPlot();
            % update RegionSummaryTable
            obj.RegionSummaryTable.Data = reg.SummaryTable;
        end

        function processAllRegions(obj)
            % create progress dialog
            h = uiprogressdlg(obj.Fig,"Message",'Please wait...','Indeterminate','on');
            % re-process everything
            obj.Project.processAll(app.config.RunConfig.fromSettings(obj.Settings))
            % close the progress dialog
            close(h);
            % get the ActiveImage, exit if empty
            img = obj.Project.ActiveImage; if isempty(img), return; end
            % get the ActiveRegion, exit if empty
            reg = img.ActiveRegion; if isempty(reg), return; end
            % update the region linescan plot
            obj.refreshRegionLinescanPlot();
            % update RegionSummaryTable
            obj.RegionSummaryTable.Data = reg.SummaryTable;
        end

        function onAutopickRegions(obj)
            %% OLD METHOD

            % create progress dialog
            h = uiprogressdlg(obj.Fig,"Message",'Please wait...','Indeterminate','on');

            % detect regions for the active image
            obj.Project.detectRegions(app.config.RunConfig.fromSettings(obj.Settings),h);

            % close the progress dialog
            close(h);

            %% NEW METHOD


        end

        function onRunClassifier(obj)
            imgs = obj.Project.ImageArray;
            if isempty(imgs), return; end

            % --- get file ---
            % hide figure to show file selection dialog
            obj.Fig.Visible = 'off';
            % file selection dialog
            [file, path] = uigetfile( ...
                {'*.mat'}, ...
                'Select classifier file', ...
                app.Paths.ml, ...
                'MultiSelect','off');

            % cancelled -> return
            if isequal(file,0)
                obj.Fig.Visible = 'on';
                return
            end
            % build full file path
            classifierFile = fullfile(path,file);

            % --- load ---
            app.Log.INFO(sprintf("Loading classifier file: %s",classifierFile));
            pkg = model.ml.loadClassifierPackage(classifierFile);
            net = pkg.Net;
            propOpts = pkg.PropOpts;

            % get proposal options
            params = matlabx.app.ParamsDialog.prompt( ...
                'Class proposal options', ...
                {'Stride','Stride','double',propOpts.Stride, @(x) x>=1, 'Stride must be >= 1'},...
                {'ScoreThreshold','ScoreThreshold','double',propOpts.ScoreThreshold, @(x) x<=1 && x>=0, 'ScoreThreshold must be between 0 and 1'},...
                {'NmsIoU','NmsIoU','double',propOpts.NmsIoU, @(x) x>=0 && x<=1, 'NmsIoU must be between 0 and 1'},...
                {'BatchSize','BatchSize','choice',propOpts.BatchSize,{64,128,256,512,1024}});

            % show figure
            obj.Fig.Visible = 'on';
            pause(0.5)

            if isempty(params)
                return
            end

            propOpts.Stride         = params.Stride;
            propOpts.ScoreThreshold = params.ScoreThreshold;
            propOpts.NmsIoU         = params.NmsIoU;
            propOpts.BatchSize      = str2double(params.BatchSize);

            % create progress dialog
            h = uiprogressdlg(obj.Fig,"Message",'Please wait...','Indeterminate','on');

            fprintf('\n');
            fprintf('Proposal options\n');
            fprintf('----------------\n');
            fprintf('BoxSize            : %d\n',    propOpts.BoxSize);
            fprintf('Stride             : %d\n',    propOpts.Stride);
            fprintf('ScoreThreshold     : %.2f\n',  propOpts.ScoreThreshold);
            fprintf('NmsIoU             : %.2f\n',  propOpts.NmsIoU);
            fprintf('BatchSize          : %d\n',    propOpts.BatchSize);
            fprintf('PositiveClass      : %s\n',    propOpts.PositiveClass);
            fprintf('\n');

            % --- run ---
            N = numel(imgs);
            for i = 1:N
                app.Log.INFO(sprintf("Running classifier on image (%i/%i): %s",i,N,imgs(i).Name));
                imgs(i).runClassifier(net,propOpts);
            end


            % --- sync UI ---
            obj.syncActiveImageToView();

            % close the progress dialog
            close(h);

        end

        function onTrainNewClassifier(obj)
            % --- get params ---
            % hide figure to show params dialog
            obj.Fig.Visible = 'off';

            % get initial training options
            params = matlabx.app.ParamsDialog.prompt( ...
                'Initial training options', ...
                {'BaseName','Classifier name','char','new_classifier', @(x) ~contains(x,' '), 'Name cannot contain spaces'},...
                {'MaxEpochs','MaxEpochs','double',15, @(x) x>=1, 'MaxEpochs must be >= 1'},...
                {'InitialLearnRate','InitialLearnRate','double',0.0003, @(x) x>0, 'InitialLearnRate must be > 0'},...
                {'IoUMax','IoUMax','double',0.05, @(x) x>=0 && x<=1, 'IoUMax must be between 0 and 1'},...
                {'MiniBatchSize','MiniBatchSize','choice',8,{8,16,32,64,128}});

            % show figure
            obj.Fig.Visible = 'on';
            pause(0.5)

            if isempty(params), return; end

            % --- train a new classifier ---
            app.Log.INFO(sprintf("Training new classifier: %s",params.BaseName));
            model.ml.trainNewClassifierFromProject(obj.Project,...
                "BaseName",         params.BaseName, ...
                "MaxEpochs",        params.MaxEpochs, ...
                "InitialLearnRate", params.InitialLearnRate, ...
                "IoUMax",           params.IoUMax, ...
                "MiniBatchSize",    str2double(params.MiniBatchSize));


            app.Log.INFO("Initial training complete.");

        end

        function onContinueTrainingClassifier(obj)
            % --- get file ---
            % hide figure to show file selection dialog
            obj.Fig.Visible = 'off';
            % file selection dialog
            [file, path] = uigetfile( ...
                {'*.mat'}, ...
                'Select classifier file', ...
                app.Paths.ml, ...
                'MultiSelect','off');

            % cancelled -> return
            if isequal(file,0)
                obj.Fig.Visible = 'on';
                return
            end
            % build full file path
            classifierFile = fullfile(path,file);

            % get continued training options
            params = matlabx.app.ParamsDialog.prompt( ...
                'Continued training options', ...
                {'MaxEpochs','MaxEpochs','double',5, @(x) x>=1, 'MaxEpochs must be >= 1'},...
                {'InitialLearnRate','InitialLearnRate','double',0.0001, @(x) x>0, 'InitialLearnRate must be > 0'},...
                {'IoUMax','IoUMax','double',0.05, @(x) x>=0 && x<=1, 'IoUMax must be between 0 and 1'},...
                {'MiniBatchSize','MiniBatchSize','choice',8,{8,16,32,64,128}});

            % show figure
            obj.Fig.Visible = 'on';
            pause(0.5)

            if isempty(params), return; end

            % --- continue training classifier ---
            app.Log.INFO(sprintf("Continuing training from: %s",classifierFile));
            model.ml.continueClassifierTrainingFromProject(obj.Project,classifierFile, ...
                "MaxEpochs",            params.MaxEpochs, ...
                "InitialLearnRate",     params.InitialLearnRate, ...
                "IoUMax",               params.IoUMax, ...
                "MiniBatchSize",        str2double(params.MiniBatchSize));

            app.Log.INFO("Continued training complete.");
        end


    end

    %% Event handlers for Pick tool callbacks
    methods (Access=private)

        function onBoxCreated(obj, data)

            disp('onBoxCreated()')

            % Get active image
            img = obj.Project.ActiveImage; if isempty(img), return; end

            % Get current active label
            L = obj.Project.LabelBank.active();

            % Create a new STORMRegion in the active image with the active label
            img.addRegion(data.ID, data.CenterPx, obj.Settings.Analysis.BoxSize, L.ID, "user");
            %reg = img.getRegion(data.ID);

            % Apply active label color to the newly created box
            obj.Ax.Tools.Pick.setBoxColorByID(data.ID, L.Color);
            obj.Ax.Tools.Pick.setBoxLabelByID(data.ID, img.getRegion(data.ID).Name);

            % % Make it active (this will drive downstream sync)
            % img.setActiveRegion(data.ID);
        end

        function onBoxMoveStarted(obj, data)
            img = obj.Project.ActiveImage; if isempty(img), return; end
            regionID = data.ID;
            if img.hasRegion(regionID)
                img.setActiveRegion(regionID);
            end
        end

        function onBoxPreviewMoved(obj, data)
            % Live move previews — optional
            % get active image
            img = obj.Project.ActiveImage; if isempty(img), return; end
            % get region using ID
            regionID = data.ID;
            r = img.getRegion(regionID);
            if ~isempty(r)
                % update region in model
                r.Center = data.CenterPx;
                % sync view
                obj.syncActiveRegionToView();
            end
        end

        function onBoxMoveCommitted(obj, data)
            img = obj.Project.ActiveImage; if isempty(img), return; end
            regionID = data.ID;
            r = img.getRegion(regionID);
            if ~isempty(r)
                r.Center = data.CenterPx;
                obj.syncActiveRegionToView();
            end
            % testing below
            % process the linescan for this region
            img.processRegionLinescan(r,app.config.RunConfig.fromSettings(obj.Settings));
            % update the region linescan plot
            obj.refreshRegionLinescanPlot();
            % update RegionSummaryTable
            obj.RegionSummaryTable.Data = r.SummaryTable;
        end

        function onBoxDeleted(obj, data)
            % Widget already removed the overlay optimistically -> remove the corresponding region
            img = obj.Project.ActiveImage; if isempty(img), return; end
            regionID = data.ID;
            if img.hasRegion(regionID)
                img.removeRegion(regionID);
            end
        end

        function onBoxActivated(obj, data)
            % return if no active image
            img = obj.Project.ActiveImage; if isempty(img), return; end
            % get region id from box id
            regionID = data.ID;
            % if region exists in active image
            if img.hasRegion(regionID)
                % set it as the active region
                img.setActiveRegion(regionID);
            else
                % set active region to empty
                img.setActiveRegion(string.empty(1,0));
            end
        end

        function onBoxSelectionChanged(obj, data)
            if obj.IsSyncingSelection
                return
            end

            ids = string(data.IDs);
            img = obj.Project.ActiveImage;
            if isempty(img), return; end

            obj.IsSyncingSelection = true;



            if isempty(ids)
                obj.RegionListBox.Value = {};
                img.clearRegionSelection();
                img.setActiveRegion("");
            else
                obj.RegionListBox.Value = ids;        % multi-select
                img.setRegionSelection(ids);
                %img.setActiveRegion(ids(end));        % last in selection is active
            end

            obj.IsSyncingSelection = false;
        end

    end

    %% Event handlers for DrawRectangle tool callbacks
    methods (Access=private)

        function onROIPreviewMoved(obj,data)
            obj.onROIMoveCommitted(data);
        end

        function onROIMoveCommitted(obj,data)
            % get the ActiveImage, exit if empty
            img = obj.Project.ActiveImage; if isempty(img), return; end
            % get the ActiveRegion, exit if empty
            reg = img.ActiveRegion; if isempty(reg), return; end
            % update region linescan properties
            reg.updateLinescan(data);
            % process the linescan for this region
            img.processRegionLinescan(reg,app.config.RunConfig.fromSettings(obj.Settings));
            % update the region linescan plot
            obj.refreshRegionLinescanPlot();
            % update RegionSummaryTable
            obj.RegionSummaryTable.Data = reg.SummaryTable;
        end

        function onROIDeleted(obj)
            % exit if project empty
            if isempty(obj.Project), return; end
            % get the ActiveImage, exit if empty
            img = obj.Project.ActiveImage; if isempty(img), return; end
            % get the ActiveRegion, exit if empty
            reg = img.ActiveRegion; if isempty(reg), return; end
            % reset linescan ROI for the active region (also resets linescan results)
            img.resetRegionLinescan(reg);
            % update linescan
            obj.refreshRegionLinescanROI();
            obj.refreshRegionLinescanPlot();
            % update RegionSummaryTable
            obj.RegionSummaryTable.Data = reg.SummaryTable;
        end

    end

    %% Export data
    methods

        function onExportMeasurements(app, ~, ~)

            app.Fig.Visible = 'off';

            defaultName = fullfile(app.Settings.IO.DefaultFolder, 'region_measurements.xlsx');
            [file, path] = uiputfile('*.xlsx', ...
                'Export region measurements', defaultName);

            app.Fig.Visible = 'on';

            if isequal(file,0)
                return;  % user cancelled
            end

            fname = fullfile(path, file);
            app.Project.exportRegionTableToXlsx(fname);
        end

        function onExportPeakPlots(app, ~, ~)

            app.Fig.Visible = 'off';

            defaultName = fullfile(app.Settings.IO.DefaultFolder, 'peak_plots.pdf');
            [file, path] = uiputfile('*.pdf', ...
                'Export peak plots', defaultName);

            app.Fig.Visible = 'on';

            if isequal(file,0)
                return;  % user cancelled
            end

            outputFile = fullfile(path,file);

            fNames = {};

            f = uifigure("WindowStyle","normal",...
                "Visible","on",...
                "Position",[0 0 1065 400]);

            movegui(f,'center')

            g = uigridlayout(f,[2,2],...
                "RowHeight",{250,140},...
                "RowSpacing",5,...
                "ColumnWidth",{800,250},...
                "ColumnSpacing",5,...
                "Padding",[5 5 5 5],...
                "BackgroundColor",[1 1 1]);

            p = widgets.PeaksPlotContainer(g,...
                "RawLineWidth",app.Settings.PeaksPlot.RawLineWidth, ...
                "RawLineColor",app.Settings.PeaksPlot.RawLineColor, ...
                "SmoothLineWidth",app.Settings.PeaksPlot.SmoothLineWidth, ...
                "SmoothLineColor",app.Settings.PeaksPlot.SmoothLineColor, ...
                "BackgroundColor",app.Settings.PeaksPlot.BackgroundColor, ...
                "ForegroundColor",app.Settings.PeaksPlot.ForegroundColor, ...
                "XLabel",sprintf("Distance (%s)",app.Settings.Analysis.PixelSizeUnit), ...
                "YLabel","Normalized Intensity",...
                "FontSize",10);
            p.Layout.Row = [1 2];
            p.Layout.Column = 1;

            % ImageAxes to show region CData and ROI position
            ax = matlabx.ui.widgets.ImageAxes(g,...
                'Name','RegionViewer',...
                'ToolBox',{'DrawRectangle'},...
                'ToolBelt',{'DrawRectangle'},...
                'Colormap',app.Settings.Display.Colormap,...
                'CLim',[0 1],...
                'CData',[]);
            ax.Layout.Row = 1;
            ax.Layout.Column = 2;
            % set options for RegionViewer DrawRectangle tool
            ax.Tools.DrawRectangle.RotationAngleMode = 'half-circle';
            % enable the DrawRectangle tool
            ax.Tools.DrawRectangle.enable();
            % set the FontSize on the DrawRectangle tool
            ax.Tools.DrawRectangle.FontSize = 10;

            % uilabel to show region measurements
            l = uilabel(g,...
                "Text",'',...
                "BackgroundColor",[1 1 1],...
                "FontColor",[0 0 0],...
                "HorizontalAlignment","left",...
                "VerticalAlignment","top",...
                "FontName","courier",...
                "FontSize",10);
            l.Layout.Column = 2;
            l.Layout.Row = 2;

            % hide the figure after adding all components
            f.Visible = 'off';

            % create progress dialog
            h = uiprogressdlg(app.Fig,"Message",'Exporting peak plots. Please wait...','Indeterminate','on');

            imgs = app.Project.ImageArray;

            if isempty(imgs)
                return
            end

            for i = 1:numel(imgs)
                regs = imgs(i).RegionArray;

                if isempty(regs)
                    continue
                end

                for j = 1:numel(regs)

                    % update region linescan plot and title
                    p.Data = regs(j).LinescanResults;
                    p.Title = matlabx.utils.text.texFriendly(imgs(i).Name) + " | " + regs(j).Name;

                    % update region CData and CLim
                    ax.CData = imgs(i).regionSubimage(regs(j));

                    % get CLim
                    switch app.Settings.Display.AutoScaleDisplayIntensity
                        case true
                            ax.CLim = imgs(i).AutoDisplayCLim;
                        case false
                            ax.CLim = imgs(i).DisplayCLim;
                    end

                    % update linescan ROI position
                    ax.Tools.DrawRectangle.setROIPosition(regs(j).Linescan);

                    % update uilabel Text
                    l.Text = regs(j).TextSummaryTable;

                    % create a temporary unique name for each PDF
                    tempName = fullfile(path,[matlabx.utils.text.uniqueID("char"),'.pdf']);

                    drawnow
                    if i==1 && j==1
                        pause(1)
                    else
                        pause(0.1)
                    end


                    % export the figure content to PDF
                    exportapp(f,tempName);

                    % store the temporary name so we can merge the PDFs at the end
                    fNames{end+1} = tempName;

                end

            end

            delete(f); % delete the figure

            % merge the PDFs
            memSet = org.apache.pdfbox.io.MemoryUsageSetting.setupMainMemoryOnly();
            merger = org.apache.pdfbox.multipdf.PDFMergerUtility;
            cellfun(@(fN) merger.addSource(fN), fNames)
            merger.setDestinationFileName(outputFile)
            merger.mergeDocuments(memSet)

            % delete the temporary PDFs
            cellfun(@(fN) delete(fN),fNames);

            % close the progress dialog
            close(h);

        end

        function onExportRegionImages(obj, ~, ~)

            obj.Fig.Visible = 'off';

            folderName = uigetdir(obj.Settings.IO.DefaultFolder, 'Export region images');

            obj.Fig.Visible = 'on';

            % invalid folder -> return
            if ~isfolder(folderName)
                return
            end

            % export region images to folderName
            obj.Project.exportRegionImages(folderName);

        end

    end

    %% Static helpers
    methods (Static)

        function h = findGUI()
            % locate and return handle to GUI figure window
            h = findobj(groot,'Tag',app.Info.Name);
            % more than one found -> return first
            if numel(h) > 1, h = h(1); end
        end

    end

end
