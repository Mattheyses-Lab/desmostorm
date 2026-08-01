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
        Project
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

        function T = getChannelPeakStatsTable(obj)
            % --- peak stats table (for all channels) --- 
            % get max number of channels in the project
            proj = obj.Project;
            nChannels = proj.MaxSizeC;
            % cell array to hold tables for each channel
            channelTableCells = cell(1,nChannels);
            for C = 1:nChannels
                channelTableCells{C} = obj.getSingleChannelPeakStatsTable(C);
            end
            % concatenate horizontally to form final channels table 
            T = [channelTableCells{:}];
        end

        function T = getSingleChannelPeakStatsTable(obj,C)
            arguments
                obj (1,1) desmostorm.model.STORMRegion
                C (1,1) double
            end

            peakStatNames = cell(5,1);
            peakStatValues = cell(1,5);

            % variable names per channel
            peakStatNames{1} = sprintf('Peak distance (C%i)',C);
            peakStatNames{2} = sprintf('Peak L FWHM (C%i)',C);
            peakStatNames{3} = sprintf('Peak L location (C%i)',C);
            peakStatNames{4} = sprintf('Peak R FWHM (C%i)',C);
            peakStatNames{5} = sprintf('Peak R location (C%i)',C);

            if C <= length(obj.LinescanResults)
                if obj.LinescanResults(C).hasCentralPeakPair
                    peakStatValues{1} = obj.LinescanResults(C).CentralPeakPairDistance;
                end
                if obj.LinescanResults(C).hasLeftPeak
                    peakStatValues{2} = obj.LinescanResults(C).LeftPeakWidth;
                    peakStatValues{3} = obj.LinescanResults(C).LeftPeakLocation;
                end
                if obj.LinescanResults(C).hasRightPeak
                    peakStatValues{4} = obj.LinescanResults(C).RightPeakWidth;
                    peakStatValues{5} = obj.LinescanResults(C).RightPeakLocation;
                end
            end

            % format peak stats for display in table
            peakStatValues = cellfun(@(v) obj.formatLength(v),peakStatValues,'UniformOutput',false);
            % build the table
            T = cell2table(peakStatValues,"VariableNames",peakStatNames);
        end

        function T = getRegionAndROIInfoTable(obj)
            % --- region summary table without peak stats ---
            % table variable names
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
            % table data formatted as text
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
            T = cell2table(TableData,"VariableNames",VariableNames);
        end

    end

    %% Derived getters

    methods

        function T = get.SummaryTable(obj)
        %SUMMARYTABLE Get summary table for use in app uitable
            % region summary table without peak stats
            regionTable = obj.getRegionAndROIInfoTable;
            % peak stats table (for all channels)
            channelsTable = obj.getChannelPeakStatsTable;
            % final combined table
            T = [regionTable,channelsTable];
            % rotate for display in uitable
            T = matlabx.utils.table.rotate(T,'ColumnNames',{'Values'});
        end

        function ps = get.PixelSize(obj)
            ps = obj.Parent.PixelSize;
        end

        function proj = get.Project(obj)
            if isempty(obj.Parent) || isempty(obj.Parent.Parent)
                proj = desmostorm.model.STORMProject.empty();
            else
                proj = obj.Parent.Parent;
            end
        end

        function debug(obj)
            disp('Debug');
        end

    end


    methods

        function out = TextSummaryTable(obj,C)
            arguments
                obj desmostorm.model.STORMRegion
                C double = []
            end
            % get region/ROI info table
            T1 = obj.getRegionAndROIInfoTable();
            % get channel(s) peak stats table
            if isempty(C) % no channel idx specified
                T2 = obj.getChannelPeakStatsTable(); % get peak stats table for all channels
            else
                T2 = obj.getSingleChannelPeakStatsTable(C); % get peak stats for specified channel
            end
            % concatenate region info and channel stats tables
            T = [T1,T2];
            % rotate table
            T = matlabx.utils.table.rotate(T,'ColumnNames',{'Values'});
            % format table into monospaced line-based string
            names = T.Properties.RowNames;
            vals = T.Values;
            out = matlabx.utils.text.formatKeyValueText(names,vals);
        end

        function str = getBaseExportName(obj)
            str = obj.Parent.shortName() + "_" + obj.Name;
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
