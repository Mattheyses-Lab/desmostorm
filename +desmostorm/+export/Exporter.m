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

classdef Exporter
    methods (Static)
        function result = exportRegionMeasurements(project,config,opts)
            arguments
                project (1,1) desmostorm.model.STORMProject
                config  (1,1) desmostorm.config.Settings
                opts.ProgressDialog = []
                opts.ProgressFactory = []
            end

            result = false;

            defaultName = fullfile(config.IO.DefaultFolder, [char(project.Name),'_region-measurements.xlsx']);
            [file, path] = uiputfile('*.xlsx', ...
                'Export region measurements', defaultName);
            desmostorm.app.focusMainFigure();

            if isequal(file,0), return; end

            [progress,cleanupProgress] = startExportProgress(opts,'Writing region measurements...'); %#ok<NASGU>
            desmostorm.export.regionMeasurementsXlsx(project, fullfile(path, file), ...
                "ProgressDialog",progress);
            result = true;
        end

        function result = exportSummaryPDF(project,config,opts)
            arguments
                project (1,1) desmostorm.model.STORMProject
                config  (1,1) desmostorm.config.Settings
                opts.ProgressDialog = []
                opts.ProgressFactory = []
            end

            result = false;

            if isempty(project.Channels), return, end
            channelChoices = ["All channels", projectChannelChoices(project)];
            params = desmostorm.export.ExportDialog.prompt("Export Summary PDF", {
                "Export Options", {
                    choiceField("ImageChannel","Channel",channelChoices,channelChoices(1))
                    numberField("PageWidthInches","Page width (inches)",11)
                    numberField("FontSizePoints","Summary text size (points)",8)
                    sizingField("StyleSizing","Style sizing")
                }
                "Plot Options", plotFields(config.PeaksPlot)
                "Image Options", {
                    numberField("ImageResolution","Image resolution (DPI)",600)
                    scalingField()
                }
            });
            desmostorm.app.focusMainFigure();

            if isempty(params), return; end
            selected = find(channelChoices == string(params.ImageChannel),1);
            if selected == 1
                params.ImageChannel = "all";
            else
                params.ImageChannel = string(selected - 1);
            end
            params = inheritPlotStyle(params,config.PeaksPlot);
            params = inheritROIVisibility(params,config.ROI);
            params.WidthAnnotationsMode = "normal";
            params.PlotFontSize = params.FontSize;
            params = rmfield(params,"FontSize");
            params.ScalingMode = string(params.ScalingMode);

            defaultName = fullfile(config.IO.DefaultFolder, [char(project.Name),'_summary.pdf']);
            [file, path] = uiputfile('*.pdf', ...
                'Export peak plots', defaultName);
            desmostorm.app.focusMainFigure();

            if isequal(file,0), return; end

            [progress,cleanupProgress] = startExportProgress(opts,'Exporting summary PDF...'); %#ok<NASGU>

            paramsCell = matlabx.struct.toKeyValueCell(params);

            desmostorm.export.summaryPDF(project, fullfile(path,file), config, ...
                "ProgressDialog", progress, paramsCell{:});

            result = true;
        end

        function result = exportRegionImages(project,config,opts)
            arguments
                project (1,1) desmostorm.model.STORMProject
                config  (1,1) desmostorm.config.Settings
                opts.CurrentChannel (1,1) double {mustBeInteger,mustBePositive} = 1
                opts.ProgressDialog = []
                opts.ProgressFactory = []
            end

            result = false;

            if isempty(project.Channels), return, end
            channelChoices = projectChannelChoices(project);
            options = desmostorm.export.ExportDialog.prompt("Export Region Images", {
                "Export Options", {
                    channelField(project,opts.CurrentChannel,channelChoices)
                    choiceField("OutputFormat","Format",["grayscale TIFF","RGB PNG"],"grayscale TIFF")
                    toggleField("TiledSummary","Tiled summary",false)
                }
                "Image Options", {scalingField()}
            });
            desmostorm.app.focusMainFigure();

            if isempty(options), return; end

            folderName = uigetdir(config.IO.DefaultFolder, 'Export region images');
            desmostorm.app.focusMainFigure();

            if ~isfolder(folderName), return; end

            [progress,cleanupProgress] = startExportProgress(opts,'Writing region images...'); %#ok<NASGU>
            desmostorm.export.regionImages(project, folderName, ...
                "Channel",find(channelChoices == string(options.Channel),1), ...
                "ScalingMode",string(options.ScalingMode), ...
                "DisplaySettings",config.Display, ...
                "OutputFormat",string(options.OutputFormat), ...
                "ChannelColorMode",config.Display.ChannelColorMode, ...
                "TiledSummary",options.TiledSummary, ...
                "ProgressDialog",progress);
            result = true;
        end

        function result = exportImagesWithRegionBoxes(project,config,opts)
            arguments
                project (1,1) desmostorm.model.STORMProject
                config  (1,1) desmostorm.config.Settings
                opts.CurrentChannel (1,1) double {mustBeInteger,mustBePositive} = 1
                opts.ProgressDialog = []
                opts.ProgressFactory = []
            end

            result = false;

            if isempty(project.Channels), return, end
            channelChoices = projectChannelChoices(project);
            options = desmostorm.export.ExportDialog.prompt("Export Images with Region Boxes", {
                "Export Options", [
                    {
                        choiceField("Scope","Images",["active","all"],"active")
                        channelField(project,opts.CurrentChannel,channelChoices)
                    }
                    imageFileFields(7)
                ]
                "Image Options", {scalingField()}
                "Region Boxes", {
                    colorModeField("ColorMode","Box colors",["label","manual"],"label","Color",config.Box.EdgeColor)
                    toggleField("RegionNamesVisible","Show region names",config.Box.ShowTitle)
                    opacityField("BoxFaceAlpha","Box opacity",0)
                    numberField("FontSize","Font size",10)
                }
            });
            desmostorm.app.focusMainFigure();

            if isempty(options), return; end

            options.Scope = string(options.Scope);
            options.Channel = find(channelChoices == string(options.Channel),1);
            options.ScalingMode = string(options.ScalingMode);
            options.ColorMode = string(options.ColorMode);
            options.Colormap = project.getChannelColormap(options.Channel);
            if config.Display.ChannelColorMode == "colors"
                options.Colormap = linspace(0,1,256).' .* project.getChannelRGB(options.Channel);
            end

            folderName = uigetdir(config.IO.DefaultFolder, 'Export images with region box overlays');
            desmostorm.app.focusMainFigure();

            if ~isfolder(folderName), return; end

            [progress,cleanupProgress] = startExportProgress(opts,'Writing image region box overlays...'); %#ok<NASGU>
            optionsCell = matlabx.struct.toKeyValueCell(options);
            summary = desmostorm.export.imagesWithRegionBoxes(project,folderName, ...
                "ProgressDialog",progress, ...
                "DisplaySettings",config.Display, ...
                optionsCell{:});
            desmostorm.Log.INFO(sprintf( ...
                "Image + region box overlay export complete: %d exported, %d skipped.", ...
                summary.Exported,summary.Skipped));

            result = true;
        end

        function result = exportRegionLinescanPlot(project,config,opts)
            arguments
                project (1,1) desmostorm.model.STORMProject
                config  (1,1) desmostorm.config.Settings
                opts.CurrentChannel (1,1) double {mustBeInteger,mustBePositive} = 1
                opts.ProgressDialog = []
                opts.ProgressFactory = []
            end

            % export success indicator, false unless end of function is reached
            result = false;

            % get active region
            region = project.ActiveRegion;

            % ensure project has active region
            if isempty(region)
                error('desmostorm:export:Exporter:NoActiveRegion','No active region')
            end

            names = region.Parent.channelNames();
            channelChoices = ["current","all","C" + (1:numel(names)) + " — " + names];
            options = desmostorm.export.ExportDialog.prompt("Export Linescan Plot", {
                "Export Options", {
                    choiceField("Channels","Channels",channelChoices,"all")
                    choiceField("Format","Format",["SVG","PDF","EPS"],"SVG")
                    choiceField("Units","Units",["inches","centimeters","pixels","points"],"inches")
                    numberField("Width","Width",6.5)
                    numberField("Height","Height",3)
                    toggleField("PreserveAspectRatio","Preserve aspect ratio",false)
                    sizingField("StyleSizing","Style sizing")
                }
                "Plot Options", plotFields(config.PeaksPlot)
            });

            if isempty(options), return; end % return on cancel

            % get extra options (without dialog)
            if config.Analysis.Normalize
                options.YLabel = "Normalized intensity";
            else
                options.YLabel = "Intensity";
            end
            options.XLabel = sprintf("Distance (%s)",region.PixelSize.Unit);
            selected = find(channelChoices == string(options.Channels),1);
            if selected > 2
                options.Channels = selected - 2;
            end
            options.CurrentChannel = opts.CurrentChannel;
            options = inheritPlotStyle(options,config.PeaksPlot);
            options.WidthAnnotationsMode = "normal";

            % --- get filename ---
            name = region.getBaseExportName() + "_linescan-plot";
            extension = "." + lower(options.Format);
            options = rmfield(options,"Format");
            defaultName = fullfile(config.IO.DefaultFolder,name + extension);
            [file,path] = uiputfile(char("*"+extension),'Export linescan plot',defaultName);
            desmostorm.app.focusMainFigure();
            if isequal(file,0), return; end
            [~,stem] = fileparts(file);
            filename = fullfile(path,string(stem) + extension);

            % --- export ---
            [progress,cleanupProgress] = startExportProgress(opts,'Writing linescan plot...'); %#ok<NASGU>
            optionsCell = matlabx.struct.toKeyValueCell(options);
            desmostorm.export.regionLinescanPlot(region,filename, ...
                "ProgressDialog",progress, ...
                optionsCell{:});

            result = true;

        end

        function result = exportRegionSubimageWithROI(project,config,opts)
            arguments
                project (1,1) desmostorm.model.STORMProject
                config  (1,1) desmostorm.config.Settings
                opts.CurrentChannel (1,1) double {mustBeInteger,mustBePositive} = 1
                opts.ProgressDialog = []
                opts.ProgressFactory = []
            end

            % export success indicator, false unless end of function is reached
            result = false;

            % --- get export/plot options ---
            % get options using ParamsDialog
            if isempty(project.Channels), return, end
            channelChoices = projectChannelChoices(project);
            options = desmostorm.export.ExportDialog.prompt("Export Region Images with ROI", {
                "Export Options", [
                    {
                        choiceField("Scope","Regions",["active","all"],"active")
                        channelField(project,opts.CurrentChannel,channelChoices)
                    }
                    imageFileFields(3)
                    {toggleField("TiledSummary","Tiled summary",false)}
                ]
                "Image Options", {scalingField()}
                "Linescan ROI", {numberField("FontSize","Font size (points)",config.ROI.FontSize)}
            });

            if isempty(options), return; end % return on cancel

            % get extra options (without dialog)
            options.Channel = find(channelChoices == string(options.Channel),1);
            options.Scope = string(options.Scope);
            options.ScalingMode = string(options.ScalingMode);
            options.Colormap = project.getChannelColormap(options.Channel);
            if config.Display.ChannelColorMode == "colors"
                options.Colormap = linspace(0,1,256).' .* project.getChannelRGB(options.Channel);
            end
            options = inheritROIVisibility(options,config.ROI);
            options.ROIColor = config.ROI.ROIColor;
            options.ROILineWidth = config.ROI.ROILineWidth;
            options.ROIMarkerSize = config.ROI.ROIMarkerSize;
            options.AnnotationLineColor = config.ROI.AnnotationLineColor;
            options.AnnotationLineWidth = config.ROI.AnnotationLineWidth;
            options.RotationAngleMode = config.ROI.RotationAngleMode;
            options.FontColor = config.ROI.FontColor;

            if options.Scope == "active"
                region = project.ActiveRegion;
                if isempty(region)
                    error('desmostorm:export:Exporter:NoActiveRegion','No active region')
                end
                exportSource = region;
                folderTitle = 'Export active region image with ROI overlay';
            else
                exportSource = project;
                folderTitle = 'Export region images with ROI overlays';
            end

            folderName = uigetdir(config.IO.DefaultFolder, folderTitle);
            desmostorm.app.focusMainFigure();

            if ~isfolder(folderName), return; end

            [progress,cleanupProgress] = startExportProgress(opts,'Writing region images...'); %#ok<NASGU>
            optionsCell = matlabx.struct.toKeyValueCell(rmfield(options,"Scope"));
            summary = desmostorm.export.regionSubimagesWithROI(exportSource,folderName, ...
                "ProgressDialog",progress, ...
                "DisplaySettings",config.Display, ...
                optionsCell{:});
            desmostorm.Log.INFO(sprintf( ...
                "Region image + ROI overlay export complete: %d exported, %d skipped.", ...
                summary.Exported,summary.Skipped));

            result = true;
        end
    end
end

function [progress,cleanup] = startExportProgress(opts,message)
    if isempty(opts.ProgressFactory)
        progress = opts.ProgressDialog;
        cleanup = [];
        desmostorm.runtime.updateProgress(progress,message);
    else
        [progress,cleanup] = opts.ProgressFactory(message);
    end
end

function choices = projectChannelChoices(project)
    names = string({project.Channels.Name});
    choices = "C" + (1:numel(names)) + " — " + names;
end

function fields = plotFields(plot)
    fields = {
        numberField("AnnotationFontSize","Annotation font size (points)",plot.AnnotationFontSize)
        toggleField("DistanceAnnotations","Show distance labels",logical(plot.DistanceAnnotations))
        toggleField("WidthAnnotations","Show width labels",logical(plot.WidthAnnotations))
        toggleField("TitleVisible","Show title",logical(plot.TitleVisible))
        numberField("FontSize","Axes font size (points)",plot.FontSize)
        numberField("TitleFontSizeMultiplier","Title font size multiplier",1)
        numberField("LabelFontSizeMultiplier","Label font size multiplier",1)
    };
end

function options = inheritPlotStyle(options,plot)
    options.ColorSource = plot.ColorSource;
    options.Color = plot.Color;
    options.AnnotationColorMode = plot.AnnotationColorMode;
    options.AnnotationColor = plot.AnnotationColor;
    options.BackgroundColor = plot.BackgroundColor;
    options.ForegroundColor = plot.ForegroundColor;
    options.DistanceAnnotationsMode = plot.DistanceAnnotationsMode;
    options.RawLineWidth = plot.RawLineWidth;
    options.SmoothLineWidth = plot.SmoothLineWidth;
    options.AnnotationLineWidth = plot.AnnotationLineWidth;
end

function options = inheritROIVisibility(options,roi)
    options.ROIFaceAlpha = roi.ROIFaceAlpha;
    options.RotationAngleVisible = roi.RotationAngleVisible;
end

function field = channelField(project,currentChannel,choices)
    field = choiceField("Channel","Channel",choices,activeImageChannel(project,currentChannel,choices));
end

function choice = activeImageChannel(project,currentChannel,choices)
    index = 1;
    img = project.ActiveImage;
    if ~isempty(img) && currentChannel <= numel(img.ChannelIDs)
        match = find(string({project.Channels.ID}) == img.ChannelIDs(currentChannel),1);
        if ~isempty(match), index = match; end
    end
    choice = choices(index);
end

function field = scalingField()
    field = choiceField("ScalingMode","Display limits", ...
        ["Auto","Current limits","Data range"],"Auto");
    field.OutputValues = ["auto","user","data"];
end

function fields = imageFileFields(sizeValue)
    fields = [
        {choiceField("Format","Format",["PNG","TIFF","JPEG"],"PNG")}
        dimensionsFields(sizeValue,sizeValue,600)
        {
            toggleField("PreserveAspectRatio","Preserve aspect ratio",true)
            sizingField("OverlaySizing","Overlay sizing")
        }
    ];
end

function fields = dimensionsFields(width,height,dpi)
    fields = {
        choiceField("Units","Units",["inches","centimeters","pixels","points"],"inches")
        numberField("Width","Width",width)
        numberField("Height","Height",height)
        numberField("Resolution","Resolution (DPI)",dpi)
    };
end

function field = sizingField(name,label)
    field = choiceField(name,label,["Preserve physical sizes","Scale with output"], ...
        "Preserve physical sizes");
    field.OutputValues = ["physical","scale"];
end

function field = choiceField(name,label,items,value)
    field = struct("Name",name,"Label",label,"Type","choice", ...
        "Items",items,"Value",value,"OutputValues",items);
end

function field = numberField(name,label,value)
    field = struct("Name",name,"Label",label,"Type","number","Value",value, ...
        "Limits",[0 Inf],"LowerLimitInclusive","off");
end

function field = opacityField(name,label,value)
    field = struct("Name",name,"Label",label,"Type","number","Value",value, ...
        "Limits",[0 1],"LowerLimitInclusive","on");
end

function field = toggleField(name,label,value)
    field = struct("Name",name,"Label",label,"Type","toggle","Value",logical(value));
end

function field = colorField(name,label,value)
    field = struct("Name",name,"Label",label,"Type","color","Value",value);
end


function field = colorModeField(name,label,modes,value,colorName,color)
    field = choiceField(name,label,modes,value);
    field.Companion = colorField(colorName,label,color);
end
