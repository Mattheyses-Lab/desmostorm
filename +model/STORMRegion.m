classdef STORMRegion < handle
% model.STORMRegion - geometry + per-region results

    %% ID/metadata
    properties
        ID (1,1) string
        % ParentImageID (1,1) string
        Parent (1,1) model.STORMImage
        Name (1,1) string = ""
    end

    properties (Dependent=true)
        PixelSize (1,1) model.units.PixelSize
    end

    %% Geometry/measurements
    properties
        % Geometry in image pixel center coords (x right, y down)
        Center (1,2) double = [NaN NaN]
        BoxSize (1,1) double = NaN

        % Linescan input parameters
        Linescan struct = struct(...
            'CenterX',NaN,...           % rectangle center in pixel edge coordinates
            'CenterY',NaN,...
            'Width',NaN,...             % width of the rectangle (px)
            'Height',NaN,...            % height of the rectangle (px)
            'RotationAngle',NaN)        % CCW rotation angle of the rectangle (deg)

        % % Linescan output parameters
        % LinescanResults struct = struct(...
        %     'Dist',NaN,...
        %     'Profile',NaN,...
        %     'ProfileNorm',NaN,...
        %     'ProfileSmooth',NaN,...
        %     'PeakX1',NaN,...
        %     'PeakY1',NaN,...
        %     'PeakX2',NaN,...
        %     'PeakY2',NaN,...
        %     'PeakDistance',NaN,...
        %     'PeakWidth1',NaN,...
        %     'PeakWidth2',NaN,...
        %     'PeakWidthxL1',NaN,...
        %     'PeakWidthxR1',NaN,...
        %     'PeakWidthxL2',NaN,...
        %     'PeakWidthxR2',NaN,...
        %     'BorderLineXY',NaN,...
        %     'Valid',false);
    end

    %% Outputs
    properties(Dependent)
        PlaqueToPlaqueDistance (1,1) double
        PlaqueLength (1,1) double
        Orientation (1,1) double
        SummaryTable (:,:) table

        LinescanPhys struct
        LinescanResultsPhys struct

    end


    %% Outputs (development)
    properties

        LinescanResults (:,1) model.analysis.PeaksData = model.analysis.PeaksData.empty()



    end


    %% Lifecycle
    methods

        % Constructor
        function obj = STORMRegion(Parent, ID, Center, BoxSize)
            arguments
                Parent (1,1) model.STORMImage
                ID (1,1) string
                Center (1,2) double
                BoxSize (1,1) double
            end
            obj.ID = ID;
            obj.BoxSize = BoxSize;
            obj.Parent = Parent;
            obj.Center = Center;
        end

    end

    %% Public helpers (update results)
    methods

        function updateLinescan(obj,data)
            % Update the region linescan properties with the values in data
            obj.Linescan.CenterX = data.CenterX;
            obj.Linescan.CenterY = data.CenterY;
            obj.Linescan.Width = data.Width;
            obj.Linescan.Height = data.Height;
            obj.Linescan.RotationAngle = data.RotationAngle;
        end

        function updateLinescanResults(obj,data)
            % % Update the region linescan results with the values in data
            % obj.LinescanResults.Dist = data.Dist;
            % obj.LinescanResults.Profile = data.Profile;
            % obj.LinescanResults.ProfileNorm = data.ProfileNorm;
            % obj.LinescanResults.ProfileSmooth = data.ProfileSmooth;
            % obj.LinescanResults.PeakX1 = data.PeakX1;
            % obj.LinescanResults.PeakY1 = data.PeakY1;
            % obj.LinescanResults.PeakX2 = data.PeakX2;
            % obj.LinescanResults.PeakY2 = data.PeakY2;
            % obj.LinescanResults.PeakDistance = data.PeakDistance;
            % obj.LinescanResults.PeakWidth1 = data.PeakWidth1;
            % obj.LinescanResults.PeakWidth2 = data.PeakWidth2;
            % obj.LinescanResults.PeakWidthxL1 = data.PeakWidthxL1;
            % obj.LinescanResults.PeakWidthxR1 = data.PeakWidthxR1;
            % obj.LinescanResults.PeakWidthxL2 = data.PeakWidthxL2;
            % obj.LinescanResults.PeakWidthxR2 = data.PeakWidthxR2;
            % obj.LinescanResults.BorderLineXY = data.BorderLineXY;
            % obj.LinescanResults.Valid = data.Valid;

            data.DistanceScale = obj.PixelSize.Value;
            data.DistanceUnit = obj.PixelSize.Unit;
            obj.LinescanResults = data;
        end

        function resetLinescan(obj)
            % reset the linescan ROI params
            obj.Linescan = model.STORMRegion.LinescanTemplate();
            % also reset linescan results
            obj.resetLinescanResults();
        end

        function resetLinescanResults(obj)
            % obj.LinescanResults = model.STORMRegion.LinescanResultsTemplate();


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

        function out = get.LinescanPhys(obj)
            out = obj.Linescan;
            % Convert length measurements according to pixel size
            out.Width = obj.px2phys(out.Width);
            out.Height = obj.px2phys(out.Height);
        end


        function out = get.LinescanResultsPhys(obj)
            % out = obj.LinescanResults;
            % % Convert length measurements according to pixel size
            % out.Dist = obj.px2phys(out.Dist);
            % out.PeakX1 = obj.px2phys(out.PeakX1);
            % out.PeakX2 = obj.px2phys(out.PeakX2);
            % out.PeakDistance = obj.px2phys(out.PeakDistance);
            % out.PeakWidth1 = obj.px2phys(out.PeakWidth1);
            % out.PeakWidth2 = obj.px2phys(out.PeakWidth2);
            % 
            % % below are used for plotting only, don't round
            % out.PeakWidthxL1 = obj.px2phys(out.PeakWidthxL1); 
            % out.PeakWidthxR1 = obj.px2phys(out.PeakWidthxR1);
            % out.PeakWidthxL2 = obj.px2phys(out.PeakWidthxL2);
            % out.PeakWidthxR2 = obj.px2phys(out.PeakWidthxR2);
            % out.BorderLineXY(1,:) = obj.px2phys(out.BorderLineXY(1,:));


            out = obj.LinescanResults.OutputScaled;


        end

        function T = get.SummaryTable(obj)
            % % get summary table for use in app uitable
            % % variable names to act as row names when the table is rotated
            % VariableNames = {...
            %     'Name';...
            %     'Region center (x,y)';...
            %     'Region width';...
            %     'Region height';...
            %     'ROI center';...
            %     'ROI width';...
            %     'ROI height';...
            %     'ROI rotation angle';...
            %     'Peak distance';...
            %     'Peak 1 width (FWHM)';...
            %     'Peak 2 width (FWHM)';...
            %     };
            % % the actual table data (with distance measurements formatted according to PixelSize)
            % T = table(...
            %     {obj.Name},...
            %     {sprintf('(%.1f, %.1f)',obj.Center(1),obj.Center(2))},...
            %     {sprintf('%i px',obj.BoxSize)},...
            %     {sprintf('%i px',obj.BoxSize)},...
            %     {sprintf('(%.1f, %.1f)',obj.Linescan.CenterX,obj.Linescan.CenterY)},...
            %     {obj.formatLength(obj.Linescan.Width)},...
            %     {obj.formatLength(obj.Linescan.Height)},...
            %     {obj.formatAngle(obj.Linescan.RotationAngle)},...
            %     {obj.formatLength(obj.LinescanResults.PeakDistance)},...
            %     {obj.formatLength(obj.LinescanResults.PeakWidth1)},...
            %     {obj.formatLength(obj.LinescanResults.PeakWidth2)},...
            %     'VariableNames',VariableNames);
            % % rotate the table before returning
            % T = utils.rotateTable(T);



            % get summary table for use in app uitable
            % variable names to act as row names when the table is rotated
            VariableNames = {...
                'Name';...
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

            if isempty(obj.LinescanResults) || obj.LinescanResults.nPeaks ~= 2
                PeakDistance = NaN;
                PeakWidth1 = NaN;
                PeakWidth2 = NaN;
            else
                PeakDistance = obj.LinescanResults.PeakDistances;
                PeakWidth1 = obj.LinescanResults.PeakWidths(1);
                PeakWidth2 = obj.LinescanResults.PeakWidths(2);
            end


            % the actual table data (with distance measurements formatted according to PixelSize)
            T = table(...
                {obj.Name},...
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
            T = utils.rotateTable(T);


        end

        function val = get.PlaqueToPlaqueDistance(obj)
            val = obj.LinescanResults.PeakDistance;
        end

        function val = get.PlaqueLength(obj)
            val = obj.Linescan.Width;
        end

        function val = get.Orientation(obj)
            val = obj.Linescan.RotationAngle;
        end

        function ps = get.PixelSize(obj)
            ps = obj.Parent.PixelSize;
        end

    end

    %% Export data
    methods

        function row = exportRow(obj)

            % ps = obj.PixelSize;
            % % linescan ROI properties
            % S = obj.Linescan;
            % % linescan profile/peak measurements
            % L  = obj.LinescanResults;
            % 
            % row = struct();
            % 
            % % ID/meta
            % row.ProjectName   = string(obj.Parent.Parent.Name);  % if Project has Name
            % row.ImageName     = string(obj.Parent.Name);
            % row.RegionID      = string(obj.ID);
            % row.PixelSize     = ps.stringDisplay;
            % 
            % % Region position/geometry
            % row.RegionCenter        = string(sprintf('(%.1f, %.1f)',obj.Center(1),obj.Center(2)));
            % row.RegionWidth_px      = obj.BoxSize;
            % row.RegionHeight_px     = obj.BoxSize;
            % row.RegionWidth_phys    = obj.px2phys(obj.BoxSize);
            % row.RegionHeight_phys   = obj.px2phys(obj.BoxSize);
            % 
            % % Linescan ROI position/geometry
            % row.ROICenter           = string(sprintf('(%.1f, %.1f)',S.CenterX,S.CenterY));
            % row.ROIWidth_px         = S.Width;
            % row.ROIHeight_px        = S.Height;
            % row.ROIWidth_phys       = obj.px2phys(S.Width);
            % row.ROIHeight_phys      = obj.px2phys(S.Height);
            % row.ROIRotationAngle    = round(S.RotationAngle,2);
            % 
            % % Peak distance/width measurements
            % row.PeakDistance_px     = round(L.PeakDistance,2);
            % row.PeakWidth1_px       = round(L.PeakWidth1,2);
            % row.PeakWidth2_px       = round(L.PeakWidth2,2);
            % row.PeakDistance_phys   = obj.px2phys(row.PeakDistance_px);
            % row.PeakWidth1_phys     = obj.px2phys(row.PeakWidth1_px);
            % row.PeakWidth2_phys     = obj.px2phys(row.PeakWidth2_px);



            ps = obj.PixelSize;
            % linescan ROI properties
            S = obj.Linescan;
            % linescan profile/peak measurements
            L  = obj.LinescanResults;

            row = struct();

            % ID/meta
            % row.ProjectName   = string(obj.Parent.Parent.Name);  % if Project has Name
            % row.ImageName     = string(obj.Parent.Name);
            % row.RegionID      = string(obj.ID);
            % row.PixelSize     = ps.stringDisplay;

            row.ProjectName   = string(obj.Parent.Parent.Name);  % if Project has Name
            row.ImageName     = string(obj.Parent.Name);
            row.RegionName    = string(obj.Name);
            row.PixelSize     = ps.stringDisplay;


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

    %% Static methods

    methods (Static)

        % function ID = newID()
        %     ID = string(char(java.util.UUID.randomUUID()));
        % end

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

        function T = LinescanResultsTemplate()
            % Linescan output parameters
            T = struct(...
                'Dist',NaN,...
                'Profile',NaN,...
                'ProfileNorm',NaN,...
                'ProfileSmooth',NaN,...
                'PeakX1',NaN,...
                'PeakY1',NaN,...
                'PeakX2',NaN,...
                'PeakY2',NaN,...
                'PeakDistance',NaN,...
                'PeakWidth1',NaN,...
                'PeakWidth2',NaN,...
                'PeakWidthxL1',NaN,...
                'PeakWidthxR1',NaN,...
                'PeakWidthxL2',NaN,...
                'PeakWidthxR2',NaN,...
                'BorderLineXY',NaN,...
                'Valid',false);
        end

    end

end

