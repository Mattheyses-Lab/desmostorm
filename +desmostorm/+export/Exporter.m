classdef Exporter
    methods (Static)
        function exportRegionLinescanPlot(project,config)
            arguments
                project (1,1) desmostorm.model.STORMProject
                config  (1,1) desmostorm.config.Settings
            end

            region = project.ActiveRegion;

            % ensure project has active region
            if isempty(region)
                error('desmostorm:export:Exporter:NoActiveRegion','No active region to export')
            end

            % --- get export/plot options ---
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

            % --- get filename ---
            baseName = region.getBaseExportName();
            defaultName = fullfile(config.IO.DefaultFolder, baseName);
            [file, path] = uiputfile({'*.svg';'*.eps';'*.pdf'}, 'Export linescan plot', defaultName);

            if isequal(file,0), return; end % return on cancel
            filename = fullfile(path,file);            

            % --- export ---
            optionsCell = matlabx.struct.toKeyValueCell(options);
            desmostorm.export.regionLinescanPlot(region,filename,optionsCell{:});

        end

    end
end