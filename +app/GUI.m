classdef GUI < handle
% app.GUI - GUI controller

    % add Transient and NonCopyable attributes?
    properties (Access=private)
        % --- window and grids ---
        Fig matlab.ui.Figure
        Grid matlab.ui.container.GridLayout
        LeftPane matlab.ui.container.GridLayout
        RegionGrid matlab.ui.container.GridLayout

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
        % active image
        ImageViewerPanel matlab.ui.container.Panel
        ImageViewerPanelGrid matlab.ui.container.GridLayout
        Ax widgets.ImageAxes
        % active region
        RegionViewerPanel matlab.ui.container.Panel
        RegionViewerPanelGrid matlab.ui.container.GridLayout
        RegionViewer widgets.ImageAxes

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
        SettingsUI struct

        SettingsAccordion widgets.uiaccordion
        ExampleColormapPanel matlab.ui.container.Panel
        ExampleColormapAxes matlab.ui.control.UIAxes
        ExampleColormapImage matlab.graphics.primitive.Image
        ColormapTree matlab.ui.container.Tree
        IntensitySlider widgets.uirangeslidereditfield

    end


    % Menu-related graphics components
    properties (Access=private)

        MenubarUI struct

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

    %% Public properties

    % Model (Project), processing settings
    properties
        Project model.STORMProject
        Settings app.config.Settings
    end

    %% Constructor/Destructor
    methods

        function obj = GUI()

            % %% --- Settings ---
            obj.Settings = app.config.Settings.load();

            % %% --- Model ---
            % obj.Project = model.STORMProject("untitled");
            % obj.Project.DefaultPixelSize = obj.Settings.Analysis.getDefaultPixelSize();

            %% --- Figure ---
            % need to add a more elegant way to set window size once app components are finalized
            s = utils.getScreenSize();
            s(4) = 0.45*s(3);
            obj.Fig  = uifigure('Name','DesmoSTORM',...
                'Color',[0 0 0],...
                'Position',s(1,:),...
                'WindowStyle','alwaysontop',...
                'Visible','off',...
                'Theme','dark');

            %% --- Menubar ---

            % Set up MenubarUI struct
            obj.MenubarUI = struct(...
                "File",struct(),...
                "Run",struct());

            % --- File ---
            %mFile = uimenu(obj.Fig,'Text','File');
            % uimenu(mFile,'Text','New',  'MenuSelectedFcn',@(~,~) obj.onNew());
            % uimenu(mFile,'Text','Open', 'MenuSelectedFcn',@(~,~) obj.onOpen());
            % uimenu(mFile,'Text','Close','MenuSelectedFcn',@(~,~) obj.onClose());
            % uimenu(mFile,'Text','Save', 'MenuSelectedFcn',@(~,~) obj.onSave(),'Separator','on');


            obj.MenubarUI.File       = uimenu(obj.Fig,'Text','File');
            obj.MenubarUI.File_New   = uimenu(obj.MenubarUI.File,'Text','New',  'MenuSelectedFcn',@(~,~) obj.onNew());
            obj.MenubarUI.File_Open  = uimenu(obj.MenubarUI.File,'Text','Open', 'MenuSelectedFcn',@(~,~) obj.onOpen());
            obj.MenubarUI.File_Close = uimenu(obj.MenubarUI.File,'Text','Close','MenuSelectedFcn',@(~,~) obj.onClose());
            obj.MenubarUI.File_Save  = uimenu(obj.MenubarUI.File,'Text','Save', 'MenuSelectedFcn',@(~,~) obj.onSave(),'Separator','on');



            % --- separator ---
            % uimenu(mFile,'Text','Save Settings','MenuSelectedFcn',@(~,~) obj.onSaveSettings(),'Separator','on');
            obj.MenubarUI.File_SaveSettings = uimenu(obj.MenubarUI.File,'Text','Save Settings','MenuSelectedFcn',@(~,~) obj.onSaveSettings(),'Separator','on');
            % --- separator ---
            % uimenu(mFile,'Text','Load Images','MenuSelectedFcn',@(~,~) obj.onLoadImages());
            obj.MenubarUI.File_LoadImages = uimenu(obj.MenubarUI.File,'Text','Load Images','MenuSelectedFcn',@(~,~) obj.onLoadImages());
            % --- File -> Export ---
            % mFileExport = uimenu(mFile,'Text','Export');
            % uimenu(mFileExport,'Text','Measurements (.xlsx)', 'MenuSelectedFcn',@(~,~) obj.onExportMeasurements());
            % uimenu(mFileExport,'Text','Peak Plots (.pdf)',    'MenuSelectedFcn',@(~,~) obj.onExportPeakPlots());

            obj.MenubarUI.File_Export = uimenu(obj.MenubarUI.File,'Text','Export');
            obj.MenubarUI.File_Export_Measurements = uimenu(obj.MenubarUI.File_Export,'Text','Measurements (.xlsx)', 'MenuSelectedFcn',@(~,~) obj.onExportMeasurements());
            obj.MenubarUI.File_Export_PeakPlots    = uimenu(obj.MenubarUI.File_Export,'Text','Peak Plots (.pdf)',    'MenuSelectedFcn',@(~,~) obj.onExportPeakPlots());


            % --- Run ---
            % mRun = uimenu(obj.Fig,'Text','Run');
            % uimenu(mRun,'Text','Auto-pick Regions (experimental)...','MenuSelectedFcn',@(~,~) obj.onAutopickRegions());
            obj.MenubarUI.Run = uimenu(obj.Fig,'Text','Run');
            obj.MenubarUI.Run_Autopick = uimenu(obj.MenubarUI.Run,'Text','Auto-pick Regions (experimental)...','MenuSelectedFcn',@(~,~) obj.onAutopickRegions());



            %% --- Layout ---
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

            %% --- Settings controllers ---
            % create the accordion and parent it to the grid
            obj.SettingsAccordion = widgets.uiaccordion(obj.LeftPane,...
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
                'Items',string.empty(1,0),...
                'ItemsData',string.empty(1,0),...
                'Value',string.empty(1,0),...
                'ValueChangedFcn',@(lb,~) obj.onSelectRegion(lb.Value),...
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
            categories = app.colormaps.Registry.categories;

            for i = 1:numel(categories)
                thisCategory = categories(i);
                catNode = uitreenode("Parent",obj.ColormapTree,"Text",thisCategory);

                names = app.colormaps.Registry.names(thisCategory);

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

            obj.IntensitySlider = widgets.uirangeslidereditfield(obj.SettingsAccordion.Items(5).Pane,...
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

            %% --- ImageViewer ---
            obj.ImageViewerPanel = uipanel(obj.Grid,'Title','Image Viewer','BackgroundColor',[0.12 0.12 0.12]);
            obj.ImageViewerPanel.Layout.Column = 2;
            obj.ImageViewerPanel.Layout.Row = [1 2];

            obj.ImageViewerPanelGrid = uigridlayout(obj.ImageViewerPanel,[1 1],...
                "ColumnWidth",{'1x'},...
                "RowHeight",{'1x'},...
                "Padding",[0 0 0 0]);

            % ImageAxes to view active image CData, select Regions
            obj.Ax = widgets.ImageAxes(obj.ImageViewerPanelGrid,...
                'Name','ImageViewer',...
                'ToolBox',{'Zoom','Pick','Colorbar'},...
                'ToolBelt',{'Zoom','Pick','Colorbar'},...
                'Colormap',obj.Settings.Display.Colormap,...
                'CLim',[0 1],...
                'CData',[]);

            % wire the optimistic callbacks for ImageViewer Pick tool
            obj.Ax.Tools.Pick.BoxCreatedFcn       = @(~,d) obj.onBoxCreated(d);
            obj.Ax.Tools.Pick.BoxMoveStartedFcn   = @(~,d) obj.onBoxMoveStarted(d);
            obj.Ax.Tools.Pick.BoxPreviewMovedFcn  = @(~,d) obj.onBoxPreviewMoved(d);   % optional
            obj.Ax.Tools.Pick.BoxMoveCommittedFcn = @(~,d) obj.onBoxMoveCommitted(d);
            obj.Ax.Tools.Pick.BoxDeletedFcn       = @(~,d) obj.onBoxDeleted(d);
            obj.Ax.Tools.Pick.BoxActivatedFcn     = @(~,d) obj.onBoxActivated(d);

            % set the box size for Pick tool
            obj.Ax.Tools.Pick.BoxSize = obj.Settings.Analysis.BoxSize;

            %% --- RegionViewer ---

            % separate gridlayout object for the Region area
            obj.RegionGrid = uigridlayout(obj.Grid,[1 1],...
                "ColumnWidth",{'1x'},...
                "RowHeight",{'1x'},...
                "Padding",[0 0 0 0],...
                "ColumnSpacing",5,...
                "RowSpacing",5);
            obj.RegionGrid.Layout.Column = 3;
            obj.RegionGrid.Layout.Row = [1 2];

            % --- RegionViewer ---
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
            obj.RegionViewer = widgets.ImageAxes(obj.RegionViewerPanelGrid,...
                'Name','RegionViewer',...
                'ToolBox',{'DrawRectangle'},...
                'ToolBelt',{'DrawRectangle'},...
                'Colormap',obj.Settings.Display.Colormap,...
                'CLim',[0 1],...
                'CData',[]);

            % wire the callbacks for RegionViewer DrawRectangle tool
            obj.RegionViewer.Tools.DrawRectangle.ROIPreviewMovedFcn    = @(~,d) obj.onROIPreviewMoved(d);
            obj.RegionViewer.Tools.DrawRectangle.ROIMoveCommittedFcn   = @(~,d) obj.onROIMoveCommitted(d);
            obj.RegionViewer.Tools.DrawRectangle.ROIDeletedFcn         = @(~,~) obj.onROIDeleted();
            % set options for RegionViewer DrawRectangle tool
            obj.RegionViewer.Tools.DrawRectangle.RotationAngleMode = 'half-circle';

            %% --- RegionSummaryTable ---
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

            %% --- RegionSummaryPlot ---
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

            % center the GUI after defining all graphics components and ImageAxesTool settings
            movegui(obj.Fig,"center");

            %% --- Listeners ---
            % obj.projectL(1) = addlistener(obj.Project,'ImageAdded',          @(~,~) obj.refreshImageList());
            % obj.projectL(2) = addlistener(obj.Project,'ImageRemoved',        @(~,~) obj.refreshImageList());
            % obj.projectL(3) = addlistener(obj.Project,'ActiveImageChanged',  @(~,~) obj.syncActiveImageToView());
            % obj.projectL(4) = addlistener(obj.Project,'RegionAdded',         @(~,~) obj.onRegionAdded());
            % obj.projectL(5) = addlistener(obj.Project,'RegionRemoved',       @(~,~) obj.refreshRegionList());
            % obj.projectL(6) = addlistener(obj.Project,'ActiveRegionChanged', @(~,~) obj.syncActiveRegionToView());
            % 
            % obj.settingsL(1) = addlistener(obj.Settings,'DisplayChanged',   @(~,e) obj.onDisplayChanged(e));
            % obj.settingsL(2) = addlistener(obj.Settings,'AnalysisChanged',  @(~,e) obj.onAnalysisChanged(e));
            % obj.settingsL(3) = addlistener(obj.Settings,'IOChanged',        @(~,e) obj.onIOChanged(e));
            % obj.settingsL(4) = addlistener(obj.Settings,'PeaksPlotChanged', @(~,e) obj.onPeaksPlotChanged(e));
            % obj.settingsL(5) = addlistener(obj.Settings,'BoxChanged',       @(~,e) obj.onBoxChanged(e));

            %% --- Final cleanup ---
            % Expand Image and Region listbox accordion items
            obj.SettingsAccordion.Items(1).expand();
            obj.SettingsAccordion.Items(2).expand();

            % Show figure
            obj.Fig.Visible = 'on';

            % Initial UI sync
            obj.refreshUI();

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
                "Items",str,...
                "ItemsData",str,...
                "Value",str);

            % RegionViewer
            obj.RegionViewer.CData = [];
            obj.RegionViewer.Tools.DrawRectangle.setROIPosition(model.STORMRegion.LinescanTemplate);

            % RegionLinescanPlot
            obj.RegionLinescanPlot.Data = model.analysis.PeaksData.empty();
            obj.RegionLinescanPlot.Title = '';

            % RegionSummaryTable
            obj.RegionSummaryTable.Data = [];

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
                obj.projectL(1) = addlistener(obj.Project,'ImageAdded',          @(~,~) obj.refreshImageList());
                obj.projectL(2) = addlistener(obj.Project,'ImageRemoved',        @(~,~) obj.refreshImageList());
                obj.projectL(3) = addlistener(obj.Project,'ActiveImageChanged',  @(~,~) obj.syncActiveImageToView());
                obj.projectL(4) = addlistener(obj.Project,'RegionAdded',         @(~,~) obj.onRegionAdded());
                obj.projectL(5) = addlistener(obj.Project,'RegionRemoved',       @(~,~) obj.refreshRegionList());
                obj.projectL(6) = addlistener(obj.Project,'ActiveRegionChanged', @(~,~) obj.syncActiveRegionToView());
            end

            obj.settingsL(1) = addlistener(obj.Settings,'DisplayChanged',   @(~,e) obj.onDisplayChanged(e));
            obj.settingsL(2) = addlistener(obj.Settings,'AnalysisChanged',  @(~,e) obj.onAnalysisChanged(e));
            obj.settingsL(3) = addlistener(obj.Settings,'IOChanged',        @(~,e) obj.onIOChanged(e));
            obj.settingsL(4) = addlistener(obj.Settings,'PeaksPlotChanged', @(~,e) obj.onPeaksPlotChanged(e));
            obj.settingsL(5) = addlistener(obj.Settings,'BoxChanged',       @(~,e) obj.onBoxChanged(e));
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
            % refresh region boxes
            obj.refreshRegionBoxes();
            % refresh RegionListBox
            obj.refreshRegionList();
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
            % refresh region boxes
            obj.refreshRegionBoxes();

            % refresh region listbox
            obj.refreshRegionList();

            % sync view to active region
            %obj.syncActiveRegionToView();
        end

        function refreshRegionList(obj)
            img = obj.Project.ActiveImage;
            if isempty(img)
                ids = [];
            else
                % string array of region IDs
                ids = img.RegionOrder;
            end

            if isempty(ids)
                obj.RegionListBox.Items = string.empty(1,0);
                obj.RegionListBox.ItemsData = string.empty(1,0);
                obj.RegionListBox.Value = string.empty(1,0);
                return
            end

            % string array of image names
            names = img.RegionNames;         

            obj.RegionListBox.Items     = names;
            obj.RegionListBox.ItemsData = ids;

            % Keep selection synced
            if strlength(img.ActiveRegionID) > 0
                obj.RegionListBox.Value = img.ActiveRegionID;
            else
                obj.RegionListBox.Value = ids(1);
            end

            % forward value to ValueChangedFcn of RegionListBox
            obj.onSelectRegion(obj.RegionListBox.Value);
        end

        function refreshRegionBoxes(obj)
            % clear overlays
            obj.Ax.Tools.Pick.clearBoxes();

            % get the active image
            img = obj.Project.ActiveImage;
            % if empty -> return
            if isempty(img), return; end

            % get the region array
            regs = img.RegionArray;
            % if empty -> return
            if isempty(regs), return; end

            for k = 1:numel(regs)
                r = regs(k);
                % bs = r.BoxSize;
                % if ~isfinite(bs) || bs<=0
                %     bs = obj.Settings.Analysis.BoxSize;
                % end
                % obj.Ax.Tools.Pick.addBox(r.ID, r.Center, bs);
                obj.Ax.Tools.Pick.addBox(r.ID, r.Center, r.BoxSize);
            end

        end

        function onSelectRegion(obj, regionID)
            if isempty(regionID), return; end
            obj.Project.ActiveImage.setActiveRegion(regionID);
        end

        function syncActiveRegionToView(obj)
            % get the active region
            img = obj.Project.ActiveImage;
            if isempty(img)
                reg = [];
            else
                reg = img.ActiveRegion;
            end

            if ~isempty(reg)
                % update RegionListBox selection
                obj.RegionListBox.Value = reg.ID;
                % update ROI box selection highlight
                obj.Ax.Tools.Pick.setActiveBoxByID(reg.ID);
            end

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
            if isempty(img)
                reg = [];
            else
                reg = img.ActiveRegion;
            end
            % if empty, clear view and return
            if isempty(reg), obj.RegionViewer.CData = []; return, end
            % get CData
            cdata = img.regionSubimage(reg);
            % get CLim
            switch obj.Settings.Display.AutoScaleDisplayIntensity
                case true
                    clim = img.AutoDisplayCLim;
                case false
                    clim = img.DisplayCLim;
            end
            % update ImageViewer CData and CLim
            set(obj.RegionViewer,'CData',cdata,'CLim',clim);
        end

        function refreshRegionSummaryTable(obj)
            img = obj.Project.ActiveImage;
            if isempty(img)
                reg = [];
            else
                reg = img.ActiveRegion;
            end

            if isempty(reg)
                obj.RegionSummaryTable.Data = [];
            else
                obj.RegionSummaryTable.Data = reg.SummaryTable;
            end
        end

        function refreshRegionLinescanPlot(obj)

            % get the ActiveImage, exit if empty
            img = obj.Project.ActiveImage; if isempty(img), return; end

            % get the ActiveRegion, exit if empty
            reg = img.ActiveRegion; 
            if isempty(reg)
                obj.RegionLinescanPlot.Data = model.analysis.PeaksData.empty();
                obj.RegionLinescanPlot.Title = '';
                return
            end

            obj.RegionLinescanPlot.XLabel = sprintf("Distance (%s)",img.PixelSize.Unit);
            obj.RegionLinescanPlot.Data = reg.LinescanResults;
            obj.RegionLinescanPlot.Title = utils.texFriendly(img.Name) + " | " + reg.Name;

        end

        function refreshRegionLinescanROI(obj)
            % get the ActiveImage, exit if empty
            img = obj.Project.ActiveImage; if isempty(img), return; end

            % get the ActiveRegion, exit if empty
            reg = img.ActiveRegion;
            if isempty(reg)
                % clear linescan position
                obj.RegionViewer.Tools.DrawRectangle.setROIPosition(model.STORMRegion.LinescanTemplate);
                return
            end

            % update linescan ROI position
            obj.RegionViewer.Tools.DrawRectangle.setROIPosition(reg.Linescan);

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
            % start a new project

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

            % refresh UI
            obj.refreshUI();  

            % refresh listeners
            obj.refreshListeners();
        end

        function onOpen(obj)
            % open existing project from file
            % hide figure to show file selection dialog
            obj.Fig.Visible = 'off';
            % file selection dialog
            [file, path] = uigetfile('*.mat','Select project file (.mat)','MultiSelect','off');
            % show figure
            obj.Fig.Visible = 'on';
            % if cancelled or no files selected
            if isequal(file,0)
                return
            end

            % get full file name
            fname = fullfile(path, file);

            % create progress dialog
            msg = sprintf('Loading project:\n%s',fname);
            h = uiprogressdlg(obj.Fig,"Message",msg,'Indeterminate','on');


            % --- cleanup before loading ---
            % delete project
            obj.Project.delete();
            % delete settings
            obj.Settings.delete();
            % detach listeners
            obj.detatchListeners();

            % --- load the project ---
            [proj,stgs] = model.STORMProject.load(fname);

            % --- update after load ---
            % assign new project and settings
            obj.Project = proj;
            obj.Settings = stgs;

            % run region analysis
            obj.processAllRegions();

            % refresh UI
            obj.refreshUI();
            % refresh listeners
            obj.refreshListeners();

            % close progress dialog
            close(h);
        end

        function onClose(obj)
            % close current project

            % return if empty
            if isempty(obj.Project)
                return
            end

            % --- delete current project and cleanup ---
            % delete project
            obj.Project.delete(); obj.Project = model.STORMProject.empty();
            % detach listeners
            obj.detatchListeners();

            % --- update ---
            % refresh view
            obj.refreshUI();

        end

        function onSave(obj)
            % save current project
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
            % save currently selected settings to default file
            obj.Settings.save();
        end

    end

    %% Per-image settings
    methods (Access=private)

        function onIntensitySliderChanging(obj,~)
            % get the active image
            img = obj.Project.ActiveImage;
            if isempty(img), return; end

            change = max(abs(obj.Ax.CLim-obj.IntensitySlider.Value));

            if change > img.CDataLimits(2)*0.01
                set([obj.Ax,obj.RegionViewer],'CLim',obj.IntensitySlider.Value);
            end

        end

        function onIntensitySliderChanged(obj,~)
            % get the active image
            img = obj.Project.ActiveImage;
            if isempty(img), return; end

            % newVal = evt.Source.Value;
            newVal = obj.IntensitySlider.Value;

            img.DisplayCLim = newVal;
            obj.Ax.CLim = newVal;
            obj.RegionViewer.CLim = newVal;

            % disable AutoScaleDisplayIntensity if enabled
            if obj.Settings.Display.AutoScaleDisplayIntensity
                obj.Settings.Display.AutoScaleDisplayIntensity = false;
            end

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
            % % get the ActiveImage, exit if empty
            % img = obj.Project.ActiveImage; if isempty(img), return; end
            % 
            % % create progress dialog
            % h = uiprogressdlg(obj.Fig,"Message",'Please wait...','Indeterminate','on');
            % 
            % % detect regions for the active image
            % img.detectRegions(app.config.RunConfig.fromSettings(obj.Settings));
            % 
            % % close the progress dialog
            % close(h);



            % create progress dialog
            h = uiprogressdlg(obj.Fig,"Message",'Please wait...','Indeterminate','on');

            % detect regions for the active image
            obj.Project.detectRegions(app.config.RunConfig.fromSettings(obj.Settings),h);

            % close the progress dialog
            close(h);

        end

    end

    %% Event handlers for Pick tool callbacks
    methods (Access=private)

        function onBoxCreated(obj, data)
            % Widget drew a new box -> create a STORMRegion and set it as active
            % get the ActiveImage, exit if empty
            img = obj.Project.ActiveImage; if isempty(img), return; end
            % create a new STORMRegion
            img.addRegion(data.UUID, data.CenterPx, obj.Settings.Analysis.BoxSize);
            % set new region as the ActiveRegion
            img.setActiveRegion(data.UUID);
        end

        function onBoxMoveStarted(obj, data)
            img = obj.Project.ActiveImage; if isempty(img), return; end
            regionID = data.UUID;
            if img.hasRegion(regionID)
                img.setActiveRegion(regionID);
            end
        end

        function onBoxPreviewMoved(obj, data)
            % Live move previews — optional
            % get active image
            img = obj.Project.ActiveImage; if isempty(img), return; end
            % get region using ID
            regionID = data.UUID;
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
            regionID = data.UUID;
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
            regionID = data.UUID;
            if img.hasRegion(regionID)
                img.removeRegion(regionID);
            end
        end

        function onBoxActivated(obj, data)
            % return if no active image
            img = obj.Project.ActiveImage; if isempty(img), return; end
            % get region id from box id
            regionID = data.UUID;
            % if region exists in active image
            if img.hasRegion(regionID)
                % set it as the active region
                img.setActiveRegion(regionID);
            else
                % set active region to empty
                img.setActiveRegion(string.empty(1,0));
            end
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
            ax = widgets.ImageAxes(g,...
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
                    p.Title = utils.texFriendly(imgs(i).Name) + " | " + regs(j).Name;

                    % update region CData and CLim
                    ax.CData = imgs(i).regionSubimage(regs(j));
                    ax.CLim = imgs(i).DisplayCLim;

                    % update linescan ROI position
                    ax.Tools.DrawRectangle.setROIPosition(regs(j).Linescan);

                    % update uilabel Text
                    l.Text = regs(j).TextSummaryTable;

                    % create a temporary unique name for each PDF
                    tempName = fullfile(path,[char(java.util.UUID.randomUUID()),'.pdf']);

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

    end

end
