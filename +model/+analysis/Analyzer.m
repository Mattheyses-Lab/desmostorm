classdef Analyzer
    methods (Static)
        function out = run(I, data, rc)
            arguments
                % image to analyze
                I (:,:) double
                % ROI data struct - ROI within which we will perform the linescan
                %   fields: CenterX, CenterY, Width, Height, RotationAngle
                data (1,1) struct
                % Analysis settings snapshot
                rc (1,1) app.config.RunConfig
            end
            % check for valid ROI input -> return if invalid (i.e. if any NaNs are found)
            if any(isnan([data.CenterX,data.CenterY,data.Width,data.Height,data.RotationAngle])), out = []; return, end
            % compute the linescan
            linescanData = model.analysis.profile.measure2D(I,...
                data.CenterX,...
                data.CenterY,...
                data.Width,...
                data.Height,...
                data.RotationAngle,...
                'Interp','linear');
            % detect the peaks and get annotation coordinates ("out" is an instance of model.PeaksData)
            out = model.analysis.PeaksData(linescanData.HeightProfile,linescanData.HeightDist,...
                "MinPeakDistance",rc.MinPeakDistance, ...
                "MinPeakHeight",rc.MinPeakHeight, ...
                "PeakSmoothing",rc.PeakSmoothing);
        end


        function out = autofitRegionROI(I, rc)
            arguments
                % image to analyze
                I (:,:) double
                % Analysis settings snapshot
                rc (1,1) app.config.RunConfig
            end
            % automatically fit rectangular ROI
            out = model.analysis.image.fitPlaquePairROI(I);
        end


    end
end