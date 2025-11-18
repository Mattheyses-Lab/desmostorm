classdef Analyzer
    methods (Static)

        function out = run(I, data, rc)
            arguments
                % image to analyze
                I (:,:) double
                % ROI data struct - ROI within which we will perform the linescan
                %   CenterX
                %   CenterY
                %   Width
                %   Height
                %   RotationAngle
                data (1,1) struct
                % Analysis settings snapshot
                rc (1,1) app.config.RunConfig
            end

            % compute the 2D linescan across both axes of the ROI in the image
            % check for valid input -> return if invalid
            if any(isnan([data.CenterX,data.CenterY,data.Width,data.Height,data.RotationAngle]))
                out = [];
                return
            end

            % compute the linescan
            linescanData = model.analysis.profile.measure2D(I,...
                data.CenterX,...
                data.CenterY,...
                data.Width,...
                data.Height,...
                data.RotationAngle,...
                'Interp','linear');


            % % Get intensity profile and distance axes (centered at 0) from left edge to right edge
            % Dist = linescanData.WidthDist; % distance values along ROI width (measured from center)
            % Profile = linescanData.WidthProfile; % raw profile
            % ProfileNorm = rescale(Profile); % rescale to range [0 1] (maybe put this in utils?)

            % Get intensity profile and distance axes (centered at 0) from top edge to bottom edge
            Dist = linescanData.HeightDist; % distance values along ROI width (measured from center)
            Profile = linescanData.HeightProfile; % raw profile
            ProfileNorm = rescale(Profile); % rescale to range [0 1] (maybe put this in utils?)


            % smooth with moving average filter
            ProfileSmooth = model.analysis.profile.smooth(ProfileNorm,rc.PeakSmoothing);

            % find peaks along the 'Width' direction of the ROI
            peaksData = model.analysis.peaks.detect(ProfileSmooth,Dist,rc.MinPeakDistance,rc.MinPeakHeight);

            % get measurements
            out = model.analysis.peaks.measure(...
                Dist,...
                ProfileSmooth,...
                peaksData.PeakValues,...
                peaksData.PeakLocations,...
                peaksData.PeakWidths);

            out.Dist = Dist;
            out.Profile = Profile;
            out.ProfileNorm = ProfileNorm;
            out.ProfileSmooth = ProfileSmooth;

        end

    end
end