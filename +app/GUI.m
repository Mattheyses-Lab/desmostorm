classdef GUI < handle
% app.GUI - GUI controller

    % add Transient and NonCopyable attributes?
    properties (Access=private)
        Fig matlab.ui.Figure
        Grid matlab.ui.container.GridLayout

        LeftPane matlab.ui.container.GridLayout

        SettingsAccordionPanel matlab.ui.container.Panel
        SettingsAccordionPanelGrid matlab.ui.container.GridLayout
        SettingsAccordion widgets.uiaccordion

        ImageListBoxPanel matlab.ui.container.Panel
        ImageListBoxPanelGrid matlab.ui.container.GridLayout
        ImageListBox matlab.ui.control.ListBox

        RegionListBoxPanel matlab.ui.container.Panel
        RegionListBoxPanelGrid matlab.ui.container.GridLayout
        RegionListBox matlab.ui.control.ListBox

        ImageViewerPanel matlab.ui.container.Panel
        ImageViewerPanelGrid matlab.ui.container.GridLayout
        % ImageAxes object for the ImageViewer
        Ax widgets.ImageAxes

        RegionGrid matlab.ui.container.GridLayout

        RegionViewerPanel matlab.ui.container.Panel
        RegionViewerPanelGrid matlab.ui.container.GridLayout
        % ImageAxes object for the RegionViewer
        RegionViewer widgets.ImageAxes

        RegionSummaryPanel matlab.ui.container.Panel
        RegionSummaryPanelGrid matlab.ui.container.GridLayout
        RegionSummaryTable matlab.ui.control.Table

        RegionLinescanPanel matlab.ui.container.Panel
        RegionLinescanPanelGrid matlab.ui.container.GridLayout
        RegionLinescanAxes matlab.ui.control.UIAxes

        RegionLinescanPlotRaw matlab.graphics.primitive.Line
        RegionLinescanPlotSmooth matlab.graphics.primitive.Line

        RegionLinescanPeakVerticalLines matlab.graphics.primitive.Line % one line() object, two lines
        RegionLinescanPeakToPeakLine matlab.graphics.primitive.Line % one line() object, one line
        RegionLinescanPeakWidthLines matlab.graphics.primitive.Line % one line() object, two lines
        RegionLinescanPeakBorderLines matlab.graphics.primitive.Line % one line() object, n lines

        RegionLinescanPeakDistanceLabel matlab.graphics.primitive.Text
        RegionLinescanPeakWidthLabel1 matlab.graphics.primitive.Text
        RegionLinescanPeakWidthLabel2 matlab.graphics.primitive.Text

        L event.listener
    end

    % More components for settings, separated from above to reduce clutter
    properties (Access=private)
        ExampleColormapPanel matlab.ui.container.Panel
        ExampleColormapAxes matlab.ui.control.UIAxes
        ExampleColormapImage matlab.graphics.primitive.Image
        ColormapTree matlab.ui.container.Tree

        IntensitySlider widgets.uirangeslidereditfield

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

    % Display settings
    properties
        LinescanRawLineColor = [1 0 0]
        LinescanRawLineWidth = 1
        LinescanSmoothLineColor = [0 0 1]
        LinescanSmoothLineWidth = 2
    end

    %% Constructor/Destructor
    methods

        function obj = GUI()

            % --- Settings ---
            obj.Settings = app.config.Settings.load();

            % --- Model ---
            obj.Project = model.STORMProject("Untitled Project");
            obj.Project.DefaultPixelSize = obj.Settings.Analysis.getDefaultPixelSize();

            % --- Figure ---
            % need to add a more elegant way to set window size once app components are finalized
            s = utils.getScreenSize();
            s(4) = 0.45*s(3);
            obj.Fig  = uifigure('Name','dSTORM Analyzer',...
                'Color',[0 0 0],...
                'Position',s(1,:),...
                'WindowStyle','normal',...
                'Visible','off',...
                'Theme','dark');

            % --- Menubar ---
            mFile = uimenu(obj.Fig,'Text','File');
            uimenu(mFile,'Text','Load Images...','MenuSelectedFcn',@(~,~) obj.onLoadImages());
            uimenu(mFile,'Text','Save Current Settings','MenuSelectedFcn',@(~,~) obj.onSaveSettings());
            uimenu(mFile,'Text','Export Measurements','MenuSelectedFcn',@(~,~) obj.onExportMeasurements());

            % --- Layout ---
            obj.Grid = uigridlayout(obj.Fig,[2 3], ...
                'ColumnWidth',{'fit','1x'}, ...
                'RowHeight',{'1x'}, ...
                'ColumnSpacing',5, ...
                'RowSpacing',5, ...
                'Padding',[5 5 5 5],...
                'BackgroundColor',[0.12 0.12 0.12]);

            % --- Left Pane Grid (ListBoxes and settings) ---
            obj.LeftPane = uigridlayout(obj.Grid,[1 1],...
                "RowHeight",{'fit'},...
                "ColumnWidth",300,...
                "Padding",[0 0 0 0],...
                "BackgroundColor",[.12 .12 .12],...
                "Scrollable","on");
            obj.LeftPane.Layout.Row = [1 2];
            obj.LeftPane.Layout.Column = 1;

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
            % set axes limits to show so that colorbar image fills axes area
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
            uieditfield(...
                obj.SettingsAccordion.Items(4).Pane,...
                "numeric",...
                "ValueChangedFcn",@(o,~) obj.AnalysisSettingsChanged(o,"BoxSize"),...
                "Value",obj.Settings.Analysis.BoxSize);

            uilabel(obj.SettingsAccordion.Items(4).Pane,"Text","Minimum Peak Distance","FontColor",[0.85 0.85 0.85]);
            uieditfield(...
                obj.SettingsAccordion.Items(4).Pane,...
                "numeric",...
                "ValueChangedFcn",@(o,~) obj.AnalysisSettingsChanged(o,"MinPeakDistance"),...
                "Value",obj.Settings.Analysis.MinPeakDistance);

            uilabel(obj.SettingsAccordion.Items(4).Pane,"Text","Minimum Peak Height","FontColor",[0.85 0.85 0.85]);
            uieditfield(...
                obj.SettingsAccordion.Items(4).Pane,...
                "numeric",...
                "ValueChangedFcn",@(o,~) obj.AnalysisSettingsChanged(o,"MinPeakHeight"),...
                "Value",obj.Settings.Analysis.MinPeakHeight);

            uilabel(obj.SettingsAccordion.Items(4).Pane,"Text","Peak Smoothing","FontColor",[0.85 0.85 0.85]);
            uieditfield(...
                obj.SettingsAccordion.Items(4).Pane,...
                "numeric",...
                "ValueChangedFcn",@(o,~) obj.AnalysisSettingsChanged(o,"PeakSmoothing"),...
                "Value",obj.Settings.Analysis.PeakSmoothing);

            uilabel(obj.SettingsAccordion.Items(4).Pane,"Text","Pixel Size Value","FontColor",[0.85 0.85 0.85]);
            uieditfield(...
                obj.SettingsAccordion.Items(4).Pane,...
                "numeric",...
                "ValueChangedFcn",@(o,~) obj.AnalysisSettingsChanged(o,"PixelSizeValue"),...
                "Value",obj.Settings.Analysis.PixelSizeValue);

            uilabel(obj.SettingsAccordion.Items(4).Pane,"Text","Pixel Size Unit","FontColor",[0.85 0.85 0.85]);
            uidropdown(...
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
                "RowHeight",{'fit'},...
                "ColumnWidth",{'1x'},...
                "RowSpacing",5,...
                "ColumnSpacing",5);


            % obj.IntensitySlider = widgets.uirangeslidereditfield(obj.SettingsAccordion.Items(5).Pane,...
            %     "Title",'Adjust display limits',...
            %     "FontColor",[1 1 1],...
            %     "Limits",[0 1],...
            %     "Value",[0 1],...
            %     "Colormap",obj.Settings.Display.Colormap,...
            %     "ValueChangedFcn",@(~,evt) obj.onIntensitySliderChanged(evt));


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



            % --- ImageViewer ---
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
                'ToolBox',{'Zoom','Pick'},...
                'ToolBelt',{'Zoom','Pick'},...
                'Colormap',obj.Settings.Display.Colormap,...
                'CLim',[0 1]);

            % wire the optimistic callbacks for ImageViewer Pick tool
            obj.Ax.Tools.Pick.BoxCreatedFcn       = @(~,d) obj.onBoxCreated(d);
            obj.Ax.Tools.Pick.BoxMoveStartedFcn   = @(~,d) obj.onBoxMoveStarted(d);
            obj.Ax.Tools.Pick.BoxPreviewMovedFcn  = @(~,d) obj.onBoxPreviewMoved(d);   % optional
            obj.Ax.Tools.Pick.BoxMoveCommittedFcn = @(~,d) obj.onBoxMoveCommitted(d);
            obj.Ax.Tools.Pick.BoxDeletedFcn       = @(~,d) obj.onBoxDeleted(d);
            obj.Ax.Tools.Pick.BoxActivatedFcn     = @(~,d) obj.onBoxActivated(d);

            % set the box size for Pick tool
            obj.Ax.Tools.Pick.BoxSize = obj.Settings.Analysis.BoxSize;

            % --- Region Area ---

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
                'ToolBox',{'Zoom','DrawRectangle'},...
                'ToolBelt',{'Zoom','DrawRectangle'},...
                'Colormap',obj.Settings.Display.Colormap,...
                'CLim',[0 1]);

            % wire the callbacks for RegionViewer DrawRectangle tool
            obj.RegionViewer.Tools.DrawRectangle.ROIPreviewMovedFcn    = @(~,d) obj.onROIPreviewMoved(d);
            obj.RegionViewer.Tools.DrawRectangle.ROIMoveCommittedFcn   = @(~,d) obj.onROIMoveCommitted(d);
            obj.RegionViewer.Tools.DrawRectangle.ROIDeletedFcn         = @(~,~) obj.onROIDeleted();
            % set options for RegionViewer DrawRectangle tool
            obj.RegionViewer.Tools.DrawRectangle.RotationAngleMode = 'half-circle';

            % --- RegionSummaryTable ---
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

            % --- RegionLinescanAxes ---
            obj.RegionLinescanPanel = uipanel(obj.RegionGrid,...
                'Title','Region Linescan',...
                'BackgroundColor',[.12 .12 .12]);
            obj.RegionLinescanPanel.Layout.Row = 2;
            obj.RegionLinescanPanel.Layout.Column = [1 2];

            obj.RegionLinescanPanelGrid = uigridlayout(obj.RegionLinescanPanel,[1,1],...
                "ColumnWidth",{'1x'},...
                "RowHeight",{'1x'},...
                "Padding",[0 0 0 0]);

            obj.RegionLinescanAxes = uiaxes(obj.RegionLinescanPanelGrid,...
                "XLim",[0 1],...
                "XLimMode","auto",...
                "YLim",[0 1],...
                "YLimMode","auto");
            obj.RegionLinescanAxes.Layout.Row = 1;
            obj.RegionLinescanAxes.Layout.Column = 1;
            obj.RegionLinescanAxes.XLabel.String = 'Distance';
            obj.RegionLinescanAxes.YLabel.String = 'Intensity';
            legend(obj.RegionLinescanAxes); % add legend

            % Create empty line plots to show the linescan data
            obj.RegionLinescanPlotRaw = line(obj.RegionLinescanAxes,...
                NaN,NaN,...
                'LineWidth',obj.LinescanRawLineWidth,...
                'Color',obj.LinescanRawLineColor,...
                'DisplayName','Raw');
            obj.RegionLinescanPlotSmooth = line(obj.RegionLinescanAxes,...
                NaN,NaN,...
                'LineWidth',obj.LinescanSmoothLineWidth,...
                'Color',obj.LinescanSmoothLineColor,...
                'DisplayName','Smoothed');

            obj.RegionLinescanPeakVerticalLines = line(obj.RegionLinescanAxes,...
                NaN,NaN,'LineWidth',0.5,'Color',[1 1 1],'LineStyle','--');
            obj.RegionLinescanPeakVerticalLines.Annotation.LegendInformation.IconDisplayStyle = "off";

            obj.RegionLinescanPeakToPeakLine = line(obj.RegionLinescanAxes,...
                NaN,NaN,'LineWidth',0.5,'Color',[1 1 1],'LineStyle','-');
            obj.RegionLinescanPeakToPeakLine.Annotation.LegendInformation.IconDisplayStyle = "off";

            obj.RegionLinescanPeakWidthLines = line(obj.RegionLinescanAxes,...
                NaN,NaN,'LineWidth',0.5,'Color',[1 1 1],'LineStyle','-');
            obj.RegionLinescanPeakWidthLines.Annotation.LegendInformation.IconDisplayStyle = "off";

            obj.RegionLinescanPeakBorderLines = line(obj.RegionLinescanAxes,...
                NaN,NaN,'LineWidth',0.5,'Color',[1 1 1],'LineStyle','-');
            obj.RegionLinescanPeakBorderLines.Annotation.LegendInformation.IconDisplayStyle = "off";


            obj.RegionLinescanPeakDistanceLabel = text(obj.RegionLinescanAxes,...
                'Position',[0 0.9],...
                'Color',[1 1 1],...
                'String','',...
                'VerticalAlignment','bottom',...
                'HorizontalAlignment','center');

            obj.RegionLinescanPeakWidthLabel1 = text(obj.RegionLinescanAxes,...
                'Position',[0.25 0.5],...
                'Color',[1 1 1],...
                'String','',...
                'VerticalAlignment','bottom',...
                'HorizontalAlignment','center');

            obj.RegionLinescanPeakWidthLabel2 = text(obj.RegionLinescanAxes,...
                'Position',[0.75 0.5],...
                'Color',[1 1 1],...
                'String','',...
                'VerticalAlignment','bottom',...
                'HorizontalAlignment','center');

            % center the GUI after defining all graphics components and ImageAxesTool settings
            movegui(obj.Fig,"center");

            % % --- Model ---
            % obj.Project = model.STORMProject("Untitled Project");

            % --- Listeners ---
            obj.L(1) = addlistener(obj.Project,'ImageAdded',         @(~,~) obj.refreshImageList());
            obj.L(2) = addlistener(obj.Project,'ImageRemoved',       @(~,~) obj.refreshImageList());
            obj.L(3) = addlistener(obj.Project,'ActiveImageChanged', @(~,~) obj.syncActiveImageToView());
            obj.L(4) = addlistener(obj.Project,'RegionAdded',         @(~,~) obj.refreshRegionList());
            obj.L(5) = addlistener(obj.Project,'RegionRemoved',       @(~,~) obj.refreshRegionList());
            obj.L(6) = addlistener(obj.Project,'ActiveRegionChanged', @(~,~) obj.syncActiveRegionToView());

            obj.L(7) = addlistener(obj.Settings,'DisplayChanged', @(~,e) obj.onDisplayChanged(e));
            obj.L(8) = addlistener(obj.Settings,'AnalysisChanged',@(~,e) obj.onAnalysisChanged(e));
            obj.L(9) = addlistener(obj.Settings,'IOChanged',      @(~,e) obj.onIOChanged(e));

            % Expand Image and Region listbox accordion items
            obj.SettingsAccordion.Items(1).expand();
            obj.SettingsAccordion.Items(2).expand();


            % Show figure
            obj.Fig.Visible = 'on';

            % Initial UI sync
            obj.refreshImageList();
            obj.syncActiveImageToView();
        end

        function delete(obj)
            if ~isempty(obj.L), delete(obj.L(isvalid(obj.L))); end
            if ~isempty(obj.Ax) && isvalid(obj.Ax), delete(obj.Ax); end
            if ~isempty(obj.RegionViewer) && isvalid(obj.RegionViewer), delete(obj.RegionViewer); end
            if ~isempty(obj.Grid) && isvalid(obj.Grid), delete(obj.Grid); end
            if ~isempty(obj.Fig)  && isvalid(obj.Fig),  delete(obj.Fig);  end
        end

    end

    %% Derived getters
    methods

        function h = get.RegionLinescanPlotAnnotations(obj)
            h = [...
                obj.RegionLinescanPeakVerticalLines,...
                obj.RegionLinescanPeakToPeakLine,...
                obj.RegionLinescanPeakWidthLines,...
                obj.RegionLinescanPeakBorderLines,...
                obj.RegionLinescanPeakDistanceLabel,...
                obj.RegionLinescanPeakWidthLabel1,...
                obj.RegionLinescanPeakWidthLabel2...
                ];
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
            ids = obj.Project.ImageOrder;
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

            % Keep selection synced
            if strlength(obj.Project.ActiveImageID) > 0
                obj.ImageListBox.Value = obj.Project.ActiveImageID;
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
            % get the active image
            img = obj.Project.ActiveImage;
            % if empty, clear view and return
            if isempty(img)
                obj.Ax.CData = [];
                obj.Ax.Tools.Pick.clearBoxes();
                % obj.UIToRegion = dictionary;
                % obj.RegionToUI = dictionary;
                return
            end

            % get the CData for this image
            % obj.Ax.CData = im2double(img.CData);
            obj.Ax.CData = img.CData;
            % clear overlays & bindings, then replay from model
            obj.Ax.Tools.Pick.clearBoxes();
            % obj.UIToRegion = dictionary;
            % obj.RegionToUI = dictionary;

            regs = img.RegionArray;
            if ~isempty(regs)
                for k = 1:numel(regs)
                    r = regs(k);
                    bs = r.BoxSize; 
                    if ~isfinite(bs) || bs<=0
                        bs = obj.Settings.Analysis.BoxSize;
                    end
                    obj.Ax.Tools.Pick.addBox(r.ID, r.Center, bs);
                    % % trivial binding (overlay id == regionID for replayed boxes)
                    % obj.UIToRegion(r.ID) = r.ID;
                    % obj.RegionToUI(r.ID) = r.ID;
                end
            end

            % refresh RegionListBox
            obj.refreshRegionList();
            obj.syncActiveRegionToView();

            % update IntensitySlider
            obj.IntensitySlider.Limits = img.RawIntensityRange;
            obj.IntensitySlider.Value = img.DisplayCLim;
        end

    end

    %% Callbacks / UI sync (Regions)
    methods (Access=private)

        function refreshRegionList(obj)
            % string array of region IDs
            ids = obj.Project.ActiveImage.RegionOrder;
            if isempty(ids)
                obj.RegionListBox.Items = string.empty(1,0);
                obj.RegionListBox.ItemsData = string.empty(1,0);
                obj.RegionListBox.Value = string.empty(1,0);
                return
            end

            % string array of image names
            names = obj.Project.ActiveImage.RegionNames;         

            obj.RegionListBox.Items     = names;
            obj.RegionListBox.ItemsData = ids;

            % Keep selection synced
            if strlength(obj.Project.ActiveImage.ActiveRegionID) > 0
                obj.RegionListBox.Value = obj.Project.ActiveImage.ActiveRegionID;
            else
                obj.RegionListBox.Value = ids(1);
            end

            % forward value to ValueChangedFcn of RegionListBox
            obj.onSelectRegion(obj.RegionListBox.Value);
        end

        function onSelectRegion(obj, regionID)
            if isempty(regionID), return; end
            obj.Project.ActiveImage.setActiveRegion(regionID);
        end

        function syncActiveRegionToView(obj)
            % get the ActiveRegion
            reg = obj.Project.ActiveImage.ActiveRegion;

            % no ActiveRegion exists -> clear out view and return
            if isempty(reg)
                obj.RegionViewer.CData = [];
                obj.RegionSummaryTable.Data = [];
                obj.refreshRegionLinescanROI();
                obj.refreshRegionLinescanPlot();
                return
            end

            % update RegionViewer CData with ActiveRegion CData
            obj.RegionViewer.CData = obj.Project.ActiveImage.regionSubimage(reg);

            % update RegionListBox selection
            obj.RegionListBox.Value = reg.ID;

            % update ROI box selection highlight
            obj.Ax.Tools.Pick.setActiveBoxByID(reg.ID);

            % update RegionSummaryTable
            obj.RegionSummaryTable.Data = reg.SummaryTable;

            % update linescan
            obj.refreshRegionLinescanROI();
            obj.refreshRegionLinescanPlot();
        end

        function refreshRegionLinescanPlot(obj)

            % get the ActiveImage, exit if empty
            img = obj.Project.ActiveImage; if isempty(img), return; end

            % get the ActiveRegion, exit if empty
            reg = img.ActiveRegion; 
            if isempty(reg)
                set([obj.RegionLinescanPlotRaw,...
                    obj.RegionLinescanPlotSmooth,...
                    obj.RegionLinescanPlotAnnotations],'Visible','off');
                return
            end

            data = reg.LinescanResultsPhys;
            PixelSizeUnit = reg.PixelSize.Unit;

            % update X axis label
            obj.RegionLinescanAxes.XLabel.String = sprintf('Distance (%s)',PixelSizeUnit);


            % update linescan plot
            set(obj.RegionLinescanPlotRaw,...
                'XData',data.Dist,...
                'YData',data.ProfileNorm,...
                'Visible','on');
            set(obj.RegionLinescanPlotSmooth,...
                'XData',data.Dist,...
                'YData',data.ProfileSmooth,...
                'Visible','on');

            % if linescan results are invalid, hide annotations and return
            if ~data.Valid
                set(obj.RegionLinescanPlotAnnotations,'Visible','off');
                return
            else % otherwise, make annotations visible
                set(obj.RegionLinescanPlotAnnotations,'Visible','on');
            end

            % update linescan annotations
            X1 = data.PeakX1; X2 = data.PeakX2; % peak locations (X)
            Y1 = data.PeakY1; Y2 = data.PeakY2; % peak heights (Y)
            % W1 = data.PeakWidth1; W2 = data.PeakWidth2; % peak widths (W)

            xL1 = data.PeakWidthxL1; xR1 = data.PeakWidthxR1;
            xL2 = data.PeakWidthxL2; xR2 = data.PeakWidthxR2;

            set(obj.RegionLinescanPeakVerticalLines,...
                'XData',[X1,X1,NaN,X2,X2],...
                'YData',[0,1,NaN,0,1]);
            set(obj.RegionLinescanPeakToPeakLine,...
                'XData',[X1,X2],...
                'YData',[0.9,0.9]);
            set(obj.RegionLinescanPeakWidthLines,...
                'XData',[xL1,xR1,NaN,xL2,xR2],...
                'YData',[Y1/2,Y1/2,NaN,Y2/2,Y2/2]);


            BorderLineXY = data.BorderLineXY;

            if all(isnan(BorderLineXY))
                XData=NaN; YData=NaN;
            else
                XData=BorderLineXY(1,:); YData=BorderLineXY(2,:);
            end

            set(obj.RegionLinescanPeakBorderLines,...
                'XData',XData,...
                'YData',YData);

            set(obj.RegionLinescanPeakDistanceLabel,...
                'String',sprintf('%.1f %s',data.PeakDistance,PixelSizeUnit),...
                'Position',[mean([X1,X2]),0.9]);
            set(obj.RegionLinescanPeakWidthLabel1,...
                'String',sprintf('%.1f %s',data.PeakWidth1,PixelSizeUnit),...
                'Position',[X1,Y1/2]);
            set(obj.RegionLinescanPeakWidthLabel2,...
                'String',sprintf('%.1f %s',data.PeakWidth2,PixelSizeUnit),...
                'Position',[X2,Y2/2]);

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
            end
        end

        function onAnalysisChanged(obj,e)
            switch e.Name
                case {"MinPeakDistance","MinPeakHeight","PeakSmoothing"}
                    % % cheap update: re-run peaks on current ROI only
                    % obj.processActiveRegion();

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
                evt.Source.SelectedNodes = evt.PreviousSelectedNodes;
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

        function onSaveSettings(obj)
            % save currently selected settings to default file
            obj.Settings.save();
        end

    end

    %% Per-image settings
    methods (Access=private)

        function onIntensitySliderChanging(obj,~)
            % onIntensitySliderChanged(obj,evt)

            % get the active image
            img = obj.Project.ActiveImage;
            if isempty(img), return; end


            % oldVal = double(obj.Ax.CLim);
            oldVal = double(img.DisplayCLim);

            % newVal = round(obj.IntensitySlider.Value);
            newVal = obj.IntensitySlider.Value;

            change = max(abs(oldVal-newVal));

            if change >= (diff(img.RawIntensityLimits)+1)/(32)
                % obj.Ax.CLim = newVal;
                % obj.RegionViewer.CLim = newVal;
                set([obj.Ax,obj.RegionViewer],'CLim',newVal);
                %drawnow limitrate nocallbacks
            end

        end

        function onIntensitySliderChanged(obj,~)
            % onIntensitySliderChanged(obj,evt)

            % get the active image
            img = obj.Project.ActiveImage;
            if isempty(img), return; end



            % newVal = evt.Source.Value;
            newVal = obj.IntensitySlider.Value;

            img.DisplayCLim = newVal;

            obj.Ax.CLim = newVal;
            obj.RegionViewer.CLim = newVal;

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
            defaultName = fullfile(app.Settings.IO.DefaultFolder, 'region_measurements.xlsx');
            [file, path] = uiputfile('*.xlsx', ...
                'Export region measurements', defaultName);

            if isequal(file,0)
                return;  % user cancelled
            end

            fname = fullfile(path, file);
            app.Project.exportRegionTableToXlsx(fname);
        end

    end

end
