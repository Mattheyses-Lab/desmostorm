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
        Ax matlabx.ui.axes.ImageAxes
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

            % --- Log ---
            obj.Log = desmostorm.Log.get();

            desmostorm.Log.INFO("Starting DesmoSTORM...");

            % --- Settings ---
            desmostorm.Log.INFO("Loading settings...");
            try
                obj.Settings = desmostorm.config.Settings.load();
            catch ME
                desmostorm.Log.ERROR(ME); rethrow(ME);
            end

            % --- UICalibration ---
            desmostorm.Log.INFO("Calibrating UI...");
            try obj.setupUICalibration(); catch ME, desmostorm.Log.ERROR(ME); rethrow(ME); end

            % --- Build GUI ---
            desmostorm.Log.INFO("Building GUI...");
            try obj.buildGUI(); catch ME, desmostorm.Log.ERROR(ME); rethrow(ME); end

            % --- Initial UI sync ---
            desmostorm.Log.INFO("Refreshing UI...");
            try obj.refreshUI(); catch ME, desmostorm.Log.ERROR(ME); rethrow(ME); end

            % --- Show figure ---
            desmostorm.Log.INFO("Opening...");
            obj.Fig.Visible = 'on';

            % --- Set UI sink for logger ---

            obj.Log.setUISink(@(lines) obj.onLogFlush(lines));



        end

        function setupUICalibration(obj)
            obj.UICal = matlabx.UICal.get();
        end

        function buildGUI(obj)
            % --- Figure ---
            desmostorm.Log.INFO("Setting up main figure window...");
            try obj.setupFigure(); catch ME, desmostorm.Log.ERROR(ME); rethrow(ME); end

            % --- CommandRouter ---
            desmostorm.Log.INFO("Setting up CommandRouter...");
            try obj.setupCommandRouter(); catch ME, desmostorm.Log.ERROR(ME); rethrow(ME); end

            % --- Menubar ---
            desmostorm.Log.INFO("Setting up Menubar...");
            try obj.setupMenubar(); catch ME, desmostorm.Log.ERROR(ME); rethrow(ME); end

            % --- Grids ---
            desmostorm.Log.INFO("Setting up main grid layout managers...");
            try obj.setupGrids(); catch ME, desmostorm.Log.ERROR(ME); rethrow(ME); end

            % --- Settings controllers ---
            desmostorm.Log.INFO("Setting up settings controllers...");
            try obj.setupSettingsControllers(); catch ME, desmostorm.Log.ERROR(ME); rethrow(ME); end

            % --- Log window ---
            desmostorm.Log.INFO("Setting up log window...");
            try obj.setupLogWindow(); catch ME, desmostorm.Log.ERROR(ME); rethrow(ME); end

            % --- ImageViewer ---
            desmostorm.Log.INFO("Setting up ImageViewer...");
            try obj.setupImageViewer(); catch ME, desmostorm.Log.ERROR(ME); rethrow(ME); end

            % --- RegionViewer ---
            desmostorm.Log.INFO("Setting up RegionViewer...");
            try obj.setupRegionViewer(); catch ME, desmostorm.Log.ERROR(ME); rethrow(ME); end

            % --- RegionSummaryTable ---
            desmostorm.Log.INFO("Setting up RegionSummaryTable...");
            try obj.setupRegionSummaryTable(); catch ME, desmostorm.Log.ERROR(ME); rethrow(ME); end

            % --- RegionLinescanPlot ---
            desmostorm.Log.INFO("Setting up RegionSummaryTable...");
            try obj.setupRegionLinescanPlot(); catch ME, desmostorm.Log.ERROR(ME); rethrow(ME); end

            % center the GUI after defining all graphics components
            movegui(obj.Fig,"center");
        end

        function setupFigure(obj)
            % need to add a more elegant way to set window size once app components are finalized
            s = matlabx.UICal.screenSize();
            % obj.Fig = uifigure(...
            %     'WindowStyle','alwaysontop',...
            %     'Tag',desmostorm.Info.Name,...
            %     'Name','DesmoSTORM',...
            %     'Color',[0 0 0],...
            %     'OuterPosition',s(1,:),...
            %     'Visible','off',...
            %     'Theme','dark',...
            %     'HandleVisibility','on',...
            %     'AutoResizeChildren','off',...
            %     'SizeChangedFcn',@(~,~) obj.refreshComponentSizes(),...
            %     'CloseRequestFcn',@(~,~) obj.onCloseRequest());

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

            obj.MenubarUI.Run_AutoFitROIs       = uimenu(obj.MenubarUI.Run,'Text','Auto-Fit Region ROIs (experimental)...');
            obj.MenubarUI.Run_AutoFitAllROIs    = uimenu(obj.MenubarUI.Run_AutoFitROIs,'Text','All Regions','MenuSelectedFcn',@(~,~) obj.onAutoFitAllROIs());
            obj.MenubarUI.Run_AutoFitActiveROI  = uimenu(obj.MenubarUI.Run_AutoFitROIs,'Text','Active Region Only','MenuSelectedFcn',@(~,~) obj.onAutoFitActiveROI(),'Accelerator','A');

            % --- Test ---
            obj.MenubarUI.Test = uimenu(obj.Fig,'Text','Test');
            obj.MenubarUI.Test_Cluster = uimenu(obj.MenubarUI.Test,'Text','Cluster','MenuSelectedFcn',@(~,~) obj.onTestRegion());
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
            itemTitles = ["Images","Regions","Colormap","Analysis","Image Display","Peaks Plot","Labels"];

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
            desmostorm.Log.INFO("Setting up Images listbox...");
            try obj.setupImagesListBox(); catch ME, desmostorm.Log.ERROR(ME); rethrow(ME); end

            % --- Regions ---
            desmostorm.Log.INFO("Setting up Regions listbox...");
            try obj.setupRegionsListBox(); catch ME, desmostorm.Log.ERROR(ME); rethrow(ME); end

            % Set up SettingsUI struct
            obj.SettingsUI = struct(...
                "Display",struct(),...
                "Analysis",struct(),...
                "PeaksPlot",struct(),...
                "Box",struct());

            % --- Colormap ---
            desmostorm.Log.INFO("Setting up Colormap controls...");
            try obj.setupColormapControls(); catch ME, desmostorm.Log.ERROR(ME); rethrow(ME); end

            % --- Analysis ---
            desmostorm.Log.INFO("Setting up Analysis controls...");
            try obj.setupAnalysisControls(); catch ME, desmostorm.Log.ERROR(ME); rethrow(ME); end

            % --- Image Display ---
            desmostorm.Log.INFO("Setting up Image Display controls...");
            try obj.setupImageDisplayControls(); catch ME, desmostorm.Log.ERROR(ME); rethrow(ME); end

            % --- Peaks Plot ---
            desmostorm.Log.INFO("Setting up Peaks Plot controls...");
            try obj.setupPeaksPlotControls(); catch ME, desmostorm.Log.ERROR(ME); rethrow(ME); end

            % --- Labels ---
            desmostorm.Log.INFO("Setting up Labels controls...");
            try obj.setupLabelsControls(); catch ME, desmostorm.Log.ERROR(ME); rethrow(ME); end

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
                "RowHeight",{'fit','fit','fit','fit'},...
                "ColumnWidth",{'1x'},...
                "RowSpacing",5,...
                "ColumnSpacing",5);

            obj.SettingsUI.Display.AutoScaleDisplayIntensityCheckBox = uicheckbox(item.Pane,...
                "Value",obj.Settings.Display.AutoScaleDisplayIntensity,...
                "ValueChangedFcn",@(o,~) obj.DisplaySettingsChanged(o,"AutoScaleDisplayIntensity"),...
                "Text","Auto-scale display intensity");

            % --- IntensitySliders ---
            desmostorm.Log.INFO("Setting up IntensitySliders...");
            try obj.setupIntensitySliders(); catch ME, desmostorm.Log.ERROR(ME); rethrow(ME); end
        end

        function setupIntensitySliders(obj)
            item = obj.SettingsAccordion.getItem("Image Display");
            for C = 1:3
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
        end

        function setupPeaksPlotControls(obj)
            item = obj.SettingsAccordion.getItem("Peaks Plot");
            % set size and spacing of pane grid
            set(item.Pane,...
                "RowHeight",repmat({'fit'},1,6),...
                "ColumnWidth",{'fit','1x'},...
                "RowSpacing",5,...
                "ColumnSpacing",5);

            uilabel(item.Pane,"Text","Raw Line Color","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.PeaksPlot.RawLineColorPicker = uicolorpicker(...
                'Parent',item.Pane,...
                'Value',obj.Settings.PeaksPlot.RawLineColor,...
                'ValueChangedFcn',@(o,~) obj.PeaksPlotSettingsChanged(o,"RawLineColor"));

            uilabel(item.Pane,"Text","Raw Line Width","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.PeaksPlot.RawLineWidthEditField = uieditfield(...
                item.Pane,...
                "numeric",...
                "ValueChangedFcn",@(o,~) obj.PeaksPlotSettingsChanged(o,"RawLineWidth"),...
                "Value",obj.Settings.PeaksPlot.RawLineWidth);

            uilabel(item.Pane,"Text","Smooth Line Color","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.PeaksPlot.SmoothLineColorPicker = uicolorpicker(...
                'Parent',item.Pane,...
                'Value',obj.Settings.PeaksPlot.SmoothLineColor,...
                'ValueChangedFcn',@(o,~) obj.PeaksPlotSettingsChanged(o,"SmoothLineColor"));

            uilabel(item.Pane,"Text","Smooth Line Width","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.PeaksPlot.SmoothLineWidthEditField = uieditfield(...
                item.Pane,...
                "numeric",...
                "ValueChangedFcn",@(o,~) obj.PeaksPlotSettingsChanged(o,"SmoothLineWidth"),...
                "Value",obj.Settings.PeaksPlot.SmoothLineWidth);

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
            obj.Ax = matlabx.ui.axes.ImageAxes(obj.ImageViewerPanelGrid,...
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

            %obj.Ax.ImageVisible = 'off';
            %obj.Ax.AxesVisible = 'on';
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

            obj.RegionLinescanPanelGrid = uigridlayout(obj.RegionLinescanPanel,[2,1],...
                "RowHeight",{'1x',0},...
                "RowSpacing",0,...
                "ColumnWidth",{'1x'},...
                "Padding",[0 0 0 0]);

            obj.RegionLinescanPlot(1) = desmostorm.widgets.PeaksPlotContainer(obj.RegionLinescanPanelGrid,...
                "RawLineWidth",obj.Settings.PeaksPlot.RawLineWidth, ...
                "RawLineColor",obj.Settings.PeaksPlot.RawLineColor, ...
                "SmoothLineWidth",obj.Settings.PeaksPlot.SmoothLineWidth, ...
                "SmoothLineColor",obj.Settings.PeaksPlot.SmoothLineColor, ...
                "BackgroundColor",obj.Settings.PeaksPlot.BackgroundColor, ...
                "ForegroundColor",obj.Settings.PeaksPlot.ForegroundColor, ...
                "XLabel",sprintf("Distance (%s)",obj.Settings.Analysis.PixelSizeUnit), ...
                "YLabel","Normalized Intensity");

            obj.RegionLinescanPlot(2) = desmostorm.widgets.PeaksPlotContainer(obj.RegionLinescanPanelGrid,...
                "RawLineWidth",obj.Settings.PeaksPlot.RawLineWidth, ...
                "RawLineColor",obj.Settings.PeaksPlot.RawLineColor, ...
                "SmoothLineWidth",obj.Settings.PeaksPlot.SmoothLineWidth, ...
                "SmoothLineColor",obj.Settings.PeaksPlot.SmoothLineColor, ...
                "BackgroundColor",obj.Settings.PeaksPlot.BackgroundColor, ...
                "ForegroundColor",obj.Settings.PeaksPlot.ForegroundColor, ...
                "XLabel",sprintf("Distance (%s)",obj.Settings.Analysis.PixelSizeUnit), ...
                "YLabel","Normalized Intensity", ...
                "Visible","off");

        end

        function delete(obj)
            % if ~isempty(obj.L), delete(obj.L(isvalid(obj.L))); end

            % delete the logger
            % clear static facade first
            desmostorm.Log.clear();
            if ~isempty(obj.Log), delete(obj.Log(isvalid(obj.Log))); end


            if ~isempty(obj.projectL), delete(obj.projectL(isvalid(obj.projectL))); end
            if ~isempty(obj.settingsL), delete(obj.settingsL(isvalid(obj.settingsL))); end
            if ~isempty(obj.Ax) && isvalid(obj.Ax), delete(obj.Ax); end
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

        function onTestRegion(obj)
            img = obj.Project.ActiveImage;
            % if empty, return
            if isempty(img) || isempty(img.ActiveRegion)
                return
            end

            % get active region CData
            I = img.regionSubimage(img.ActiveRegion);

            desmostorm.analysis.image.detectPlaques(I,"DisplayClusterOutput",true);
        end

        function onLogFlush(obj,lines)
            nOld = numel(obj.LogTextArea.Value);
            obj.LogTextArea.Value(nOld+1:nOld+numel(lines)) = cellstr(lines);
            scroll(obj.LogTextArea,"bottom");
        end

        function onCloseRequest(obj)
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
            if isempty(obj.Project)
                obj.Fig.Name = sprintf("%s (%s)",desmostorm.Info.Name,desmostorm.Info.Version);
            else
                obj.Fig.Name = sprintf("%s (%s) - %s",desmostorm.Info.Name,desmostorm.Info.Version,obj.Project.Name);
            end
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
            obj.SettingsUI.Analysis.MinPeakProminenceEditField.Value = S.Analysis.MinPeakProminence;
            obj.SettingsUI.Analysis.NormalizeDropDown.Value = S.Analysis.Normalize;
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
            set(obj.IntensitySliders,'Limits',[0 1],'Value',[0 1]);
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
                % Regions
                obj.projectL(4) = addlistener(obj.Project,'RegionAdded',            @(~,~) obj.onRegionAdded());
                obj.projectL(5) = addlistener(obj.Project,'RegionRemoved',          @(~,~) obj.onRegionRemoved());
                obj.projectL(6) = addlistener(obj.Project,'ActiveRegionChanged',    @(~,~) obj.onActiveRegionChanged());
                obj.projectL(7) = addlistener(obj.Project,'RegionSelectionChanged', @(~,~) obj.onRegionSelectionChanged());
                % Labels
                obj.projectL(8) = addlistener(obj.Project,'LabelsChanged',          @(~,~) obj.onLabelsChanged());
            end
            % Settings
            obj.settingsL(1) = addlistener(obj.Settings,'DisplayChanged',   @(~,e) obj.onDisplayChanged(e));
            obj.settingsL(2) = addlistener(obj.Settings,'AnalysisChanged',  @(~,e) obj.onAnalysisChanged(e));
            obj.settingsL(3) = addlistener(obj.Settings,'IOChanged',        @(~,e) obj.onIOChanged(e));
            obj.settingsL(4) = addlistener(obj.Settings,'PeaksPlotChanged', @(~,e) obj.onPeaksPlotChanged(e));
            obj.settingsL(5) = addlistener(obj.Settings,'BoxChanged',       @(~,e) obj.onBoxChanged(e));
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
            % LabelsTree
            obj.clearLabelsTree();
        end

    end

    %% Other helpers
    methods (Access=private)

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
            desmostorm.Log.INFO("Image added.")
        end

        function onImageRemoved(obj)
        %ONIMAGEREMOVED ImageRemoved event callback    
            obj.refreshImageListBox();
            desmostorm.Log.INFO("Image removed.")
        end

        function onActiveImageChanged(obj)
        %ONACTIVEIMAGECHANGED ActiveImageChanged event callback
            obj.syncActiveImageToView();
            desmostorm.Log.INFO("Active Image changed.")
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
            if isempty(img), obj.Ax.CData = []; return, end
            % get channel index of ImageViewer
            C = obj.Ax.C;
            % get CLim
            switch obj.Settings.Display.AutoScaleDisplayIntensity
                case true
                    clim = img.getAutoDisplayRange(C);
                case false
                    clim = img.getDisplayRange(C);
            end

            % update ImageViewer CData and CLim
            obj.Ax.ImageData = img.ImageData;
            obj.Ax.setCLim(clim,C);
            obj.refreshIntensitySliders();
        end

        function clearImageViewer(obj)
        %REFRESHIMAGEVIEWER Reset ImageViewer
            obj.Ax.CData = [];
            obj.Ax.Tools.Pick.clearBoxes();
        end

        function refreshRegionBoxes(obj)
        %REFRESHREGIONBOXES Sync Region boxes in ImageViewer to ActiveImage

            % clear boxes from ImageViewer
            obj.Ax.Tools.Pick.clearBoxes();

            img = obj.Project.ActiveImage;

            if isempty(img) || isempty(img.RegionArray)
                return
            end

            % % add a box for each region, colored according to its label
            % regs = img.RegionArray;
            % for i = 1:numel(regs)
            %     r = regs(i);
            %     boxColor = obj.Project.LabelBank.getByID(r.LabelID).Color;
            %     obj.Ax.Tools.Pick.addBox(r.ID, r.Center, r.BoxSize, ...
            %         "EdgeColor", boxColor, "FaceColor", boxColor, "Label", r.Name);
            % end


            % add a box for each region, colored according to its label
            for r = img.RegionArray'
                boxColor = obj.Project.LabelBank.getByID(r.LabelID).Color;
                obj.Ax.Tools.Pick.addBox(r.ID, r.Center, r.BoxSize, ...
                    "EdgeColor", boxColor, "FaceColor", boxColor, "Label", r.Name);
            end



            % apply selection status to region boxes
            obj.Ax.Tools.Pick.setSelectedBoxIDs(img.SelectedRegionIDs);
            % set active box
            obj.Ax.Tools.Pick.setActiveBoxID(img.ActiveRegionID);
        end

        function refreshIntensitySliders(obj)
        %REFRESHINTENSITYSLIDERS Sync intensity sliders to ActiveImage
            % get the active image
            img = obj.Project.ActiveImage;
            % if empty, reset sliders and return
            if isempty(img)
                obj.resetIntensitySliders();
                return
            end

            for C = 1:numel(obj.IntensitySliders)
                if C > img.SizeC
                    obj.IntensitySliders(C).Visible = 'off';
                    continue
                end
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

        end

        function resetIntensitySliders(obj)
        %RESETINTENSITYSLIDERS Reset IntensitySliders    
            set(obj.IntensitySliders,'Limits',[0 1],'Value',[0 1]);
            set(obj.IntensitySliders(2:3),'Visible','off');
        end


    end

    %% Listener callbacks / UI sync (Regions)
    methods (Access=private)

        % --- LISTENER CALLBACKS ---
        function onRegionAdded(obj)
        %ONREGIONADDED RegionAdded event callback
            obj.refreshRegionListBox();
            desmostorm.Log.INFO("Region added.")
        end

        function onRegionRemoved(obj)
        %ONREGIONREMOVED RegionRemoved event callback    
            obj.refreshRegionListBox();
            desmostorm.Log.INFO("Region removed.")
        end

        function onActiveRegionChanged(obj)
        %ONACTIVEREGIONCHANGED ActiveRegionChanged event callback
            obj.syncActiveRegionToView();
            desmostorm.Log.INFO("Active Region changed.")
        end

        function onRegionSelectionChanged(obj)
        %ONREGIONSELECTIONCHANGED RegionSelectionChanged event callback
            obj.refreshRegionListBox();
            desmostorm.Log.INFO("Region selection changed.")
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
                obj.Ax.Tools.Pick.setActiveBoxID(reg.ID);
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
            obj.Ax.Tools.Pick.setActiveBoxID(id);
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
                % set new active region in model, event will drive UI sync
                % obj.RegionListBox.Value = img.RegionOrder(1);
                img.setActiveRegion(img.RegionOrder(1));
            end
        end

        function clearRegionListBox(obj)
        %CLEARREGIONLISTBOX Reset RegionListBox
            set(obj.RegionListBox,"Items",{},"ItemsData",{},"Value",{});
        end

        function refreshRegionViewer(obj)
        %REFRESHREGIONVIEWER Sync RegionViewer to ActiveRegion
            img = obj.Project.ActiveImage;
            % if empty, clear view and return
            if isempty(img) || isempty(img.ActiveRegion)
                obj.clearRegionViewer(); return
            end
            % get channel index from RegionViewer
            C = obj.RegionViewer.C;
            % update ImageViewer CData and CLim
            switch obj.Settings.Display.AutoScaleDisplayIntensity
                case true
                    clim = img.getAutoDisplayRange(C);
                case false
                    clim = img.getDisplayRange(C);
            end

            obj.RegionViewer.CData = img.regionSubimageCell(img.ActiveRegion);
            obj.RegionViewer.setCLim(clim,C);
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

            % get active Image
            img = obj.Project.ActiveImage;

            % if empty, clear plot and return
            if isempty(img) || isempty(img.ActiveRegion)
                obj.clearRegionLinescanPlot(); return
            end

            % get active Region
            reg = img.ActiveRegion;

            nRegionChannels = numel(reg.LinescanResults);

            for C = 1:numel(obj.RegionLinescanPlot)

                if C > nRegionChannels
                    set(obj.RegionLinescanPlot(C:end),"Visible","off");
                    obj.RegionLinescanPanelGrid.RowHeight(C:end) = {0};
                    break
                else
                    obj.RegionLinescanPlot(C).Visible = 'on';
                    obj.RegionLinescanPanelGrid.RowHeight(C) = {'1x'};
                end

                if obj.Settings.Analysis.Normalize
                    obj.RegionLinescanPlot(C).YLabel = "Normalized intensity";
                else
                    obj.RegionLinescanPlot(C).YLabel = "Intensity";
                end

                obj.RegionLinescanPlot(C).XLabel = sprintf("Distance (%s)",img.PixelSize.Unit);
                obj.RegionLinescanPlot(C).Data = reg.LinescanResults(C);
                obj.RegionLinescanPlot(C).Title = matlabx.utils.text.texFriendly(img.Name) + " | " + reg.Name + "(" + img.ImageData.Components(C).Name + ")";
            end

        end

        function clearRegionLinescanPlot(obj)
        %CLEARREGIONLINESCANPLOT Reset RegionLinescanPlot
            set(obj.RegionLinescanPlot,'Data',desmostorm.analysis.PeaksData.empty(),'Title','');
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

            % refresh region table
            obj.refreshRegionSummaryTable();
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




    end

    %% Callbacks / UI sync (Settings)
    methods (Access=private)

        function onDisplayChanged(obj,e)
            switch e.Name
                case "Colormap"
                    cmap = obj.Settings.Display.Colormap;
                    obj.ExampleColormapAxes.Colormap = cmap;

                    C = obj.Ax.C;
                    obj.Ax.setColormap(cmap,C);

                    if C <= obj.RegionViewer.NumComponents
                        obj.RegionViewer.setColormap(cmap,C);
                    end

                    % obj.Ax.Colormap = obj.Settings.Display.Colormap;
                    % obj.RegionViewer.Colormap = obj.Settings.Display.Colormap;
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
            %obj.RegionLinescanPlot.(e.Name) = obj.Settings.PeaksPlot.(e.Name);
            set(obj.RegionLinescanPlot,e.Name,obj.Settings.PeaksPlot.(e.Name));
        end

        function onBoxChanged(obj,e)
            % do something
        end

        function onAnalysisChanged(obj,e)
            switch e.Name
                case {"MinPeakDistance","MinPeakHeight","MinPeakProminence","PeakSmoothing","Normalize"}
                    % immediately re-process all existing regions when analysis settings change
                    obj.processAllRegions();
                case "BoxSize"
                    % delete all existing Regions
                    obj.Project.removeAllRegions();
                    % refresh the display for the current image
                    obj.syncActiveImageToView();
                    obj.refreshRegionROI();
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

        function DisplaySettingsChanged(obj,src,stgName)
            % apply the specified setting
            obj.Settings.Display.(stgName) = src.Value;
        end

    end

    %% Callbacks (Menubar)
    methods (Access=private)

        function onNew(obj)
        %ONNEW MenuSelectedCallback for [File]->[New]
            % cleanup before starting new
            obj.Project.delete();
            obj.Settings.delete();
            obj.detatchListeners();
            % new Settings
            obj.Settings = desmostorm.config.Settings.load();
            % new Project
            obj.Project = desmostorm.model.STORMProject("untitled");
            obj.Project.DefaultPixelSize = obj.Settings.Analysis.getDefaultPixelSize();
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
            % cleanup before loading
            obj.Project.delete();   % delete project
            obj.Settings.delete();  % delete settings
            obj.detatchListeners(); % detach listeners
            % load Project and Settings
            [proj,stgs] = desmostorm.model.STORMProject.load(fname);
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
            % close progress dialog
            close(h);
            % update log
            desmostorm.Log.INFO(sprintf("Successfully loaded project file: %s",fname));
        end

        function onClose(obj)
        %ONOPEN MenuSelectedCallback for [File]->[Close]
            % no project -> return
            if isempty(obj.Project), return; end
            % --- delete project, detach listeners, refresh UI ---
            obj.Project.delete(); 
            obj.Project = desmostorm.model.STORMProject.empty(); % set empty so we do not store old handle
            obj.detatchListeners();
            obj.refreshUI();
        end

        function onSave(obj)
        %ONSAVE MenuSelectedCallback for [File]->[Save...]    
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
            % save the project
            obj.Project.save(fname,obj.Settings);
            % refresh the window name
            obj.refreshWindowName();
            % clost progress dialog
            close(h);
            % update log
            desmostorm.Log.INFO(sprintf("Successfully saved project file: %s",fname));
        end

        function onSaveSettings(obj)
        %ONSAVESETTINGS MenuSelectedCallback for [File]->[Save Settings]        
            obj.Settings.save(); % save current settings to default file
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
        end

    end

    %% Per-image settings
    methods (Access=private)

        function onIntensitySliderChanging(obj,~,C)
            % get the active image
            img = obj.Project.ActiveImage;
            if isempty(img), return; end

            % set MaxRenderedResolution for smoother updates in ImageViewer, RegionViewer
            obj.Ax.MaxRenderedResolution = obj.Ax.CDataSize(1)/4;
            obj.RegionViewer.MaxRenderedResolution = obj.Settings.Analysis.BoxSize/4;

            % set the new CLim for both axes
            clim = obj.IntensitySliders(C).Value;
            obj.Ax.setCLim(clim,C);
            if C <= obj.RegionViewer.NumComponents
                obj.RegionViewer.setCLim(clim,C);
            end
        end

        function onIntensitySliderChanged(obj,~,C)
            % get the active image
            img = obj.Project.ActiveImage;
            if isempty(img), return; end

            % update model with slider value
            newVal = obj.IntensitySliders(C).Value;
            img.setDisplayRange(newVal,C);

            % update view
            obj.Ax.setCLim(newVal,C);
            if C <= obj.RegionViewer.NumComponents
                obj.RegionViewer.setCLim(newVal,C);
            end

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
            img.processRegionLinescan(reg,obj.getRunConfig());
            % sync UI
            obj.syncActiveRegionToView();
        end

        function processAllRegions(obj)
            % create progress dialog
            h = uiprogressdlg(obj.Fig,"Message",'Analyzing ROIs. Please wait...','Indeterminate','on');
            % re-process everything
            obj.Project.processAll(obj.getRunConfig())
            % close the progress dialog
            close(h);
            % sync UI
            obj.syncActiveImageToView();
        end

        function onAutoFitAllROIs(obj)
            % create progress dialog
            h = uiprogressdlg(obj.Fig,"Message",'Fitting ROIs. Please wait...','Indeterminate','on');
            % re-process everything
            obj.Project.autofitAllRegionROIs(obj.getRunConfig())
            % close the progress dialog
            close(h);

            % reprocess region measurements
            obj.processAllRegions();
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
            h = uiprogressdlg(obj.Fig,"Message",'Fitting ROI. Please wait...','Indeterminate','on');
            % re-process everything
            img.autofitRegionROI(reg,obj.getRunConfig());
            % close the progress dialog
            close(h);
            % reprocess region measurements
            obj.processActiveRegion();
        end

        function onAutopickRegions(obj)
            % create progress dialog
            h = uiprogressdlg(obj.Fig,"Message",'Please wait...','Indeterminate','on');
            % detect regions for the active image
            obj.Project.detectRegions(obj.getRunConfig(),h);
            % close the progress dialog
            close(h);
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
                desmostorm.Log.INFO(sprintf("Running classifier on image (%i/%i): %s",i,N,imgs(i).Name));
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
            desmostorm.Log.INFO(sprintf("Training new classifier: %s",params.BaseName));
            desmostorm.ml.trainNewClassifierFromProject(obj.Project,...
                "BaseName",         params.BaseName, ...
                "MaxEpochs",        params.MaxEpochs, ...
                "InitialLearnRate", params.InitialLearnRate, ...
                "IoUMax",           params.IoUMax, ...
                "MiniBatchSize",    str2double(params.MiniBatchSize));


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
                {'MiniBatchSize','MiniBatchSize','choice',8,{8,16,32,64,128}});

            % show figure
            obj.Fig.Visible = 'on';
            pause(0.5)

            if isempty(params), return; end

            % --- continue training classifier ---
            desmostorm.Log.INFO(sprintf("Continuing training from: %s",classifierFile));
            desmostorm.ml.continueClassifierTrainingFromProject(obj.Project,classifierFile, ...
                "MaxEpochs",            params.MaxEpochs, ...
                "InitialLearnRate",     params.InitialLearnRate, ...
                "IoUMax",               params.IoUMax, ...
                "MiniBatchSize",        str2double(params.MiniBatchSize));

            desmostorm.Log.INFO("Continued training complete.");
        end


    end

    %% Event handlers for Pick tool callbacks
    methods (Access=private)

        function onBoxCreated(obj, data)
            % Get active image
            img = obj.Project.ActiveImage; if isempty(img), return; end
            % Get current active label
            L = obj.Project.LabelBank.active();
            % Create a new STORMRegion in the active image with the active label
            img.addRegion(data.ID, data.CenterPx, obj.Settings.Analysis.BoxSize, L.ID, "user");


            % Apply active label color to the newly created box
            obj.Ax.Tools.Pick.setBoxColorByID(data.ID, L.Color);
            obj.Ax.Tools.Pick.setBoxLabelByID(data.ID, img.getRegion(data.ID).Name);
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
                obj.RegionListBox.Value = [];
                % set active region to empty
                img.setActiveRegion(string.empty(1,0));
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
                %obj.RegionListBox.Value = ids;        % multi-select
                img.setRegionSelection(ids);
                %img.setActiveRegion(ids(end));        % last in selection is active
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
            reg.updateROI(ROI);
            % process the linescan for this region
            img.processRegionLinescan(reg,obj.getRunConfig());
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
            img.resetRegionROI(reg);
            % update linescan
            obj.refreshRegionROI();
            obj.refreshRegionLinescanPlot();
            % update RegionSummaryTable
            obj.RegionSummaryTable.Data = reg.SummaryTable;
        end

    end

    %% Export data
    methods

        function onExportMeasurements(obj, ~, ~)

            obj.Fig.Visible = 'off';

            defaultName = fullfile(obj.Settings.IO.DefaultFolder, 'region_measurements.xlsx');
            [file, path] = uiputfile('*.xlsx', ...
                'Export region measurements', defaultName);

            obj.Fig.Visible = 'on';

            if isequal(file,0)
                return;  % user cancelled
            end

            fname = fullfile(path, file);
            obj.Project.exportRegionTableToXlsx(fname);
        end

        function onExportSummaryPDF(obj, ~, ~)

            obj.Fig.Visible = 'off';

            defaultName = fullfile(obj.Settings.IO.DefaultFolder, 'peak_plots.pdf');
            [file, path] = uiputfile('*.pdf', ...
                'Export peak plots', defaultName);

            obj.Fig.Visible = 'on';

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

            p = desmostorm.widgets.PeaksPlotContainer(g,...
                "RawLineWidth",obj.Settings.PeaksPlot.RawLineWidth, ...
                "RawLineColor",obj.Settings.PeaksPlot.RawLineColor, ...
                "SmoothLineWidth",obj.Settings.PeaksPlot.SmoothLineWidth, ...
                "SmoothLineColor",obj.Settings.PeaksPlot.SmoothLineColor, ...
                "BackgroundColor",obj.Settings.PeaksPlot.BackgroundColor, ...
                "ForegroundColor",obj.Settings.PeaksPlot.ForegroundColor, ...
                "XLabel",sprintf("Distance (%s)",obj.Settings.Analysis.PixelSizeUnit), ...
                "YLabel","Normalized Intensity",...
                "FontSize",10);
            p.Layout.Row = [1 2];
            p.Layout.Column = 1;

            % ImageAxes to show region CData and ROI position
            ax = matlabx.ui.axes.ImageAxes(g,...
                'Name','RegionViewer',...
                'ToolBox',{'DrawRectangle'},...
                'ToolBelt',{'DrawRectangle'},...
                'Colormap',obj.Settings.Display.Colormap,...
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
            h = uiprogressdlg(obj.Fig,"Message",'Exporting peak plots. Please wait...','Indeterminate','on');

            imgs = obj.Project.ImageArray;

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
                    switch obj.Settings.Display.AutoScaleDisplayIntensity
                        case true
                            ax.CLim = imgs(i).AutoDisplayRange;
                        case false
                            ax.CLim = imgs(i).DisplayRange;
                    end

                    % update linescan ROI position
                    ax.Tools.DrawRectangle.setROIPosition(regs(j).ROI);

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

        function onExportLinescanPlot(obj, ~, ~)

            % cleanup upon function completion
            c = onCleanup(@() figure(obj.Fig));

            desmostorm.Log.INFO("Exporting region linescan plot...");
            try
                success = desmostorm.export.Exporter.exportRegionLinescanPlot(obj.Project,obj.Settings);
                if success
                    desmostorm.Log.INFO("Success.");
                else
                    desmostorm.Log.INFO("Export cancelled.");
                end
            catch ME
                desmostorm.Log.ERROR(ME);
                obj.guialert("Title",'Error',"Message",ME.message,"Icon",'error');
            end
        end

        function onExportRegionSubimageWithROI(obj, ~, ~)

            % cleanup upon function completion
            c = onCleanup(@() figure(obj.Fig));

            desmostorm.Log.INFO("Exporting region subimage with ROI overlay...");
            try
                success = desmostorm.export.Exporter.exportRegionSubimageWithROI(obj.Project,obj.Settings);
                if success
                    desmostorm.Log.INFO("Success.");
                else
                    desmostorm.Log.INFO("Export cancelled.");
                end
            catch ME
                desmostorm.Log.ERROR(ME);
                obj.guialert("Title",'Error',"Message",ME.message,"Icon",'error');
            end
        end


    end

    %% Static helpers
    methods (Static)

        function h = findGUI()
            % locate and return handle to GUI figure window
            h = findobj(groot,'Tag',desmostorm.Info.Name);
            % more than one found -> return first
            if numel(h) > 1, h = h(1); end
        end

    end

end
