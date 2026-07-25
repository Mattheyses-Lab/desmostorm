classdef Exporter
    methods (Static)
        function result = exportRegionMeasurements(project,config,parentFig)
            arguments
                project (1,1) desmostorm.model.STORMProject
                config  (1,1) desmostorm.config.Settings
                parentFig = matlab.ui.Figure.empty()
            end

            result = false;

            defaultName = fullfile(config.IO.DefaultFolder, [char(project.Name),'_region-measurements.xlsx']);
            [file, path] = uiputfile('*.xlsx', ...
                'Export region measurements', defaultName);

            if isequal(file,0), return; end

            cleanupExportWindow = holdFigureAlwaysOnTop(parentFig); %#ok<NASGU>
            desmostorm.export.regionMeasurementsXlsx(project, fullfile(path, file));
            result = true;
        end

        function result = exportSummaryPDF(project,config,parentFig)
            arguments
                project (1,1) desmostorm.model.STORMProject
                config  (1,1) desmostorm.config.Settings
                parentFig = matlab.ui.Figure.empty()
            end

            result = false;

            maxChannel = max(1, project.MaxSizeC);
            channelChoices = [string(1:maxChannel), "all"];
            params = matlabx.app.ParamsDialog.prompt( ...
                'Summary PDF export options', ...
                {'ImageChannel','Image channel','choice',"1",cellstr(channelChoices)}, ...
                {'PageWidthInches','Page width (inches)','double',11,@(x) x>0,'PageWidthInches must be a positive number'}, ...
                {'FontSizePoints','Font size (points)','double',8,@(x) x>0,'FontSizePoints must be a positive integer'}...
                );

            focusFigure(parentFig);

            if isempty(params), return; end

            defaultName = fullfile(config.IO.DefaultFolder, [char(project.Name),'_summary.pdf']);
            [file, path] = uiputfile('*.pdf', ...
                'Export peak plots', defaultName);

            focusFigure(parentFig);

            if isequal(file,0), return; end

            cleanupExportWindow = holdFigureAlwaysOnTop(parentFig); %#ok<NASGU>

            h = matlab.ui.dialog.ProgressDialog.empty();
            if ~isempty(parentFig) && isvalid(parentFig)
                h = uiprogressdlg(parentFig, ...
                    "Message",'Exporting summary PDF. Please wait...', ...
                    'Indeterminate','on');
            end
            cleanupProgress = onCleanup(@() closeProgressDialog(h));

            paramsCell = matlabx.struct.toKeyValueCell(params);
            desmostorm.export.summaryPDF(project, fullfile(path,file), config, ...
                "ProgressDialog", h, paramsCell{:});

            result = true;
        end

        function result = exportRegionImages(project,config,parentFig)
            arguments
                project (1,1) desmostorm.model.STORMProject
                config  (1,1) desmostorm.config.Settings
                parentFig = matlab.ui.Figure.empty()
            end

            result = false;

            folderName = uigetdir(config.IO.DefaultFolder, 'Export region images');

            if ~isfolder(folderName), return; end

            cleanupExportWindow = holdFigureAlwaysOnTop(parentFig); %#ok<NASGU>
            desmostorm.export.regionImages(project, folderName);
            result = true;
        end

        function result = exportRegionLinescanPlot(project,config,parentFig)
            arguments
                project (1,1) desmostorm.model.STORMProject
                config  (1,1) desmostorm.config.Settings
                parentFig = matlab.ui.Figure.empty()
            end

            % export success indicator, false unless end of function is reached
            result = false;

            % get active region
            region = project.ActiveRegion;

            % ensure project has active region
            if isempty(region)
                error('desmostorm:export:Exporter:NoActiveRegion','No active region')
            end

            % --- get export/plot options ---
            % get options using ParamsDialog
            options = matlabx.app.ParamsDialog.prompt( ...
                'Linescan plot export options', ...
                {'TitleVisible','Title','choice',"off",{"on","off"}}, ...
                {'DistanceAnnotations','Distance anotations','choice',"off",{"on","off"}}, ...
                {'WidthAnnotations','Width annotations','choice',"off",{"on","off"}}, ...
                {'RawLineWidth','Raw line width','double',config.PeaksPlot.RawLineWidth,@(x) x>0,'Line width must be positive'}, ...
                {'RawLineColor','Raw line color','color',config.PeaksPlot.RawLineColor}, ...
                {'SmoothLineWidth','Smooth line width','double',config.PeaksPlot.SmoothLineWidth,@(x) x>0,'Line width must be positive'}, ...
                {'SmoothLineColor','Smooth line color','color',config.PeaksPlot.SmoothLineColor}, ...
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

            % --- get filename ---
            name = region.getBaseExportName() + "_linescan-plot";
            defaultName = fullfile(config.IO.DefaultFolder, name);
            [file, path] = uiputfile({'*.svg';'*.eps';'*.pdf'}, 'Export linescan plot', defaultName);

            if isequal(file,0), return; end % return on cancel
            filename = fullfile(path,file);            

            % --- export ---
            cleanupExportWindow = holdFigureAlwaysOnTop(parentFig); %#ok<NASGU>
            optionsCell = matlabx.struct.toKeyValueCell(options);
            desmostorm.export.regionLinescanPlot(region,filename,optionsCell{:});

            result = true;

        end

        function result = exportRegionSubimageWithROI(project,config,parentFig)
            arguments
                project (1,1) desmostorm.model.STORMProject
                config  (1,1) desmostorm.config.Settings
                parentFig = matlab.ui.Figure.empty()
            end

            % export success indicator, false unless end of function is reached
            result = false;

            % get active region
            region = project.ActiveRegion;

            % ensure project has active region
            if isempty(region)
                error('desmostorm:export:Exporter:NoActiveRegion','No active region')
            end

            % --- get export/plot options ---
            % get options using ParamsDialog
            options = matlabx.app.ParamsDialog.prompt( ...
                'Region image with ROI overlay export options', ...
                {'ROIFaceAlpha','ROI opacity','double',0,@(x) x>=0 && x<=1,'ROI opacity must be between 0 and 1'}, ...
                {'Units','Units','choice',"inches",{"inches","points","pixels"}}, ...
                {'Size','Size','double',3,@(x) x>0,'Size must be positive'}, ...
                {'FontSize','Font size','double',12,@(x) x>0 && x==round(x),'FontSize must be a positive integer'}, ...
                {'Resolution','Resolution (dpi)','double',600,@(x) x >= 150 && x <= 600,'Resolution must be between 150 and 600'});

            if isempty(options), return; end % return on cancel

            % get extra options (without dialog)
            options.Colormap = config.Display.Colormap;
            options.AutoScaleDisplayIntensity = config.Display.AutoScaleDisplayIntensity;

            % --- get filename ---
            name = region.getBaseExportName() + "_subimage-ROI-overlay";
            defaultName = fullfile(config.IO.DefaultFolder, name);
            [file, path] = uiputfile({'*.png'}, 'Export subimage with ROI overlay', defaultName);

            if isequal(file,0), return; end % return on cancel
            filename = fullfile(path,file);            

            % --- export ---
            cleanupExportWindow = holdFigureAlwaysOnTop(parentFig); %#ok<NASGU>
            optionsCell = matlabx.struct.toKeyValueCell(options);
            desmostorm.export.regionSubimageWithROI(region,filename,optionsCell{:});

            result = true;
        end
    end
end

function closeProgressDialog(h)
    if ~isempty(h) && isvalid(h)
        close(h);
    end
end

function focusFigure(fig)
    if ~isempty(fig) && isvalid(fig)
        figure(fig);
        drawnow
    end
end

function cleanup = holdFigureAlwaysOnTop(fig)
    cleanup = onCleanup(@() []);
    if isempty(fig) || ~isvalid(fig)
        return
    end

    % Keep the GUI above temporary export figures while exportapp does its
    % initial render pass, then put the app exactly back how it was.
    originalWindowStyle = fig.WindowStyle;
    fig.WindowStyle = 'alwaysontop';
    figure(fig);
    drawnow

    cleanup = onCleanup(@() restoreFigureWindowStyle(fig, originalWindowStyle));
end

function restoreFigureWindowStyle(fig, originalWindowStyle)
    if ~isempty(fig) && isvalid(fig)
        fig.WindowStyle = originalWindowStyle;
        figure(fig);
        drawnow
    end
end
