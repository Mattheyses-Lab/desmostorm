classdef Exporter
    methods (Static)
        function result = exportRegionMeasurements(project,config,opts)
            arguments
                project (1,1) desmostorm.model.STORMProject
                config  (1,1) desmostorm.config.Settings
                opts.ProgressDialog = matlab.ui.dialog.ProgressDialog.empty()
            end

            result = false;

            defaultName = fullfile(config.IO.DefaultFolder, [char(project.Name),'_region-measurements.xlsx']);
            [file, path] = uiputfile('*.xlsx', ...
                'Export region measurements', defaultName);
            desmostorm.app.focusMainFigure();

            if isequal(file,0), return; end

            setProgressMessage(opts.ProgressDialog,'Writing region measurements...');
            desmostorm.export.regionMeasurementsXlsx(project, fullfile(path, file), ...
                "ProgressDialog",opts.ProgressDialog);
            result = true;
        end

        function result = exportSummaryPDF(project,config,opts)
            arguments
                project (1,1) desmostorm.model.STORMProject
                config  (1,1) desmostorm.config.Settings
                opts.ProgressDialog = matlab.ui.dialog.ProgressDialog.empty()
            end

            result = false;

            maxChannel = max(1, project.MaxSizeC);
            channelChoices = [string(1:maxChannel), "all"];
            params = matlabx.app.ParamsDialog.prompt( ...
                'Summary PDF export options', ...
                {'ImageChannel','Image channel','choice',"1",cellstr(channelChoices)}, ...
                {'ScalingMode','Image scaling','choice',"data",{"data","auto","user"}}, ...
                {'ColorSource','Color source','choice',config.PeaksPlot.ColorSource,{"channel","manual"}}, ...
                {'Color','Plot color','color',config.PeaksPlot.Color}, ...
                {'AnnotationColorMode','Annotation color mode','choice',config.PeaksPlot.AnnotationColorMode,{"auto","manual"}}, ...
                {'AnnotationColor','Annotation color','color',config.PeaksPlot.AnnotationColor}, ...
                {'BackgroundColor','Background color','color',config.PeaksPlot.BackgroundColor}, ...
                {'ForegroundColor','Foreground color','color',config.PeaksPlot.ForegroundColor}, ...
                {'RawLineWidth','Raw line width','double',config.PeaksPlot.RawLineWidth,@(x) x>0,'Line width must be positive'}, ...
                {'SmoothLineWidth','Smooth line width','double',config.PeaksPlot.SmoothLineWidth,@(x) x>0,'Line width must be positive'}, ...
                {'DistanceAnnotations','Distance annotations','choice',config.PeaksPlot.DistanceAnnotations,{"on","off"}}, ...
                {'DistanceAnnotationsMode','Distance mode','choice',config.PeaksPlot.DistanceAnnotationsMode,{"lanes","data"}}, ...
                {'WidthAnnotations','Width annotations','choice',config.PeaksPlot.WidthAnnotations,{"on","off"}}, ...
                {'ROIFaceAlpha','ROI opacity','double',config.ROI.ROIFaceAlpha,@(x) x>=0 && x<=1,'ROI opacity must be between 0 and 1'}, ...
                {'RotationAngleVisible','Angle label','choice',config.ROI.RotationAngleVisible,{"on","off"}}, ...
                {'PageWidthInches','Page width (inches)','double',11,@(x) x>0,'PageWidthInches must be a positive number'}, ...
                {'FontSizePoints','Font size (points)','double',8,@(x) x>0,'FontSizePoints must be a positive integer'}...
                );
            desmostorm.app.focusMainFigure();

            if isempty(params), return; end
            params.WidthAnnotationsMode = "normal";
            params.ScalingMode = string(params.ScalingMode);
            params.RotationAngleVisible = matlab.lang.OnOffSwitchState(params.RotationAngleVisible);

            defaultName = fullfile(config.IO.DefaultFolder, [char(project.Name),'_summary.pdf']);
            [file, path] = uiputfile('*.pdf', ...
                'Export peak plots', defaultName);
            desmostorm.app.focusMainFigure();

            if isequal(file,0), return; end

            setProgressMessage(opts.ProgressDialog,'Exporting summary PDF...');

            paramsCell = matlabx.struct.toKeyValueCell(params);

            desmostorm.export.summaryPDF(project, fullfile(path,file), config, ...
                "ProgressDialog", opts.ProgressDialog, paramsCell{:});

            result = true;
        end

        function result = exportRegionImages(project,config,opts)
            arguments
                project (1,1) desmostorm.model.STORMProject
                config  (1,1) desmostorm.config.Settings
                opts.ProgressDialog = matlab.ui.dialog.ProgressDialog.empty()
            end

            result = false;

            maxChannel = max(1,project.MaxSizeC);
            channelChoices = cellstr(string(1:maxChannel));
            options = matlabx.app.ParamsDialog.prompt( ...
                'Region image export options', ...
                {'Channel','Channel','choice','1',channelChoices}, ...
                {'OutputFormat','Output format','choice',"grayscale TIFF",{"grayscale TIFF","RGB PNG"}}, ...
                {'ScalingMode','Scaling mode','choice','data',{'data','auto','user'}}, ...
                {'TiledSummary','Tiled summary','choice',"off",{"on","off"}});
            desmostorm.app.focusMainFigure();

            if isempty(options), return; end

            folderName = uigetdir(config.IO.DefaultFolder, 'Export region images');
            desmostorm.app.focusMainFigure();

            if ~isfolder(folderName), return; end

            setProgressMessage(opts.ProgressDialog,'Writing region images...');
            desmostorm.export.regionImages(project, folderName, ...
                "Channel",str2double(string(options.Channel)), ...
                "ScalingMode",string(options.ScalingMode), ...
                "OutputFormat",string(options.OutputFormat), ...
                "ChannelColorMode",config.Display.ChannelColorMode, ...
                "TiledSummary",matlab.lang.OnOffSwitchState(options.TiledSummary), ...
                "ProgressDialog",opts.ProgressDialog);
            result = true;
        end

        function result = exportImagesWithRegionBoxes(project,config,opts)
            arguments
                project (1,1) desmostorm.model.STORMProject
                config  (1,1) desmostorm.config.Settings
                opts.ProgressDialog = matlab.ui.dialog.ProgressDialog.empty()
            end

            result = false;

            maxChannel = max(1,project.MaxSizeC);
            channelChoices = cellstr(string(1:maxChannel));
            options = matlabx.app.ParamsDialog.prompt( ...
                'Image with region box overlay export options', ...
                {'Scope','Images','choice',"active",{"active","all"}}, ...
                {'Channel','Channel','choice',"1",channelChoices}, ...
                {'ScalingMode','Scaling mode','choice',"data",{"data","auto","user"}}, ...
                {'ColorMode','Box colors','choice',"label",{"label","manual"}}, ...
                {'Color','Manual color','color',config.Box.EdgeColor}, ...
                {'RegionNamesVisible','Region names','choice',matlab.lang.OnOffSwitchState(config.Box.ShowTitle),{"on","off"}}, ...
                {'BoxLineWidth','Box line width','double',1,@(x) x>0,'Line width must be positive'}, ...
                {'BoxFaceAlpha','Box opacity','double',0,@(x) x>=0 && x<=1,'Box opacity must be between 0 and 1'}, ...
                {'Units','Units','choice',"inches",{"inches","points","pixels"}}, ...
                {'Size','Long side size','double',7,@(x) x>0,'Size must be positive'}, ...
                {'FontSize','Font size','double',10,@(x) x>0 && x==round(x),'FontSize must be a positive integer'}, ...
                {'Resolution','Resolution (dpi)','double',600,@(x) x >= 150 && x <= 600,'Resolution must be between 150 and 600'});
            desmostorm.app.focusMainFigure();

            if isempty(options), return; end

            options.Scope = string(options.Scope);
            options.Channel = str2double(string(options.Channel));
            options.ScalingMode = string(options.ScalingMode);
            options.ColorMode = string(options.ColorMode);
            options.RegionNamesVisible = matlab.lang.OnOffSwitchState(options.RegionNamesVisible);
            options.Colormap = project.getChannelColormap(options.Channel);

            folderName = uigetdir(config.IO.DefaultFolder, 'Export images with region box overlays');
            desmostorm.app.focusMainFigure();

            if ~isfolder(folderName), return; end

            setProgressMessage(opts.ProgressDialog,'Writing image region box overlays...');
            optionsCell = matlabx.struct.toKeyValueCell(options);
            summary = desmostorm.export.imagesWithRegionBoxes(project,folderName, ...
                "ProgressDialog",opts.ProgressDialog, ...
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
                opts.ProgressDialog = matlab.ui.dialog.ProgressDialog.empty()
            end

            % export success indicator, false unless end of function is reached
            result = false;

            % get active region
            region = project.ActiveRegion;

            % ensure project has active region
            if isempty(region)
                error('desmostorm:export:Exporter:NoActiveRegion','No active region')
            end

            nChannels = max(numel(region.LinescanResults),1);
            channelChoices = ["current","all",string(1:nChannels)];
            defaultChannels = "all";
            if config.PeaksPlot.ShownPlots == "current"
                defaultChannels = "current";
            end

            % --- get export/plot options ---
            % get options using ParamsDialog
            options = matlabx.app.ParamsDialog.prompt( ...
                'Linescan plot export options', ...
                {'TitleVisible','Title','choice',"off",{"on","off"}}, ...
                {'Channels','Channels','choice',defaultChannels,cellstr(channelChoices)}, ...
                {'ColorSource','Color source','choice',config.PeaksPlot.ColorSource,{"channel","manual"}}, ...
                {'Color','Plot color','color',config.PeaksPlot.Color}, ...
                {'AnnotationColorMode','Annotation color mode','choice',config.PeaksPlot.AnnotationColorMode,{"auto","manual"}}, ...
                {'AnnotationColor','Annotation color','color',config.PeaksPlot.AnnotationColor}, ...
                {'BackgroundColor','Background color','color',config.PeaksPlot.BackgroundColor}, ...
                {'ForegroundColor','Foreground color','color',config.PeaksPlot.ForegroundColor}, ...
                {'RawLineWidth','Raw line width','double',config.PeaksPlot.RawLineWidth,@(x) x>0,'Line width must be positive'}, ...
                {'SmoothLineWidth','Smooth line width','double',config.PeaksPlot.SmoothLineWidth,@(x) x>0,'Line width must be positive'}, ...
                {'DistanceAnnotations','Distance annotations','choice',config.PeaksPlot.DistanceAnnotations,{"on","off"}}, ...
                {'DistanceAnnotationsMode','Distance mode','choice',config.PeaksPlot.DistanceAnnotationsMode,{"lanes","data"}}, ...
                {'WidthAnnotations','Width annotations','choice',config.PeaksPlot.WidthAnnotations,{"on","off"}}, ...
                {'Units','Units','choice',"inches",{"inches","points","pixels"}}, ...
                {'Height','Height','double',3,@(x) isempty(x) || x>0,'Height must be positive'}, ...
                {'Width','Width','double',6.5,@(x) isempty(x) || x>0,'Width must be positive'});

            if isempty(options), return; end % return on cancel

            % get extra options (without dialog)
            if config.Analysis.Normalize
                options.YLabel = "Normalized intensity";
            else
                options.YLabel = "Intensity";
            end
            options.XLabel = sprintf("Distance (%s)",region.PixelSize.Unit);
            options.CurrentChannel = opts.CurrentChannel;
            options.WidthAnnotationsMode = "normal";

            % --- get filename ---
            name = region.getBaseExportName() + "_linescan-plot";
            defaultName = fullfile(config.IO.DefaultFolder, name);
            [file, path] = uiputfile({'*.svg';'*.eps';'*.pdf'}, 'Export linescan plot', defaultName);
            desmostorm.app.focusMainFigure();

            if isequal(file,0), return; end % return on cancel
            filename = fullfile(path,file);            

            % --- export ---
            setProgressMessage(opts.ProgressDialog,'Writing linescan plot...');
            optionsCell = matlabx.struct.toKeyValueCell(options);
            desmostorm.export.regionLinescanPlot(region,filename, ...
                "ProgressDialog",opts.ProgressDialog, ...
                optionsCell{:});

            result = true;

        end

        function result = exportRegionSubimageWithROI(project,config,opts)
            arguments
                project (1,1) desmostorm.model.STORMProject
                config  (1,1) desmostorm.config.Settings
                opts.ProgressDialog = matlab.ui.dialog.ProgressDialog.empty()
            end

            % export success indicator, false unless end of function is reached
            result = false;

            % --- get export/plot options ---
            % get options using ParamsDialog
            maxChannel = max(1,project.MaxSizeC);
            channelChoices = cellstr(string(1:maxChannel));
            options = matlabx.app.ParamsDialog.prompt( ...
                'Region image with ROI overlay export options', ...
                {'Scope','Regions','choice',"active",{"active","all"}}, ...
                {'Channel','Channel','choice',"1",channelChoices}, ...
                {'ScalingMode','Scaling mode','choice',"data",{"data","auto","user"}}, ...
                {'ROIFaceAlpha','ROI opacity','double',config.ROI.ROIFaceAlpha,@(x) x>=0 && x<=1,'ROI opacity must be between 0 and 1'}, ...
                {'RotationAngleVisible','Angle label','choice',config.ROI.RotationAngleVisible,{"on","off"}}, ...
                {'TiledSummary','Tiled summary','choice',"off",{"on","off"}}, ...
                {'Units','Units','choice',"inches",{"inches","points","pixels"}}, ...
                {'Size','Size','double',3,@(x) x>0,'Size must be positive'}, ...
                {'FontSize','Font size','double',config.ROI.FontSize,@(x) x>0 && x==round(x),'FontSize must be a positive integer'}, ...
                {'Resolution','Resolution (dpi)','double',600,@(x) x >= 150 && x <= 600,'Resolution must be between 150 and 600'});

            if isempty(options), return; end % return on cancel

            % get extra options (without dialog)
            options.Channel = str2double(string(options.Channel));
            options.Scope = string(options.Scope);
            options.ScalingMode = string(options.ScalingMode);
            options.RotationAngleVisible = matlab.lang.OnOffSwitchState(options.RotationAngleVisible);
            options.TiledSummary = matlab.lang.OnOffSwitchState(options.TiledSummary);
            options.Colormap = project.getChannelColormap(options.Channel);
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

            setProgressMessage(opts.ProgressDialog,'Writing region images...');
            optionsCell = matlabx.struct.toKeyValueCell(rmfield(options,"Scope"));
            summary = desmostorm.export.regionSubimagesWithROI(exportSource,folderName, ...
                "ProgressDialog",opts.ProgressDialog, ...
                optionsCell{:});
            desmostorm.Log.INFO(sprintf( ...
                "Region image + ROI overlay export complete: %d exported, %d skipped.", ...
                summary.Exported,summary.Skipped));

            result = true;
        end
    end
end

function setProgressMessage(h,msg)
    if ~isempty(h) && isvalid(h)
        h.Message = msg;
        drawnow limitrate
    end
end
