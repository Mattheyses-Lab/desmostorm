function out = detectBlobs(I,opts)
%DETECTBLOBS Detects SURF (Speeded-Up Robust Features) points in an image

    arguments
        % image to detect blobs in
        I (:,:) double
        % strongest feature threshold for SURF point detection | lower values -> more sensitive
        opts.MetricThreshold (1,1) double {mustBePositive(opts.MetricThreshold)} = 50
        % number of octaves | integer >= 1 | higher values -> larger blobs | recommended values between 1 and 4
        opts.NumOctaves (1,1) double {mustBeGreaterThanOrEqual(opts.NumOctaves,1)} = 3
        % number of scale levels per octave to compute | integer >= 3
        % higher values -> detect more blobs at finer scale increments | recommended values between 3 and 6
        opts.NumScaleLevels (1,1) double {mustBeGreaterThanOrEqual(opts.NumScaleLevels,3)} = 3
    end

    %% detect blobs using SURF features (SURFPoints object)
    points = detectSURFFeatures(I,...
        "MetricThreshold",opts.MetricThreshold,...
        "NumOctaves",opts.NumOctaves,...
        "NumScaleLevels",opts.NumScaleLevels);

    % return point locations (converted to double)
    out = double(points.Location);

end