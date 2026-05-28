% classdef STORMRegion < handle
% %STORMRegion Geometry and per-region results
% 
%     %% ID/ownership/meta
%     properties
%         ID (1,1) string
%         Parent model.STORMImage
%         Name (1,1) string = ""
%         CreatedAt datetime = datetime('now')
% 
%         % Labeling (for ML training/export)
%         LabelID (1,1) string = "unlabeled"
%         LabelSource (1,1) string = "user"
%     end
% 
%     % props derived from parent
%     properties (Dependent=true)
%         PixelSize (1,1) model.units.PixelSize
%     end
% 
%     %% Classification/auto-detection
%     properties
%         Score (1,1) = NaN
%     end
% 
%     %% Geometry/measurements
%     properties
%         % Geometry in image pixel center coords (x right, y down)
%         Center (1,2) double = [NaN NaN]
%         BoxSize (1,1) double = NaN
%         % Linescan ROI properties
%         Linescan struct = struct(...
%             'CenterX',NaN,...           % rectangle center in pixel center coordinates
%             'CenterY',NaN,...
%             'Width',NaN,...             % width of the rectangle (px)
%             'Height',NaN,...            % height of the rectangle (px)
%             'RotationAngle',NaN)        % CCW rotation angle of the rectangle (deg)
%         % Linescan measurement results
%         LinescanResults (:,1) model.analysis.PeaksData = model.analysis.PeaksData.empty()
%     end
% 
%     %% Outputs
%     properties(Dependent)
%         SummaryTable (:,:) table
%     end
% 
%     %% Lifecycle
%     methods
%         % Constructor
%         function obj = STORMRegion(Parent, ID, Center, BoxSize, LabelID, LabelSource, Score)
%             arguments
%                 Parent      model.STORMImage
%                 ID          (1,1) string
%                 Center      (1,2) double
%                 BoxSize     (1,1) double
%                 LabelID     (1,1) string = "unlabeled"
%                 LabelSource (1,1) string = "user"
%                 Score       (1,1) double = NaN
%             end
%             obj.ID = ID;
%             obj.BoxSize = BoxSize;
% 
%             if isempty(Parent)
%                 disp('empty parent')
%             end
% 
%             obj.Parent = Parent;
%             obj.LabelID = LabelID;
%             obj.LabelSource = LabelSource;
%             obj.Score = Score;
% 
%             % clamp the box center to fall within image limits
%             obj.Center = matlabx.image.roi.clampBoxToImage(Center,BoxSize,[obj.Parent.Width obj.Parent.Height]);
% 
%         end
%     end
% 
%     %% Public helpers (update results)
%     methods
% 
%         function updateLinescan(obj,data)
%             % Update the region linescan properties with the values in data
%             obj.Linescan = data;
%         end
% 
%         function updateLinescanResults(obj,data)
%             % add pixel scale and unit info to linescan results
%             data.DistanceScale = obj.PixelSize.Value;
%             data.DistanceUnit = obj.PixelSize.Unit;
%             % Update the region linescan results with the values in data
%             obj.LinescanResults = data;
%         end
% 
%         function resetLinescan(obj)
%             % reset the linescan ROI params
%             obj.Linescan = model.STORMRegion.LinescanTemplate();
%             % also reset linescan results
%             obj.resetLinescanResults();
%         end
% 
%         function resetLinescanResults(obj)
%             obj.LinescanResults = model.analysis.PeaksData.empty();
%         end
% 
%     end
% 
%     %% Private helpers
%     methods (Access=private)
% 
%         function str = formatLength(obj,val,mode)
%             arguments
%                 obj (1,1) model.STORMRegion
%                 val (1,1)
%                 mode (1,:) char {mustBeMember(mode,{'physical','px'})} = 'physical'
%             end
% 
%             str = obj.PixelSize.formatLength(val,mode);
%         end
% 
%         function out = formatAngle(~,val)
%             out = sprintf('%.3g°', val);
%         end
% 
%         function out = px2phys(obj,in)
%             out = obj.PixelSize.px2phys(in);
%         end
% 
%     end
% 
%     %% Derived getters
% 
%     methods
% 
%         function T = get.SummaryTable(obj)
%             % get summary table for use in app uitable
%             % variable names to act as row names when the table is rotated
%             VariableNames = {...
%                 'Name';...
%                 'Label';...
%                 'LabelSource';...
%                 'Score';...
%                 'Region center (x,y)';...
%                 'Region width';...
%                 'Region height';...
%                 'ROI center';...
%                 'ROI width';...
%                 'ROI height';...
%                 'ROI rotation angle';...
%                 'Peak distance';...
%                 'Peak 1 width (FWHM)';...
%                 'Peak 2 width (FWHM)';...
%                 };
% 
%             if isempty(obj.LinescanResults) || obj.LinescanResults.nPeaks ~= 2
%                 PeakDistance = NaN;
%                 PeakWidth1 = NaN;
%                 PeakWidth2 = NaN;
%             else
%                 PeakDistance = obj.LinescanResults.PeakDistances;
%                 PeakWidth1 = obj.LinescanResults.PeakWidths(1);
%                 PeakWidth2 = obj.LinescanResults.PeakWidths(2);
%             end
%             % the actual table data (with distance measurements formatted according to PixelSize)
%             T = table(...
%                 {char(obj.Name)},...
%                 {char(obj.LabelID)},...
%                 {char(obj.LabelSource)},...
%                 {sprintf('%.2f',obj.Score)},...
%                 {sprintf('(%.1f, %.1f)',obj.Center(1),obj.Center(2))},...
%                 {sprintf('%i px',obj.BoxSize)},...
%                 {sprintf('%i px',obj.BoxSize)},...
%                 {sprintf('(%.1f, %.1f)',obj.Linescan.CenterX,obj.Linescan.CenterY)},...
%                 {obj.formatLength(obj.Linescan.Width)},...
%                 {obj.formatLength(obj.Linescan.Height)},...
%                 {obj.formatAngle(obj.Linescan.RotationAngle)},...
%                 {obj.formatLength(PeakDistance)},...
%                 {obj.formatLength(PeakWidth1)},...
%                 {obj.formatLength(PeakWidth2)},...
%                 'VariableNames',VariableNames);
%             % rotate the table before returning
%             T = matlabx.utils.table.rotate(T,'ColumnNames',{'Values'});
%         end
% 
%         function ps = get.PixelSize(obj)
%             ps = obj.Parent.PixelSize;
%         end
% 
%     end
% 
%     methods
% 
%         % format summary table into monospaced line-based string
%         function out = TextSummaryTable(obj)
%             T = obj.SummaryTable;
%             names = T.Properties.RowNames;
%             vals = T.Values;
%             out = matlabx.utils.text.formatKeyValueText(names,vals);
%         end
% 
%     end
% 
%     %% Export data
%     methods
% 
%         function row = exportRow(obj)
% 
%             ps = obj.PixelSize;
%             % linescan ROI properties
%             S = obj.Linescan;
%             % linescan profile/peak measurements
%             L  = obj.LinescanResults;
% 
%             row = struct();
% 
%             % ID/meta
%             row.ProjectName   = string(obj.Parent.Parent.Name);  % if Project has Name
%             row.ImageName     = string(obj.Parent.Name);
%             row.RegionName    = string(obj.Name);
%             row.PixelSize     = ps.stringDisplay;
% 
%             % Label
%             row.LabelID       = string(obj.LabelID);
%             row.LabelSource   = string(obj.LabelSource);
% 
%             % Score
%             row.Score         = sprintf('%.2f',obj.Score);
% 
%             % Region position/geometry
%             row.RegionCenter        = string(sprintf('(%.1f, %.1f)',obj.Center(1),obj.Center(2)));
%             row.RegionWidth_px      = obj.BoxSize;
%             row.RegionHeight_px     = obj.BoxSize;
%             row.RegionWidth_phys    = obj.px2phys(obj.BoxSize);
%             row.RegionHeight_phys   = obj.px2phys(obj.BoxSize);
% 
%             % Linescan ROI position/geometry
%             row.ROICenter           = string(sprintf('(%.1f, %.1f)',S.CenterX,S.CenterY));
%             row.ROIWidth_px         = S.Width;
%             row.ROIHeight_px        = S.Height;
%             row.ROIWidth_phys       = obj.px2phys(S.Width);
%             row.ROIHeight_phys      = obj.px2phys(S.Height);
%             row.ROIRotationAngle    = round(S.RotationAngle,2);
% 
%             % Peak distance/width measurements
%             if isempty(L) || L.nPeaks ~= 2
%                 PeakDistance = NaN;
%                 PeakWidth1 = NaN;
%                 PeakWidth2 = NaN;
%             else
%                 PeakDistance = L.PeakDistances;
%                 PeakWidth1 = L.PeakWidths(1);
%                 PeakWidth2 = L.PeakWidths(2);
%             end
% 
%             row.PeakDistance_px     = round(PeakDistance,2);
%             row.PeakWidth1_px       = round(PeakWidth1,2);
%             row.PeakWidth2_px       = round(PeakWidth2,2);
%             row.PeakDistance_phys   = obj.px2phys(row.PeakDistance_px);
%             row.PeakWidth1_phys     = obj.px2phys(row.PeakWidth1_px);
%             row.PeakWidth2_phys     = obj.px2phys(row.PeakWidth2_px);
% 
%         end
% 
%     end
% 
%     %% Static methods
% 
%     methods (Static)
% 
%         function T = SummaryTableTemplate()
%             VariableNames = {...
%                 'Name';...
%                 'Center coordinates (x,y)';...
%                 'Plaque-to-plaque distance';...
%                 'Plaque length';...
%                 'Orientation';...
%                 };
% 
%             T = table({},{},{},{},{},'VariableNames',VariableNames);
%         end
% 
%         function T = LinescanTemplate()
%             % Linescan input parameters
%             T = struct(...
%                 'CenterX',NaN,...           % rectangle center in pixel edge coordinates
%                 'CenterY',NaN,...
%                 'Width',NaN,...             % width of the rectangle (px)
%                 'Height',NaN,...            % height of the rectangle (px)
%                 'RotationAngle',NaN);       % CCW rotation angle of the rectangle (deg)
%         end
% 
%     end
% 
% end

classdef STORMRegion < handle & matlab.mixin.SetGetExactNames
%STORMRegion Geometry and per-region results

    %% ID/ownership/meta
    properties
        ID (1,1) string
        Parent model.STORMImage
        Name (1,1) string = ""
        CreatedAt datetime = datetime('now')

        % Labeling (for ML training/export)
        LabelID (1,1) string = "unlabeled"
        LabelSource (1,1) string = "user"
    end

    % props derived from parent
    properties (Dependent=true)
        PixelSize (1,1) model.units.PixelSize
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
        Linescan struct = struct(...
            'CenterX',NaN,...           % rectangle center in pixel center coordinates
            'CenterY',NaN,...
            'Width',NaN,...             % width of the rectangle (px)
            'Height',NaN,...            % height of the rectangle (px)
            'RotationAngle',NaN)        % CCW rotation angle of the rectangle (deg)
        % Linescan measurement results
        LinescanResults (:,1) model.analysis.PeaksData = model.analysis.PeaksData.empty()
    end

    %% Outputs
    properties(Dependent)
        SummaryTable (:,:) table
    end

    %% Lifecycle
    methods
        % Constructor
        function obj = STORMRegion(Parent, ID, Center, BoxSize, LabelID, LabelSource, Score)
            arguments
                Parent      model.STORMImage
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

        function updateLinescan(obj,data)
            % Update the region linescan properties with the values in data
            obj.Linescan = data;
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


        function resetLinescan(obj)
            % reset the linescan ROI params
            obj.Linescan = model.STORMRegion.LinescanTemplate();
            % also reset linescan results
            obj.resetLinescanResults();
        end

        function resetLinescanResults(obj)
            obj.LinescanResults = model.analysis.PeaksData.empty();
        end

    end

    %% Private helpers
    methods (Access=private)

        function str = formatLength(obj,val,mode)
            arguments
                obj (1,1) model.STORMRegion
                val (1,1)
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

    end

    %% Derived getters

    methods

        function T = get.SummaryTable(obj)
            % get summary table for use in app uitable
            % variable names to act as row names when the table is rotated
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
                'ROI rotation angle';...
                'Peak distance';...
                'Peak 1 width (FWHM)';...
                'Peak 2 width (FWHM)';...
                };

            if isempty(obj.LinescanResults) || obj.LinescanResults(1).nPeaks ~= 2
                PeakDistance = NaN;
                PeakWidth1 = NaN;
                PeakWidth2 = NaN;
            else
                PeakDistance = obj.LinescanResults(1).PeakDistances;
                PeakWidth1 = obj.LinescanResults(1).PeakWidths(1);
                PeakWidth2 = obj.LinescanResults(1).PeakWidths(2);
            end
            % the actual table data (with distance measurements formatted according to PixelSize)
            T = table(...
                {char(obj.Name)},...
                {char(obj.LabelID)},...
                {char(obj.LabelSource)},...
                {sprintf('%.2f',obj.Score)},...
                {sprintf('(%.1f, %.1f)',obj.Center(1),obj.Center(2))},...
                {sprintf('%i px',obj.BoxSize)},...
                {sprintf('%i px',obj.BoxSize)},...
                {sprintf('(%.1f, %.1f)',obj.Linescan.CenterX,obj.Linescan.CenterY)},...
                {obj.formatLength(obj.Linescan.Width)},...
                {obj.formatLength(obj.Linescan.Height)},...
                {obj.formatAngle(obj.Linescan.RotationAngle)},...
                {obj.formatLength(PeakDistance)},...
                {obj.formatLength(PeakWidth1)},...
                {obj.formatLength(PeakWidth2)},...
                'VariableNames',VariableNames);
            % rotate the table before returning
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

    end

    %% Export data
    methods

        function row = exportRow(obj)

            ps = obj.PixelSize;
            % linescan ROI properties
            S = obj.Linescan;
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

            % Peak distance/width measurements
            if isempty(L) || L.nPeaks ~= 2
                PeakDistance = NaN;
                PeakWidth1 = NaN;
                PeakWidth2 = NaN;
            else
                PeakDistance = L.PeakDistances;
                PeakWidth1 = L.PeakWidths(1);
                PeakWidth2 = L.PeakWidths(2);
            end

            row.PeakDistance_px     = round(PeakDistance,2);
            row.PeakWidth1_px       = round(PeakWidth1,2);
            row.PeakWidth2_px       = round(PeakWidth2,2);
            row.PeakDistance_phys   = obj.px2phys(row.PeakDistance_px);
            row.PeakWidth1_phys     = obj.px2phys(row.PeakWidth1_px);
            row.PeakWidth2_phys     = obj.px2phys(row.PeakWidth2_px);

        end
        
    end

    %% Serialization helpers
    methods(Access=?model.STORMImage)

        function R = toStruct(obj)
            R.ID             = obj.ID;
            R.Name           = obj.Name;
            R.CreatedAt      = obj.CreatedAt;
            R.Center         = obj.Center;
            R.BoxSize        = obj.BoxSize;
            R.Linescan       = obj.Linescan;
            R.LabelID        = obj.LabelID;
            R.LabelSource    = obj.LabelSource;
            R.Score          = obj.Score;
        end

    end



    %% Static methods

    methods (Static)

        function reg = fromStruct(R,img)
                % create a new STORMRegion parented to the STORMImage, img
                reg = model.STORMRegion(img, string(R.ID), R.Center, R.BoxSize);
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
                    reg.Linescan = R.Linescan;
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

        function T = LinescanTemplate()
            % Linescan input parameters
            T = struct(...
                'CenterX',NaN,...           % rectangle center in pixel edge coordinates
                'CenterY',NaN,...
                'Width',NaN,...             % width of the rectangle (px)
                'Height',NaN,...            % height of the rectangle (px)
                'RotationAngle',NaN);       % CCW rotation angle of the rectangle (deg)
        end

    end
    
end

