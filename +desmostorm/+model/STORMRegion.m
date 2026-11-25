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

classdef STORMRegion < handle & matlab.mixin.SetGetExactNames
%STORMRegion  Region geometry and measurements

    %% ID/ownership/meta
    properties
        % Stable identifier used to look up this record.
        ID (1,1) string
        % Model object that owns this record.
        Parent desmostorm.model.STORMImage
        % Display name shown in the application.
        Name (1,1) string = ""
        % Time when this record was created.
        CreatedAt datetime = datetime('now')

        % Labeling (for ML training/export)
        LabelID (1,1) string = "unlabeled"
        % Origin of the current label assignment.
        LabelSource (1,1) string = "user"
    end

    %% Classification/auto-detection
    properties
        % Classifier score associated with the region.
        Score (1,1) = NaN
    end

    %% Geometry/measurements
    properties
        % Geometry in image pixel center coords (x right, y down)
        Center (1,2) double = [NaN NaN]
        % Side length of the square region box in pixels.
        BoxSize (1,1) double = NaN
        % Linescan ROI properties
        ROI struct = struct(...
            'CenterX',NaN,...           % rectangle center in pixel center coordinates
            'CenterY',NaN,...
            'Width',NaN,...             % width of the rectangle (px)
            'Height',NaN,...            % height of the rectangle (px)
            'RotationAngle',NaN)        % CCW rotation angle of the rectangle (deg)
        % Origin of the current linescan ROI geometry.
        ROISource (1,1) string = "none"
        % Linescan measurement results
        LinescanResults (:,1) desmostorm.analysis.PeaksData = desmostorm.analysis.PeaksData.empty()
    end

    %% Derived properties
    properties(Dependent)
        % Region and linescan measurements for display and export.
        SummaryTable (:,:) table
        % Physical calibration for the image pixels.
        PixelSize (1,1) desmostorm.model.units.PixelSize
        % Project currently open in the application.
        Project
    end

    %% Lifecycle
    methods
        % Constructor
        function obj = STORMRegion(Parent, ID, Center, BoxSize, LabelID, LabelSource, Score)
        %STORMREGION Initialize a labeled region in its parent image.
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

        function updateROI(obj,data,opts)
        %UPDATEROI Update ROI.
            arguments
                obj (1,1) desmostorm.model.STORMRegion
                data (1,1) struct
                opts.Source (1,1) string = "user"
            end
            % Update the region linescan properties with the values in data
            obj.ROI = data;
            obj.ROISource = opts.Source;
        end

        function updateLinescanResults(obj,data)
        %UPDATELINESCANRESULTS Update linescan results.
            % Visit each entry in data.
            for i = 1:numel(data)
                % add pixel scale and unit info to linescan results
                data(i).DistanceScale = obj.PixelSize.Value;
                data(i).DistanceUnit = obj.PixelSize.Unit;
            end
            % Update the region linescan results with the values in data
            obj.LinescanResults = data;
        end

        function refreshLinescanPixelSize(obj)
        %REFRESHLINESCANPIXELSIZE Update physical units without re-running peak detection.
            data = obj.LinescanResults;
            if isempty(data), return; end

            % Process data in order.
            for i = 1:numel(data)
                data(i).DistanceScale = obj.PixelSize.Value;
                data(i).DistanceUnit = obj.PixelSize.Unit;
            end
            obj.LinescanResults = data;
        end

        function resetROI(obj)
            % reset the linescan ROI params
            obj.ROI = desmostorm.model.STORMRegion.ROITemplate();
            obj.ROISource = "none";
            % also reset linescan results
            obj.resetLinescanResults();
        end

        function resetLinescanResults(obj)
        %RESETLINESCANRESULTS Reset linescan results.
            obj.LinescanResults = desmostorm.analysis.PeaksData.empty();
        end

    end

    %% Private helpers
    methods (Access=private)

        function str = formatLength(obj,val,mode)
        %FORMATLENGTH Format length.
            arguments
                obj (1,1) desmostorm.model.STORMRegion
                val (:,1)
                mode (1,:) char {mustBeMember(mode,{'physical','px'})} = 'physical'
            end

            str = obj.PixelSize.formatLength(val,mode);
        end

        function out = formatAngle(~,val)
        %FORMATANGLE Format angle.
            out = sprintf('%.3g°', val);
        end

        function out = px2phys(obj,in)
        %PX2PHYS Convert pixel distances to the calibrated physical units.
            out = obj.PixelSize.px2phys(in);
        end

        function T = getChannelPeakStatsTable(obj)
            % --- peak stats table (for all channels) --- 
            % get max number of channels in the project
            proj = obj.Project;
            % Number of channels to process.
            nChannels = numel(proj.Channels);
            % cell array to hold tables for each channel
            channelTableCells = cell(1,nChannels);
            % Process each source channel in its original component order.
            for C = 1:nChannels
                channelTableCells{C} = obj.getSingleChannelPeakStatsTable(C);
            end
            % concatenate horizontally to form final channels table 
            T = [channelTableCells{:}];
        end

        function T = getSingleChannelPeakStatsTable(obj,C)
        %GETSINGLECHANNELPEAKSTATSTABLE Return single channel peak stats table.
            arguments
                obj (1,1) desmostorm.model.STORMRegion
                C (1,1) double
            end

            peakStatNames = cell(5,1);
            peakStatValues = cell(1,5);

            % Names refer to project channels; measurements stay in source order.
            name = obj.Project.getChannelName(C);
            peakStatNames{1} = sprintf('Peak distance (%s)',name);
            peakStatNames{2} = sprintf('Peak L FWHM (%s)',name);
            peakStatNames{3} = sprintf('Peak L location (%s)',name);
            peakStatNames{4} = sprintf('Peak R FWHM (%s)',name);
            peakStatNames{5} = sprintf('Peak R location (%s)',name);

            % Source channel index.
            c = obj.Parent.sourceChannelIndex(C);
            if ~isempty(c) && c <= numel(obj.LinescanResults)
                if obj.LinescanResults(c).hasCentralPeakPair
                    peakStatValues{1} = obj.LinescanResults(c).CentralPeakPairDistance;
                end
                if obj.LinescanResults(c).hasLeftPeak
                    peakStatValues{2} = obj.LinescanResults(c).LeftPeakWidth;
                    peakStatValues{3} = obj.LinescanResults(c).LeftPeakLocation;
                end
                if obj.LinescanResults(c).hasRightPeak
                    peakStatValues{4} = obj.LinescanResults(c).RightPeakWidth;
                    peakStatValues{5} = obj.LinescanResults(c).RightPeakLocation;
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
                'ROISource';...
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
                char(obj.ROISource),...
                sprintf('(%.1f, %.1f)',obj.Center(1),obj.Center(2)),...
                sprintf('%i px',obj.BoxSize),...
                sprintf('%i px',obj.BoxSize),...
                sprintf('(%.1f, %.1f)',obj.ROI.CenterX,obj.ROI.CenterY),...
                obj.formatLength(obj.ROI.Width),...
                obj.formatLength(obj.ROI.Height),...
                obj.formatAngle(obj.ROI.RotationAngle)};
            % Table assembled from the current records.
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
        %GET.PIXELSIZE Return the pixel size.
            % Physical calibration used to convert pixel measurements.
            ps = obj.Parent.PixelSize;
        end

        function proj = get.Project(obj)
        %GET.PROJECT Return the project.
            if isempty(obj.Parent) || isempty(obj.Parent.Parent)
                proj = desmostorm.model.STORMProject.empty();
            else
                proj = obj.Parent.Parent;
            end
        end

        function debug(obj)
        %DEBUG Return debug.
            disp('Debug');
        end

    end


    methods

        function out = TextSummaryTable(obj,C)
        %TEXTSUMMARYTABLE Format region measurements as aligned text for display and export.
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
                T2 = obj.getSingleChannelPeakStatsTable(obj.Project.channelIndex(obj.Parent.ChannelIDs(C)));
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
        %GETBASEEXPORTNAME Return base export name.
            str = obj.Parent.shortName() + "_" + obj.Name;
        end

    end

    %% Serialization helpers
    methods(Access=?desmostorm.model.STORMImage)

        function R = toStruct(obj)
        %TOSTRUCT Serialize the current values into a plain MATLAB structure.
            R.ID            = obj.ID;
            R.Name          = obj.Name;
            R.CreatedAt     = obj.CreatedAt;
            R.Center        = obj.Center;
            R.BoxSize       = obj.BoxSize;
            R.ROI           = obj.ROI;
            R.ROISource     = obj.ROISource;
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
                if isempty(reg.Project.LabelBank.getByID(reg.LabelID))
                    reg.LabelID = "unlabeled";
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

                if isfield(R,'ROISource') && ~isempty(R.ROISource)
                    reg.ROISource = string(R.ROISource);
                elseif desmostorm.model.STORMRegion.hasValidROI(reg.ROI)
                    reg.ROISource = "unknown";
                end
        end

        function T = SummaryTableTemplate()
        %SUMMARYTABLETEMPLATE Return the fields and default values for a region summary row.
            VariableNames = {...
                'Name';...
                'Center coordinates (x,y)';...
                'Plaque-to-plaque distance';...
                'Plaque length';...
                'Orientation';...
                };

            % Table assembled from the current records.
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

    methods (Static)

        function tf = hasValidROI(ROI)
        %HASVALIDROI True when a saved linescan ROI has finite geometry.
            required = ["CenterX","CenterY","Width","Height","RotationAngle"];
            tf = isstruct(ROI) && all(isfield(ROI,cellstr(required)));
            if tf
                vals = [ROI.CenterX,ROI.CenterY,ROI.Width,ROI.Height,ROI.RotationAngle];
                tf = all(isfinite(vals));
            end
        end

    end
    
end
