% DesmoSTORM - MATLAB app for desmosomal plaque protein analysis.
% Copyright (C) 2026 William Dean
%
% This program is free software; you can redistribute it and/or modify it
% under the terms of the GNU General Public License as published by the Free
% Software Foundation; either version 2 of the License, or (at your option)
% any later version.
%
% This program is distributed in the hope that it will be useful, but WITHOUT
% ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
% FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
% details.
%
% You should have received a copy of the GNU General Public License along
% with this program; if not, see <https://www.gnu.org/licenses/>.

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

        % --- navigation trees ---
        % images
        ImageTree matlab.ui.container.CheckBoxTree
        % regions
        RegionTree matlab.ui.container.CheckBoxTree

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
        RegionLinescanPlot matlabx.ui.axes.PlotAxes
        RegionLinescanRenderer desmostorm.plot.PeaksPlotRenderer

        % --- Settings-related UI ---
        ColormapPreview matlab.ui.control.Image
        ColormapTree matlab.ui.container.Tree
        DisplayLimitBlocks struct = struct.empty()
        LabelsTree matlab.ui.container.CheckBoxTree
        
        % Extra graphics handles, stored as struct to reduce clutter
        MenubarUI struct
        SettingsUI struct
        LabelsUI struct

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
        isSyncingTrees (1,1) logical = false
        registeredLabelHotkeys (1,:) string = strings(1,0)
        isSyncingColormapSelection (1,1) logical = false
        isSyncingChannelDisplay (1,1) logical = false
        displayedChannelIDs (1,:) string = strings(1,0)
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
            obj.Fig.SizeChangedFcn = @(~,~) obj.refreshComponentSizes();
            obj.refreshComponentSizes();
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
            obj.MenubarUI.File_Save  = uimenu(obj.MenubarUI.File,'Text','Save...', 'MenuSelectedFcn',@(~,~) obj.saveProject(false),'Separator','on','Accelerator','S');
            obj.MenubarUI.File_SaveAs = uimenu(obj.MenubarUI.File,'Text','Save As...', ...
                'MenuSelectedFcn',@(~,~) obj.saveProject(true));
            obj.MenubarUI.File_ImportImages = uimenu(obj.MenubarUI.File,'Text','Import Images...', ...
                'MenuSelectedFcn',@(~,~) obj.onImportImages(),'Separator','on','Accelerator','L');
            % --- File -> Export ---
            obj.MenubarUI.File_Export = uimenu(obj.MenubarUI.File,'Text','Export','Separator','on');
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

            % --- Edit ---
            obj.MenubarUI.Edit = uimenu(obj.Fig,'Text','Edit');
            obj.MenubarUI.Edit_Channels = uimenu(obj.MenubarUI.Edit,'Text','Channels...', ...
                'MenuSelectedFcn',@(~,~) obj.onEditChannels());

            obj.MenubarUI.Edit_Labels = uimenu(obj.MenubarUI.Edit,'Text','Labels...', ...
                'MenuSelectedFcn',@(~,~) obj.onManageLabels());

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
            obj.MenubarUI.Settings = uimenu(obj.Fig,'Text','Settings');
            obj.MenubarUI.Settings_SaveDefaults = uimenu(obj.MenubarUI.Settings, ...
                'Text','Save as app defaults','MenuSelectedFcn',@(~,~) obj.onSaveSettings());
            obj.MenubarUI.Settings_LoadDefaults = uimenu(obj.MenubarUI.Settings, ...
                'Text','Load app defaults','MenuSelectedFcn',@(~,~) obj.onLoadSettings());
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
            % Left pane grid for navigation and settings
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
            itemTitles = ["Images","Regions","Analysis","Display Limits","Image Display","Peaks Plot","Linescan ROI","Labels"];

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
            desmostorm.Log.DEBUG("Setting up Images tree...");
            try obj.setupImagesTree(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % --- Regions ---
            desmostorm.Log.DEBUG("Setting up Regions tree...");
            try obj.setupRegionsTree(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % Set up SettingsUI struct
            obj.SettingsUI = struct(...
                "Display",struct(),...
                "ChannelDisplay",struct(),...
                "Analysis",struct(),...
                "PeaksPlot",struct(),...
                "ROI",struct(),...
                "Box",struct());

            % --- Analysis ---
            desmostorm.Log.DEBUG("Setting up Analysis controls...");
            try obj.setupAnalysisControls(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % --- Display Limits and Image Display ---
            desmostorm.Log.DEBUG("Setting up Display Limits and Image Display controls...");
            try
                obj.setupDisplayLimitsControls();
                obj.setupImageDisplayControls();
            catch ME
                desmostorm.Log.EXCEPTION(ME);
                rethrow(ME);
            end

            % --- Peaks Plot ---
            desmostorm.Log.DEBUG("Setting up Peaks Plot controls...");
            try obj.setupPeaksPlotControls(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % --- Linescan ROI ---
            desmostorm.Log.DEBUG("Setting up Linescan ROI controls...");
            try obj.setupROIControls(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % --- Labels ---
            desmostorm.Log.DEBUG("Setting up Labels controls...");
            try obj.setupLabelsControls(); catch ME, desmostorm.Log.EXCEPTION(ME); rethrow(ME); end

            % Expand Images and Regions tree accordion items
            obj.SettingsAccordion.getItem("Images").expand();
            obj.SettingsAccordion.getItem("Regions").expand();
        end

        function setupImagesTree(obj)
            obj.ImageTree = obj.buildNavigationTree("Images");
        end

        function setupRegionsTree(obj)
            obj.RegionTree = obj.buildNavigationTree("Regions");
        end

        function tree = buildNavigationTree(obj,scope)
            item = obj.SettingsAccordion.getItem(scope);
            set(item.Pane,'RowHeight',{200},'ColumnWidth',{'1x'},'Padding',0);
            tree = uitree(item.Pane,'checkbox', ...
                'BackgroundColor',[.18 .18 .18],'FontColor',[.9 .9 .9], ...
                'SelectionChangedFcn',@(src,~) obj.onNavigationTreeChanged(src,scope,false), ...
                'CheckedNodesChangedFcn',@(src,~) obj.onNavigationTreeChanged(src,scope,true));
            tree.Tooltip = 'Highlight to activate. Check boxes for batch operations.';
            tree.ContextMenu = obj.navigationMenu(scope,"");
        end

        function setupImageDisplayControls(obj)
            item = obj.SettingsAccordion.getItem("Image Display");
            pane = item.Pane;
            set(pane,'ColumnWidth',{70,'1x'},'RowHeight',{24,24,24,200}, ...
                'Padding',5,'RowSpacing',5,'ColumnSpacing',5);

            modeLabel = uilabel(pane,'Text','Mode','FontColor',[.85 .85 .85]);
            modeLabel.Layout.Row = 1;
            mode = uidropdown(pane,'Items',{'Colors','LUTs'}, ...
                'ItemsData',{'colors','luts'},'BackgroundColor',[.3 .3 .3], ...
                'FontColor',[.9 .9 .9], ...
                'ValueChangedFcn',@(src,~) obj.DisplaySettingsChanged(src,"ChannelColorMode"));
            mode.Layout.Row = 1;
            mode.Layout.Column = 2;

            channelLabel = uilabel(pane,'Text','Channel','FontColor',[.85 .85 .85]);
            channelLabel.Layout.Row = 2;
            channel = uidropdown(pane,'Items',{'No channels'},'ItemsData',{''}, ...
                'Enable','off','BackgroundColor',[.3 .3 .3],'FontColor',[.9 .9 .9], ...
                'ValueChangedFcn',@(~,~) obj.refreshChannelDisplayControls());
            channel.Layout.Row = 2;
            channel.Layout.Column = 2;

            appearance = uilabel(pane,'Text','Color','FontColor',[.85 .85 .85]);
            appearance.Layout.Row = 3;
            color = uidropdown(pane,'Items',matlabx.ui.axes.ImageAxes.getColorNames(), ...
                'BackgroundColor',[.3 .3 .3],'FontColor',[.9 .9 .9], ...
                'ValueChangedFcn',@(src,~) obj.ChannelColorChanged(src));
            color.Layout.Row = 3;
            color.Layout.Column = 2;
            obj.ColormapPreview = uiimage(pane,'ScaleMethod','stretch');
            obj.ColormapPreview.Layout.Row = 3;
            obj.ColormapPreview.Layout.Column = 2;
            obj.ColormapTree = uitree(pane,'BackgroundColor',[.18 .18 .18], ...
                'FontColor',[.9 .9 .9], ...
                'SelectionChangedFcn',@(~,e) obj.ColormapSelectionChanged(e));
            obj.ColormapTree.Layout.Row = 4;
            obj.ColormapTree.Layout.Column = [1 2];

            for category = reshape(matlabx.colors.maps.Registry.categories(),1,[])
                categoryNode = uitreenode(obj.ColormapTree,'Text',category);
                for name = reshape(matlabx.colors.maps.Registry.names(category),1,[])
                    uitreenode(categoryNode,'Text',name, ...
                        'NodeData',struct('Category',category,'Name',name));
                end
            end
            obj.SettingsUI.ChannelDisplay = struct( ...
                'Mode',mode,'Channel',channel,'AppearanceLabel',appearance,'Color',color);
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

        function setupDisplayLimitsControls(obj)
            item = obj.SettingsAccordion.getItem("Display Limits");
            set(item.Pane,'RowHeight',{'fit'},'ColumnWidth',{'1x'}, ...
                'RowSpacing',5,'ColumnSpacing',5);
        end

        function setupPeaksPlotControls(obj)
            item = obj.SettingsAccordion.getItem("Peaks Plot");
            pane = item.Pane;
            rows = {
                "Channel",               "ShownPlots",               ["all","current"], [],                     []
                "Color",                 "ColorSource",             ["channel","manual"], "Color",            "color"
                "Raw Line Width",        "RawLineWidth",             "number", [],                              []
                "Smooth Line Width",     "SmoothLineWidth",          "number", [],                              []
                "Annotation Color",      "AnnotationColorMode",      ["auto","manual"], "AnnotationColor",     "color"
                "Annotation Line Width", "AnnotationLineWidth",      "number", [],                              []
                "Annotation Font Size (pt)", "AnnotationFontSize",      "number", [],                              []
                "Distance Labels",       "DistanceAnnotations",      ["on","off"], "DistanceAnnotationsMode", ["lanes","data"]
                "Width Labels",          "WidthAnnotations",         ["on","off"], "WidthAnnotationsMode",     ["hover","normal"]
                "Title",                 "TitleVisible",            ["on","off"], [],                         []
                "Font Size (pt)",        "FontSize",                "number", [],                              []
                "Background Color",     "BackgroundColor",         "color", [],                               []
                "Foreground Color",     "ForegroundColor",         "color", [],                               []
            };
            set(pane,'RowHeight',repmat({'fit'},1,size(rows,1)),'ColumnWidth',{'fit','1x'}, ...
                'Padding',5,'RowSpacing',5,'ColumnSpacing',5);
            for row = 1:size(rows,1)
                label = uilabel(pane,'Text',rows{row,1},'FontColor',[.85 .85 .85]);
                label.Layout.Row = row;
                label.Layout.Column = 1;
                second = rows{row,4};
                if isempty(second)
                    control = obj.addPeaksPlotControl(pane,rows{row,2},rows{row,3});
                    control.Layout.Row = row;
                    control.Layout.Column = 2;
                else
                    columns = {'1x','1x'};
                    if isequal(rows{row,5},"color"), columns{2} = 'fit'; end
                    pair = uigridlayout(pane,[1 2],'ColumnWidth',columns, ...
                        'RowHeight',{'fit'},'Padding',0,'ColumnSpacing',5, ...
                        'BackgroundColor',[.18 .18 .18]);
                    pair.Layout.Row = row;
                    pair.Layout.Column = 2;
                    left = obj.addPeaksPlotControl(pair,rows{row,2},rows{row,3});
                    left.Layout.Column = 1;
                    right = obj.addPeaksPlotControl(pair,second,rows{row,5});
                    right.Layout.Column = 2;
                end
            end
            obj.refreshPeaksPlotControls();
        end

        function control = addPeaksPlotControl(obj,parent,name,choices)
            callback = @(src,~) obj.PeaksPlotSettingsChanged(src,name);
            if isequal(choices,"color")
                control = uicolorpicker(parent,'ValueChangedFcn',callback);
            elseif isequal(choices,"number")
                control = uieditfield(parent,'numeric','Value',1, ...
                    'Limits',[0 Inf],'LowerLimitInclusive','off','ValueChangedFcn',callback);
            else
                control = uidropdown(parent,'Items',cellstr(choices), ...
                    'BackgroundColor',[.3 .3 .3],'FontColor',[.9 .9 .9], ...
                    'ValueChangedFcn',callback);
            end
            obj.SettingsUI.PeaksPlot.(name) = control;
        end

        function refreshPeaksPlotControls(obj)
            controls = obj.SettingsUI.PeaksPlot;
            settings = obj.Settings.PeaksPlot;
            for name = reshape(string(fieldnames(controls)),1,[])
                control = controls.(name);
                value = settings.(name);
                if isa(control,'matlab.ui.control.DropDown'), value = char(value); end
                control.Value = value;
            end
            controls.Color.Enable = settings.ColorSource == "manual";
            controls.AnnotationColor.Enable = settings.AnnotationColorMode == "manual";
            controls.DistanceAnnotationsMode.Enable = logical(settings.DistanceAnnotations);
            controls.WidthAnnotationsMode.Enable = logical(settings.WidthAnnotations);
        end

        function setupROIControls(obj)
            item = obj.SettingsAccordion.getItem("Linescan ROI");
            set(item.Pane,...
                "RowHeight",repmat({'fit'},1,9),...
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

            uilabel(item.Pane,"Text","Font Color","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.ROI.FontColorPicker = uicolorpicker(...
                'Parent',item.Pane,...
                'Value',obj.Settings.ROI.FontColor,...
                'ValueChangedFcn',@(o,~) obj.ROISettingsChanged(o,"FontColor"));

            uilabel(item.Pane,"Text","Font Size (pt)","FontColor",[0.85 0.85 0.85]);
            obj.SettingsUI.ROI.FontSizeEditField = uieditfield(...
                item.Pane,...
                "numeric",...
                "Value",obj.Settings.ROI.FontSize,...
                "ValueChangedFcn",@(o,~) obj.ROISettingsChanged(o,"FontSize"));
        end

        function setupLabelsControls(obj)
            item = obj.SettingsAccordion.getItem("Labels");
            set(item.Pane,'RowHeight',{150},'ColumnWidth',{'1x'},'Padding',0);
            obj.LabelsTree = uitree(item.Pane,'checkbox', ...
                'BackgroundColor',[.18 .18 .18],'FontColor',[.9 .9 .9], ...
                'SelectionChangedFcn',@(~,e) obj.onSelectLabel(e), ...
                'CheckedNodesChangedFcn',@(~,e) obj.onCheckLabels(e));
            obj.LabelsTree.ContextMenu = obj.labelMenu("");
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
                'Tools',{'Zoom','Box','DisplayLimits','Colorbar','ExportView'},...
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
            obj.axesL(2) = addlistener(obj.ImageViewer,'DisplayStateChanged', ...
                @(~,e) obj.onImageViewerChannelDisplayChanged(e));

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
                'Tools',{'DrawRectangle','DisplayLimits','ExportView'},...
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

            obj.RegionLinescanPlot = matlabx.ui.axes.PlotAxes(obj.RegionLinescanPanelGrid, ...
                Name="RegionLinescan",FontName="Arial",Visible="off");
            obj.RegionLinescanPlot.Layout.Row = 1;
            obj.RegionLinescanPlot.Layout.Column = 1;
            obj.RegionLinescanRenderer = desmostorm.plot.PeaksPlotRenderer();
            obj.RegionLinescanPlot.mount(obj.RegionLinescanRenderer);
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
            if ~isempty(obj.RegionLinescanRenderer) && isvalid(obj.RegionLinescanRenderer)
                delete(obj.RegionLinescanRenderer);
            end
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
            obj.refreshImageTree();
            obj.syncActiveImageToView();

            % regions
            obj.refreshRegionTree();
            obj.syncActiveRegionToView();

            % labels
            obj.refreshLabelsTree()

        end

        function refreshMenubar(obj)
            % File, New, and Open must stay available without a project.
            projectMenus = setdiff(fieldnames(obj.MenubarUI), ...
                {'File','File_New','File_Open','Settings','Settings_SaveDefaults','Settings_LoadDefaults'});
            hasProject = ~isempty(obj.Project);
            for i = 1:numel(projectMenus)
                obj.MenubarUI.(projectMenus{i}).Enable = hasProject;
            end
            obj.MenubarUI.Edit_Channels.Enable = hasProject && ~isempty(obj.Project.Channels);
        end

        function refreshWindowName(obj)
            title = "DesmoSTORM (" + desmostorm.Info.Version + ")";
            if isempty(obj.Project)
                obj.Fig.Name = char(title + " — No project");
                return
            end

            title = title + " — " + obj.Project.Name;
            if obj.Project.HasUnsavedChanges, title = title + "*"; end
            if obj.Project.SourcePath ~= "", title = title + " — " + obj.Project.SourcePath; end
            obj.Fig.Name = char(title);
        end

        function refreshSettingsControllers(obj)
            S = obj.Settings;
            obj.refreshChannelDisplayControls();
            % Analysis
            obj.SettingsUI.Analysis.BoxSizeEditField.Value = S.Analysis.BoxSize;
            obj.SettingsUI.Analysis.MinPeakDistanceEditField.Value = S.Analysis.MinPeakDistance;
            obj.SettingsUI.Analysis.MinPeakHeightEditField.Value = S.Analysis.MinPeakHeight;
            obj.SettingsUI.Analysis.MinPeakProminenceEditField.Value = S.Analysis.MinPeakProminence;
            obj.SettingsUI.Analysis.NormalizeDropDown.Value = S.Analysis.Normalize;
            obj.SettingsUI.Analysis.PeakSmoothingEditField.Value = S.Analysis.PeakSmoothing;
            obj.SettingsUI.Analysis.PixelSizeValueEditField.Value = S.Analysis.PixelSizeValue;
            obj.SettingsUI.Analysis.PixelSizeUnitDropDown.Value = S.Analysis.PixelSizeUnit;
            obj.refreshPeaksPlotControls();
            % Linescan ROI
            obj.SettingsUI.ROI.ROIColorPicker.Value = S.ROI.ROIColor;
            obj.SettingsUI.ROI.ROILineWidthEditField.Value = S.ROI.ROILineWidth;
            obj.SettingsUI.ROI.ROIFaceAlphaEditField.Value = S.ROI.ROIFaceAlpha;
            obj.SettingsUI.ROI.ROIMarkerSizeEditField.Value = S.ROI.ROIMarkerSize;
            obj.SettingsUI.ROI.AnnotationLineColorPicker.Value = S.ROI.AnnotationLineColor;
            obj.SettingsUI.ROI.AnnotationLineWidthEditField.Value = S.ROI.AnnotationLineWidth;
            obj.SettingsUI.ROI.RotationAngleVisibleDropDown.Value = char(S.ROI.RotationAngleVisible);
            obj.SettingsUI.ROI.FontColorPicker.Value = S.ROI.FontColor;
            obj.SettingsUI.ROI.FontSizeEditField.Value = S.ROI.FontSize;
            obj.refreshROISettings();
            obj.refreshDisplayLimits();
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
                obj.projectL(10) = addlistener(obj.Project,'ChannelsChanged',     @(~,~) obj.onChannelsChanged());
                obj.projectL(11) = addlistener(obj.Project,'DirtyStateChanged',   @(~,~) obj.onDirtyStateChanged());
                obj.projectL(12) = addlistener(obj.Project,'ImageSelectionChanged', ...
                    @(~,~) obj.refreshImageTree());
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
            for key = obj.registeredLabelHotkeys
                obj.CommandRouter.removeHotkey(key);
            end
            obj.registeredLabelHotkeys = strings(1,0);
            if isempty(obj.Project), return, end
            keys = obj.Project.LabelBank.hotkeys();
            for key = reshape(unique(keys(strlength(keys)>0),'stable'),1,[])
                obj.CommandRouter.addHotkey(key,@(~,k) obj.onLabelHotkeyPressed(k));
                obj.registeredLabelHotkeys(end+1) = key;
            end
        end

        function refreshComponentSizes(obj)

            if obj.pendingSizeUpdate || isempty(obj.Fig) || ~isvalid(obj.Fig) || ...
                    isempty(obj.RegionGrid) || ~isvalid(obj.RegionGrid) || ...
                    isempty(obj.ImageViewerPanelGrid) || ~isvalid(obj.ImageViewerPanelGrid) || ...
                    isempty(obj.RegionViewerPanelGrid) || ~isvalid(obj.RegionViewerPanelGrid) || ...
                    isempty(obj.RegionSummaryPanelGrid) || ~isvalid(obj.RegionSummaryPanelGrid)
                return
            end
            obj.pendingSizeUpdate = true;
            guard = onCleanup(@() obj.finishSizeUpdate());

            p = obj.Fig.InnerPosition;
            W = p(3);

            % remaining width for top row of right panel
            remW = W - 300 - obj.Padding*2 - obj.ColumnSpacing;

            % account for uipanel overhead
            panelTop = obj.uipanelTopChromePx;

            % take half for the ImageViewer
            imageW = max(1,(remW-obj.ColumnSpacing)/2);
            imageH = imageW+panelTop;

            % half of that is the RegionViewer
            regionW = max(1,(imageW-obj.ColumnSpacing)/2);
            regionH = regionW+panelTop;

            % second row of RegionGrid is for linescan plots
            plotPanelOuterH = max(1,imageH - regionH - obj.Padding);

            % set sizes
            set(obj.ImageViewerPanelGrid,"RowHeight",{imageH},"ColumnWidth",{imageW});
            set(obj.RegionViewerPanelGrid,"RowHeight",{regionH},"ColumnWidth",{regionW});

            set(obj.RegionSummaryPanelGrid,"RowHeight",{regionH});

            obj.RegionGrid.RowHeight{2} = plotPanelOuterH;

            drawnow

        end

        function finishSizeUpdate(obj)
            if isvalid(obj), obj.pendingSizeUpdate = false; end
        end

        % clear / reset
        function clearUI(obj)
            obj.refreshMenubar();
            obj.refreshWindowName();
            obj.clearImageTree();
            obj.clearImageViewer();
            obj.clearRegionTree();
            obj.clearRegionViewer();
            obj.clearRegionLinescanPlot();
            obj.clearRegionSummaryTable();
            obj.refreshDisplayLimits();
            obj.refreshChannelDisplayControls();
            obj.clearLabelsTree();
            obj.refreshHotkeys();
        end

    end

    %% Other helpers
    methods (Access=private)

        function applyProjectChannelColormapsToAxes(obj)
        %APPLYPROJECTCHANNELCOLORMAPSTOAXES Apply saved project colormaps to ImageViewer
            if isempty(obj.Project) || isempty(obj.ImageViewer) || ~isvalid(obj.ImageViewer)
                return
            end

            img = obj.Project.ActiveImage;
            if isempty(img), return, end
            n = min(img.SizeC,obj.ImageViewer.NumComponents);
            cmaps = obj.ImageViewer.ComponentColormaps;
            for C = 1:n
                cmaps{C} = obj.Project.getChannelColormap(img.ChannelIDs(C));
            end
            obj.ImageViewer.ComponentColormaps = cmaps;
        end

        function applyProjectChannelColorsToAxes(obj)
        %APPLYPROJECTCHANNELCOLORSTOAXES Apply saved project color names to ImageViewer
            if isempty(obj.Project) || isempty(obj.ImageViewer) || ~isvalid(obj.ImageViewer)
                return
            end

            img = obj.Project.ActiveImage;
            if isempty(img), return, end
            n = min(img.SizeC,obj.ImageViewer.NumComponents);
            previous = obj.isSyncingChannelDisplay;
            obj.isSyncingChannelDisplay = true;
            cleanup = onCleanup(@() obj.setChannelDisplaySyncFlag(previous));
            colors = obj.ImageViewer.ComponentColors;
            for C = 1:n
                colors{C} = obj.Project.getChannelColorName(img.ChannelIDs(C));
            end
            obj.ImageViewer.ComponentColors = colors;
        end

        function applyProjectChannelDisplayToAxes(obj)
        %APPLYPROJECTCHANNELDISPLAYTOAXES Apply project display choices and settings mode
            if isempty(obj.Project) || isempty(obj.ImageViewer) || ~isvalid(obj.ImageViewer)
                return
            end

            previous = obj.isSyncingChannelDisplay;
            obj.isSyncingChannelDisplay = true;
            cleanup = onCleanup(@() obj.setChannelDisplaySyncFlag(previous));

            obj.applyProjectChannelColormapsToAxes();
            obj.applyProjectChannelColorsToAxes();
            obj.ImageViewer.ComponentColorMode = char(obj.Settings.Display.ChannelColorMode);
        end

        function refreshChannelDisplayControls(obj)
            controls = obj.SettingsUI.ChannelDisplay;
            channel = controls.Channel;
            id = string(channel.Value);
            ids = strings(1,0);
            if ~isempty(obj.Project)
                ids = string({obj.Project.Channels.ID});
            end

            if isempty(ids)
                set(channel,'Items',{'No channels'},'ItemsData',{''}, ...
                    'Value','','Enable','off');
                id = "";
            else
                if ~ismember(id,ids), id = ids(1); end
                set(channel,'Items',cellstr(string({obj.Project.Channels.Name})), ...
                    'ItemsData',cellstr(ids),'Value',char(id),'Enable','on');
            end

            colorsMode = obj.Settings.Display.ChannelColorMode == "colors";
            controls.Mode.Value = char(obj.Settings.Display.ChannelColorMode);
            controls.Mode.Enable = id ~= "";
            controls.Color.Visible = colorsMode;
            controls.Color.Enable = id ~= "";
            showLookup = ~colorsMode && id ~= "";
            obj.ColormapTree.Visible = showLookup;
            obj.ColormapPreview.Visible = showLookup;
            item = obj.SettingsAccordion.getItem("Image Display");
            item.Pane.RowHeight = {24,24,24,200*double(showLookup)};
            if colorsMode
                controls.AppearanceLabel.Text = 'Color';
            else
                controls.AppearanceLabel.Text = 'LUT';
            end

            previous = obj.isSyncingColormapSelection;
            obj.isSyncingColormapSelection = true;
            cleanup = onCleanup(@() obj.setColormapSelectionSyncFlag(previous));
            if id == ""
                obj.ColormapTree.SelectedNodes = [];
                obj.ColormapPreview.ImageSource = '';
                return
            end

            controls.Color.Value = char(obj.Project.getChannelColorName(id));
            [name,category] = obj.Project.getChannelColormapInfo(id);
            nodes = findall(obj.ColormapTree,'Type','uitreenode');
            obj.ColormapTree.SelectedNodes = [];
            for i = 1:numel(nodes)
                data = nodes(i).NodeData;
                if isstruct(data) && data.Name == name && data.Category == category
                    obj.ColormapTree.SelectedNodes = nodes(i);
                    if ~colorsMode, expand(nodes(i).Parent); end
                    break
                end
            end
            cmap = obj.Project.getChannelColormap(id);
            obj.ColormapPreview.ImageSource = permute(repmat(cmap,1,1,16),[3 1 2]);
        end

        function setColormapSelectionSyncFlag(obj,value)
            obj.isSyncingColormapSelection = value;
        end

        function setChannelDisplaySyncFlag(obj,value)
            obj.isSyncingChannelDisplay = value;
        end

        function guialert(obj,opts)
            arguments
                obj (1,1) desmostorm.app.GUI
                opts.Message = ""
                opts.Title = "Untitled"
                opts.Icon (1,:) char {mustBeMember(opts.Icon,{'error','warning','info','message','success',''})} = ''
            end

            % give focus to figure
            figure(obj.Fig);
            % The alert itself blocks interaction until it is dismissed.
            uialert(obj.Fig,...
                opts.Message,...
                opts.Title,...
                'Icon',opts.Icon);
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
            obj.refreshImageTree();
            desmostorm.Log.DEBUG("Image added.")
        end

        function onImageRemoved(obj)
        %ONIMAGEREMOVED ImageRemoved event callback    
            obj.refreshImageTree();
            desmostorm.Log.DEBUG("Image removed.")
        end

        function onActiveImageChanged(obj)
        %ONACTIVEIMAGECHANGED ActiveImageChanged event callback
            obj.refreshImageTree();
            obj.syncActiveImageToView();
            desmostorm.Log.DEBUG("Active Image changed.")
        end

        function onMaxSizeCChanged(obj)
        %ONMAXSIZECCHANGED MaxSizeCChanged event callback
            obj.refreshDisplayLimits();
            obj.refreshRegionLinescanPlot();
            obj.applyProjectChannelDisplayToAxes();
            obj.refreshChannelDisplayControls();
        end

        function onImageViewerChannelChanged(obj)
        %ONIMAGEVIEWERCHANNELCHANGED Update the current-channel linescan.
            if obj.Settings.PeaksPlot.ShownPlots == "current"
                obj.refreshRegionLinescanPlot();
            end
        end

        function onImageViewerChannelDisplayChanged(obj,event)
            if obj.isSyncingChannelDisplay || isempty(obj.Project) || ...
                    ~ismember(event.Property,["ComponentColorMode","ComponentColors","ComponentColormaps","ComponentCLims"])
                return
            end
            img = obj.Project.ActiveImage;
            if isempty(img), return, end

            obj.isSyncingChannelDisplay = true;
            cleanup = onCleanup(@() obj.setChannelDisplaySyncFlag(false));
            switch event.Property
                case "ComponentCLims"
                    limits = obj.ImageViewer.ComponentCLims;
                    for c = reshape(event.ComponentIdx,1,[])
                        if c <= img.SizeC && c <= numel(event.PreviousValue) && ...
                                ~isequaln(event.PreviousValue{c},limits{c}) && ...
                                all(isfinite(limits{c})) && limits{c}(1) < limits{c}(2)
                            value = img.normalizeDisplayRange(c,limits{c});
                            obj.storeManualDisplayLimits(img,c,value);
                            obj.previewDisplayLimits(c,value);
                        end
                    end
                    obj.refreshDisplayLimits();
                    return
                case "ComponentColorMode"
                    obj.Settings.Display.ChannelColorMode = string(obj.ImageViewer.ComponentColorMode);
                case "ComponentColors"
                    colors = obj.ImageViewer.ComponentColors;
                    for c = reshape(event.ComponentIdx,1,[])
                        if c <= img.SizeC
                            obj.Project.setChannelColor(img.ChannelIDs(c),string(colors{c}));
                        end
                    end
                case "ComponentColormaps"
                    maps = obj.ImageViewer.ComponentColormaps;
                    for c = reshape(event.ComponentIdx,1,[])
                        if c > img.SizeC || isequaln(event.PreviousValue{c},maps{c})
                            continue
                        end
                        id = img.ChannelIDs(c);
                        if isequal(maps{c},obj.Project.getChannelColormap(id)), continue, end
                        [name,category] = identifyColormap(maps{c});
                        if name ~= ""
                            obj.Project.setChannelColormap(id,name,category);
                        end
                    end
            end
            obj.refreshChannelDisplayControls();
            obj.refreshDisplayLimits();
        end

        function onChannelsChanged(obj)
            obj.MenubarUI.Edit_Channels.Enable = ~isempty(obj.Project.Channels);
            if ~obj.isSyncingChannelDisplay
                obj.applyProjectChannelColorsToAxes();
            end
            obj.refreshChannelDisplayControls();
            obj.refreshDisplayLimits();
            obj.refreshRegionSummaryTable();
            if ~isempty(obj.Project.ActiveRegion)
                components = obj.RegionViewer.ImageData.Components;
                names = obj.Project.ActiveImage.channelNames();
                for c = 1:min(numel(components),numel(names))
                    components(c).Name = names(c);
                end
            end
            if obj.Settings.PeaksPlot.ColorSource == "channel"
                obj.refreshRegionLinescanPlot();
            end
        end

        % --- UI SYNC DRIVER ---
        function syncActiveImageToView(obj)
        % SYNCACTIVEIMAGETOVIEW Sync UI to ActiveImage
            obj.refreshImageViewer();
            obj.refreshRegionTree();
            obj.refreshRegionBoxes();
            obj.syncActiveRegionToView();
        end

        % --- COMPONENT CALLBACKS ---
        function refreshImageTree(obj)
            img = obj.Project.ActiveImage;
            active = "";
            if ~isempty(img), active = img.ID; end
            obj.syncNavigationTree(obj.ImageTree,"Images",obj.Project.ImageIDs, ...
                obj.Project.ImageNames,active,obj.Project.SelectedImageIDs);
        end

        function clearImageTree(obj)
            deleteTreeNodes(obj.ImageTree.Children);
        end

        function onNavigationTreeChanged(obj,tree,scope,checked)
            if obj.isSyncingTrees || isempty(obj.Project), return, end
            if checked
                obj.setNavigationSelection(scope,nodeIDs(tree.CheckedNodes));
                return
            end
            ids = nodeIDs(tree.SelectedNodes);
            id = "";
            if ~isempty(ids), id = ids(1); end
            if scope == "Images"
                obj.Project.setActiveImage(id);
            else
                img = obj.Project.ActiveImage;
                if ~isempty(img), img.setActiveRegion(id); end
            end
        end

        function syncNavigationTree(obj,tree,scope,ids,names,active,selected)
            obj.isSyncingTrees = true;
            guard = onCleanup(@() obj.endTreeSync());
            ids = reshape(ids,1,[]);
            nodes = tree.Children;
            removed = ~ismember(nodeIDs(nodes),ids);
            deleteTreeNodes(nodes(removed));
            nodes = tree.Children;
            if ~isequal(nodeIDs(nodes),ids(1:numel(nodes)))
                deleteTreeNodes(nodes);
                nodes = tree.Children;
            end
            for k = numel(nodes)+1:numel(ids)
                node = uitreenode(tree,'Text',char(names(k)),'NodeData',ids(k));
                node.ContextMenu = obj.navigationMenu(scope,ids(k));
            end
            nodes = tree.Children;
            for k = 1:numel(nodes)
                if ~strcmp(nodes(k).Text,names(k))
                    nodes(k).Text = char(names(k));
                end
            end
            syncTreeSelection(tree,active,selected);
        end

        function endTreeSync(obj)
            obj.isSyncingTrees = false;
        end

        function menu = navigationMenu(obj,scope,id)
            menu = uicontextmenu(obj.Fig);
            singular = lower(extractBefore(scope,strlength(scope)));
            if scope == "Images" && id ~= ""
                uimenu(menu,'Text','Info...', ...
                    'MenuSelectedFcn',@(~,~) obj.showImageInfo(id));
            end
            uimenu(menu,'Text','Select all','Separator','on', ...
                'MenuSelectedFcn',@(~,~) obj.changeNavigationSelection(scope,"All"));
            uimenu(menu,'Text','Clear selection', ...
                'MenuSelectedFcn',@(~,~) obj.changeNavigationSelection(scope,"Clear"));
            uimenu(menu,'Text','Invert selection', ...
                'MenuSelectedFcn',@(~,~) obj.changeNavigationSelection(scope,"Invert"));
            if id ~= ""
                uimenu(menu,'Text',"Delete " + singular, ...
                    'MenuSelectedFcn',@(~,~) obj.deleteNavigation(scope,id));
            end
            uimenu(menu,'Text',"Delete selected " + lower(scope), ...
                'MenuSelectedFcn',@(~,~) obj.deleteNavigation(scope,""));
        end

        function [allIDs,selected] = navigationSelection(obj,scope)
            allIDs = strings(0,1);
            selected = strings(0,1);
            if isempty(obj.Project), return, end
            if scope == "Images"
                allIDs = obj.Project.ImageIDs;
                selected = obj.Project.SelectedImageIDs;
            elseif ~isempty(obj.Project.ActiveImage)
                img = obj.Project.ActiveImage;
                allIDs = img.RegionOrder;
                selected = img.SelectedRegionIDs;
            end
        end

        function setNavigationSelection(obj,scope,ids)
            if scope == "Images"
                obj.Project.setImageSelection(ids);
            elseif ~isempty(obj.Project.ActiveImage)
                obj.Project.ActiveImage.setRegionSelection(ids);
            end
        end

        function changeNavigationSelection(obj,scope,action)
            if isempty(obj.Project), return, end
            [ids,selected] = obj.navigationSelection(scope);
            switch action
                case "Clear", ids = strings(0,1);
                case "Invert", ids = setdiff(ids,selected,'stable');
            end
            obj.setNavigationSelection(scope,ids);
        end

        function deleteNavigation(obj,scope,id)
            if isempty(obj.Project), return, end
            [~,selected] = obj.navigationSelection(scope);
            if id == "", ids = selected; else, ids = id; end
            if isempty(ids) || ~obj.confirmTreeDeletion(numel(ids),lower(scope)), return, end
            img = obj.Project.ActiveImage;
            for id = reshape(ids,1,[])
                if scope == "Images"
                    obj.Project.removeImage(id);
                else
                    img.removeRegion(id);
                end
            end
            if scope == "Regions", obj.refreshRegionBoxes(); end
        end

        function confirmed = confirmTreeDeletion(obj,count,description)
            confirmed = uiconfirm(obj.Fig,sprintf('Delete %d %s?',count,description), ...
                'Confirm deletion','Options',{'Delete','Cancel'},'DefaultOption',2, ...
                'CancelOption',2,'Icon','warning') == "Delete";
        end

        function showImageInfo(obj,id)
            img = obj.Project.getImage(id);
            if isempty(img), return, end
            info = struct('Name',img.Name,'SourcePath',img.SourcePath, ...
                'Height',img.SizeY,'Width',img.SizeX,'Channels',img.channelNames(), ...
                'Regions',numel(img.RegionArray));
            matlabx.app.TextWindow('Title',img.Name + " Info", ...
                'Text',cellstr(matlabx.struct.prettyPrint(info,StringArrayStyle="lines")));
        end

        function refreshImageViewer(obj)
        %REFRESHIMAGEVIEWER Sync ImageViewer to ActiveImage
            % get the active image
            img = obj.Project.ActiveImage;
            if isempty(img)
                obj.clearImageViewer();
                return
            end

            C = 1;
            previousIndex = obj.ImageViewer.C;
            if previousIndex <= numel(obj.displayedChannelIDs)
                nextIndex = img.sourceChannelIndex(obj.displayedChannelIDs(previousIndex));
                if ~isempty(nextIndex), C = nextIndex; end
            end
            obj.displayedChannelIDs = img.ChannelIDs;

            clims = cell(1,img.SizeC);
            for c = 1:img.SizeC
                policy = obj.Settings.Display.channelPolicy(img.ChannelIDs(c));
                clims{c} = img.displayLimits(c,policy);
            end

            % update ImageViewer ImageData, C, and CLims
            obj.isSyncingChannelDisplay = true;
            cleanup = onCleanup(@() obj.setChannelDisplaySyncFlag(false));
            set(obj.ImageViewer,'ImageData',img.ImageData,'C',C,'ComponentCLims',clims);
            obj.applyProjectChannelDisplayToAxes();
            obj.refreshChannelDisplayControls();
            obj.refreshDisplayLimits();
        end



        function clearImageViewer(obj)
        %REFRESHIMAGEVIEWER Reset ImageViewer
            obj.displayedChannelIDs = strings(1,0);
            obj.ImageViewer.CData = [];
            obj.ImageViewer.Tools.Box.clearBoxes();
        end

        function refreshRegionBoxes(obj)
        %REFRESHREGIONBOXES Sync Region boxes in ImageViewer to ActiveImage

            previous = obj.isSyncingSelection;
            obj.isSyncingSelection = true;
            guard = onCleanup(@() obj.setBoxSelectionSync(previous));
            obj.ImageViewer.Tools.Box.clearBoxes();

            img = obj.Project.ActiveImage;

            if isempty(img) || isempty(img.RegionArray)
                return
            end

            % add a box for each region, colored according to its label
            for r = img.RegionArray'
                label = obj.Project.LabelBank.getByID(r.LabelID);
                if isempty(label), label = obj.Project.LabelBank.getByID("unlabeled"); end
                boxColor = label.Color;
                obj.ImageViewer.Tools.Box.addBox(r.ID, r.Center, r.BoxSize, ...
                    "EdgeColor", boxColor, "FaceColor", boxColor, "Label", r.Name);
            end

            % apply selection status to region boxes
            obj.ImageViewer.Tools.Box.setSelectedBoxIDs(img.SelectedRegionIDs);
            % set active box
            id = img.ActiveRegionID;
            if isempty(id), id = ""; end
            obj.ImageViewer.Tools.Box.setActiveBoxID(id);
        end

        function refreshDisplayLimits(obj)
            item = obj.SettingsAccordion.getItem("Display Limits");
            img = desmostorm.model.STORMImage.empty();
            if ~isempty(obj.Project), img = obj.Project.ActiveImage; end
            n = 0;
            if ~isempty(img), n = img.SizeC; end

            for c = n+1:numel(obj.DisplayLimitBlocks)
                delete(obj.DisplayLimitBlocks(c).Host);
            end
            obj.DisplayLimitBlocks = obj.DisplayLimitBlocks(1:min(n,numel(obj.DisplayLimitBlocks)));
            item.Pane.RowHeight = repmat({'fit'},1,max(1,n));

            for c = 1:n
                if c > numel(obj.DisplayLimitBlocks)
                    block = obj.createDisplayLimitBlock(item.Pane,c);
                    if isempty(obj.DisplayLimitBlocks)
                        obj.DisplayLimitBlocks = block;
                    else
                        obj.DisplayLimitBlocks(c) = block;
                    end
                end
                block = obj.DisplayLimitBlocks(c);
                id = img.ChannelIDs(c);
                policy = obj.Settings.Display.channelPolicy(id);
                [value,bounds] = img.displayLimits(c,policy);
                block.Slider.Title = char(img.channelName(c));
                integerDisplay = any(startsWith(string(img.ImageData.getComponentClass(c)),["int","uint"]));
                block.Slider.RoundValues = integerDisplay;
                if integerDisplay
                    block.Slider.ValueDisplayFormat = '%d';
                else
                    block.Slider.ValueDisplayFormat = '%.2f';
                end
                block.Slider.Limits = bounds;
                block.Slider.Value = value;
                block.KeepAuto.Value = policy.KeepAuto;
                block.Lock.Value = policy.Lock;
                block.Method.Value = char(policy.Method);
                if obj.Settings.Display.ChannelColorMode == "colors"
                    block.Slider.Colormap = linspace(0,1,256).' * obj.Project.getChannelRGB(id);
                else
                    cmap = obj.Project.getChannelColormap(id);
                    sample = round(linspace(1,size(cmap,1),256));
                    block.Slider.Colormap = cmap(sample,:);
                end
            end
        end

        function block = createDisplayLimitBlock(obj,parent,c)
            host = uigridlayout(parent,[3 2], ...
                'ColumnWidth',{'fit','1x'},'RowHeight',{'fit','fit','fit'}, ...
                'Padding',0,'RowSpacing',4,'ColumnSpacing',5, ...
                'BackgroundColor',[.18 .18 .18]);
            host.Layout.Row = c;
            slider = matlabx.ui.control.Slider(host,'ValueMode','range', ...
                'Limits',[0 1],'Value',[0 1],'ValueDisplayFormat','%.2f', ...
                'FontColor',[.9 .9 .9],'BackgroundColor',[.18 .18 .18], ...
                'RoundDigits',0, ...
                'ValueChangingFcn',@(src,~) obj.dragDisplayLimits(c,src.Value), ...
                'ValueChangedFcn',@(src,~) obj.commitDisplayLimits(c,src.Value));
            slider.Layout.Row = 1;
            slider.Layout.Column = [1 2];

            buttons = uigridlayout(host,[1 4], ...
                'ColumnWidth',{'1x','1x','1x','1x'},'RowHeight',{'fit'}, ...
                'ColumnSpacing',4,'Padding',0,'BackgroundColor',[.18 .18 .18]);
            buttons.Layout.Row = 2;
            buttons.Layout.Column = [1 2];
            uibutton(buttons,'Text','Reset', ...
                'ButtonPushedFcn',@(~,~) obj.applyDisplayLimitAction(c,"Reset"));
            uibutton(buttons,'Text','Auto', ...
                'ButtonPushedFcn',@(~,~) obj.applyDisplayLimitAction(c,"Auto"));
            keepAuto = uibutton(buttons,'state','Text','Keep Auto', ...
                'ValueChangedFcn',@(src,~) obj.changeDisplayLimitPolicy(c,"KeepAuto",src.Value));
            lock = uibutton(buttons,'state','Text','Lock', ...
                'ValueChangedFcn',@(src,~) obj.changeDisplayLimitPolicy(c,"Lock",src.Value));
            label = uilabel(host,'Text','Scaling method','FontColor',[.75 .75 .75]);
            label.Layout.Row = 3;
            method = uidropdown(host, ...
                'Items',{'Light contrast','Medium contrast','Strong contrast','Zero to max','Data range'}, ...
                'ValueChangedFcn',@(src,~) obj.changeDisplayLimitPolicy(c,"Method",string(src.Value)));
            method.Layout.Row = 3;
            method.Layout.Column = 2;
            block = struct('Host',host,'Slider',slider,'KeepAuto',keepAuto, ...
                'Lock',lock,'Method',method);
        end

    end

    %% Listener callbacks / UI sync (Regions)
    methods (Access=private)

        % --- LISTENER CALLBACKS ---
        function onRegionAdded(obj,evt)
        %ONREGIONADDED RegionAdded event callback
            desmostorm.Log.INFO("Region added (" + obj.formatRegionEventLabel(evt) + ").")
            obj.refreshRegionTree();
            obj.markProjectDirty();
        end

        function onRegionRemoved(obj,evt)
        %ONREGIONREMOVED RegionRemoved event callback    
            desmostorm.Log.INFO("Region removed (" + obj.formatRegionEventLabel(evt) + ").")
            obj.refreshRegionTree();
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
            obj.refreshRegionTree();
            if ~obj.isSyncingSelection
                obj.isSyncingSelection = true;
                guard = onCleanup(@() obj.setBoxSelectionSync(false));
                obj.ImageViewer.Tools.Box.setSelectedBoxIDs(evt.NewIDs);
            end
        end

        % --- UI SYNC DRIVER ---
        function syncActiveRegionToView(obj)
        %SYNCACTIVEREGIONTOVIEW Sync UI to ActiveRegion
            obj.refreshRegionViewer();
            obj.refreshRegionSummaryTable();
            obj.refreshRegionROI();
            obj.refreshRegionLinescanPlot();

            obj.refreshRegionTree();
            img = obj.Project.ActiveImage;
            if ~isempty(img)
                id = img.ActiveRegionID;
                if isempty(id), id = ""; end
                previous = obj.isSyncingSelection;
                obj.isSyncingSelection = true;
                guard = onCleanup(@() obj.setBoxSelectionSync(previous));
                obj.ImageViewer.Tools.Box.setActiveBoxID(id);
            end
        end

        function refreshRegionTree(obj)
            img = obj.Project.ActiveImage;
            if isempty(img)
                obj.clearRegionTree();
                return
            end
            obj.syncNavigationTree(obj.RegionTree,"Regions",img.RegionOrder, ...
                img.RegionNames,img.ActiveRegionID,img.SelectedRegionIDs);
        end

        function clearRegionTree(obj)
            deleteTreeNodes(obj.RegionTree.Children);
        end

        function setBoxSelectionSync(obj,value)
            obj.isSyncingSelection = value;
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

            previous = obj.isSyncingChannelDisplay;
            obj.isSyncingChannelDisplay = true;
            guard = onCleanup(@() obj.setChannelDisplaySyncFlag(previous));
            obj.RegionViewer.ImageData = matlabx.image.Image5D.fromComponents( ...
                img.regionSubimageCell(img.ActiveRegion),Names=img.channelNames());
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

            [plotData,colorChannels] = obj.getRegionLinescanPlotData(reg);
            if isempty(plotData)
                obj.clearRegionLinescanPlot();
                return
            end

            host = obj.RegionLinescanPlot;
            yLabel = "Intensity";
            if obj.Settings.Analysis.Normalize, yLabel = "Normalized intensity"; end
            xlabel(host.Axes,"Distance (" + img.PixelSize.Unit + ")");
            ylabel(host.Axes,yLabel);
            title(host.Axes,matlabx.utils.text.texFriendly(img.Name) + " | " + ...
                matlabx.utils.text.texFriendly(reg.Name));

            appearance = obj.Settings.PeaksPlot;
            host.FontSize = appearance.FontSize;
            host.TitleVisible = appearance.TitleVisible;
            colors = appearance.Color;
            if appearance.ColorSource == "channel"
                colors = obj.getRegionLinescanPlotColors(colorChannels);
            end
            annotationColors = zeros(0,3);
            if appearance.AnnotationColorMode == "manual"
                annotationColors = appearance.AnnotationColor;
            end
            names = img.channelNames();
            data = desmostorm.plot.PeaksPlotData(plotData, ...
                ChannelIDs=img.ChannelIDs(colorChannels),Names=names(colorChannels));
            style = desmostorm.plot.PeaksPlotStyle( ...
                Colors=colors,AnnotationColors=annotationColors, ...
                RawLineWidth=appearance.RawLineWidth,SmoothLineWidth=appearance.SmoothLineWidth, ...
                AnnotationLineWidth=appearance.AnnotationLineWidth, ...
                AnnotationsFontSize=appearance.AnnotationFontSize, ...
                BackgroundColor=appearance.BackgroundColor,ForegroundColor=appearance.ForegroundColor, ...
                DistanceAnnotations=appearance.DistanceAnnotations, ...
                DistanceAnnotationsMode=appearance.DistanceAnnotationsMode, ...
                WidthAnnotations=appearance.WidthAnnotations, ...
                WidthAnnotationsMode=appearance.WidthAnnotationsMode);
            obj.RegionLinescanRenderer.update(data,style);
            host.Visible = 'on';
            obj.updateRegionLinescanPlotRows(1);
        end

        function clearRegionLinescanPlot(obj)
            if isempty(obj.RegionLinescanPlot), return, end
            obj.RegionLinescanRenderer.update(desmostorm.plot.PeaksPlotData());
            obj.RegionLinescanPlot.Visible = 'off';
            obj.updateRegionLinescanPlotRows(0);
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

        function colors = getRegionLinescanPlotColors(obj,channels)
        %GETREGIONLINESCANPLOTCOLORS Convert project channel color names to RGB rows
            channels = channels(:).';
            colors = zeros(numel(channels),3);
            img = obj.Project.ActiveImage;
            for i = 1:numel(channels)
                colors(i,:) = obj.Project.getChannelRGB(img.ChannelIDs(channels(i)));
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
            if isempty(obj.Project), return, end
            label = obj.Project.LabelBank.getByHotkey(key);
            if isempty(label), return, end
            obj.Project.LabelBank.setActiveByID(label.ID);
            syncTreeSelection(obj.LabelsTree,label.ID,obj.Project.LabelBank.SelectedLabelIDs);
            obj.applyRegionLabel(label.ID);
        end

        function refreshLabelsTree(obj)
            obj.isSyncingTrees = true;
            guard = onCleanup(@() obj.endTreeSync());
            obj.clearLabelsTree();
            if isempty(obj.Project), return, end

            bank = obj.Project.LabelBank;
            labels = bank.labels();
            for k = 1:numel(labels)
                label = labels(k);
                title = label.Name;
                if label.hasHotkey(), title = title + "  [" + label.Hotkey + "]"; end
                node = uitreenode(obj.LabelsTree,'Text',title);
                node.NodeData = label.ID;
                node.Icon = char(matlabx.ui.icon.get(Shape="circle",Color=label.Color,Size=16));
                node.ContextMenu = obj.labelMenu(label.ID);
            end

            syncTreeSelection(obj.LabelsTree,bank.ActiveLabelID,bank.SelectedLabelIDs);
        end

        function clearLabelsTree(obj)
            deleteTreeNodes(obj.LabelsTree.Children);
        end

        function onSelectLabel(obj,evt)
            if obj.isSyncingTrees || isempty(obj.Project) || isempty(evt.SelectedNodes), return, end
            obj.Project.LabelBank.setActiveByID(string(evt.SelectedNodes(1).NodeData));
        end

        function onCheckLabels(obj,evt)
            if obj.isSyncingTrees || isempty(obj.Project), return, end
            obj.Project.LabelBank.setSelection(nodeIDs(evt.CheckedNodes));
        end

        function menu = labelMenu(obj,id)
            menu = uicontextmenu(obj.Fig);
            merge = uimenu(menu,'Text','Merge selected labels...', ...
                'MenuSelectedFcn',@(~,~) obj.mergeSelectedLabels());
            menu.ContextMenuOpeningFcn = @(~,~) obj.updateMergeMenu(merge);
            uimenu(menu,'Text','New label...', ...
                'MenuSelectedFcn',@(~,~) obj.promptLabel(""));
            if id == "", return, end
            uimenu(menu,'Text','Edit...','Separator','on', ...
                'MenuSelectedFcn',@(~,~) obj.promptLabel(id));
            uimenu(menu,'Text','Select regions with this label', ...
                'MenuSelectedFcn',@(~,~) obj.selectRegionsWithLabel(id));
            uimenu(menu,'Text','Apply to current region selection', ...
                'MenuSelectedFcn',@(~,~) obj.applyRegionLabel(id));
            uimenu(menu,'Text','Delete regions with this label', ...
                'MenuSelectedFcn',@(~,~) obj.deleteRegionsWithLabel(id));
            uimenu(menu,'Text','Delete label','Enable',id ~= "unlabeled", ...
                'MenuSelectedFcn',@(~,~) obj.deleteLabel(id));
        end

        function updateMergeMenu(obj,menu)
            menu.Enable = ~isempty(obj.Project) && ...
                nnz(obj.Project.LabelBank.SelectedLabelIDs ~= "unlabeled") >= 2;
        end

        function selectRegionsWithLabel(obj,id)
            if isempty(obj.Project), return, end
            images = obj.Project.ImageArray;
            for k = 1:numel(images)
                img = images(k);
                matches = img.getRegionsByLabelID(id);
                if isempty(matches), continue, end
                img.setRegionSelection([img.SelectedRegionIDs(:);reshape([matches.ID],[],1)]);
            end
        end

        function applyRegionLabel(obj,id)
            if isempty(obj.Project) || isempty(obj.Project.LabelBank.getByID(id)), return, end
            images = obj.Project.ImageArray;
            changed = false;
            for k = 1:numel(images)
                img = images(k);
                for regionID = reshape(img.SelectedRegionIDs,1,[])
                    region = img.getRegion(regionID);
                    if ~isempty(region) && (region.LabelID ~= id || region.LabelSource ~= "user")
                        region.LabelID = id;
                        region.LabelSource = "user";
                        changed = true;
                    end
                end
            end
            if changed
                obj.refreshRegionBoxes();
                obj.refreshRegionSummaryTable();
                obj.markProjectDirty();
            end
        end

        function deleteRegionsWithLabel(obj,id)
            if isempty(obj.Project), return, end
            regions = obj.Project.getRegionsByLabelID(id);
            if isempty(regions) || ~obj.confirmTreeDeletion(numel(regions),"matching regions"), return, end
            for k = 1:numel(regions)
                region = regions(k);
                region.Parent.removeRegion(region.ID);
            end
            obj.refreshRegionBoxes();
        end

        function onManageLabels(obj)
            if isempty(obj.Project), return, end
            snapshot = obj.Project.LabelBank.toStruct();
            [draft,originalIDs] = desmostorm.app.editLabelsDialog(snapshot.Labels);
            if ~isempty(draft)
                ids = reshape(string({draft.ID}),[],1);
                edited = originalIDs ~= "" & originalIDs ~= ids;
                removed = reshape(setdiff(string({snapshot.Labels.ID}),originalIDs),[],1);
                obj.Project.replaceLabels(draft,SourceIDs=[originalIDs(edited);removed], ...
                    TargetIDs=[ids(edited);repmat("unlabeled",numel(removed),1)]);
            end
        end

        function promptLabel(obj,id)
            if isempty(obj.Project), return, end
            bank = obj.Project.LabelBank;
            label = bank.getByID(id);
            if isempty(label)
                [name,defaultID] = obj.nextLabelIdentity("Label","label-");
                hotkey = "";
                color = [1 1 1];
                title = "New label";
            else
                name = label.Name;
                defaultID = id;
                hotkey = label.Hotkey;
                color = label.Color;
                title = "Edit label";
            end
            params = obj.labelParameters(title,name,hotkey,color,id,defaultID);
            if isempty(params), return, end
            if isempty(label)
                bank.add(params.Name,ID=params.ID,Hotkey=params.Hotkey, ...
                    Color=params.Color,MakeActive=true);
                obj.refreshLabelsTree();
            else
                snapshot = bank.toStruct();
                labels = snapshot.Labels;
                index = find(string({labels.ID}) == id,1);
                labels(index).ID = params.ID;
                labels(index).Name = params.Name;
                labels(index).Hotkey = params.Hotkey;
                labels(index).Color = params.Color;
                if params.ID == id
                    obj.Project.replaceLabels(labels);
                else
                    obj.Project.replaceLabels(labels,SourceIDs=id,TargetIDs=params.ID);
                end
            end
        end

        function [name,id] = nextLabelIdentity(obj,prefix,idPrefix)
            labels = obj.Project.LabelBank.labels();
            names = string({labels.Name});
            ids = string({labels.ID});
            number = max(1,numel(labels));
            name = prefix + " " + number;
            id = idPrefix + number;
            while any(strcmpi(name,names)) || ismember(id,ids)
                number = number+1;
                name = prefix + " " + number;
                id = idPrefix + number;
            end
        end

        function params = labelParameters(obj,title,name,hotkey,color,excludedID,defaultID)
            labels = obj.Project.LabelBank.labels();
            labels = labels(string({labels.ID}) ~= excludedID);
            names = string({labels.Name});
            keys = string({labels.Hotkey});
            idField = {};
            if excludedID ~= "unlabeled"
                ids = string({labels.ID});
                idField = {{'ID','ID','string',defaultID, ...
                    @(x) strlength(strtrim(x)) > 0 && ~ismember(strtrim(x),ids), ...
                    'ID must be nonempty and unique.'}};
            end
            params = matlabx.app.ParamsDialog.prompt(title, ...
                idField{:}, ...
                {'Name','Name','string',name, ...
                    @(x) strlength(strtrim(x)) > 0 && ~any(strcmpi(strtrim(x),names)), ...
                    'Name must be nonempty and unique.'}, ...
                {'Hotkey','Hotkey','string',hotkey, ...
                    @(x) strlength(strtrim(x)) == 0 || ...
                        (~isempty(regexp(char(strtrim(x)),'^[A-Za-z0-9]$','once')) && ...
                        ~any(strcmpi(strtrim(x),keys))), ...
                    'Enter one unique alphanumeric character, or leave blank.'}, ...
                {'Color','Color','color',color});
            if ~isempty(params)
                params.Name = strtrim(string(params.Name));
                params.Hotkey = lower(strtrim(string(params.Hotkey)));
                if excludedID == "unlabeled"
                    params.ID = excludedID;
                else
                    params.ID = strtrim(string(params.ID));
                end
            end
        end

        function deleteLabel(obj,id)
            if isempty(obj.Project) || id == "unlabeled", return, end
            bank = obj.Project.LabelBank;
            label = bank.getByID(id);
            if isempty(label) || ~obj.confirmTreeDeletion(1,"label and reassign its regions to Unlabeled"), return, end
            snapshot = bank.toStruct();
            obj.Project.replaceLabels(snapshot.Labels(string({snapshot.Labels.ID}) ~= id));
        end

        function mergeSelectedLabels(obj)
            if isempty(obj.Project), return, end
            bank = obj.Project.LabelBank;
            ids = setdiff(bank.SelectedLabelIDs,"unlabeled",'stable');
            if numel(ids) < 2, return, end
            snapshot = bank.toStruct();
            selected = ismember(string({snapshot.Labels.ID}),ids);
            color = mean(vertcat(snapshot.Labels(selected).Color),1);
            [name,defaultID] = obj.nextLabelIdentity("Merged label","merged-label-");
            params = obj.labelParameters("Merge selected labels",name,"",color,"",defaultID);
            if isempty(params), return, end

            merged = struct('ID',params.ID, ...
                'Name',params.Name,'Hotkey',params.Hotkey, ...
                'Color',params.Color,'CreatedAt',datetime('now'));
            draft = [reshape(snapshot.Labels(~selected),1,[]),merged];
            obj.Project.replaceLabels(draft,SourceIDs=ids, ...
                TargetIDs=repmat(merged.ID,size(ids)),ActivateID=merged.ID);
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
                    if ~isempty(obj.Project)
                        obj.Project.setDefaultChannelColormap( ...
                            obj.Settings.Display.ColormapName,obj.Settings.Display.ColormapCategory);
                    end
                case "BoxFaceColor"
                    %set(obj.ROI, 'FaceColor', obj.Settings.Display.BoxFaceColor);
                case "BoxEdgeColor"
                    %set(obj.ROI, 'EdgeColor', obj.Settings.Display.BoxEdgeColor);
            end
            obj.markProjectDirty();
        end

        function onPeaksPlotChanged(obj,~)
            obj.refreshPeaksPlotControls();
            if ~isempty(obj.Project), obj.refreshRegionLinescanPlot(); end
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
                    % Pixel size changes only rescale existing distance outputs.
                    obj.Project.refreshRegionLinescanPixelSizes();
                    % refresh displays that format distances or scaled plot axes
                    obj.refreshRegionSummaryTable();
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
            if obj.isSyncingColormapSelection || isempty(obj.Project)
                return
            end
            node = evt.SelectedNodes;
            id = string(obj.SettingsUI.ChannelDisplay.Channel.Value);
            if id == "" || isempty(node) || ~isstruct(node(1).NodeData)
                return
            end
            data = node(1).NodeData;
            obj.Project.setChannelColormap(id,data.Name,data.Category);
            obj.applyProjectChannelDisplayToAxes();
            obj.refreshChannelDisplayControls();
            obj.refreshDisplayLimits();
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

        function ChannelColorChanged(obj,src)
            id = string(obj.SettingsUI.ChannelDisplay.Channel.Value);
            if ~isempty(obj.Project) && id ~= ""
                obj.Project.setChannelColor(id,string(src.Value));
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
            obj.Project.setDefaultChannelColormap( ...
                obj.Settings.Display.ColormapName, ...
                obj.Settings.Display.ColormapCategory);
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
            [h,cleanupProgress] = obj.createProgressDialog(msg);
            % cleanup before loading
            if ~isempty(obj.Project), obj.Project.delete(); end   % delete project
            if ~isempty(obj.Settings), obj.Settings.delete(); end  % delete settings
            obj.detatchListeners(); % detach listeners
            % load Project and Settings
            [proj,stgs] = desmostorm.model.STORMProject.load(fname, ...
                "MissingImageResolver", @(names,folder) resolveMissingImages(h,names,folder));
            clear cleanupProgress
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

        function saved = saveProject(obj,saveAs)
            arguments
                obj
                saveAs (1,1) logical = false
            end

            saved = false;
            if isempty(obj.Project), return, end

            destination = obj.Project.SourcePath;
            if saveAs || ~obj.Project.isOnDisk || destination == ""
                if destination == ""
                    folder = obj.Settings.IO.DefaultFolder;
                else
                    folder = fileparts(destination);
                end
                suggested = fullfile(folder,obj.Project.Name + ".mat");
                [file,folder] = uiputfile('*.mat','Save DesmoSTORM project',char(suggested));
                desmostorm.app.focusMainFigure();
                if isequal(file,0), return, end
                destination = string(fullfile(folder,file));
            end

            [~,cleanup] = obj.createProgressDialog( ...
                sprintf('Saving project file:\n%s',destination));
            try
                obj.Project.save(destination,obj.Settings);
            catch ME
                clear cleanup
                desmostorm.Log.EXCEPTION(ME);
                obj.guialert("Title","Save failed","Message",ME.message,"Icon",'error');
                return
            end
            obj.refreshWindowName();
            desmostorm.Log.INFO(sprintf("Successfully saved project file: %s",destination));
            saved = true;
        end

        function onSaveSettings(obj)
            obj.Settings.save();
            desmostorm.Log.INFO("Saved app defaults.");
        end

        function onLoadSettings(obj)
            loaded = desmostorm.config.Settings.load();
            cleanup = onCleanup(@() delete(loaded));
            before = obj.Settings.toStruct();
            after = loaded.toStruct();
            if isequaln(before,after), return, end

            % Apply the snapshot together so intermediate setting events do not
            % reprocess data or delete regions when the default box size changes.
            obj.detatchListeners();
            listeners = onCleanup(@() obj.refreshListeners());
            obj.Settings.fromStruct(after);
            clear listeners

            obj.ImageViewer.Tools.Box.BoxSize = obj.Settings.Analysis.BoxSize;
            obj.refreshSettingsControllers();
            if ~isempty(obj.Project)
                obj.Project.setDefaultChannelColormap( ...
                    obj.Settings.Display.ColormapName,obj.Settings.Display.ColormapCategory);
                pixelSizeChanged = before.Analysis.PixelSizeValue ~= after.Analysis.PixelSizeValue || ...
                    string(before.Analysis.PixelSizeUnit) ~= string(after.Analysis.PixelSizeUnit);
                if pixelSizeChanged
                    obj.Project.DefaultPixelSize = obj.Settings.Analysis.getDefaultPixelSize();
                end
                obj.markProjectDirty();

                geometry = {'BoxSize','PixelSizeValue','PixelSizeUnit'};
                if ~isequaln(rmfield(before.Analysis,geometry),rmfield(after.Analysis,geometry))
                    obj.processAllRegions();
                else
                    if pixelSizeChanged, obj.Project.refreshRegionLinescanPixelSizes(); end
                    obj.syncActiveImageToView();
                end
            end
            desmostorm.Log.INFO("Loaded app defaults.");
        end

        function onImportImages(obj)
        %ONIMPORTIMAGES MenuSelectedCallback for [File]->[Import Images...]
            % get image filename(s)
            fig = obj.Fig;
            wasVisible = fig.Visible;
            restoreVisibility = onCleanup(@() set(fig,'Visible',wasVisible));
            fig.Visible = 'off';
            [files,path,~] = matlabx.image.io.uigetimagefile('MultiSelect','on');
            if isequal(files,0), return; end % cancelled | no files selected -> return
            fig.Visible = wasVisible;
            [progress,cleanupProgress] = obj.createProgressDialog("Preparing image import...");
            files = string(files);
            fullpaths = fullfile(path, files);
            images = desmostorm.model.STORMImage.empty();
            for i = 1:numel(fullpaths)
                desmostorm.runtime.updateProgress(progress, ...
                    sprintf('Image %d/%d: %s\nReading channel metadata...', ...
                    i,numel(files),files(i)),.7*(i-1)/numel(files));
                images(i) = desmostorm.model.STORMImage(obj.Project,files(i), ...
                    fullpaths(i),matlabx.utils.text.uniqueID());
            end
            [names,colors] = desmostorm.app.channelDialog(obj.Project,images, ...
                ProgressDialog=progress,Parent=fig);
            clear cleanupProgress
            clear restoreVisibility
            if isempty(names), return, end
            obj.Project.importImages(images,names,colors);
            desmostorm.Log.INFO(sprintf("Imported %d image(s).",numel(images)));
        end

        function onEditChannels(obj)
            if isempty(obj.Project.Channels), return, end
            [names,colors] = desmostorm.app.channelDialog(obj.Project);
            if ~isempty(names)
                obj.Project.editChannels(names{1},colors{1});
            end
        end

    end

    %% Per-image settings
    methods (Access=private)

        function dragDisplayLimits(obj,c,value)
            obj.ImageViewer.MaxRenderedResolution = obj.ImageViewer.CDataSize(1)/4;
            obj.RegionViewer.MaxRenderedResolution = obj.Settings.Analysis.BoxSize/4;
            obj.previewDisplayLimits(c,value);
        end

        function previewDisplayLimits(obj,c,value)
            if value(1) >= value(2), return, end
            previous = obj.isSyncingChannelDisplay;
            obj.isSyncingChannelDisplay = true;
            guard = onCleanup(@() obj.setChannelDisplaySyncFlag(previous));
            obj.ImageViewer.setComponentCLim(value,c);
        end

        function storeManualDisplayLimits(obj,img,c,value)
            id = img.ChannelIDs(c);
            policy = obj.Settings.Display.channelPolicy(id);
            img.setDisplayRange(value,c);
            policy.KeepAuto = false;
            if policy.Lock, policy.LockedRange = value; end
            obj.Settings.Display.setChannelPolicy(policy);
            obj.markProjectDirty();
        end

        function commitDisplayLimits(obj,c,value)
            img = obj.Project.ActiveImage;
            obj.ImageViewer.MaxRenderedResolution = 'none';
            obj.RegionViewer.MaxRenderedResolution = 'none';
            if value(1) >= value(2)
                policy = obj.Settings.Display.channelPolicy(img.ChannelIDs(c));
                obj.previewDisplayLimits(c,img.displayLimits(c,policy));
            else
                value = img.normalizeDisplayRange(c,value);
                obj.storeManualDisplayLimits(img,c,value);
                obj.previewDisplayLimits(c,value);
            end
            obj.refreshDisplayLimits();
        end

        function applyDisplayLimitAction(obj,c,action)
            img = obj.Project.ActiveImage;
            policy = obj.Settings.Display.channelPolicy(img.ChannelIDs(c));
            [~,~,value] = img.displayLimits(c,policy);
            if action == "Auto"
                value = img.automaticDisplayRange(c,policy.Method,value);
            end
            obj.commitDisplayLimits(c,value);
        end

        function changeDisplayLimitPolicy(obj,c,field,value)
            img = obj.Project.ActiveImage;
            policy = obj.Settings.Display.channelPolicy(img.ChannelIDs(c));
            if field == "Lock" && value
                policy.LockedRange = img.displayLimits(c,policy);
                policy.KeepAuto = false;
            elseif field == "KeepAuto" && value
                policy.Lock = false;
            end
            policy.(field) = value;
            obj.Settings.Display.setChannelPolicy(policy);
            obj.markProjectDirty();
            obj.previewDisplayLimits(c,img.displayLimits(c,policy));
            obj.refreshDisplayLimits();
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
            [h,cleanupProgress] = obj.createProgressDialog("Analyzing ROIs. Please wait...");
            % re-process everything
            obj.Project.processAll(obj.getRunConfig(), ...
                "ProgressDialog",h)
            % sync UI
            obj.syncActiveImageToView();
            obj.markProjectDirty();
            desmostorm.Log.INFO("Region analysis complete.");
        end

        function onAutoFitAllROIs(obj)
            % create progress dialog
            desmostorm.Log.INFO("Fitting ROIs for all regions...");
            [h,cleanup] = obj.createProgressDialog('Preparing ROI auto-fit...',0);
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
            [h,cleanup] = obj.createProgressDialog('Preparing ROI auto-fit...',0);
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
            [h,cleanupProgress] = obj.createProgressDialog('Preparing classifier proposals...',0);

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
                desmostorm.runtime.updateProgress(h,progressPrefix + "Running classifier...",(i-1)/N);
                propOpts.ProgressDialog = @(message,value) reportClassifierProgress(h,message,value,i,N);
                propOpts.ProgressMessagePrefix = string(progressPrefix);
                desmostorm.Log.INFO(sprintf("Running classifier on image (%i/%i): %s",i,N,imgs(i).Name));
                imgs(i).runClassifier(net,propOpts);
            end


            % --- sync UI ---
            obj.syncActiveImageToView();
            obj.markProjectDirty();
            desmostorm.runtime.updateProgress(h,"Classifier run complete.",1);

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
            [h,cleanupProgress] = obj.createProgressDialog("Preparing classifier training...");

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
            [h,cleanupProgress] = obj.createProgressDialog("Preparing classifier retraining...");

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
            [h,cleanupProgress] = obj.createProgressDialog("Preparing fresh classifier retraining...");

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

        function onBoxActivated(obj,data)
            if obj.isSyncingSelection || isempty(obj.Project), return, end
            img = obj.Project.ActiveImage;
            if ~isempty(img), img.setActiveRegion(data.ID); end
        end

        function onBoxSelectionChanged(obj,data)
            if obj.isSyncingSelection || isempty(obj.Project), return, end
            img = obj.Project.ActiveImage;
            if isempty(img), return, end
            obj.isSyncingSelection = true;
            guard = onCleanup(@() obj.setBoxSelectionSync(false));
            img.setRegionSelection(data.IDs);
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
            restoreFocus = onCleanup(@desmostorm.app.focusMainFigure);

            desmostorm.Log.INFO("Exporting region measurements...");
            try
                success = desmostorm.export.Exporter.exportRegionMeasurements(obj.Project,obj.Settings, ...
                    "ProgressFactory",@(message) obj.createProgressDialog(message));
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
            restoreFocus = onCleanup(@desmostorm.app.focusMainFigure);

            desmostorm.Log.INFO("Exporting summary PDF...");
            try
                success = desmostorm.export.Exporter.exportSummaryPDF(obj.Project,obj.Settings, ...
                    "ProgressFactory",@(message) obj.createProgressDialog(message));
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
            restoreFocus = onCleanup(@desmostorm.app.focusMainFigure);

            desmostorm.Log.INFO("Exporting region images...");
            try
                success = desmostorm.export.Exporter.exportRegionImages(obj.Project,obj.Settings, ...
                    "CurrentChannel",obj.RegionViewer.C, ...
                    "ProgressFactory",@(message) obj.createProgressDialog(message));
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
            restoreFocus = onCleanup(@desmostorm.app.focusMainFigure);

            desmostorm.Log.INFO("Exporting images with region box overlays...");
            try
                success = desmostorm.export.Exporter.exportImagesWithRegionBoxes(obj.Project,obj.Settings, ...
                    "CurrentChannel",obj.ImageViewer.C, ...
                    "ProgressFactory",@(message) obj.createProgressDialog(message));
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
            restoreFocus = onCleanup(@desmostorm.app.focusMainFigure);

            desmostorm.Log.INFO("Exporting region linescan plot...");
            try
                success = desmostorm.export.Exporter.exportRegionLinescanPlot(obj.Project,obj.Settings, ...
                    "CurrentChannel",obj.ImageViewer.C, ...
                    "ProgressFactory",@(message) obj.createProgressDialog(message));
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
            restoreFocus = onCleanup(@desmostorm.app.focusMainFigure);

            desmostorm.Log.INFO("Exporting region subimage with ROI overlay...");
            try
                success = desmostorm.export.Exporter.exportRegionSubimageWithROI(obj.Project,obj.Settings, ...
                    "CurrentChannel",obj.RegionViewer.C, ...
                    "ProgressFactory",@(message) obj.createProgressDialog(message));
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

    %% Progress dialogs
    methods (Access=private)

        function [h,cleanupProgress] = createProgressDialog(obj,msg,initialValue)
            if nargin < 3, initialValue = []; end
            h = matlab.ui.dialog.ProgressDialog.empty();
            if ~isempty(obj.Fig) && isvalid(obj.Fig) && obj.Fig.Visible == "on"
                h = uiprogressdlg(obj.Fig, ...
                    "Title","DesmoSTORM","Message",msg, ...
                    "Indeterminate","on");
            end

            cleanupProgress = onCleanup(@() closeProgressDialog(h));
            desmostorm.runtime.updateProgress(h,msg,initialValue);
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

function searchRoot = resolveMissingImages(progress, names, folder)
    closeProgressDialog(progress);
    searchRoot = desmostorm.app.promptMissingImageRoot(names, folder);
end

function [name,category] = identifyColormap(map)
    name = "";
    category = "";
    for candidateCategory = reshape(matlabx.colors.maps.Registry.categories(),1,[])
        for candidateName = reshape(matlabx.colors.maps.Registry.names(candidateCategory),1,[])
            candidate = matlabx.colors.maps.Registry.map(candidateName,candidateCategory);
            if isequal(size(candidate),size(map)) && ...
                    max(abs(double(candidate(:))-double(map(:)))) <= 1e-12
                name = candidateName;
                category = candidateCategory;
                return
            end
        end
    end
end

function ids = nodeIDs(nodes)
    if isempty(nodes)
        ids = strings(1,0);
        return
    end
    ids = reshape(string({nodes.NodeData}),1,[]);
end

function deleteTreeNodes(nodes)
    if isempty(nodes), return, end
    for k = 1:numel(nodes)
        menu = nodes(k).ContextMenu;
        if ~isempty(menu) && isvalid(menu), delete(menu); end
    end
    delete(nodes);
end

function syncTreeSelection(tree,activeID,selectedIDs)
    nodes = tree.Children;
    ids = nodeIDs(nodes);
    active = find(ismember(ids,activeID),1);
    if isempty(active)
        if ~isempty(tree.SelectedNodes), tree.SelectedNodes = []; end
    elseif ~isequal(tree.SelectedNodes,nodes(active))
        tree.SelectedNodes = nodes(active);
    end

    checked = ismember(ids,selectedIDs);
    if ~any(checked)
        if ~isempty(tree.CheckedNodes), tree.CheckedNodes = []; end
    else
        checkedNodes = nodes(checked);
        if ~isequal(tree.CheckedNodes(:),checkedNodes(:))
            tree.CheckedNodes = checkedNodes(:)';
        end
    end
end

function reportClassifierProgress(sink,message,value,index,count)
    if isempty(value)
        desmostorm.runtime.updateProgress(sink,message);
    else
        desmostorm.runtime.updateProgress(sink,message,(index-1+value)/count);
    end
end
