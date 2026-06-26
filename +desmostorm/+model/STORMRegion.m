classdef STORMRegion < handle & matlab.mixin.SetGetExactNames
%STORMRegion  Region geometry and measurements

    %% ID/ownership/meta
    properties
        ID (1,1) string
        Parent desmostorm.model.STORMImage
        Name (1,1) string = ""
        CreatedAt datetime = datetime('now')

        % Labeling (for ML training/export)
        LabelID (1,1) string = "unlabeled"
        LabelSource (1,1) string = "user"
    end

    %% Classification/auto-detection
    properties
        Score (1,1) = NaN
    end

    %% Geometry/measurements
    properties
        % Geometry in image pixel center coords (x right, y down)
        Center (1,2) double = [NaN NaN]
        BoxSize (1,1) double = NaN
        % Linescan ROI properties
        ROI struct = struct(...
            'CenterX',NaN,...           % rectangle center in pixel center coordinates
            'CenterY',NaN,...
            'Width',NaN,...             % width of the rectangle (px)
            'Height',NaN,...            % height of the rectangle (px)
            'RotationAngle',NaN)        % CCW rotation angle of the rectangle (deg)
        % Linescan measurement results
        LinescanResults (:,1) desmostorm.analysis.PeaksData = desmostorm.analysis.PeaksData.empty()
    end

    %% Derived properties
    properties(Dependent)
        SummaryTable (:,:) table
        PixelSize (1,1) desmostorm.model.units.PixelSize
    end

    %% Lifecycle
    methods
        % Constructor
        function obj = STORMRegion(Parent, ID, Center, BoxSize, LabelID, LabelSource, Score)
            arguments
                Parent      desmostorm.model.STORMImage
                ID          (1,1) string
                Center      (1,2) double
                BoxSize     (1,1) double
                LabelID     (1,1) string = "unlabeled"
                LabelSource (1,1) string = "user"
                Score       (1,1) double = NaN
            end
            obj.ID = ID;
            obj.BoxSize = BoxSize;

            if isempty(Parent)
                disp('empty parent')
            end

            obj.Parent = Parent;
            obj.LabelID = LabelID;
            obj.LabelSource = LabelSource;
            obj.Score = Score;

            % clamp the box center to fall within image limits
            obj.Center = matlabx.image.roi.clampBoxToImage(Center,BoxSize,[obj.Parent.Width obj.Parent.Height]);

        end
    end

    %% Public helpers (update results)
    methods

        function updateROI(obj,data)
            % Update the region linescan properties with the values in data
            obj.ROI = data;
        end

        function updateLinescanResults(obj,data)
            for i = 1:numel(data)
                % add pixel scale and unit info to linescan results
                data(i).DistanceScale = obj.PixelSize.Value;
                data(i).DistanceUnit = obj.PixelSize.Unit;
            end
            % Update the region linescan results with the values in data
            obj.LinescanResults = data;
        end

        function resetROI(obj)
            % reset the linescan ROI params
            obj.ROI = desmostorm.model.STORMRegion.ROITemplate();
            % also reset linescan results
            obj.resetLinescanResults();
        end

        function resetLinescanResults(obj)
            obj.LinescanResults = desmostorm.analysis.PeaksData.empty();
        end

    end

    %% Private helpers
    methods (Access=private)

        function str = formatLength(obj,val,mode)
            arguments
                obj (1,1) desmostorm.model.STORMRegion
                val (:,1)
                mode (1,:) char {mustBeMember(mode,{'physical','px'})} = 'physical'
            end

            str = obj.PixelSize.formatLength(val,mode);
        end

        function out = formatAngle(~,val)
            out = sprintf('%.3g°', val);
        end

        function out = px2phys(obj,in)
            out = obj.PixelSize.px2phys(in);
        end

        function out = getParentProject(obj)
            out = obj.Parent.Parent;
        end

    end

    %% Derived getters

    methods

        % function T = get.SummaryTable(obj)
        %     % get summary table for use in app uitable
        %     % variable names to act as row names when the table is rotated
        %     VariableNames = {...
        %         'Name';...
        %         'Label';...
        %         'LabelSource';...
        %         'Score';...
        %         'Region center (x,y)';...
        %         'Region width';...
        %         'Region height';...
        %         'ROI center';...
        %         'ROI width';...
        %         'ROI height';...
        %         'ROI rotation angle';...
        %         'Peak distance';...
        %         'Peak 1 width (FWHM)';...
        %         'Peak 2 width (FWHM)';...
        %         };
        % 
        %     if isempty(obj.LinescanResults) || obj.LinescanResults(1).nPeaks ~= 2
        %         PeakDistance = NaN;
        %         PeakWidth1 = NaN;
        %         PeakWidth2 = NaN;
        %     else
        %         PeakDistance = obj.LinescanResults(1).PeakDistances;
        %         PeakWidth1 = obj.LinescanResults(1).PeakWidths(1);
        %         PeakWidth2 = obj.LinescanResults(1).PeakWidths(2);
        %     end
        %     % the actual table data (with distance measurements formatted according to PixelSize)
        %     T = table(...
        %         {char(obj.Name)},...
        %         {char(obj.LabelID)},...
        %         {char(obj.LabelSource)},...
        %         {sprintf('%.2f',obj.Score)},...
        %         {sprintf('(%.1f, %.1f)',obj.Center(1),obj.Center(2))},...
        %         {sprintf('%i px',obj.BoxSize)},...
        %         {sprintf('%i px',obj.BoxSize)},...
        %         {sprintf('(%.1f, %.1f)',obj.ROI.CenterX,obj.ROI.CenterY)},...
        %         {obj.formatLength(obj.ROI.Width)},...
        %         {obj.formatLength(obj.ROI.Height)},...
        %         {obj.formatAngle(obj.ROI.RotationAngle)},...
        %         {obj.formatLength(PeakDistance)},...
        %         {obj.formatLength(PeakWidth1)},...
        %         {obj.formatLength(PeakWidth2)},...
        %         'VariableNames',VariableNames);
        %     % rotate the table before returning
        %     T = matlabx.utils.table.rotate(T,'ColumnNames',{'Values'});
        % end

        function T = get.SummaryTable(obj)
        %SUMMARYTABLE Get summary table for use in app uitable
            % table variable names, excluding peak stats
            VariableNames = {...
                'Name';...
                'Label';...
                'LabelSource';...
                'Score';...
                'Region center (x,y)';...
                'Region width';...
                'Region height';...
                'ROI center';...
                'ROI width';...
                'ROI height';...
                'ROI rotation angle'};
            % table data formatted as text, excluding peak stats
            TableData = {...
                char(obj.Name),...
                char(obj.LabelID),...
                char(obj.LabelSource),...
                sprintf('%.2f',obj.Score),...
                sprintf('(%.1f, %.1f)',obj.Center(1),obj.Center(2)),...
                sprintf('%i px',obj.BoxSize),...
                sprintf('%i px',obj.BoxSize),...
                sprintf('(%.1f, %.1f)',obj.ROI.CenterX,obj.ROI.CenterY),...
                obj.formatLength(obj.ROI.Width),...
                obj.formatLength(obj.ROI.Height),...
                obj.formatAngle(obj.ROI.RotationAngle)};


            % --- peak stats --- 
            % get max number of channels in the project
            proj = obj.getParentProject();
            nChannels = proj.MaxSizeC;

            peakStatNames = cell(nChannels*5,1);
            peakStatValues = cell(1,nChannels*5);
            for i = 1:nChannels
                % helper idx for each set of 3 stats
                ii = (i-1)*5;
                % dynamic variable names per channel
                peakStatNames{ii+1} = sprintf('Peak distance (C%i)',i);
                peakStatNames{ii+2} = sprintf('Peak L FWHM (C%i)',i);
                peakStatNames{ii+3} = sprintf('Peak L location (C%i)',i);
                peakStatNames{ii+4} = sprintf('Peak R FWHM (C%i)',i);
                peakStatNames{ii+5} = sprintf('Peak R location (C%i)',i);


                if i > length(obj.LinescanResults), continue; end

                if obj.LinescanResults(i).hasCentralPeakPair
                    peakStatValues{ii+1} = obj.LinescanResults(i).CentralPeakPairDistance;
                end

                if obj.LinescanResults(i).hasLeftPeak
                    peakStatValues{ii+2} = obj.LinescanResults(i).LeftPeakWidth;
                    peakStatValues{ii+3} = obj.LinescanResults(i).LeftPeakLocation;
                end

                if obj.LinescanResults(i).hasRightPeak
                    peakStatValues{ii+4} = obj.LinescanResults(i).RightPeakWidth;
                    peakStatValues{ii+5} = obj.LinescanResults(i).RightPeakLocation;
                end

            end

            % format peak stats for display in table
            peakStatValues = cellfun(@(v) obj.formatLength(v),peakStatValues,'UniformOutput',false);

            % concatenate base table names/data with peak stat names/measurements
            VariableNames = [VariableNames; peakStatNames];
            TableData = [TableData, peakStatValues];

            % construct the actual table, rotate before turning
            T = cell2table(TableData,"VariableNames",VariableNames);
            T = matlabx.utils.table.rotate(T,'ColumnNames',{'Values'});
        end

        function ps = get.PixelSize(obj)
            ps = obj.Parent.PixelSize;
        end

    end


    methods

        % format summary table into monospaced line-based string
        function out = TextSummaryTable(obj)
            T = obj.SummaryTable;
            names = T.Properties.RowNames;
            vals = T.Values;
            out = matlabx.utils.text.formatKeyValueText(names,vals);
        end

        function str = getBaseExportName(obj)
            str = obj.Parent.shortName() + "_" + obj.Name;
        end

    end

    %% Export data
    methods

        function row = exportRow(obj)

            ps = obj.PixelSize;
            % linescan ROI properties
            S = obj.ROI;
            % linescan profile/peak measurements
            L  = obj.LinescanResults;

            row = struct();

            % ID/meta
            row.ProjectName   = string(obj.Parent.Parent.Name);  % if Project has Name
            row.ImageName     = string(obj.Parent.Name);
            row.RegionName    = string(obj.Name);
            row.PixelSize     = ps.stringDisplay;

            % Label
            row.LabelID       = string(obj.LabelID);
            row.LabelSource   = string(obj.LabelSource);

            % Score
            row.Score         = sprintf('%.2f',obj.Score);

            % Region position/geometry
            row.RegionCenter        = string(sprintf('(%.1f, %.1f)',obj.Center(1),obj.Center(2)));
            row.RegionWidth_px      = obj.BoxSize;
            row.RegionHeight_px     = obj.BoxSize;
            row.RegionWidth_phys    = obj.px2phys(obj.BoxSize);
            row.RegionHeight_phys   = obj.px2phys(obj.BoxSize);

            % Linescan ROI position/geometry
            row.ROICenter           = string(sprintf('(%.1f, %.1f)',S.CenterX,S.CenterY));
            row.ROIWidth_px         = S.Width;
            row.ROIHeight_px        = S.Height;
            row.ROIWidth_phys       = obj.px2phys(S.Width);
            row.ROIHeight_phys      = obj.px2phys(S.Height);
            row.ROIRotationAngle    = round(S.RotationAngle,2);

            % % Peak distance/width measurements
            % if isempty(L) || L.nPeaks ~= 2
            %     PeakDistance = NaN;
            %     PeakWidth1 = NaN;
            %     PeakWidth2 = NaN;
            % else
            %     PeakDistance = L.PeakDistances;
            %     PeakWidth1 = L.PeakWidths(1);
            %     PeakWidth2 = L.PeakWidths(2);
            % end
            % 
            % row.PeakDistance_px     = round(PeakDistance,2);
            % row.PeakWidth1_px       = round(PeakWidth1,2);
            % row.PeakWidth2_px       = round(PeakWidth2,2);
            % row.PeakDistance_phys   = obj.px2phys(row.PeakDistance_px);
            % row.PeakWidth1_phys     = obj.px2phys(row.PeakWidth1_px);
            % row.PeakWidth2_phys     = obj.px2phys(row.PeakWidth2_px);


            proj = obj.getParentProject();
            nChannels = proj.MaxSizeC;

            nResults = length(L);

            for i = 1:nChannels

                % default values
                leftPeakFWHM_px         = NaN;
                leftPeakLocation_px     = NaN;
                rightPeakFWHM_px        = NaN;
                rightPeakLocation_px    = NaN;
                peakDistance_px         = NaN;

                % replace default values with region results if they exist
                if i <= nResults

                    if L(i).hasLeftPeak
                        leftPeakFWHM_px     = round(L(i).LeftPeakWidth,2);
                        leftPeakLocation_px = round(L(i).LeftPeakLocation,2);
                    end

                    if L(i).hasRightPeak
                        rightPeakFWHM_px     = round(L(i).RightPeakWidth,2);
                        rightPeakLocation_px = round(L(i).RightPeakLocation,2);
                    end

                    if L(i).hasCentralPeakPair
                        peakDistance_px = round(L(i).CentralPeakPairDistance,2);
                    end

                end

                row.(sprintf('PeakDistance_px__C%i_',i))      = peakDistance_px;
                row.(sprintf('LeftPeakFWHM_px__C%i_',i))      = leftPeakFWHM_px;
                row.(sprintf('RightPeakFWHM_px__C%i_',i))     = rightPeakFWHM_px;
                row.(sprintf('LeftPeakLocation_px__C%i_',i))  = leftPeakLocation_px;
                row.(sprintf('RightPeakLocation_px__C%i_',i)) = rightPeakLocation_px;

                row.(sprintf('PeakDistance_C%i_',i))          = obj.px2phys(peakDistance_px);
                row.(sprintf('LeftPeakFWHM_C%i_',i))          = obj.px2phys(leftPeakFWHM_px);
                row.(sprintf('RightPeakFWHM_C%i_',i))         = obj.px2phys(rightPeakFWHM_px);
                row.(sprintf('LeftPeakLocation_C%i_',i))      = obj.px2phys(leftPeakLocation_px);
                row.(sprintf('RightPeakLocation_C%i_',i))     = obj.px2phys(rightPeakLocation_px);

            end

        end
        
    end

    %% Serialization helpers
    methods(Access=?desmostorm.model.STORMImage)

        function R = toStruct(obj)
            R.ID            = obj.ID;
            R.Name          = obj.Name;
            R.CreatedAt     = obj.CreatedAt;
            R.Center        = obj.Center;
            R.BoxSize       = obj.BoxSize;
            R.ROI           = obj.ROI;
            R.LabelID       = obj.LabelID;
            R.LabelSource   = obj.LabelSource;
            R.Score         = obj.Score;
        end

    end



    %% Static methods

    methods (Static)

        function reg = fromStruct(R,img)
                % create a new STORMRegion parented to the STORMImage, img
                reg = desmostorm.model.STORMRegion(img, string(R.ID), R.Center, R.BoxSize);
                reg.Name = string(R.Name);

                if isfield(R,'CreatedAt') && ~isempty(R.CreatedAt)
                    reg.CreatedAt = R.CreatedAt;
                end

                if isfield(R,'LabelID') && ~isempty(R.LabelID)
                    reg.LabelID = string(R.LabelID);
                end

                if isfield(R,'LabelSource') && ~isempty(R.LabelSource)
                    reg.LabelSource = string(R.LabelSource);
                end

                if isfield(R,'Score') && ~isempty(R.Score)
                    reg.Score = R.Score;
                end

                if isfield(R,'Linescan') && ~isempty(R.Linescan)
                    reg.ROI = R.Linescan;
                end

                if isfield(R,'ROI') && ~isempty(R.ROI)
                    reg.ROI = R.ROI;
                end
        end

        function T = SummaryTableTemplate()
            VariableNames = {...
                'Name';...
                'Center coordinates (x,y)';...
                'Plaque-to-plaque distance';...
                'Plaque length';...
                'Orientation';...
                };

            T = table({},{},{},{},{},'VariableNames',VariableNames);
        end

        function T = ROITemplate()
            % ROI input parameters
            T = struct(...
                'CenterX',NaN,...           % rectangle center in pixel center coordinates
                'CenterY',NaN,...
                'Width',NaN,...             % width of the rectangle (px)
                'Height',NaN,...            % height of the rectangle (px)
                'RotationAngle',NaN);       % CCW rotation angle of the rectangle (deg)
        end

    end
    
end

