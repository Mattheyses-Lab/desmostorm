classdef GUI < handle
%GUI  Controller for DesmoSTORM GUI

    %% Private properties

    % UI components
    properties (Access=private, Transient, NonCopyable)
        % --- window and main grids ---
        Fig matlab.ui.Figure
        Grid matlab.ui.container.GridLayout
        LeftPane matlab.ui.container.GridLayout
        RightPane matlab.ui.container.GridLayout
        RegionGrid matlab.ui.container.GridLayout

        % --- listbox/settings accordion ---
        SettingsAccordion matlabx.ui.container.Accordion

        % --- Log ---
        LogPanel matlab.ui.container.Panel
        LogGrid matlab.ui.container.GridLayout
        LogTextArea matlab.ui.control.TextArea

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
        ImageViewer matlabx.ui.axes.ImageAxes
        % RegionViewer
        RegionViewerPanel matlab.ui.container.Panel
        RegionViewerPanelGrid matlab.ui.container.GridLayout
        RegionViewer matlabx.ui.axes.ImageAxes

        % --- region table ---
        RegionSummaryPanel matlab.ui.container.Panel
        RegionSummaryPanelGrid matlab.ui.container.GridLayout
        RegionSummaryTable matlab.ui.control.Table

        % --- linescan plot ---
        RegionLinescanPanel matlab.ui.container.Panel
        RegionLinescanPanelGrid matlab.ui.container.GridLayout
        RegionLinescanPlot desmostorm.widgets.PeaksPlotContainer % custom plot

        % --- Settings-related UI ---
        ExampleColormapPanel matlab.ui.container.Panel
        ExampleColormapAxes matlab.ui.control.UIAxes
        ExampleColormapImage matlab.graphics.primitive.Image
        ColormapTree matlab.ui.container.Tree
        IntensitySliders matlabx.ui.control.Slider
        ChannelColorLabels matlab.ui.control.Label
        ChannelColorDropDowns matlab.ui.control.DropDown
        LabelsTree matlab.ui.container.Tree
        
        % Extra graphics handles, stored as struct to reduce clutter
        MenubarUI struct
        SettingsUI struct
        LabelsUI struct
        ContextMenuUI struct

    end

    % listeners
    properties (Access=private)
        settingsL event.listener
        projectL event.listener
        axesL event.listener
    end

    % Derived UI components and values
    properties (Access=private,Dependent=true)
        RegionLinescanPlotAnnotations
        uipanelTopChromePx
    end

    % UI values
    properties (Access=private)
        SettingsW = 300;
        Padding = 5;
        RowSpacing = 5;
        ColumnSpacing = 5;
        LogH = 200;
        FontSize = 12;
    end

    % UI update/sync flags
    properties (Access=private)
        pendingSizeUpdate (1,1) logical = false
        isSyncingSelection (1,1) logical = false
        isSyncingColormapSelection (1,1) logical = false
        % isSyncingChannelDisplay (1,1) logical = false
    end

    % CommnadRouter, Calibration, Log
    properties (Access=private)
        CommandRouter matlabx.ui.interaction.CommandRouter
        UICal matlabx.ui.calibration.UICalibration
        Log matlabx.logging.Logger
    end

    %% Public properties (model and settings)

    properties
        Project desmostorm.model.STORMProject
        Settings desmostorm.config.Settings
    end

    %% Constructor/destructor/setup helpers
    methods

        function obj = GUI()

            % Only one app window should own the current interactive session.
            existingFig = desmostorm.app.focusMainFigure();
            if ~isempty(existingFig)
                error('desmostorm:app:GUI:AlreadyOpen', ...
                    'DesmoSTORM is already open.');
            end

            % --- Log ---
            [obj.Log, logPath] = desmostorm.Log.startGUISession();

            desmostorm.Log.INFO("Starting DesmoSTORM...");
            desmostorm.Log.DEBUG("Session log: " + logPath);

            % --- Settings ---
            desmostorm.Log.DEBUG("Loading settings...");
            try
                obj.Settings = desmostorm.config.Settings.load();
            catch ME
                desmostorm.Log.EXCEPTION(ME); rethrow(ME);
            end

            % --- UICalibration ---
            desmostorm.Log.DEBUG("Calibrating UI...");
            try obj.setupUICalibration(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % --- Build GUI ---
            desmostorm.Log.DEBUG("Building GUI...");
            try obj.buildGUI(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % --- Initial UI sync ---
            desmostorm.Log.DEBUG("Refreshing UI...");
            try obj.refreshUI(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % --- Show figure ---
            desmostorm.Log.DEBUG("Opening GUI figure...");
            obj.Fig.Visible = 'on';

            % --- Set UI sink for logger ---

            obj.Log.setUISink(@(lines) obj.onLogFlush(lines));



        end

        function setupUICalibration(obj)
            obj.UICal = matlabx.UICal.get();
        end

        function buildGUI(obj)
            % --- Figure ---
            desmostorm.Log.DEBUG("Setting up main figure window...");
            try obj.setupFigure(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % --- CommandRouter ---
            desmostorm.Log.DEBUG("Setting up CommandRouter...");
            try obj.setupCommandRouter(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % --- Menubar ---
            desmostorm.Log.DEBUG("Setting up Menubar...");
            try obj.setupMenubar(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % --- Grids ---
            desmostorm.Log.DEBUG("Setting up main grid layout managers...");
            try obj.setupGrids(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % --- Settings controllers ---
            desmostorm.Log.DEBUG("Setting up settings controllers...");
            try obj.setupSettingsControllers(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % --- Log window ---
            desmostorm.Log.DEBUG("Setting up log window...");
            try obj.setupLogWindow(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % --- ImageViewer ---
            desmostorm.Log.DEBUG("Setting up ImageViewer...");
            try obj.setupImageViewer(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % --- RegionViewer ---
            desmostorm.Log.DEBUG("Setting up RegionViewer...");
            try obj.setupRegionViewer(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % --- RegionSummaryTable ---
            desmostorm.Log.DEBUG("Setting up RegionSummaryTable...");
            try obj.setupRegionSummaryTable(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % --- RegionLinescanPlot ---
            desmostorm.Log.DEBUG("Setting up RegionLinescanPlot...");
            try obj.setupRegionLinescanPlot(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % center the GUI after defining all graphics components
            movegui(obj.Fig,"center");
        end

        function setupFigure(obj)
            % get screen size for fig OuterPosition
            s = matlabx.UICal.screenSize();
            obj.Fig = uifigure(...
                'WindowStyle','normal',...
                'Tag',desmostorm.Info.Name,...
                'Name','DesmoSTORM',...
                'Color',[0 0 0],...
                'OuterPosition',s(1,:),...
                'Visible','off',...
                'Theme','dark',...
                'HandleVisibility','on',...
                'AutoResizeChildren','off',...
                'SizeChangedFcn',@(~,~) obj.refreshComponentSizes(),...
                'CloseRequestFcn',@(~,~) obj.onCloseRequest());
        end

        function setupCommandRouter(obj)
            obj.CommandRouter = matlabx.ui.interaction.CommandRouter('Parent',obj.Fig);
        end

        function setupMenubar(obj)
            % Set up MenubarUI struct
            obj.MenubarUI = struct(...
                "File",struct(),...
                "Run",struct());

            % --- File ---
            obj.MenubarUI.File       = uimenu(obj.Fig,'Text','File');
            obj.MenubarUI.File_New   = uimenu(obj.MenubarUI.File,'Text','New',  'MenuSelectedFcn',@(~,~) obj.onNew(),'Accelerator','N');
            obj.MenubarUI.File_Open  = uimenu(obj.MenubarUI.File,'Text','Open...', 'MenuSelectedFcn',@(~,~) obj.onOpen(),'Accelerator','O');
            obj.MenubarUI.File_Close = uimenu(obj.MenubarUI.File,'Text','Close','MenuSelectedFcn',@(~,~) obj.onClose(),'Accelerator','X');
            obj.MenubarUI.File_Save  = uimenu(obj.MenubarUI.File,'Text','Save...', 'MenuSelectedFcn',@(~,~) obj.onSave(),'Separator','on','Accelerator','S');
            % --- separator ---
            obj.MenubarUI.File_SaveSettings = uimenu(obj.MenubarUI.File,'Text','Save Settings','MenuSelectedFcn',@(~,~) obj.onSaveSettings(),'Separator','on');
            % --- separator ---
            obj.MenubarUI.File_LoadImages = uimenu(obj.MenubarUI.File,'Text','Load Images...','MenuSelectedFcn',@(~,~) obj.onLoadImages(),'Accelerator','L');
            % --- File -> Export ---
            obj.MenubarUI.File_Export = uimenu(obj.MenubarUI.File,'Text','Export');
            obj.MenubarUI.File_Export_Measurements = uimenu(obj.MenubarUI.File_Export,'Text','Measurements (.xlsx)', 'MenuSelectedFcn',@(~,~) obj.onExportMeasurements());
            obj.MenubarUI.File_Export_SumaryPDF    = uimenu(obj.MenubarUI.File_Export,'Text','Summary PDF',          'MenuSelectedFcn',@(~,~) obj.onExportSummaryPDF());
            obj.MenubarUI.File_Export_RegionImages = uimenu(obj.MenubarUI.File_Export,'Text','Region Images (.tif)', 'MenuSelectedFcn',@(~,~) obj.onExportRegionImages());
            obj.MenubarUI.File_Export_ImagesWithRegionBoxes = uimenu(obj.MenubarUI.File_Export, ...
                'Text','Image + Region Boxes...', ...
                'MenuSelectedFcn',@(~,~) obj.onExportImagesWithRegionBoxes());

            obj.MenubarUI.File_Export_LinescanPlot = uimenu(obj.MenubarUI.File_Export, ...
                'Text','Linescan Plot...', ...
                'MenuSelectedFcn',@(~,~) obj.onExportLinescanPlot());
            obj.MenubarUI.File_Export_RegionSubimageWithROI = uimenu(obj.MenubarUI.File_Export, ...
                'Text','Region Image + ROI...', ...
                'MenuSelectedFcn',@(~,~) obj.onExportRegionSubimageWithROI());

            % --- Run ---
            obj.MenubarUI.Run = uimenu(obj.Fig,'Text','Run');

            obj.MenubarUI.Run_Classifier = uimenu(obj.MenubarUI.Run,'Text','Run classifier...','MenuSelectedFcn',@(~,~) obj.onRunClassifier());
            obj.MenubarUI.Run_TrainNewClassifier = uimenu(obj.MenubarUI.Run,'Text','Train New Classifier...','MenuSelectedFcn',@(~,~) obj.onTrainNewClassifier());
            obj.MenubarUI.Run_ContinueTrainingClassifier = uimenu(obj.MenubarUI.Run,'Text','Continue Training Existing Classifier...','MenuSelectedFcn',@(~,~) obj.onContinueTrainingClassifier());
            obj.MenubarUI.Run_RetrainClassifierFromScratch = uimenu(obj.MenubarUI.Run,'Text','Retrain Existing Classifier From Scratch...','MenuSelectedFcn',@(~,~) obj.onRetrainClassifierFromScratch());

            obj.MenubarUI.Run_AutoFitROIs       = uimenu(obj.MenubarUI.Run,'Text','Auto-Fit Region ROIs (experimental)...');
            obj.MenubarUI.Run_AutoFitAllROIs    = uimenu(obj.MenubarUI.Run_AutoFitROIs,'Text','All Regions','MenuSelectedFcn',@(~,~) obj.onAutoFitAllROIs());
            obj.MenubarUI.Run_AutoFitActiveROI  = uimenu(obj.MenubarUI.Run_AutoFitROIs,'Text','Active Region Only','MenuSelectedFcn',@(~,~) obj.onAutoFitActiveROI(),'Accelerator','A');

            % --- Test ---
            obj.MenubarUI.Test = uimenu(obj.Fig,'Text','Test');
            obj.MenubarUI.Test_Image = uimenu(obj.MenubarUI.Test,'Text','Image');
            obj.MenubarUI.Test_Image_TuneClusters = uimenu(obj.MenubarUI.Test_Image, ...
                'Text','Tune Cluster Parameters', ...
                'MenuSelectedFcn',@(~,~) obj.onTuneImageClusterParameters());
            obj.MenubarUI.Test_Region = uimenu(obj.MenubarUI.Test,'Text','Region');
            obj.MenubarUI.Test_Region_TuneClusters = uimenu(obj.MenubarUI.Test_Region, ...
                'Text','Tune Cluster Parameters', ...
                'MenuSelectedFcn',@(~,~) obj.onTuneRegionClusterParameters());
        end 

        function setupGrids(obj)
            % % Main Grid
            obj.Grid = uigridlayout(obj.Fig,[1 2], ...
                'ColumnWidth',{'fit','1x'}, ...
                'RowHeight',{'1x'}, ...
                'ColumnSpacing',5, ...
                'RowSpacing',0, ...
                'Padding',[5 5 5 5],...
                'BackgroundColor',[0.12 0.12 0.12]);
            % Left Pane Grid (ListBoxes and settings)
            obj.LeftPane = uigridlayout(obj.Grid,[1 1],...
                "RowHeight",{'fit'},...
                "ColumnWidth",300,...
                "Padding",[0 0 0 0],...
                "BackgroundColor",[.12 .12 .12],...
                "Scrollable","on");
            obj.LeftPane.Layout.Row = 1;
            obj.LeftPane.Layout.Column = 1;
            % Right Pane Grid (Viewers, Plots, Summaries, Log)
            obj.RightPane = uigridlayout(obj.Grid,[2 2],...
                "RowHeight",{'fit','1x'},...
                "RowSpacing",5,...
                "ColumnWidth",{'fit','1x'},...
                "ColumnSpacing",5,...
                "Padding",[0 0 0 0],...
                "BackgroundColor",[.12 .12 .12],...
                "Scrollable","off");
            obj.RightPane.Layout.Row = 1;
            obj.RightPane.Layout.Column = 2;
        end

        function setupSettingsControllers(obj)
            % create the accordion and parent it to the grid
            obj.SettingsAccordion = matlabx.ui.container.Accordion(obj.LeftPane,...
                'ItemSpacing',5,...
                'BorderWidth',0,...
                'BorderColor',[.18 .18 .18],...
                'Padding',0,...
                'BackgroundColor',[.12 .12 .12]);

            % initialize items
            itemTitles = ["Images","Regions","Analysis","Channel Display","Colormap","Image Display","Peaks Plot","Linescan ROI","Labels"];

            for i = 1:numel(itemTitles)
                obj.SettingsAccordion.addItem("Title",itemTitles(i),...
                    "BorderColor",[0.49 0.49 0.49],...
                    "TitleBackgroundColor",[.12 .12 .12],...
                    "HoverTitleBackgroundColor",[.3 .3 .3],...
                    "PaneBackgroundColor",[.18 .18 .18],...
                    "FontColor",[0.85 0.85 0.85],...
                    "BorderWidth",1,...
                    "ExpandedBorderWidth",1,...
                    "TitlePadding",1);
            end

            % --- Images ---
            desmostorm.Log.DEBUG("Setting up Images listbox...");
            try obj.setupImagesListBox(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % --- Regions ---
            desmostorm.Log.DEBUG("Setting up Regions listbox...");
            try obj.setupRegionsListBox(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % Set up SettingsUI struct
            obj.SettingsUI = struct(...
                "Display",struct(),...
                "ChannelDisplay",struct(),...
                "Analysis",struct(),...
                "PeaksPlot",struct(),...
                "ROI",struct(),...
                "Box",struct());

            % --- Colormap ---
            desmostorm.Log.DEBUG("Setting up Colormap controls...");
            try obj.setupColormapControls(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % --- Channel Display ---
            desmostorm.Log.DEBUG("Setting up Channel Display controls...");
            try obj.setupChannelDisplayControls(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % --- Analysis ---
            desmostorm.Log.DEBUG("Setting up Analysis controls...");
            try obj.setupAnalysisControls(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % --- Image Display ---
            desmostorm.Log.DEBUG("Setting up Image Display controls...");
            try obj.setupImageDisplayControls(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % --- Peaks Plot ---
            desmostorm.Log.DEBUG("Setting up Peaks Plot controls...");
            try obj.setupPeaksPlotControls(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % --- Linescan ROI ---
            desmostorm.Log.DEBUG("Setting up Linescan ROI controls...");
            try obj.setupROIControls(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % --- Labels ---
            desmostorm.Log.DEBUG("Setting up Labels controls...");
            try obj.setupLabelsControls(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % Expand Images and Regions listbox accordion items
            obj.SettingsAccordion.getItem("Images").expand();
            obj.SettingsAccordion.getItem("Regions").expand();
        end

        function setupImagesListBox(obj)
            item = obj.SettingsAccordion.getItem("Images");
            set(item.Pane,...
                "RowHeight",{200},...
                "ColumnWidth",{'1x'},...
                "Padding",[0 0 0 0]);
            % Image selection listbox
            obj.ImageListBox = uilistbox(item.Pane, ...
                'Items',string.empty(1,0),...
                'ItemsData',string.empty(1,0),...
                'Value',string.empty(1,0),...
                'ValueChangedFcn',@(lb,~) obj.onImageListBoxValueChanged(lb.Value),...
                'BackgroundColor',[.18 .18 .18],...
                'FontColor',[.9 .9 .9]);
        end

        function setupRegionsListBox(obj)
            % set size and spacing of pane grid
            item = obj.SettingsAccordion.getItem("Regions");
            set(item.Pane,...
                "RowHeight",{200},...
                "ColumnWidth",{'1x'},...
                "Padding",[0 0 0 0]);
            % Region selection listbox
            obj.RegionListBox = uilistbox(item.Pane, ...
                'Items',string.empty(1,0),...
                'ItemsData',string.empty(1,0),...
                'Value',string.empty(1,0),...
                'ValueChangedFcn',@(lb,evt) obj.onRegionListBoxValueChanged(lb,evt),...
                'BackgroundColor',[.18 .18 .18],...
                'FontColor',[.9 .9 .9]);
        end

        function setupColormapControls(obj)
            item = obj.SettingsAccordion.getItem("Colormap");
            % set size and spacing of pane grid
            set(item.Pane,"RowHeight",{30,'1x'},...
                "ColumnWidth",{'1x'},...
                "RowSpacing",5,...
                "ColumnSpacing",5);

            % panel to hold example colormap axes
            obj.ExampleColormapPanel = uipanel(item.Pane);
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
                "Parent",item.Pane,...
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
        end

        function setupChannelDisplayControls(obj)
            item = obj.SettingsAccordion.getItem("Channel Display");
            set(item.Pane,...
                "RowHeight",{'fit'},...
                "ColumnWidth",{'fit','1x'},...
                "RowSpacing",5,...
                "ColumnSpacing",5);

            uilabel(item.Pane,...
                "Text","Color mode",...
                "FontColor",[0.85 0.85 0.85]);

            % obj.SettingsUI.ChannelDisplay.ColorModeDropDown = uidropdown(item.Pane,...
            %     "Items",["colors","luts"],...
            %     "Value",obj.Settings.Display.ChannelColorMode,...
            %     "ValueChangedFcn",@(o,~) obj.ChannelColorModeChanged(o));


            obj.SettingsUI.ChannelDisplay.ColorModeDropDown = uidropdown(item.Pane,...
                "Items",["colors","luts"],...
                "Value",obj.Settings.Display.ChannelColorMode,...
                "ValueChangedFcn",@(o,~) obj.DisplaySettingsChanged(o,"ChannelColorMode"));

            obj.SettingsUI.ChannelDisplay.ColorModeDropDown.Layout.Row = 1;
            obj.SettingsUI.ChannelDisplay.ColorModeDropDown.Layout.Column = 2;

            obj.syncChannelColorControlCount();
            obj.updateChannelColorControlRows(0);
        end

        function setupAnalysisControls(obj)
            item = obj.SettingsAccordion.getItem("Analysis");
            % set size and spacing of pane grid
            set(item.Pane,...
                "RowHeight",repmat({'fit'},1,4),...
                "ColumnWidth",{'fit','1x'},...
                "RowSpacing",5,...
                "ColumnSpacing",5);

            uilabel(item.Pane,"Text","Box Size","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.Analysis.BoxSizeEditField = uieditfield(...
                item.Pane,...
                "numeric",...
                "ValueChangedFcn",@(o,~) obj.AnalysisSettingsChanged(o,"BoxSize"),...
                "Value",obj.Settings.Analysis.BoxSize);

            uilabel(item.Pane,"Text","Normalize Linescan","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.Analysis.NormalizeDropDown = uidropdown(...
                item.Pane,...
                "Items",{'true', 'false'}, ...
                "ItemsData",{true, false}, ...
                "ValueChangedFcn",@(o,~) obj.AnalysisSettingsChanged(o,"Normalize"),...
                "Value",obj.Settings.Analysis.Normalize);

            uilabel(item.Pane,"Text","Minimum Peak Distance","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.Analysis.MinPeakDistanceEditField = uieditfield(...
                item.Pane,...
                "numeric",...
                "ValueChangedFcn",@(o,~) obj.AnalysisSettingsChanged(o,"MinPeakDistance"),...
                "Value",obj.Settings.Analysis.MinPeakDistance);

            uilabel(item.Pane,"Text","Minimum Peak Height","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.Analysis.MinPeakHeightEditField = uieditfield(...
                item.Pane,...
                "numeric",...
                "ValueChangedFcn",@(o,~) obj.AnalysisSettingsChanged(o,"MinPeakHeight"),...
                "Value",obj.Settings.Analysis.MinPeakHeight);

            uilabel(item.Pane,"Text","Minimum Peak Prominence","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.Analysis.MinPeakProminenceEditField = uieditfield(...
                item.Pane,...
                "numeric",...
                "ValueChangedFcn",@(o,~) obj.AnalysisSettingsChanged(o,"MinPeakProminence"),...
                "Value",obj.Settings.Analysis.MinPeakProminence);

            uilabel(item.Pane,"Text","Peak Smoothing","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.Analysis.PeakSmoothingEditField = uieditfield(...
                item.Pane,...
                "numeric",...
                "ValueChangedFcn",@(o,~) obj.AnalysisSettingsChanged(o,"PeakSmoothing"),...
                "Value",obj.Settings.Analysis.PeakSmoothing);

            uilabel(item.Pane,"Text","Pixel Size Value","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.Analysis.PixelSizeValueEditField = uieditfield(...
                item.Pane,...
                "numeric",...
                "ValueChangedFcn",@(o,~) obj.AnalysisSettingsChanged(o,"PixelSizeValue"),...
                "Value",obj.Settings.Analysis.PixelSizeValue);

            uilabel(item.Pane,"Text","Pixel Size Unit","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.Analysis.PixelSizeUnitDropDown = uidropdown(...
                item.Pane,...
                "Items",{'px', 'nm', 'µm'}, ...
                "ValueChangedFcn",@(o,~) obj.AnalysisSettingsChanged(o,"PixelSizeUnit"),...
                "Value",obj.Settings.Analysis.PixelSizeUnit);
        end

        function setupImageDisplayControls(obj)
            item = obj.SettingsAccordion.getItem("Image Display");
            % set size and spacing of pane grid
            set(item.Pane,...
                "RowHeight",{'fit','fit'},...
                "ColumnWidth",{'1x'},...
                "RowSpacing",5,...
                "ColumnSpacing",5);

            obj.SettingsUI.Display.AutoScaleDisplayIntensityCheckBox = uicheckbox(item.Pane,...
                "Value",obj.Settings.Display.AutoScaleDisplayIntensity,...
                "ValueChangedFcn",@(o,~) obj.DisplaySettingsChanged(o,"AutoScaleDisplayIntensity"),...
                "Text","Auto-scale display intensity");

            % --- IntensitySliders ---
            desmostorm.Log.DEBUG("Setting up IntensitySliders...");
            try obj.setupIntensitySliders(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end
        end

        function setupIntensitySliders(obj)
            obj.syncIntensitySliderCount();
            obj.updateIntensitySliderRows(1);
        end

        function setupPeaksPlotControls(obj)
            item = obj.SettingsAccordion.getItem("Peaks Plot");
            % set size and spacing of pane grid
            set(item.Pane,...
                "RowHeight",repmat({'fit'},1,13),...
                "ColumnWidth",{'fit','1x'},...
                "RowSpacing",5,...
                "ColumnSpacing",5);

            uilabel(item.Pane,"Text","Shown Plots","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.PeaksPlot.ShownPlotsDropDown = uidropdown(...
                item.Pane,...
                "Items",{'all','current'},...
                "Value",char(obj.Settings.PeaksPlot.ShownPlots),...
                "ValueChangedFcn",@(o,~) obj.PeaksPlotSettingsChanged(o,"ShownPlots"));

            uilabel(item.Pane,"Text","Color Source","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.PeaksPlot.ColorSourceDropDown = uidropdown(...
                item.Pane,...
                "Items",{'channel','manual'},...
                "Value",char(obj.Settings.PeaksPlot.ColorSource),...
                "ValueChangedFcn",@(o,~) obj.PeaksPlotSettingsChanged(o,"ColorSource"));

            uilabel(item.Pane,"Text","Plot Color","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.PeaksPlot.ColorPicker = uicolorpicker(...
                'Parent',item.Pane,...
                'Value',obj.Settings.PeaksPlot.Color,...
                'ValueChangedFcn',@(o,~) obj.PeaksPlotSettingsChanged(o,"Color"));

            uilabel(item.Pane,"Text","Annotation Color Mode","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.PeaksPlot.AnnotationColorModeDropDown = uidropdown(...
                item.Pane,...
                "Items",{'auto','manual'},...
                "Value",char(obj.Settings.PeaksPlot.AnnotationColorMode),...
                "ValueChangedFcn",@(o,~) obj.PeaksPlotSettingsChanged(o,"AnnotationColorMode"));

            uilabel(item.Pane,"Text","Annotation Color","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.PeaksPlot.AnnotationColorPicker = uicolorpicker(...
                'Parent',item.Pane,...
                'Value',obj.Settings.PeaksPlot.AnnotationColor,...
                'ValueChangedFcn',@(o,~) obj.PeaksPlotSettingsChanged(o,"AnnotationColor"));

            uilabel(item.Pane,"Text","Background Color","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.PeaksPlot.BackgroundColorPicker = uicolorpicker(...
                'Parent',item.Pane,...
                'Value',obj.Settings.PeaksPlot.BackgroundColor,...
                'ValueChangedFcn',@(o,~) obj.PeaksPlotSettingsChanged(o,"BackgroundColor"));

            uilabel(item.Pane,"Text","Foreground Color","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.PeaksPlot.ForegroundColorPicker = uicolorpicker(...
                'Parent',item.Pane,...
                'Value',obj.Settings.PeaksPlot.ForegroundColor,...
                'ValueChangedFcn',@(o,~) obj.PeaksPlotSettingsChanged(o,"ForegroundColor"));

            uilabel(item.Pane,"Text","Raw Line Width","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.PeaksPlot.RawLineWidthEditField = uieditfield(...
                item.Pane,...
                "numeric",...
                "ValueChangedFcn",@(o,~) obj.PeaksPlotSettingsChanged(o,"RawLineWidth"),...
                "Value",obj.Settings.PeaksPlot.RawLineWidth);

            uilabel(item.Pane,"Text","Smooth Line Width","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.PeaksPlot.SmoothLineWidthEditField = uieditfield(...
                item.Pane,...
                "numeric",...
                "ValueChangedFcn",@(o,~) obj.PeaksPlotSettingsChanged(o,"SmoothLineWidth"),...
                "Value",obj.Settings.PeaksPlot.SmoothLineWidth);

            uilabel(item.Pane,"Text","Distance Labels","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.PeaksPlot.DistanceAnnotationsDropDown = uidropdown(...
                item.Pane,...
                "Items",{'on','off'},...
                "Value",char(obj.Settings.PeaksPlot.DistanceAnnotations),...
                "ValueChangedFcn",@(o,~) obj.PeaksPlotSettingsChanged(o,"DistanceAnnotations"));

            uilabel(item.Pane,"Text","Distance Mode","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.PeaksPlot.DistanceAnnotationsModeDropDown = uidropdown(...
                item.Pane,...
                "Items",{'lanes','data'},...
                "Value",char(obj.Settings.PeaksPlot.DistanceAnnotationsMode),...
                "ValueChangedFcn",@(o,~) obj.PeaksPlotSettingsChanged(o,"DistanceAnnotationsMode"));

            uilabel(item.Pane,"Text","Width Labels","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.PeaksPlot.WidthAnnotationsDropDown = uidropdown(...
                item.Pane,...
                "Items",{'on','off'},...
                "Value",char(obj.Settings.PeaksPlot.WidthAnnotations),...
                "ValueChangedFcn",@(o,~) obj.PeaksPlotSettingsChanged(o,"WidthAnnotations"));

            uilabel(item.Pane,"Text","Width Mode","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.PeaksPlot.WidthAnnotationsModeDropDown = uidropdown(...
                item.Pane,...
                "Items",{'hover','normal'},...
                "Value",char(obj.Settings.PeaksPlot.WidthAnnotationsMode),...
                "ValueChangedFcn",@(o,~) obj.PeaksPlotSettingsChanged(o,"WidthAnnotationsMode"));
        end

        function setupROIControls(obj)
            item = obj.SettingsAccordion.getItem("Linescan ROI");
            set(item.Pane,...
                "RowHeight",repmat({'fit'},1,10),...
                "ColumnWidth",{'fit','1x'},...
                "RowSpacing",5,...
                "ColumnSpacing",5);

            uilabel(item.Pane,"Text","ROI Color","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.ROI.ROIColorPicker = uicolorpicker(...
                'Parent',item.Pane,...
                'Value',obj.Settings.ROI.ROIColor,...
                'ValueChangedFcn',@(o,~) obj.ROISettingsChanged(o,"ROIColor"));

            uilabel(item.Pane,"Text","ROI Line Width","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.ROI.ROILineWidthEditField = uieditfield(...
                item.Pane,...
                "numeric",...
                "Value",obj.Settings.ROI.ROILineWidth,...
                "ValueChangedFcn",@(o,~) obj.ROISettingsChanged(o,"ROILineWidth"));

            uilabel(item.Pane,"Text","ROI Opacity","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.ROI.ROIFaceAlphaEditField = uieditfield(...
                item.Pane,...
                "numeric",...
                "Limits",[0 1],...
                "Value",obj.Settings.ROI.ROIFaceAlpha,...
                "ValueChangedFcn",@(o,~) obj.ROISettingsChanged(o,"ROIFaceAlpha"));

            uilabel(item.Pane,"Text","ROI Marker Size","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.ROI.ROIMarkerSizeEditField = uieditfield(...
                item.Pane,...
                "numeric",...
                "Value",obj.Settings.ROI.ROIMarkerSize,...
                "ValueChangedFcn",@(o,~) obj.ROISettingsChanged(o,"ROIMarkerSize"));

            uilabel(item.Pane,"Text","Annotation Color","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.ROI.AnnotationLineColorPicker = uicolorpicker(...
                'Parent',item.Pane,...
                'Value',obj.Settings.ROI.AnnotationLineColor,...
                'ValueChangedFcn',@(o,~) obj.ROISettingsChanged(o,"AnnotationLineColor"));

            uilabel(item.Pane,"Text","Annotation Line Width","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.ROI.AnnotationLineWidthEditField = uieditfield(...
                item.Pane,...
                "numeric",...
                "Value",obj.Settings.ROI.AnnotationLineWidth,...
                "ValueChangedFcn",@(o,~) obj.ROISettingsChanged(o,"AnnotationLineWidth"));

            uilabel(item.Pane,"Text","Angle Label","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.ROI.RotationAngleVisibleDropDown = uidropdown(...
                item.Pane,...
                "Items",{'on','off'},...
                "Value",char(obj.Settings.ROI.RotationAngleVisible),...
                "ValueChangedFcn",@(o,~) obj.ROISettingsChanged(o,"RotationAngleVisible"));

            uilabel(item.Pane,"Text","Angle Mode","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.ROI.RotationAngleModeDropDown = uidropdown(...
                item.Pane,...
                "Items",{'half-circle','full-circle'},...
                "Value",obj.Settings.ROI.RotationAngleMode,...
                "ValueChangedFcn",@(o,~) obj.ROISettingsChanged(o,"RotationAngleMode"));

            uilabel(item.Pane,"Text","Font Color","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.ROI.FontColorPicker = uicolorpicker(...
                'Parent',item.Pane,...
                'Value',obj.Settings.ROI.FontColor,...
                'ValueChangedFcn',@(o,~) obj.ROISettingsChanged(o,"FontColor"));

            uilabel(item.Pane,"Text","Font Size","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.ROI.FontSizeEditField = uieditfield(...
                item.Pane,...
                "numeric",...
                "Value",obj.Settings.ROI.FontSize,...
                "ValueChangedFcn",@(o,~) obj.ROISettingsChanged(o,"FontSize"));
        end

        function setupLabelsControls(obj)
            item = obj.SettingsAccordion.getItem("Labels");
            % set size and spacing of pane grid
            set(item.Pane,...
                "RowHeight",{'1x'},...
                "ColumnWidth",{'1x'},...
                "Padding",[0 0 0 0]);

            obj.LabelsTree = uitree(...
                "Parent",item.Pane,...
                "SelectionChangedFcn",@(~,e) obj.onSelectLabel(e));

            obj.ContextMenuUI = struct('LabelsTreeNodeContextMenu',[]);
        end

        function setupLogWindow(obj)
            % uipanel to hold the Log window
            obj.LogPanel = uipanel(obj.RightPane,'Title','Log','BackgroundColor',[0.12 0.12 0.12]);
            obj.LogPanel.Layout.Column = [1 2];
            obj.LogPanel.Layout.Row = 2;
            % grid to hold the text area
            obj.LogGrid = uigridlayout(obj.LogPanel,[1,1],...
                "ColumnWidth",{'1x'},...
                "RowHeight",{'1x'},...
                "Padding",[0 0 0 0]);
            % uitextarea to display log messages
            obj.LogTextArea = uitextarea(obj.LogGrid,"Value",{''});
        end

        function setupImageViewer(obj)
            % uipanel to hold the viewer
            obj.ImageViewerPanel = uipanel(obj.RightPane,...
                'Title','Image Viewer',...
                'BackgroundColor',[0.12 0.12 0.12]);

            obj.ImageViewerPanel.Layout.Column = 1;
            obj.ImageViewerPanel.Layout.Row = 1;

            obj.ImageViewerPanelGrid = uigridlayout(obj.ImageViewerPanel,[1 1],...
                "ColumnWidth",{500},...
                "RowHeight",{500},...
                "Padding",[0 0 0 0]);

            % ImageAxes to view active image CData, select Regions
            obj.ImageViewer = matlabx.ui.axes.ImageAxes(obj.ImageViewerPanelGrid,...
                'Name','ImageViewer',...
                'CData',[],...
                'Tools',{'Zoom','Box','Colorbar'},...
                'Colormap',obj.Settings.Display.Colormap,...
                'CLim',[0 1]);

            % wire the optimistic callbacks for ImageViewer Box tool
            obj.ImageViewer.Tools.Box.BoxCreatedFcn          = @(~,d) obj.onBoxCreated(d);
            obj.ImageViewer.Tools.Box.BoxMoveStartedFcn      = @(~,d) obj.onBoxMoveStarted(d);
            obj.ImageViewer.Tools.Box.BoxPreviewMovedFcn     = @(~,d) obj.onBoxPreviewMoved(d);
            obj.ImageViewer.Tools.Box.BoxMoveCommittedFcn    = @(~,d) obj.onBoxMoveCommitted(d);
            obj.ImageViewer.Tools.Box.BoxDeletedFcn          = @(~,d) obj.onBoxDeleted(d);
            obj.ImageViewer.Tools.Box.BoxActivatedFcn        = @(~,d) obj.onBoxActivated(d);
            obj.ImageViewer.Tools.Box.BoxSelectionChangedFcn = @(~,d) obj.onBoxSelectionChanged(d);

            obj.axesL(1) = addlistener(obj.ImageViewer,'C','PostSet',@(~,~) obj.onImageViewerChannelChanged());
            obj.axesL(2) = addlistener(obj.ImageViewer,'ComponentColorMode','PostSet',@(~,~) obj.onImageViewerChannelDisplayChanged());
            obj.axesL(3) = addlistener(obj.ImageViewer,'ComponentColors','PostSet',@(~,~) obj.onImageViewerChannelDisplayChanged());

            % set the box size for Box tool
            obj.ImageViewer.Tools.Box.BoxSize = obj.Settings.Analysis.BoxSize;

            %obj.ImageViewer.ImageVisible = 'off';
            %obj.ImageViewer.AxesVisible = 'on';
        end

        function setupRegionViewer(obj)
            % separate gridlayout object for the Region area
            obj.RegionGrid = uigridlayout(obj.RightPane,[2 2],...
                "ColumnWidth",{'fit','1x'},...
                "RowHeight",{'fit',400},...
                "Padding",[0 0 0 0],...
                "ColumnSpacing",5,...
                "RowSpacing",5);
            obj.RegionGrid.Layout.Column = 2;
            obj.RegionGrid.Layout.Row = 1;

            % uipanel to hold the RegionViewer
            obj.RegionViewerPanel = uipanel(obj.RegionGrid,...
                'Title','Region Viewer',...
                'BackgroundColor',[0.12 0.12 0.12]);
            obj.RegionViewerPanel.Layout.Column = 1;
            obj.RegionViewerPanel.Layout.Row = 1;

            obj.RegionViewerPanelGrid = uigridlayout(obj.RegionViewerPanel,[1 1],...
                "ColumnWidth",{250},...
                "RowHeight",{250},...
                "Padding",[0 0 0 0]);

            % ImageAxes to show active region CData, make region measurements
            obj.RegionViewer = matlabx.ui.axes.ImageAxes(obj.RegionViewerPanelGrid,...
                'Name','RegionViewer',...
                'CData',[],...
                'Tools',{'DrawRectangle'},...
                'Colormap',obj.Settings.Display.Colormap,...
                'CLim',[0 1]);

            % wire the callbacks for RegionViewer DrawRectangle tool
            obj.RegionViewer.Tools.DrawRectangle.ROIPreviewMovedFcn    = @(~,d) obj.onROIPreviewMoved(d);
            obj.RegionViewer.Tools.DrawRectangle.ROIMoveCommittedFcn   = @(~,d) obj.onROIMoveCommitted(d);
            obj.RegionViewer.Tools.DrawRectangle.ROIDeletedFcn         = @(~,~) obj.onROIDeleted();
            % apply saved appearance settings to the RegionViewer DrawRectangle tool
            obj.refreshROISettings();

            % keep ImageViewer and RegionViewer on the same active channel
            obj.ImageViewer.addLink(obj.RegionViewer, {'C', ...
                'ComponentCLims', ...
                'ComponentColorMode', ...
                'ComponentColormaps', ...
                'ComponentColors', ...
                'ShowComposite'});
        end

        function setupRegionSummaryTable(obj)
            obj.RegionSummaryPanel = uipanel(obj.RegionGrid,...
                'Title','Region Summary',...
                'BackgroundColor',[.12 .12 .12],...
                'Scrollable','on');
            obj.RegionSummaryPanel.Layout.Row = 1;
            obj.RegionSummaryPanel.Layout.Column = 2;

            obj.RegionSummaryPanelGrid = uigridlayout(obj.RegionSummaryPanel,[1,1],...
                "ColumnWidth",{'1x'},...
                "RowHeight",{'1x'},...
                "Padding",[0 0 0 0],...
                "Scrollable","on");

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
                "RowHeight",{'1x'},...
                "RowSpacing",0,...
                "ColumnWidth",{'1x'},...
                "Padding",[0 0 0 0]);

            obj.syncRegionLinescanPlotCount();
            obj.updateRegionLinescanPlotRows(0);

        end

        function delete(obj)
            % if ~isempty(obj.L), delete(obj.L(isvalid(obj.L))); end

            % delete the logger
            if ~isempty(obj.Log) && isvalid(obj.Log)
                try obj.Log.flush(); catch, end
                desmostorm.Log.clear();
                delete(obj.Log);
            else
                desmostorm.Log.clear();
            end


            if ~isempty(obj.projectL), delete(obj.projectL(isvalid(obj.projectL))); end
            if ~isempty(obj.settingsL), delete(obj.settingsL(isvalid(obj.settingsL))); end
            if ~isempty(obj.axesL), delete(obj.axesL(isvalid(obj.axesL))); end
            if ~isempty(obj.ImageViewer) && isvalid(obj.ImageViewer), delete(obj.ImageViewer); end
            if ~isempty(obj.RegionViewer) && isvalid(obj.RegionViewer), delete(obj.RegionViewer); end
            if ~isempty(obj.SettingsAccordion) && isvalid(obj.SettingsAccordion), delete(obj.SettingsAccordion); end
            if ~isempty(obj.Grid) && isvalid(obj.Grid), delete(obj.Grid); end
            if ~isempty(obj.Fig)  && isvalid(obj.Fig),  delete(obj.Fig);  end
        end

    end

    %% Derived getters
    methods

        function val = get.uipanelTopChromePx(obj)
            if isempty(obj.UICal)
                val = 19;
            else
                val = obj.UICal.uipanelTopChromeHeightPx(obj.FontSize);
            end
        end

    end


    %% Development/testing

    methods

        function onTuneImageClusterParameters(obj)
            if isempty(obj.Project)
                return
            end

            img = obj.Project.ActiveImage;
            if isempty(img)
                return
            end

            matlabx.app.PointClusterTuner(img.CData);
        end

        function onTuneRegionClusterParameters(obj)
            if isempty(obj.Project)
                return
            end

            img = obj.Project.ActiveImage;
            if isempty(img) || isempty(img.ActiveRegion)
                return
            end

            matlabx.app.PointClusterTuner(img.regionSubimage(img.ActiveRegion));
        end

        function onLogFlush(obj,lines)
            nOld = numel(obj.LogTextArea.Value);
            obj.LogTextArea.Value(nOld+1:nOld+numel(lines)) = cellstr(lines);
            scroll(obj.LogTextArea,"bottom");
        end

        function onCloseRequest(obj)
            if ~obj.confirmSaveIfDirty()
                return
            end
            desmostorm.Log.INFO("Exiting...");
            % delete the GUI, will also delete fig window
            obj.delete();
        end

        function debug(obj)
            blah = 0;
        end

    end

    %% Global UI/listener sync/refresh helpers
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
            obj.refreshImageListBox();
            obj.syncActiveImageToView();

            % regions
            obj.refreshRegionListBox();
            obj.syncActiveRegionToView();

            % labels
            obj.refreshLabelsTree()

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

        function refreshWindowName(obj)
            dirtyMark = "";
            projectName = "";
            if ~isempty(obj.Project)
                projectName = obj.Project.Name;
                if obj.Project.HasUnsavedChanges
                    dirtyMark = "*";
                end
            end

            if isempty(obj.Project)
                obj.Fig.Name = sprintf("%s%s (%s)",desmostorm.Info.Name,dirtyMark,desmostorm.Info.Version);
            else
                obj.Fig.Name = sprintf("%s%s (%s) - %s",desmostorm.Info.Name,dirtyMark,desmostorm.Info.Version,projectName);
            end
        end

        function refreshSettingsControllers(obj)
            S = obj.Settings;
            % Colormap
            cmap = S.Display.Colormap;
            cmapName = obj.Settings.Display.ColormapName;
            obj.ColormapTree.SelectedNodes = obj.ColormapTree.findobj("NodeData",cmapName);
            obj.ExampleColormapAxes.Colormap = cmap;
            if ~isempty(obj.Project)
                obj.applyProjectChannelDisplayToAxes();
                obj.syncColormapSelectorToChannel();
            else
                obj.ExampleColormapAxes.Colormap = cmap;
            end
            obj.refreshChannelDisplayControls();
            % set axes limits so that colorbar image fills axes area
            set(obj.ExampleColormapAxes,"YLim",[0.5 50.5],"XLim",[0.5 256.5]);
            % Analysis
            obj.SettingsUI.Analysis.BoxSizeEditField.Value = S.Analysis.BoxSize;
            obj.SettingsUI.Analysis.MinPeakDistanceEditField.Value = S.Analysis.MinPeakDistance;
            obj.SettingsUI.Analysis.MinPeakHeightEditField.Value = S.Analysis.MinPeakHeight;
            obj.SettingsUI.Analysis.MinPeakProminenceEditField.Value = S.Analysis.MinPeakProminence;
            obj.SettingsUI.Analysis.NormalizeDropDown.Value = S.Analysis.Normalize;
            obj.SettingsUI.Analysis.PeakSmoothingEditField.Value = S.Analysis.PeakSmoothing;
            obj.SettingsUI.Analysis.PixelSizeValueEditField.Value = S.Analysis.PixelSizeValue;
            obj.SettingsUI.Analysis.PixelSizeUnitDropDown.Value = S.Analysis.PixelSizeUnit;
            % PeaksPlot
            obj.SettingsUI.PeaksPlot.ShownPlotsDropDown.Value = char(S.PeaksPlot.ShownPlots);
            obj.SettingsUI.PeaksPlot.ColorSourceDropDown.Value = char(S.PeaksPlot.ColorSource);
            obj.SettingsUI.PeaksPlot.RawLineWidthEditField.Value = S.PeaksPlot.RawLineWidth;
            obj.SettingsUI.PeaksPlot.ColorPicker.Value = S.PeaksPlot.Color;
            obj.SettingsUI.PeaksPlot.SmoothLineWidthEditField.Value = S.PeaksPlot.SmoothLineWidth;
            obj.SettingsUI.PeaksPlot.BackgroundColorPicker.Value = S.PeaksPlot.BackgroundColor;
            obj.SettingsUI.PeaksPlot.ForegroundColorPicker.Value = S.PeaksPlot.ForegroundColor;
            obj.SettingsUI.PeaksPlot.AnnotationColorModeDropDown.Value = char(S.PeaksPlot.AnnotationColorMode);
            obj.SettingsUI.PeaksPlot.AnnotationColorPicker.Value = S.PeaksPlot.AnnotationColor;
            obj.SettingsUI.PeaksPlot.DistanceAnnotationsDropDown.Value = char(S.PeaksPlot.DistanceAnnotations);
            obj.SettingsUI.PeaksPlot.DistanceAnnotationsModeDropDown.Value = char(S.PeaksPlot.DistanceAnnotationsMode);
            obj.SettingsUI.PeaksPlot.WidthAnnotationsDropDown.Value = char(S.PeaksPlot.WidthAnnotations);
            obj.SettingsUI.PeaksPlot.WidthAnnotationsModeDropDown.Value = char(S.PeaksPlot.WidthAnnotationsMode);
            % Linescan ROI
            obj.SettingsUI.ROI.ROIColorPicker.Value = S.ROI.ROIColor;
            obj.SettingsUI.ROI.ROILineWidthEditField.Value = S.ROI.ROILineWidth;
            obj.SettingsUI.ROI.ROIFaceAlphaEditField.Value = S.ROI.ROIFaceAlpha;
            obj.SettingsUI.ROI.ROIMarkerSizeEditField.Value = S.ROI.ROIMarkerSize;
            obj.SettingsUI.ROI.AnnotationLineColorPicker.Value = S.ROI.AnnotationLineColor;
            obj.SettingsUI.ROI.AnnotationLineWidthEditField.Value = S.ROI.AnnotationLineWidth;
            obj.SettingsUI.ROI.RotationAngleVisibleDropDown.Value = char(S.ROI.RotationAngleVisible);
            obj.SettingsUI.ROI.RotationAngleModeDropDown.Value = S.ROI.RotationAngleMode;
            obj.SettingsUI.ROI.FontColorPicker.Value = S.ROI.FontColor;
            obj.SettingsUI.ROI.FontSizeEditField.Value = S.ROI.FontSize;
            obj.refreshROISettings();
            % Display
            obj.SettingsUI.Display.AutoScaleDisplayIntensityCheckBox.Value = S.Display.AutoScaleDisplayIntensity;
            % Sliders
            obj.resetIntensitySliders();
        end

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
                % Images
                obj.projectL(1) = addlistener(obj.Project,'ImageAdded',             @(~,~) obj.onImageAdded());
                obj.projectL(2) = addlistener(obj.Project,'ImageRemoved',           @(~,~) obj.onImageRemoved());
                obj.projectL(3) = addlistener(obj.Project,'ActiveImageChanged',     @(~,~) obj.onActiveImageChanged());
                obj.projectL(4) = addlistener(obj.Project,'MaxSizeCChanged',        @(~,~) obj.onMaxSizeCChanged());
                % Regions
                obj.projectL(5) = addlistener(obj.Project,'RegionAdded',            @(~,e) obj.onRegionAdded(e));
                obj.projectL(6) = addlistener(obj.Project,'RegionRemoved',          @(~,e) obj.onRegionRemoved(e));
                obj.projectL(7) = addlistener(obj.Project,'ActiveRegionChanged',    @(~,e) obj.onActiveRegionChanged(e));
                obj.projectL(8) = addlistener(obj.Project,'RegionSelectionChanged', @(~,e) obj.onRegionSelectionChanged(e));
                % Labels
                obj.projectL(9) = addlistener(obj.Project,'LabelsChanged',          @(~,~) obj.onLabelsChanged());
                % Dirty state
                obj.projectL(10) = addlistener(obj.Project,'DirtyStateChanged',     @(~,~) obj.onDirtyStateChanged());
            end
            % Settings
            obj.settingsL(1) = addlistener(obj.Settings,'DisplayChanged',   @(~,e) obj.onDisplayChanged(e));
            obj.settingsL(2) = addlistener(obj.Settings,'AnalysisChanged',  @(~,e) obj.onAnalysisChanged(e));
            obj.settingsL(3) = addlistener(obj.Settings,'IOChanged',        @(~,e) obj.onIOChanged(e));
            obj.settingsL(4) = addlistener(obj.Settings,'PeaksPlotChanged', @(~,e) obj.onPeaksPlotChanged(e));
            obj.settingsL(5) = addlistener(obj.Settings,'BoxChanged',       @(~,e) obj.onBoxChanged(e));
            obj.settingsL(6) = addlistener(obj.Settings,'ROIChanged',       @(~,e) obj.onROIChanged(e));
        end

        function refreshHotkeys(obj)
            % refresh hotkeys for label selection
            labels = obj.Project.LabelBank.labels;
            for i = 1:numel(labels)
                % add a hotkey for each label
                obj.CommandRouter.addHotkey(labels(i).Hotkey,@(~,k) obj.onLabelHotkeyPressed(k));
            end
        end

        function refreshComponentSizes(obj)

            if obj.pendingSizeUpdate, return; end
            obj.pendingSizeUpdate = true;

            p = obj.Fig.InnerPosition;
            H = p(4);
            W = p(3);

            % remaining width for top row of right panel
            remW = W - 300 - obj.Padding*2 - obj.ColumnSpacing;

            % account for uipanel overhead
            panelTop = obj.uipanelTopChromePx;

            % take half for the ImageViewer
            imageW = (remW-obj.ColumnSpacing)/2;
            % imageH = imageW+panelTop;
            imageH = imageW+panelTop;

            % half of that is the RegionViewer
            regionW = (imageW-obj.ColumnSpacing)/2;
            regionH = regionW+panelTop;

            % second row of RegionGrid is for linescan plots
            plotPanelOuterH = (imageH - regionH - obj.Padding);

            % set sizes
            set(obj.ImageViewerPanelGrid,"RowHeight",{imageH},"ColumnWidth",{imageW});
            set(obj.RegionViewerPanelGrid,"RowHeight",{regionH},"ColumnWidth",{regionW});

            % test below
            set(obj.RegionSummaryPanelGrid,"RowHeight",{regionH});
            % end test

            obj.RegionGrid.RowHeight{2} = plotPanelOuterH;

            drawnow
            obj.pendingSizeUpdate = false;

        end

        % clear / reset
        function clearUI(obj)
            obj.refreshMenubar();
            obj.refreshWindowName();
            obj.clearImageListBox();
            obj.clearImageViewer();
            obj.clearRegionListBox();
            obj.clearRegionViewer();
            obj.clearRegionLinescanPlot();
            obj.clearRegionSummaryTable();
            obj.resetIntensitySliders();
            obj.refreshChannelDisplayControls();
            obj.clearLabelsTree();
        end

    end

    %% Other helpers
    methods (Access=private)

        function applyProjectChannelColormapsToAxes(obj)
        %APPLYPROJECTCHANNELCOLORMAPSTOAXES Apply saved project colormaps to ImageViewer
            if isempty(obj.Project) || isempty(obj.ImageViewer) || ~isvalid(obj.ImageViewer)
                return
            end

            n = min(obj.Project.MaxSizeC,obj.ImageViewer.NumComponents);
            cmaps = obj.ImageViewer.ComponentColormaps;
            for C = 1:n
                cmaps{C} = obj.Project.getChannelColormap(C);
            end
            obj.ImageViewer.ComponentColormaps = cmaps;
        end

        function applyProjectChannelColorsToAxes(obj)
        %APPLYPROJECTCHANNELCOLORSTOAXES Apply saved project color names to ImageViewer
            if isempty(obj.Project) || isempty(obj.ImageViewer) || ~isvalid(obj.ImageViewer)
                return
            end

            n = min(obj.Project.MaxSizeC,obj.ImageViewer.NumComponents);
            colors = obj.ImageViewer.ComponentColors;
            for C = 1:n
                colors{C} = obj.Project.getChannelColorName(C);
            end
            obj.ImageViewer.ComponentColors = colors;
        end

        function applyProjectChannelDisplayToAxes(obj)
        %APPLYPROJECTCHANNELDISPLAYTOAXES Apply project display choices and settings mode
            if isempty(obj.Project) || isempty(obj.ImageViewer) || ~isvalid(obj.ImageViewer)
                return
            end

            % obj.isSyncingChannelDisplay = true;
            % cleanup = onCleanup(@() obj.clearChannelDisplaySyncFlag());

            obj.applyProjectChannelColormapsToAxes();
            obj.applyProjectChannelColorsToAxes();
        end

        function refreshChannelDisplayControls(obj)
        %REFRESHCHANNELDISPLAYCONTROLS Sync Channel Display controls to project and active image
            obj.syncChannelColorControlCount();

            if isempty(obj.SettingsUI) || ~isfield(obj.SettingsUI,'ChannelDisplay')
                return
            end

            % obj.isSyncingChannelDisplay = true;
            % cleanup = onCleanup(@() obj.clearChannelDisplaySyncFlag());

            obj.SettingsUI.ChannelDisplay.ColorModeDropDown.Value = obj.Settings.Display.ChannelColorMode;

            nVisible = 0;
            if ~isempty(obj.Project)
                img = obj.Project.ActiveImage;
                if ~isempty(img)
                    nVisible = min(numel(obj.ChannelColorDropDowns),img.SizeC);
                end
            end

            for C = 1:numel(obj.ChannelColorDropDowns)
                if C > nVisible
                    obj.ChannelColorLabels(C).Visible = 'off';
                    obj.ChannelColorDropDowns(C).Visible = 'off';
                    continue
                end

                obj.ChannelColorLabels(C).Visible = 'on';
                obj.ChannelColorDropDowns(C).Visible = 'on';
                obj.ChannelColorDropDowns(C).Value = obj.Project.getChannelColorName(C);
            end

            obj.updateChannelColorControlRows(nVisible);
        end

        function syncChannelColorControlCount(obj)
        %SYNCCHANNELCOLORCONTROLCOUNT Match color dropdown count to project channel capacity
            nDesired = 1;
            if ~isempty(obj.Project)
                nDesired = max(obj.Project.MaxSizeC,1);
            end

            nCurrent = numel(obj.ChannelColorDropDowns);
            if nCurrent > nDesired
                delete(obj.ChannelColorLabels(nDesired+1:end));
                delete(obj.ChannelColorDropDowns(nDesired+1:end));
                obj.ChannelColorLabels = obj.ChannelColorLabels(1:nDesired);
                obj.ChannelColorDropDowns = obj.ChannelColorDropDowns(1:nDesired);
                nCurrent = nDesired;
            end

            item = obj.SettingsAccordion.getItem("Channel Display");
            colorNames = string(matlabx.ui.axes.ImageAxes.getColorNames());
            for C = nCurrent+1:nDesired
                obj.ChannelColorLabels(C) = uilabel(item.Pane,...
                    "Text",sprintf("Channel %i",C),...
                    "FontColor",[0.85 0.85 0.85]);

                obj.ChannelColorDropDowns(C) = uidropdown(item.Pane,...
                    "Items",colorNames,...
                    "Value",colorNames(1 + mod(C-1,numel(colorNames))),...
                    "ValueChangedFcn",@(o,~) obj.ChannelColorChanged(o,C));
            end

            for C = 1:numel(obj.ChannelColorDropDowns)
                obj.ChannelColorLabels(C).Layout.Row = C + 1;
                obj.ChannelColorLabels(C).Layout.Column = 1;
                obj.ChannelColorLabels(C).Text = sprintf("Channel %i",C);

                obj.ChannelColorDropDowns(C).Layout.Row = C + 1;
                obj.ChannelColorDropDowns(C).Layout.Column = 2;
            end
        end

        function updateChannelColorControlRows(obj,nVisible)
        %UPDATECHANNELCOLORCONTROLROWS Collapse unused Channel Display rows
            item = obj.SettingsAccordion.getItem("Channel Display");
            nRows = numel(obj.ChannelColorDropDowns);
            nVisible = min(max(nVisible,0),nRows);

            rowHeight = [{'fit'}, repmat({0},1,nRows)];
            if nVisible > 0
                rowHeight(2:(nVisible+1)) = repmat({'fit'},1,nVisible);
            end
            item.Pane.RowHeight = rowHeight;
        end

        function syncColormapSelectorToChannel(obj)
        %SYNCCOLORMAPSELECTORTOCHANNEL Reflect the active channel colormap in the selector
            if isempty(obj.Project) || isempty(obj.ImageViewer) || isempty(obj.ColormapTree)
                return
            end
            if ~isvalid(obj.ImageViewer) || ~isvalid(obj.ColormapTree)
                return
            end

            C = obj.ImageViewer.C;
            [name,category] = obj.Project.getChannelColormapInfo(C);
            node = obj.findColormapTreeNode(name,category);
            cmap = obj.Project.getChannelColormap(C);

            obj.isSyncingColormapSelection = true;
            cleanup = onCleanup(@() obj.clearColormapSelectionSyncFlag());

            if ~isempty(node)
                obj.ColormapTree.SelectedNodes = node;
            end
            obj.ExampleColormapAxes.Colormap = cmap;
        end

        function node = findColormapTreeNode(obj,name,category)
        %FINDCOLORMAPTREENODE Find a colormap tree leaf by category/name
            node = matlab.ui.container.TreeNode.empty();

            categoryNodes = obj.ColormapTree.Children;
            for i = 1:numel(categoryNodes)
                if string(categoryNodes(i).Text) ~= category
                    continue
                end

                mapNodes = categoryNodes(i).Children;
                for j = 1:numel(mapNodes)
                    if ~isempty(mapNodes(j).NodeData) && string(mapNodes(j).NodeData) == name
                        node = mapNodes(j);
                        return
                    end
                end
            end
        end

        function clearColormapSelectionSyncFlag(obj)
        %CLEARCOLORMAPSELECTIONSYNCFLAG Reset programmatic colormap-selection guard
            obj.isSyncingColormapSelection = false;
        end

        % function clearChannelDisplaySyncFlag(obj)
        % %CLEARCHANNELDISPLAYSYNCFLAG Reset programmatic channel-display guard
        %     obj.isSyncingChannelDisplay = false;
        % end

        function guialert(obj,opts)
            arguments
                obj (1,1) desmostorm.app.GUI
                opts.Message = ""
                opts.Title = "Untitled"
                opts.Icon (1,:) char {mustBeMember(opts.Icon,{'error','warning','info','message','success',''})} = ''
            end

            % give focus to figure
            figure(obj.Fig);
            % uialert dialog, closing will resume interaction on main window
            uialert(obj.Fig,...
                opts.Message,...
                opts.Title,...
                'Icon',opts.Icon,...
                'CloseFcn',@(o,e) uiresume(obj.Fig));
            % prevent interaction with the main window until we finish
            uiwait(obj.Fig);
        end


        function config = getRunConfig(obj)
            config = desmostorm.config.RunConfig.fromSettings(obj.Settings);
        end


    end

    %% Callbacks / UI sync (Images)
    methods (Access=private)

        % --- LISTENER CALLBACKS ---
        function onImageAdded(obj)
        %ONIMAGEADDED ImageAdded event callback
            obj.refreshImageListBox();
            desmostorm.Log.DEBUG("Image added.")
        end

        function onImageRemoved(obj)
        %ONIMAGEREMOVED ImageRemoved event callback    
            obj.refreshImageListBox();
            desmostorm.Log.DEBUG("Image removed.")
        end

        function onActiveImageChanged(obj)
        %ONACTIVEIMAGECHANGED ActiveImageChanged event callback
            obj.syncActiveImageToView();
            desmostorm.Log.DEBUG("Active Image changed.")
        end

        function onMaxSizeCChanged(obj)
        %ONMAXSIZECCHANGED MaxSizeCChanged event callback
            obj.refreshIntensitySliders();
            obj.refreshRegionLinescanPlot();
            obj.applyProjectChannelDisplayToAxes();
            obj.syncColormapSelectorToChannel();
            obj.refreshChannelDisplayControls();
        end

        function onImageViewerChannelChanged(obj)
        %ONIMAGEVIEWERCHANNELCHANGED Sync colormap selector to active image channel
            obj.syncColormapSelectorToChannel();
            if obj.Settings.PeaksPlot.ShownPlots == "current"
                obj.refreshRegionLinescanPlot();
            end
        end

        function onImageViewerChannelDisplayChanged(obj)
        %ONIMAGEVIEWERCHANNELDISPLAYCHANGED Sync context-menu display changes to project/settings
            if isempty(obj.Project) || isempty(obj.ImageViewer)
                return
            end

            colors = obj.ImageViewer.ComponentColors;
            n = min(numel(colors),obj.Project.MaxSizeC);
            for C = 1:n
                obj.Project.setChannelColor(C,string(colors{C}));
            end

            obj.Settings.Display.ChannelColorMode = string(obj.ImageViewer.ComponentColorMode);
            obj.refreshChannelDisplayControls();
        end

        % --- UI SYNC DRIVER ---
        function syncActiveImageToView(obj)
        % SYNCACTIVEIMAGETOVIEW Sync UI to ActiveImage
            obj.refreshImageViewer();
            obj.refreshRegionListBox();
            obj.refreshRegionBoxes();
            obj.syncActiveRegionToView();
        end

        % --- COMPONENT CALLBACKS ---
        function onImageListBoxValueChanged(obj, imageID)
        %ONIMAGELISTBOXVALUECHANGED ValueChangedFcn callback for ImageListBox
            if isempty(imageID), return; end
            obj.Project.setActiveImage(imageID);
        end

        % --- COMPONENTS UI SYNC ---
        function refreshImageListBox(obj)
        %REFRESHIMAGELISTBOX Update ImageListBox

            ids = obj.Project.ImageIDs;

            if isempty(ids), obj.clearImageListBox(); return; end

            set(obj.ImageListBox,"Items",obj.Project.ImageNames,"ItemsData",ids)

            img = obj.Project.ActiveImage;

            if ~isempty(img)
                obj.ImageListBox.Value = img.ID;
            else
                obj.ImageListBox.Value = ids(1);
            end

            % forward value to ValueChangedFcn of ImageListBox
            obj.onImageListBoxValueChanged(obj.ImageListBox.Value);
        end

        function clearImageListBox(obj)
        %CLEARIMAGELISTBOX Reset ImageListBox
            set(obj.ImageListBox,"Items",{},"ItemsData",{},"Value",{});
        end

        function refreshImageViewer(obj)
        %REFRESHIMAGEVIEWER Sync ImageViewer to ActiveImage
            % get the active image
            img = obj.Project.ActiveImage;
            % if empty, clear view and return
            if isempty(img), obj.ImageViewer.CData = []; return, end
            % get current channel index of ImageViewer
            C = obj.ImageViewer.C;

            % new image does not have at least C channels, reset to 1
            if C > img.SizeC
                C = 1;
            end

            % get CLim
            switch obj.Settings.Display.AutoScaleDisplayIntensity
                case true
                    clims = img.getAutoDisplayRanges();
                case false
                    clims = img.getDisplayRanges();
            end

            % update ImageViewer ImageData, C, and CLims
            set(obj.ImageViewer,'ImageData',img.ImageData,'C',C,'ComponentCLims',clims);
            obj.applyProjectChannelDisplayToAxes();
            obj.syncColormapSelectorToChannel();
            obj.refreshChannelDisplayControls();
            obj.refreshIntensitySliders();
        end



        function clearImageViewer(obj)
        %REFRESHIMAGEVIEWER Reset ImageViewer
            obj.ImageViewer.CData = [];
            obj.ImageViewer.Tools.Box.clearBoxes();
        end

        function refreshRegionBoxes(obj)
        %REFRESHREGIONBOXES Sync Region boxes in ImageViewer to ActiveImage

            % clear boxes from ImageViewer
            obj.ImageViewer.Tools.Box.clearBoxes();

            img = obj.Project.ActiveImage;

            if isempty(img) || isempty(img.RegionArray)
                return
            end

            % add a box for each region, colored according to its label
            for r = img.RegionArray'
                boxColor = obj.Project.LabelBank.getByID(r.LabelID).Color;
                obj.ImageViewer.Tools.Box.addBox(r.ID, r.Center, r.BoxSize, ...
                    "EdgeColor", boxColor, "FaceColor", boxColor, "Label", r.Name);
            end

            % apply selection status to region boxes
            obj.ImageViewer.Tools.Box.setSelectedBoxIDs(img.SelectedRegionIDs);
            % set active box
            obj.ImageViewer.Tools.Box.setActiveBoxID(img.ActiveRegionID);
        end

        function refreshIntensitySliders(obj)
        %REFRESHINTENSITYSLIDERS Sync intensity sliders to ActiveImage
            obj.syncIntensitySliderCount();

            % get the active image
            if isempty(obj.Project)
                obj.resetIntensitySliders();
                return
            end

            img = obj.Project.ActiveImage;
            % if empty, reset sliders and return
            if isempty(img)
                obj.resetIntensitySliders();
                return
            end

            nVisible = img.SizeC;
            if ~isempty(obj.ImageViewer) && isvalid(obj.ImageViewer)
                nVisible = min(nVisible,obj.ImageViewer.NumComponents);
            end
            nVisible = min(numel(obj.IntensitySliders), nVisible);
            for C = 1:numel(obj.IntensitySliders)
                if C > nVisible
                    obj.IntensitySliders(C).Visible = 'off';
                    continue
                end
                obj.IntensitySliders(C).Visible = 'on';

                % get DisplayRange and DataRange
                switch obj.Settings.Display.AutoScaleDisplayIntensity
                    case true
                        val = img.getAutoDisplayRange(C);
                    case false
                        val = img.getDisplayRange(C);
                end
                lims = img.getDataRange(C);
                % update Value and Limits
                set(obj.IntensitySliders(C),'Limits',lims,'Value',val)
            end

            obj.updateIntensitySliderRows(nVisible);

        end

        function resetIntensitySliders(obj)
        %RESETINTENSITYSLIDERS Reset IntensitySliders    
            obj.syncIntensitySliderCount();

            if isempty(obj.IntensitySliders), return; end

            set(obj.IntensitySliders,'Limits',[0 1],'Value',[0 1]);
            obj.IntensitySliders(1).Visible = 'on';
            if numel(obj.IntensitySliders) > 1
                set(obj.IntensitySliders(2:end),'Visible','off');
            end

            obj.updateIntensitySliderRows(1);
        end

        function syncIntensitySliderCount(obj)
        %SYNCINTENSITYSLIDERCOUNT Match slider count to project channel capacity
            nDesired = 1;
            if ~isempty(obj.Project)
                nDesired = max(obj.Project.MaxSizeC,1);
            end

            nCurrent = numel(obj.IntensitySliders);
            if nCurrent > nDesired
                delete(obj.IntensitySliders(nDesired+1:end));
                obj.IntensitySliders = obj.IntensitySliders(1:nDesired);
                nCurrent = nDesired;
            end

            item = obj.SettingsAccordion.getItem("Image Display");
            for C = nCurrent+1:nDesired
                obj.IntensitySliders(C) = matlabx.ui.control.Slider(item.Pane,...
                    "Title",sprintf("Channel %i",C),...
                    "FontColor",[1 1 1],...
                    "BackgroundColor",[.18 .18 .18],...
                    "Limits",[0 1],...
                    "Value",[0 1],...
                    "RoundValues","on",...
                    "RoundDigits",0,...
                    "ValueChangingFcn",@(~,evt) obj.onIntensitySliderChanging(evt,C),...
                    "ValueChangedFcn",@(~,evt) obj.onIntensitySliderChanged(evt,C));
            end

            for C = 1:numel(obj.IntensitySliders)
                obj.IntensitySliders(C).Layout.Row = C + 1;
                obj.IntensitySliders(C).Layout.Column = 1;
                obj.IntensitySliders(C).Title = sprintf("Channel %i",C);
            end
        end

        function updateIntensitySliderRows(obj,nVisible)
        %UPDATEINTENSITYSLIDERROWS Collapse unused slider rows in Image Display controls
            item = obj.SettingsAccordion.getItem("Image Display");
            nSliders = numel(obj.IntensitySliders);
            nVisible = min(max(nVisible,0),nSliders);

            rowHeight = [{'fit'}, repmat({0},1,nSliders)];
            if nVisible > 0
                rowHeight(2:(nVisible+1)) = repmat({'fit'},1,nVisible);
            end
            item.Pane.RowHeight = rowHeight;
        end


    end

    %% Listener callbacks / UI sync (Regions)
    methods (Access=private)

        % --- LISTENER CALLBACKS ---
        function onRegionAdded(obj,evt)
        %ONREGIONADDED RegionAdded event callback
            desmostorm.Log.INFO("Region added (" + obj.formatRegionEventLabel(evt) + ").")
            obj.refreshRegionListBox();
            obj.markProjectDirty();
        end

        function onRegionRemoved(obj,evt)
        %ONREGIONREMOVED RegionRemoved event callback    
            desmostorm.Log.INFO("Region removed (" + obj.formatRegionEventLabel(evt) + ").")
            obj.refreshRegionListBox();
            obj.markProjectDirty();
        end

        function onActiveRegionChanged(obj,evt)
        %ONACTIVEREGIONCHANGED ActiveRegionChanged event callback
            desmostorm.Log.DEBUG("Active region changed (" + obj.formatRegionTransition(evt.OldID,evt.NewID) + ").")
            obj.syncActiveRegionToView();
        end

        function onRegionSelectionChanged(obj,evt)
        %ONREGIONSELECTIONCHANGED RegionSelectionChanged event callback
            desmostorm.Log.DEBUG("Region selection changed (" + obj.formatRegionSelection(evt.NewIDs) + ").")
            obj.refreshRegionListBox();
        end

        % --- UI SYNC DRIVER ---
        function syncActiveRegionToView(obj)
        %SYNCACTIVEREGIONTOVIEW Sync UI to ActiveRegion
            obj.refreshRegionViewer();
            obj.refreshRegionSummaryTable();
            obj.refreshRegionROI();
            obj.refreshRegionLinescanPlot();

            % set active box
            reg = obj.Project.ActiveRegion;
            if ~isempty(reg)
                obj.ImageViewer.Tools.Box.setActiveBoxID(reg.ID);
            end
        end

        % --- COMPONENT CALLBACKS ---
        function onRegionListBoxValueChanged(obj, ~, evt)
        %ONREGIONLISTBOXVALUECHANGED ValueChangedFcn for RegionListBox

            img = obj.Project.ActiveImage;
            if isempty(img), return; end

            regionID = evt.Value;
            id = string(regionID);

            % set active/selected region
            obj.ImageViewer.Tools.Box.setActiveBoxID(id);
            img.setActiveRegion(id);
        end

        % --- COMPONENTS UI SYNC ---
        function refreshRegionListBox(obj)
        %REFRESHREGIONLISTBOX Update RegionListBox
            % get ActiveImage
            img = obj.Project.ActiveImage;
            % no Image || no Regions in Image -> clear the listbox
            if isempty(img) || isempty(img.RegionOrder)
                obj.clearRegionListBox(); return
            end

            % update Items and ItemsData
            set(obj.RegionListBox,"Items",img.RegionNames,"ItemsData",img.RegionOrder);

            reg = img.ActiveRegion;
            if ~isempty(reg)
                obj.RegionListBox.Value = reg.ID;
            else
                obj.RegionListBox.Value = string.empty();
            end
        end

        function clearRegionListBox(obj)
        %CLEARREGIONLISTBOX Reset RegionListBox
            set(obj.RegionListBox,"Items",{},"ItemsData",{},"Value",{});
        end

        function label = formatRegionEventLabel(~,evt)
        %FORMATREGIONEVENTLABEL Build a readable region label from event data.
            if isprop(evt,"RegionName") && strlength(evt.RegionName) > 0
                label = evt.RegionName;
            elseif isprop(evt,"RegionID")
                label = evt.RegionID;
            else
                label = "unknown";
            end
        end

        function label = formatRegionTransition(obj,oldID,newID)
        %FORMATREGIONTRANSITION Format an old -> new region ID transition.
            label = obj.formatRegionID(oldID) + " -> " + obj.formatRegionID(newID);
        end

        function label = formatRegionSelection(~,ids)
        %FORMATREGIONSELECTION Format selected region IDs for DEBUG logs.
            ids = string(ids(:));
            if isempty(ids)
                label = "none";
            else
                label = strjoin(ids, ", ");
            end
        end

        function label = formatRegionID(~,id)
        %FORMATREGIONID Format empty region IDs as "none".
            id = string(id);
            if isempty(id) || all(strlength(id) == 0)
                label = "none";
            else
                label = strjoin(id(:), ", ");
            end
        end

        function refreshRegionViewer(obj)
        %REFRESHREGIONVIEWER Sync RegionViewer to ActiveRegion
            img = obj.Project.ActiveImage;
            % if empty, clear view and return
            if isempty(img) || isempty(img.ActiveRegion)
                obj.clearRegionViewer(); return
            end

            obj.RegionViewer.CData = img.regionSubimageCell(img.ActiveRegion);
        end

        function clearRegionViewer(obj)
        %CLEARREGIONVIEWER Reset RegionViewer
            obj.RegionViewer.CData = [];
            obj.clearRegionLinescanROI();
        end

        function refreshRegionSummaryTable(obj)
        %REFRESHREGIONSUMMARYTABLE Sync RegionSummaryTable to ActiveRegion
            if isempty(obj.Project.ActiveImage) || isempty(obj.Project.ActiveImage.ActiveRegion)
                obj.clearRegionSummaryTable(); return
            end
            obj.RegionSummaryTable.Data = obj.Project.ActiveImage.ActiveRegion.SummaryTable;
        end

        function clearRegionSummaryTable(obj)
        %CLEARREGIONSUMMARYTABLE Reset RegionSummaryTable
            obj.RegionSummaryTable.Data = [];
        end

        function refreshRegionLinescanPlot(obj)
        %REFRESHREGIONLINESCANPLOT Sync RegionLinescanPlot to ActiveRegion
            obj.syncRegionLinescanPlotCount();

            % get active Image
            img = obj.Project.ActiveImage;

            % if empty, clear plot and return
            if isempty(img) || isempty(img.ActiveRegion)
                obj.clearRegionLinescanPlot(); return
            end

            % get active Region
            reg = img.ActiveRegion;

            [plotData,colorChannels] = obj.getRegionLinescanPlotData(reg);
            if isempty(plotData)
                obj.clearRegionLinescanPlot();
                return
            end

            if obj.Settings.Analysis.Normalize
                obj.RegionLinescanPlot.YLabel = 'Normalized intensity';
            else
                obj.RegionLinescanPlot.YLabel = 'Intensity';
            end

            obj.RegionLinescanPlot.XLabel = sprintf("Distance (%s)",img.PixelSize.Unit);
            obj.RegionLinescanPlot.Title = char(matlabx.utils.text.texFriendly(img.Name) + " | " + reg.Name);
            obj.applyRegionLinescanPlotColors(colorChannels);
            obj.RegionLinescanPlot.DistanceAnnotations = obj.Settings.PeaksPlot.DistanceAnnotations;
            obj.RegionLinescanPlot.DistanceAnnotationsMode = char(obj.Settings.PeaksPlot.DistanceAnnotationsMode);
            obj.RegionLinescanPlot.WidthAnnotations = obj.Settings.PeaksPlot.WidthAnnotations;
            obj.RegionLinescanPlot.WidthAnnotationsMode = char(obj.Settings.PeaksPlot.WidthAnnotationsMode);
            obj.RegionLinescanPlot.Data = plotData;
            obj.RegionLinescanPlot.Visible = 'on';

            obj.updateRegionLinescanPlotRows(1);

        end

        function clearRegionLinescanPlot(obj)
        %CLEARREGIONLINESCANPLOT Reset RegionLinescanPlot
            obj.syncRegionLinescanPlotCount();

            if isempty(obj.RegionLinescanPlot), return; end

            set(obj.RegionLinescanPlot,'Data',desmostorm.analysis.PeaksData.empty(),'Title','');
            set(obj.RegionLinescanPlot,'Visible','off');
            obj.updateRegionLinescanPlotRows(0);
        end

        function syncRegionLinescanPlotCount(obj)
        %SYNCREGIONLINESCANPLOTCOUNT Ensure the single overlay plot exists
            nDesired = 1;

            nCurrent = numel(obj.RegionLinescanPlot);
            if nCurrent > nDesired
                delete(obj.RegionLinescanPlot(nDesired+1:end));
                obj.RegionLinescanPlot = obj.RegionLinescanPlot(1:nDesired);
                nCurrent = nDesired;
            end

            for C = nCurrent+1:nDesired
                obj.RegionLinescanPlot(C) = desmostorm.widgets.PeaksPlotContainer(obj.RegionLinescanPanelGrid,...
                    "RawLineWidth",obj.Settings.PeaksPlot.RawLineWidth, ...
                    "SmoothLineWidth",obj.Settings.PeaksPlot.SmoothLineWidth, ...
                    "Color",obj.Settings.PeaksPlot.Color, ...
                    "ColorMode",'auto', ...
                    "AlphaMode",'auto', ...
                    "AnnotationColorMode",char(obj.Settings.PeaksPlot.AnnotationColorMode), ...
                    "AnnotationColor",obj.Settings.PeaksPlot.AnnotationColor, ...
                    "DistanceAnnotations",obj.Settings.PeaksPlot.DistanceAnnotations, ...
                    "DistanceAnnotationsMode",char(obj.Settings.PeaksPlot.DistanceAnnotationsMode), ...
                    "WidthAnnotations",obj.Settings.PeaksPlot.WidthAnnotations, ...
                    "WidthAnnotationsMode",char(obj.Settings.PeaksPlot.WidthAnnotationsMode), ...
                    "BackgroundColor",obj.Settings.PeaksPlot.BackgroundColor, ...
                    "ForegroundColor",obj.Settings.PeaksPlot.ForegroundColor, ...
                    "XLabel",sprintf("Distance (%s)",obj.Settings.Analysis.PixelSizeUnit), ...
                    "YLabel","Normalized Intensity", ...
                    "Visible","off");
            end

            for C = 1:numel(obj.RegionLinescanPlot)
                obj.RegionLinescanPlot(C).Layout.Row = 1;
                obj.RegionLinescanPlot(C).Layout.Column = 1;
            end
        end

        function updateRegionLinescanPlotRows(obj,nVisible)
        %UPDATEREGIONLINESCANPLOTROWS Collapse unused Region Linescan rows
            if nVisible > 0
                obj.RegionLinescanPanelGrid.RowHeight = {'1x'};
            else
                obj.RegionLinescanPanelGrid.RowHeight = {0};
            end
        end

        function [plotData,colorChannels] = getRegionLinescanPlotData(obj,reg)
        %GETREGIONLINESCANPLOTDATA Select all channels or only the viewer channel
            allData = reg.LinescanResults(:);
            if isempty(allData)
                plotData = desmostorm.analysis.PeaksData.empty();
                colorChannels = [];
                return
            end

            switch obj.Settings.PeaksPlot.ShownPlots
                case "current"
                    C = obj.ImageViewer.C;
                    if C > numel(allData)
                        plotData = desmostorm.analysis.PeaksData.empty();
                        colorChannels = [];
                    else
                        plotData = allData(C);
                        colorChannels = C;
                    end
                otherwise
                    plotData = allData;
                    colorChannels = 1:numel(allData);
            end
        end

        function applyRegionLinescanPlotColors(obj,colorChannels)
        %APPLYREGIONLINESCANPLOTCOLORS Apply channel or manual plot colors
            nPlots = numel(colorChannels);
            obj.RegionLinescanPlot.ColorMode = 'auto';
            obj.RegionLinescanPlot.AlphaMode = 'auto';

            switch obj.Settings.PeaksPlot.ColorSource
                case "channel"
                    colors = obj.getRegionLinescanPlotColors(colorChannels);
                otherwise
                    colors = repmat(obj.Settings.PeaksPlot.Color,nPlots,1);
            end

            obj.RegionLinescanPlot.Colors = colors;
            obj.RegionLinescanPlot.SmoothLineColors = zeros(0,3);
            obj.RegionLinescanPlot.RawLineColors = zeros(0,3);
            obj.RegionLinescanPlot.AnnotationColorMode = char(obj.Settings.PeaksPlot.AnnotationColorMode);
            obj.RegionLinescanPlot.AnnotationColor = obj.Settings.PeaksPlot.AnnotationColor;
            obj.RegionLinescanPlot.AnnotationsColors = zeros(0,3);
            obj.RegionLinescanPlot.PeakAreaColors = zeros(0,3);
        end

        function colors = getRegionLinescanPlotColors(obj,channels)
        %GETREGIONLINESCANPLOTCOLORS Convert project channel color names to RGB rows
            channels = channels(:).';
            colors = zeros(numel(channels),3);
            for i = 1:numel(channels)
                colorName = obj.Project.getChannelColorName(channels(i));
                colors(i,:) = matlabx.colors.names.toRGB(char(colorName),"Palette","MATLAB");
            end
        end

        function refreshRegionROI(obj)
        %REFRESHREGIONLINESCANROI Sync RegionLinescanROI to ActiveRegion    
            img = obj.Project.ActiveImage;
            % if empty, clear linescan position and return
            if isempty(img) || isempty(img.ActiveRegion)
                obj.clearRegionLinescanROI(); return
            end
            % update linescan ROI position
            obj.RegionViewer.Tools.DrawRectangle.setROIPosition(img.ActiveRegion.ROI);
        end

        function refreshROISettings(obj)
            if isempty(obj.RegionViewer) || ~isvalid(obj.RegionViewer), return; end

            tool = obj.RegionViewer.Tools.DrawRectangle;
            S = obj.Settings.ROI.toStruct();
            names = fieldnames(S);

            for i = 1:numel(names)
                tool.(names{i}) = S.(names{i});
            end
        end

        function clearRegionLinescanROI(obj)
        %CLEARREGIONLINESCANROI Reset RegionLinescanROI
            obj.RegionViewer.Tools.DrawRectangle.setROIPosition(desmostorm.model.STORMRegion.ROITemplate);
        end

    end

    %% Callbacks / UI sync (Labels)
    methods (Access=private)

        function onLabelsChanged(obj)
        %ONLABELSCHANGED LabelsChanged event callback
            % refresh UI and hotkeys
            obj.refreshHotkeys();
            obj.refreshLabelsTree();
            obj.refreshRegionBoxes();
            obj.refreshRegionSummaryTable();
            obj.markProjectDirty();
        end

        function onLabelHotkeyPressed(obj,key)
        %ONLABELHOTKEYPRESSED Shared callback for label hotkeys    
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
        %REFRESHLABELSTREE Sync labels uitree to LabelBank
            if isempty(obj.Project) || isempty(obj.LabelsTree) || ~isvalid(obj.LabelsTree)
                return
            end

            delete(obj.LabelsTree.Children);

            % get label bank and labels
            bank = obj.Project.LabelBank;
            arr = bank.labels();

            % --- build context menu for tree nodes ---
            % delete old context menu if valid
            CM = obj.ContextMenuUI.LabelsTreeNodeContextMenu;
            if ~isempty(CM)
                delete(CM(isvalid(CM)));
            end
            % make new context menu
            obj.ContextMenuUI.LabelsTreeNodeContextMenu = uicontextmenu(obj.Fig);
            % add menu options
            uimenu(obj.ContextMenuUI.LabelsTreeNodeContextMenu, ...
                "Text","Edit", ...
                "MenuSelectedFcn",@(~,e) obj.onEditLabel(e))

            for k = 1:numel(arr)
                L = arr(k);
                txt = string(L.Name);
                if strlength(L.Hotkey) > 0
                    txt = txt + "  [" + L.Hotkey + "]";
                end
                % create tree node
                tempNode = uitreenode("Parent",obj.LabelsTree,"Text",txt);
                % IMPORTANT - set NodeData outside the constructor call in case label ID is "default"
                tempNode.NodeData = L.ID;
                % add the context menu to the newly created node
                tempNode.ContextMenu = obj.ContextMenuUI.LabelsTreeNodeContextMenu;

                % create uistyle and add to the node
                nodeStyle = uistyle("Icon",reshape(L.Color,1,1,3));
                addStyle(obj.LabelsTree,nodeStyle,"node",tempNode);
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

        function applyActiveLabelToSelection(obj)
            img = obj.Project.ActiveImage;
            if isempty(img), return; end

            ids = obj.ImageViewer.Tools.Box.getSelectedBoxIDs();
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
            obj.ImageViewer.Tools.Box.setBoxesColorByIDs(ids, L.Color);

            % refresh region table
            obj.refreshRegionSummaryTable();
            obj.markProjectDirty();
        end

        function clearLabelOnSelection(obj)
            img = obj.Project.ActiveImage;
            if isempty(img), return; end

            ids = obj.ImageViewer.Tools.Box.getSelectedBoxIDs();
            if isempty(ids), return; end

            for i = 1:numel(ids)
                r = img.getRegion(ids(i));
                if ~isempty(r)
                    r.LabelID = "";
                end
            end

            obj.ImageViewer.Tools.Box.setBoxesColorByIDs(ids, 'w');
            obj.markProjectDirty();
        end

        % labels uitree callbacks
        function onSelectLabel(obj, evt)
            if isempty(obj.Project), return; end
            if isempty(evt.SelectedNodes) || isempty(evt.SelectedNodes.NodeData), return; end
            % get label ID from NodeData of selected node
            labelID = string(evt.SelectedNodes.NodeData);
            obj.Project.LabelBank.setActiveByID(labelID);
        end

        % labels uitree context menu callbacks
        function onEditLabel(obj, evt)
            % get clicked node from InteractionInformation of event payload
            clickedNode = evt.InteractionInformation.Node;
            % get label ID from NodeData of right-clicked node
            labelID = string(clickedNode.NodeData);
            % get the active label using its ID
            label = obj.Project.LabelBank.getByID(labelID);


            % get IDs of other labels
            labelIDs = obj.Project.LabelBank.ids();
            labelIDs(labelIDs==label.ID) = [];

            % get Hotkeys of other labels
            labelHotkeys = obj.Project.LabelBank.hotkeys();
            labelHotkeys(labelHotkeys==label.Hotkey) = [];

            % open form dialog to edit label info
            obj.Fig.Visible = 'off';
            labelInfo = matlabx.app.ParamsDialog.prompt( ...
                'Edit label info', ...
                {'Name','Name','string',label.Name,@(x) strlength(x) > 0,'Name cannot be empty'}, ...
                {'ID','ID','string',label.ID,@(x) strlength(x) > 0 && ~ismember(x,labelIDs),'ID must be unique and non-empty'}, ...
                {'Hotkey','Hotkey','string',label.Hotkey,@(x) strlength(x) == 1 && ~ismember(x,labelHotkeys),'Hotkey must be a single unique alphanumeric character'}, ...
                {'Color','Color','color',label.Color});
            % return if empty
            if isempty(labelInfo)
                obj.Fig.Visible = 'on';
                return
            end

            % update any regions labeled with the old LabelID
            regs = obj.Project.getRegionsByLabelID(label.ID);
            if ~isempty(regs), set(regs,"LabelID",labelInfo.ID); end

            % if hotkey changed, remove old hotkey from CommandRouter
            if ~strcmp(label.Hotkey,labelInfo.Hotkey), obj.CommandRouter.removeHotkey(label.Hotkey); end

            % update the label
            obj.Project.LabelBank.edit(label.ID, ...
                "Name",labelInfo.Name, ...
                "ID",labelInfo.ID, ...
                "Hotkey",labelInfo.Hotkey, ...
                "Color",labelInfo.Color);
            obj.Fig.Visible = 'on';
        end

        function markProjectDirty(obj)
            if ~isempty(obj.Project)
                obj.Project.markDirty();
            end
        end

        function onDirtyStateChanged(obj)
            obj.refreshWindowName();
        end

        function tf = confirmSaveIfDirty(obj)
            tf = true;
            if isempty(obj.Project) || ~obj.Project.HasUnsavedChanges
                return
            end

            selection = uiconfirm(obj.Fig, ...
                sprintf('Project "%s" has unsaved changes.',obj.Project.Name), ...
                'Save changes?', ...
                'Icon','warning', ...
                'Options',{'Save','Discard','Cancel'}, ...
                'DefaultOption','Save', ...
                'CancelOption','Cancel');

            switch selection
                case 'Save'
                    tf = obj.saveProject();
                case 'Discard'
                    tf = true;
                otherwise
                    tf = false;
            end
        end




    end

    %% Callbacks / UI sync (Settings)
    methods (Access=private)

        function onDisplayChanged(obj,e)
            switch e.Name
                case "ChannelColorMode"
                    obj.ImageViewer.ComponentColorMode = char(obj.Settings.Display.ChannelColorMode);
                    obj.refreshChannelDisplayControls();
                case "Colormap"
                    cmap = obj.Settings.Display.Colormap;
                    obj.ExampleColormapAxes.Colormap = cmap;

                    C = obj.ImageViewer.C;
                    if ~obj.isSyncingColormapSelection && ~isempty(obj.Project)
                        obj.Project.setChannelColormap( ...
                            C, ...
                            obj.Settings.Display.ColormapName, ...
                            obj.Settings.Display.ColormapCategory);
                    end

                    if C <= obj.ImageViewer.NumComponents
                        obj.ImageViewer.setComponentColormap(cmap,C);
                    end
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
            obj.markProjectDirty();
        end

        function onPeaksPlotChanged(obj,e)
            %obj.RegionLinescanPlot.(e.Name) = obj.Settings.PeaksPlot.(e.Name);
            switch e.Name
                case {"ShownPlots","ColorSource","Color"}
                    obj.refreshRegionLinescanPlot();
                case {"DistanceAnnotationsMode","WidthAnnotationsMode","AnnotationColorMode"}
                    set(obj.RegionLinescanPlot,e.Name,char(obj.Settings.PeaksPlot.(e.Name)));
                otherwise
                    set(obj.RegionLinescanPlot,e.Name,obj.Settings.PeaksPlot.(e.Name));
            end
            obj.markProjectDirty();
        end

        function onROIChanged(obj,e)
            if isempty(obj.RegionViewer) || ~isvalid(obj.RegionViewer), return; end
            obj.RegionViewer.Tools.DrawRectangle.(e.Name) = e.NewValue;
            obj.markProjectDirty();
        end

        function onBoxChanged(obj,~)
            % do something
            obj.markProjectDirty();
        end

        function onAnalysisChanged(obj,e)
            switch e.Name
                case {"MinPeakDistance","MinPeakHeight","MinPeakProminence","PeakSmoothing","Normalize"}
                    % immediately re-process all existing regions when analysis settings change
                    obj.processAllRegions();
                case "BoxSize"
                    % delete all existing Regions
                    obj.Project.removeAllRegions();
                    desmostorm.Log.INFO("Removed all regions after box size changed.");
                    % refresh the display for the current image
                    obj.syncActiveImageToView();
                    obj.refreshRegionROI();
                    obj.refreshRegionLinescanPlot();
                    % update BoxSize for Box tool
                    obj.ImageViewer.Tools.Box.BoxSize = obj.Settings.Analysis.BoxSize;
                case {"PixelSizeValue","PixelSizeUnit"}
                    obj.Project.setDefaultPixelSize(obj.Settings.Analysis.getDefaultPixelSize);
                    % re-process all existing regions to reflect new pixel size
                    obj.processAllRegions();
                    % refresh the region linescan plot
                    obj.refreshRegionLinescanPlot();
            end
            obj.markProjectDirty();
        end

        function onIOChanged(obj,e)
            if e.Name=="DefaultFolder"
                % do something
            end
            obj.markProjectDirty();
        end

        function ColormapSelectionChanged(obj,evt)
            if obj.isSyncingColormapSelection, return; end

            % get the newly selected node
            node = evt.SelectedNodes;
            if isempty(node), return; end
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
                case {"MinPeakDistance","MinPeakHeight","MinPeakProminence","PeakSmoothing","Normalize"}
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

        function ROISettingsChanged(obj,src,stgName)
            % apply the specified setting
            obj.Settings.ROI.(stgName) = src.Value;
        end

        function DisplaySettingsChanged(obj,src,stgName)
            % apply the specified setting
            obj.Settings.Display.(stgName) = src.Value;
        end

        function ChannelColorChanged(obj,src,C)
            if isempty(obj.Project)
                return
            end

            colorName = string(src.Value);
            obj.Project.setChannelColor(C,colorName);

            if C <= obj.ImageViewer.NumComponents
                obj.ImageViewer.setComponentColor(colorName,C);
            end
        end

    end

    %% Callbacks (Menubar)
    methods (Access=private)

        function onNew(obj)
        %ONNEW MenuSelectedCallback for [File]->[New]
            if ~obj.confirmSaveIfDirty()
                return
            end

            % cleanup before starting new
            if ~isempty(obj.Project), obj.Project.delete(); end
            if ~isempty(obj.Settings), obj.Settings.delete(); end
            obj.detatchListeners();
            % new Settings
            obj.Settings = desmostorm.config.Settings.load();
            % new Project
            obj.Project = desmostorm.model.STORMProject("untitled");
            obj.Project.DefaultPixelSize = obj.Settings.Analysis.getDefaultPixelSize();
            obj.Project.markClean();
            % refresh hotkeys
            obj.refreshHotkeys();
            % refresh UI
            obj.refreshUI();
            % refresh listeners
            obj.refreshListeners();
            % update log
            desmostorm.Log.INFO(sprintf("Started new project: %s",obj.Project.Name));
        end

        function onOpen(obj)
        %ONOPEN MenuSelectedCallback for [File]->[Open...]
            if ~obj.confirmSaveIfDirty()
                return
            end

            % get project filename
            obj.Fig.Visible = 'off';
            [file, path] = uigetfile('*.mat','Select project file (.mat)','MultiSelect','off');
            obj.Fig.Visible = 'on';
            if isequal(file,0), return; end % cancelled | no files selected -> return
            fname = fullfile(path, file);

            % update log
            desmostorm.Log.INFO(sprintf("Loading project file: %s",fname));
            % set up progress dialog
            msg = sprintf("Loading project file:\n%s",fname);
            h = uiprogressdlg(obj.Fig,"Message",msg,'Indeterminate','on');
            cleanupProgress = onCleanup(@() closeProgressDialog(h));
            % cleanup before loading
            if ~isempty(obj.Project), obj.Project.delete(); end   % delete project
            if ~isempty(obj.Settings), obj.Settings.delete(); end  % delete settings
            obj.detatchListeners(); % detach listeners
            % load Project and Settings
            [proj,stgs] = desmostorm.model.STORMProject.load(fname, ...
                "MissingImageResolver", @desmostorm.app.promptMissingImageRoot);
            % valid output from load -> assign and process
            if ~isempty(proj) && ~isempty(stgs)
                obj.Project = proj;
                obj.Settings = stgs;
                obj.processAllRegions(); % run region analysis
            else
                obj.Project = desmostorm.model.STORMProject.empty(); % empty project
                obj.Settings = desmostorm.config.Settings.load(); % default settings
            end
            % refresh hotkeys/UI/listeners
            obj.refreshHotkeys();
            obj.refreshUI();
            obj.refreshListeners();
            if ~isempty(obj.Project)
                obj.Project.markClean();
                obj.refreshWindowName();
            end
            % update log
            desmostorm.Log.INFO(sprintf("Successfully loaded project file: %s",fname));
        end

        function onClose(obj)
        %ONOPEN MenuSelectedCallback for [File]->[Close]
            % no project -> return
            if isempty(obj.Project), return; end
            if ~obj.confirmSaveIfDirty()
                return
            end

            projectName = obj.Project.Name;
            % --- delete project, detach listeners, refresh UI ---
            obj.Project.delete(); 
            obj.Project = desmostorm.model.STORMProject.empty(); % set empty so we do not store old handle
            obj.detatchListeners();
            obj.refreshUI();
            desmostorm.Log.INFO(sprintf("Closed project: %s",projectName));
        end

        function onSave(obj)
        %ONSAVE MenuSelectedCallback for [File]->[Save...]    
            obj.saveProject();
        end

        function tf = saveProject(obj)
        %SAVEPROJECT Save the active project; true only when save completes.
            tf = false;
            if isempty(obj.Project), return; end

            % get filename to save project
            obj.Fig.Visible = 'off';
            if obj.Project.isOnDisk
                defaultName = obj.Project.SourcePath;
            else
                defaultName = fullfile(obj.Settings.IO.DefaultFolder, obj.Project.Name + '.mat');
            end
            [file, path] = uiputfile('*.mat','Save project', defaultName);
            obj.Fig.Visible = 'on';
            if isequal(file,0), return; end % cancelled | no files selected -> return
            fname = fullfile(path, file);

            % update log
            desmostorm.Log.INFO(sprintf("Saving project file: %s",fname));
            % create progress dialog
            msg = sprintf("Saving project file:\n%s",fname);
            h = uiprogressdlg(obj.Fig,"Message",msg,'Indeterminate','on');
            cleanupProgress = onCleanup(@() closeProgressDialog(h));
            % save the project
            obj.Project.save(fname,obj.Settings);
            % refresh the window name
            obj.refreshWindowName();
            % update log
            desmostorm.Log.INFO(sprintf("Successfully saved project file: %s",fname));
            tf = true;
        end

        function onSaveSettings(obj)
        %ONSAVESETTINGS MenuSelectedCallback for [File]->[Save Settings]        
            obj.Settings.save(); % save current settings to default file
            desmostorm.Log.INFO("Settings saved.");
        end

        function onLoadImages(obj)
        %ONLOADIMAGES MenuSelectedCallback for [File]->[Load Images...]
            % get image filename(s)
            obj.Fig.Visible = 'off';
            [files,path,~] = matlabx.image.io.uigetimagefile('MultiSelect','on');
            obj.Fig.Visible = 'on';
            if isequal(files,0), return; end % cancelled | no files selected -> return
            if ischar(files), files = {files}; end
            fullpaths = fullfile(path, files);
            % add new STORMImage for each file
            obj.Project.addImagesFromPaths(fullpaths);
            desmostorm.Log.INFO(sprintf("Loaded %d image(s).",numel(fullpaths)));
        end

    end

    %% Per-image settings
    methods (Access=private)

        function onIntensitySliderChanging(obj,~,C)
            % get the active image
            img = obj.Project.ActiveImage;
            if isempty(img), return; end

            % set MaxRenderedResolution for smoother updates in ImageViewer, RegionViewer
            obj.ImageViewer.MaxRenderedResolution = obj.ImageViewer.CDataSize(1)/4;
            obj.RegionViewer.MaxRenderedResolution = obj.Settings.Analysis.BoxSize/4;

            % set the new CLim for the ImageViewer, linked RegionViewer will update
            clim = obj.IntensitySliders(C).Value;
            obj.ImageViewer.setComponentCLim(clim,C);
        end

        function onIntensitySliderChanged(obj,~,C)
            % get the active image
            img = obj.Project.ActiveImage;
            if isempty(img), return; end

            % update model with slider value
            newVal = obj.IntensitySliders(C).Value;
            img.setDisplayRange(newVal,C);

            % update view
            obj.ImageViewer.setComponentCLim(newVal,C);

            % disable AutoScaleDisplayIntensity if enabled
            if obj.Settings.Display.AutoScaleDisplayIntensity
                obj.Settings.Display.AutoScaleDisplayIntensity = false;
            end

            % reset MaxRenderedResolution
            obj.ImageViewer.MaxRenderedResolution = 'none';
            obj.RegionViewer.MaxRenderedResolution = 'none';

            obj.markProjectDirty();
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
            img.processRegionLinescan(reg,obj.getRunConfig());
            % sync UI
            obj.syncActiveRegionToView();
            obj.markProjectDirty();
        end

        function processAllRegions(obj)
            % create progress dialog
            desmostorm.Log.INFO("Analyzing region measurements...");
            h = uiprogressdlg(obj.Fig,"Message",'Analyzing ROIs. Please wait...','Indeterminate','on');
            % re-process everything
            obj.Project.processAll(obj.getRunConfig())
            % close the progress dialog
            close(h);
            % sync UI
            obj.syncActiveImageToView();
            obj.markProjectDirty();
            desmostorm.Log.INFO("Region analysis complete.");
        end

        function onAutoFitAllROIs(obj)
            % create progress dialog
            desmostorm.Log.INFO("Fitting ROIs for all regions...");
            h = uiprogressdlg(obj.Fig, ...
                "Title","Auto-Fit Region ROIs", ...
                "Message",'Preparing ROI auto-fit...', ...
                "Indeterminate",'off', ...
                "Value",0);
            cleanup = onCleanup(@() closeProgressDialog(h));
            % re-process everything
            summary = obj.Project.autofitAllRegionROIs(obj.getRunConfig(), ...
                "ProgressDialog",h);
            % close the progress dialog
            delete(cleanup);

            % reprocess region measurements
            obj.processAllRegions();
            desmostorm.Log.INFO(sprintf( ...
                "ROI fitting complete: %d/%d succeeded, %d failed.", ...
                summary.Succeeded,summary.Attempted,summary.Failed));
        end

        function onAutoFitActiveROI(obj)
            img = obj.Project.ActiveImage;
            % if empty, clear plot and return
            if isempty(img) || isempty(img.ActiveRegion)
                obj.guialert("Title","No region selected","Message","Select a region and try again.","Icon",'error');
                return
            end
            reg = img.ActiveRegion;

            % create progress dialog
            desmostorm.Log.INFO(sprintf("Fitting ROI for region: %s",reg.Name));
            h = uiprogressdlg(obj.Fig, ...
                "Title","Auto-Fit Region ROI", ...
                "Message",'Preparing ROI auto-fit...', ...
                "Indeterminate",'off', ...
                "Value",0);
            cleanup = onCleanup(@() closeProgressDialog(h));
            % re-process everything
            ok = img.autofitRegionROI(reg,obj.getRunConfig(), ...
                "ProgressDialog",h);
            % close the progress dialog
            delete(cleanup);
            if ~ok
                desmostorm.Log.WARN(sprintf("ROI fitting failed for region: %s",reg.Name));
                return
            end
            % reprocess region measurements
            obj.processActiveRegion();
            desmostorm.Log.INFO(sprintf("ROI fitting complete for region: %s",reg.Name));
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
                desmostorm.Paths.ml, ...
                'MultiSelect','off');

            % cancelled -> return
            if isequal(file,0)
                obj.Fig.Visible = 'on';
                return
            end
            % build full file path
            classifierFile = fullfile(path,file);

            % --- load ---
            desmostorm.Log.INFO(sprintf("Loading classifier file: %s",classifierFile));
            pkg = desmostorm.ml.loadClassifierPackage(classifierFile);
            net = pkg.Net;
            propOpts = pkg.PropOpts;
            if ~isfield(propOpts,"CandidateMode")
                propOpts.CandidateMode = "grid";
            elseif string(propOpts.CandidateMode) == "cluster"
                propOpts.CandidateMode = "ClusterCentroid";
            end
            if ~isfield(propOpts,"PositiveClass")
                propOpts.PositiveClass = "object";
            end

            % get proposal options
            params = matlabx.app.ParamsDialog.prompt( ...
                'Class proposal options', ...
                {'Scope','Images','choice',"all",{"all","active"}},...
                {'CandidateMode','CandidateMode','choice',propOpts.CandidateMode,{'grid','ClusterCentroid','ClusterArea'}},...
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

            scope = string(params.Scope);
            switch scope
                case "active"
                    img = obj.Project.ActiveImage;
                    if isempty(img)
                        desmostorm.Log.WARN("Classifier run cancelled: no active image.");
                        return
                    end
                    imgs = img;
                case "all"
                    imgs = obj.Project.ImageArray;
            end

            propOpts.CandidateMode   = string(params.CandidateMode);
            propOpts.Stride         = params.Stride;
            propOpts.ScoreThreshold = params.ScoreThreshold;
            propOpts.NmsIoU         = params.NmsIoU;
            propOpts.BatchSize      = str2double(params.BatchSize);

            % Create one dialog for the whole classifier run. The ML layer
            % updates it with per-image proposal-generation details.
            h = uiprogressdlg(obj.Fig, ...
                "Message",'Preparing classifier proposals...', ...
                "Indeterminate",'off', ...
                "Value",0);
            cleanupProgress = onCleanup(@() closeProgressDialog(h));

            desmostorm.Log.INFO(sprintf([ ...
                'Proposal options: BoxSize=%d, CandidateMode=%s, Stride=%d, ' ...
                'ScoreThreshold=%.3g, NmsIoU=%.3g, BatchSize=%d, PositiveClass=%s'], ...
                propOpts.BoxSize, ...
                char(propOpts.CandidateMode), ...
                propOpts.Stride, ...
                propOpts.ScoreThreshold, ...
                propOpts.NmsIoU, ...
                propOpts.BatchSize, ...
                propOpts.PositiveClass));

            % --- run ---
            N = numel(imgs);
            for i = 1:N
                progressPrefix = sprintf("Image %d/%d: %s | ",i,N,imgs(i).Name);
                h.Message = sprintf("%sRunning classifier...",progressPrefix);
                h.Value = (i-1) / N;
                propOpts.ProgressDialog = h;
                propOpts.ProgressMessagePrefix = string(progressPrefix);
                desmostorm.Log.INFO(sprintf("Running classifier on image (%i/%i): %s",i,N,imgs(i).Name));
                imgs(i).runClassifier(net,propOpts);
            end


            % --- sync UI ---
            obj.syncActiveImageToView();
            obj.markProjectDirty();
            h.Value = 1;
            h.Message = "Classifier run complete.";

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
                {'ValidationFrequency','ValidationFrequency','double',50, @(x) x>=1, 'ValidationFrequency must be >= 1'},...
                {'MiniBatchSize','MiniBatchSize','choice',8,{8,16,32,64,128}});

            % show figure
            obj.Fig.Visible = 'on';
            pause(0.5)

            if isempty(params), return; end

            % Show coarse progress around setup, training, packaging, and save.
            % MATLAB's training-progress window still owns iteration details.
            h = uiprogressdlg(obj.Fig, ...
                "Message","Preparing classifier training...", ...
                "Indeterminate","on");
            cleanupProgress = onCleanup(@() closeProgressDialog(h));

            % --- train a new classifier ---
            desmostorm.Log.INFO(sprintf("Training new classifier: %s",params.BaseName));
            desmostorm.ml.trainNewClassifierFromProject(obj.Project,...
                "BaseName",         params.BaseName, ...
                "MaxEpochs",        params.MaxEpochs, ...
                "InitialLearnRate", params.InitialLearnRate, ...
                "IoUMax",           params.IoUMax, ...
                "ValidationFrequency",params.ValidationFrequency, ...
                "MiniBatchSize",    str2double(params.MiniBatchSize), ...
                "ProgressDialog",   h);


            desmostorm.Log.INFO("Initial training complete.");

        end

        function onContinueTrainingClassifier(obj)
            % --- get file ---
            % hide figure to show file selection dialog
            obj.Fig.Visible = 'off';
            % file selection dialog
            [file, path] = uigetfile( ...
                {'*.mat'}, ...
                'Select classifier file', ...
                desmostorm.Paths.ml, ...
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
                {'ValidationFrequency','ValidationFrequency','double',50, @(x) x>=1, 'ValidationFrequency must be >= 1'},...
                {'MiniBatchSize','MiniBatchSize','choice',8,{8,16,32,64,128}});

            % show figure
            obj.Fig.Visible = 'on';
            pause(0.5)

            if isempty(params), return; end

            % Show coarse progress around setup, training, packaging, and save.
            % MATLAB's training-progress window still owns iteration details.
            h = uiprogressdlg(obj.Fig, ...
                "Message","Preparing classifier retraining...", ...
                "Indeterminate","on");
            cleanupProgress = onCleanup(@() closeProgressDialog(h));

            % --- continue training classifier ---
            desmostorm.Log.INFO(sprintf("Continuing training from: %s",classifierFile));
            desmostorm.ml.continueClassifierTrainingFromProject(obj.Project,classifierFile, ...
                "MaxEpochs",            params.MaxEpochs, ...
                "InitialLearnRate",     params.InitialLearnRate, ...
                "IoUMax",               params.IoUMax, ...
                "ValidationFrequency",  params.ValidationFrequency, ...
                "MiniBatchSize",        str2double(params.MiniBatchSize), ...
                "ProgressDialog",       h);

            desmostorm.Log.INFO("Continued training complete.");
        end

        function onRetrainClassifierFromScratch(obj)
            % --- get file ---
            % hide figure to show file selection dialog
            obj.Fig.Visible = 'off';
            % file selection dialog
            [file, path] = uigetfile( ...
                {'*.mat'}, ...
                'Select classifier file', ...
                desmostorm.Paths.ml, ...
                'MultiSelect','off');

            % cancelled -> return
            if isequal(file,0)
                obj.Fig.Visible = 'on';
                return
            end
            % build full file path
            classifierFile = fullfile(path,file);

            sourceBaseName = desmostorm.ml.classifierBaseNameFromFile(classifierFile);
            defaultBaseName = sourceBaseName + "_scratch";

            % get fresh retraining options
            params = matlabx.app.ParamsDialog.prompt( ...
                'Retrain from scratch options', ...
                {'BaseName','New classifier name','char',char(defaultBaseName), @(x) ~contains(x,' '), 'Name cannot contain spaces'},...
                {'MaxEpochs','MaxEpochs','double',15, @(x) x>=1, 'MaxEpochs must be >= 1'},...
                {'InitialLearnRate','InitialLearnRate','double',0.0003, @(x) x>0, 'InitialLearnRate must be > 0'},...
                {'ValidationFrequency','ValidationFrequency','double',50, @(x) x>=1, 'ValidationFrequency must be >= 1'},...
                {'MiniBatchSize','MiniBatchSize','choice',8,{8,16,32,64,128}});

            % show figure
            obj.Fig.Visible = 'on';
            pause(0.5)

            if isempty(params), return; end

            % Show coarse progress around split, training, packaging, and save.
            % MATLAB's training-progress window still owns iteration details.
            h = uiprogressdlg(obj.Fig, ...
                "Message","Preparing fresh classifier retraining...", ...
                "Indeterminate","on");
            cleanupProgress = onCleanup(@() closeProgressDialog(h));

            % --- retrain classifier from accumulated package data ---
            desmostorm.Log.INFO(sprintf("Retraining classifier from scratch: %s",classifierFile));
            desmostorm.ml.retrainClassifierFromPackage(classifierFile, ...
                "BaseName",             string(params.BaseName), ...
                "MaxEpochs",            params.MaxEpochs, ...
                "InitialLearnRate",     params.InitialLearnRate, ...
                "ValidationFrequency",  params.ValidationFrequency, ...
                "MiniBatchSize",        str2double(params.MiniBatchSize), ...
                "ProgressDialog",       h);

            desmostorm.Log.INFO("Fresh classifier retraining complete.");
        end


    end

    %% Event handlers for Box tool callbacks
    methods (Access=private)

        function onBoxCreated(obj, data)
            % Get active image
            img = obj.Project.ActiveImage; if isempty(img), return; end
            % Get current active label
            L = obj.Project.LabelBank.active();
            % Create a new STORMRegion in the active image with the active label
            img.addRegion(data.ID, data.CenterPx, obj.Settings.Analysis.BoxSize, L.ID, "user");


            % Apply active label color to the newly created box
            obj.ImageViewer.Tools.Box.setBoxColorByID(data.ID, L.Color);
            obj.ImageViewer.Tools.Box.setBoxLabelByID(data.ID, img.getRegion(data.ID).Name);
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
            img.processRegionLinescan(r,obj.getRunConfig());
            % update the region linescan plot
            obj.refreshRegionLinescanPlot();
            % update RegionSummaryTable
            obj.RegionSummaryTable.Data = r.SummaryTable;
            obj.markProjectDirty();
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
                % update listbox
                obj.RegionListBox.Value = regionID;
                % set it as the active region
                img.setActiveRegion(regionID);
            else
                % update listbox
                obj.RegionListBox.Value = {};
                % set active region to empty
                img.setActiveRegion(string.empty());
            end
        end

        function onBoxSelectionChanged(obj, data)
            if obj.isSyncingSelection
                return
            end

            ids = string(data.IDs);
            img = obj.Project.ActiveImage;
            if isempty(img), return; end

            obj.isSyncingSelection = true;

            if isempty(ids)
                img.clearRegionSelection();
            else
                img.setRegionSelection(ids);
            end

            obj.isSyncingSelection = false;
        end

    end

    %% Event handlers for DrawRectangle tool callbacks
    methods (Access=private)

        function onROIPreviewMoved(obj,ROI)
            obj.onROIMoveCommitted(ROI);
        end

        function onROIMoveCommitted(obj,ROI)
            % get the ActiveImage, exit if empty
            img = obj.Project.ActiveImage; if isempty(img), return; end
            % get the ActiveRegion, exit if empty
            reg = img.ActiveRegion; if isempty(reg), return; end
            % update region linescan properties
            reg.updateROI(ROI,"Source","user");
            % process the linescan for this region
            img.processRegionLinescan(reg,obj.getRunConfig());
            % update the region linescan plot
            obj.refreshRegionLinescanPlot();
            % update RegionSummaryTable
            obj.RegionSummaryTable.Data = reg.SummaryTable;
            obj.markProjectDirty();
        end

        function onROIDeleted(obj)
            % exit if project empty
            if isempty(obj.Project), return; end
            % get the ActiveImage, exit if empty
            img = obj.Project.ActiveImage; if isempty(img), return; end
            % get the ActiveRegion, exit if empty
            reg = img.ActiveRegion; if isempty(reg), return; end
            % reset linescan ROI for the active region (also resets linescan results)
            img.resetRegionROI(reg);
            % update linescan
            obj.refreshRegionROI();
            obj.refreshRegionLinescanPlot();
            % update RegionSummaryTable
            obj.RegionSummaryTable.Data = reg.SummaryTable;
            obj.markProjectDirty();
        end

    end

    %% Export data
    methods

        function onExportMeasurements(obj, ~, ~)

            desmostorm.Log.INFO("Exporting region measurements...");
            try
                [h,cleanupProgress] = obj.createExportProgressDialog("Preparing region measurements export..."); %#ok<ASGLU>
                success = desmostorm.export.Exporter.exportRegionMeasurements(obj.Project,obj.Settings, ...
                    "ProgressDialog",h);
                if success
                    desmostorm.Log.INFO("Success.");
                else
                    desmostorm.Log.INFO("Export cancelled.");
                end
            catch ME
                desmostorm.Log.EXCEPTION(ME);
                obj.guialert("Title",'Error',"Message",ME.message,"Icon",'error');
            end
        end

        function onExportSummaryPDF(obj, ~, ~)

            desmostorm.Log.INFO("Exporting summary PDF...");
            try
                [h,cleanupProgress] = obj.createExportProgressDialog("Preparing summary PDF export..."); %#ok<ASGLU>
                success = desmostorm.export.Exporter.exportSummaryPDF(obj.Project,obj.Settings, ...
                    "ProgressDialog",h);
                if success
                    desmostorm.Log.INFO("Success.");
                else
                    desmostorm.Log.INFO("Export cancelled.");
                end
            catch ME
                desmostorm.Log.EXCEPTION(ME);
                obj.guialert("Title",'Error',"Message",ME.message,"Icon",'error');
            end

        end

        function onExportRegionImages(obj, ~, ~)

            desmostorm.Log.INFO("Exporting region images...");
            try
                [h,cleanupProgress] = obj.createExportProgressDialog("Preparing region image export..."); %#ok<ASGLU>
                success = desmostorm.export.Exporter.exportRegionImages(obj.Project,obj.Settings, ...
                    "ProgressDialog",h);
                if success
                    desmostorm.Log.INFO("Success.");
                else
                    desmostorm.Log.INFO("Export cancelled.");
                end
            catch ME
                desmostorm.Log.EXCEPTION(ME);
                obj.guialert("Title",'Error',"Message",ME.message,"Icon",'error');
            end
        end

        function onExportImagesWithRegionBoxes(obj, ~, ~)

            desmostorm.Log.INFO("Exporting images with region box overlays...");
            try
                [h,cleanupProgress] = obj.createExportProgressDialog("Preparing image region box overlay export..."); %#ok<ASGLU>
                success = desmostorm.export.Exporter.exportImagesWithRegionBoxes(obj.Project,obj.Settings, ...
                    "ProgressDialog",h);
                if success
                    desmostorm.Log.INFO("Success.");
                else
                    desmostorm.Log.INFO("Export cancelled.");
                end
            catch ME
                desmostorm.Log.EXCEPTION(ME);
                obj.guialert("Title",'Error',"Message",ME.message,"Icon",'error');
            end
        end

        function onExportLinescanPlot(obj, ~, ~)

            desmostorm.Log.INFO("Exporting region linescan plot...");
            try
                [h,cleanupProgress] = obj.createExportProgressDialog("Preparing linescan plot export..."); %#ok<ASGLU>
                success = desmostorm.export.Exporter.exportRegionLinescanPlot(obj.Project,obj.Settings, ...
                    "CurrentChannel",obj.ImageViewer.C, ...
                    "ProgressDialog",h);
                if success
                    desmostorm.Log.INFO("Success.");
                else
                    desmostorm.Log.INFO("Export cancelled.");
                end
            catch ME
                desmostorm.Log.EXCEPTION(ME);
                obj.guialert("Title",'Error',"Message",ME.message,"Icon",'error');
            end
        end

        function onExportRegionSubimageWithROI(obj, ~, ~)

            desmostorm.Log.INFO("Exporting region subimage with ROI overlay...");
            try
                [h,cleanupProgress] = obj.createExportProgressDialog("Preparing region image export..."); %#ok<ASGLU>
                success = desmostorm.export.Exporter.exportRegionSubimageWithROI(obj.Project,obj.Settings, ...
                    "ProgressDialog",h);
                if success
                    desmostorm.Log.INFO("Success.");
                else
                    desmostorm.Log.INFO("Export cancelled.");
                end
            catch ME
                desmostorm.Log.EXCEPTION(ME);
                obj.guialert("Title",'Error',"Message",ME.message,"Icon",'error');
            end
        end

    end

    %% Export helpers
    methods (Access=private)

        function [h,cleanupProgress] = createExportProgressDialog(obj,msg)
            h = matlab.ui.dialog.ProgressDialog.empty();
            if ~isempty(obj.Fig) && isvalid(obj.Fig)
                h = uiprogressdlg(obj.Fig, ...
                    "Message",msg, ...
                    "Indeterminate","on");
            end

            cleanupProgress = onCleanup(@() closeProgressDialog(h));
        end

    end

    %% Static helpers
    methods (Static)

        function h = findGUI()
            % locate and return handle to GUI figure window
            h = findobj(groot,'Type','figure','Tag',desmostorm.Info.Name);
            % more than one found -> return first
            if numel(h) > 1, h = h(1); end
        end

    end

end

function closeProgressDialog(h)
    if ~isempty(h) && isvalid(h)
        close(h);
    end
end
