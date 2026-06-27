classdef Exporter
    methods (Static)
        function result = exportRegionLinescanPlot(project,config)
            arguments
                project (1,1) desmostorm.model.STORMProject
                config  (1,1) desmostorm.config.Settings
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
            optionsCell = matlabx.struct.toKeyValueCell(options);
            desmostorm.export.regionLinescanPlot(region,filename,optionsCell{:});

            result = true;

        end

        function result = exportRegionSubimageWithROI(project,config)
            arguments
                project (1,1) desmostorm.model.STORMProject
                config  (1,1) desmostorm.config.Settings
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
            % desmostorm.export.regionSubimageWithROI(region,filename, ...
            %     "Colormap",config.Display.Colormap, ...
            %     "AutoScaleDisplayIntensity",config.Display.AutoScaleDisplayIntensity, ...
            %     "Resolution",600, ...
            %     "ROIFaceAlpha",0);

            optionsCell = matlabx.struct.toKeyValueCell(options);
            desmostorm.export.regionSubimageWithROI(region,filename,optionsCell{:});

            result = true;

        end


    end
end