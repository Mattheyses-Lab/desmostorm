function T = detectorLabelTable(project, opts)
%DETECTORLABELTABLE Build a box-label table for MATLAB object detectors.
%
% This helper is separate from the patch-classifier workflow. It converts
% existing desmostorm regions into the table shape expected by detector
% training APIs: one imageFilename column plus one cell-valued box column named
% by opts.ClassName.

arguments
    project (1,1) desmostorm.model.STORMProject
    opts.ClassName (1,1) string = "plaque_pair"
    opts.BoxSizeOverride (1,1) double = NaN
    opts.ClampToImage (1,1) logical = true
    opts.SkipEmptyImages (1,1) logical = true
    opts.RequireFilesExist (1,1) logical = true
end

imgs = project.ImageArray;
if isempty(imgs)
    T = table();
    return
end

n = numel(imgs);
imageFilename = strings(n,1);
boxesPerImage = cell(n,1);
keep = true(n,1);

for i = 1:n
    img = imgs(i);
    imageFilename(i) = string(img.SourcePath);

    % Detector training reads source images from disk, so fail early if the
    % project points to missing files and strict checking is enabled.
    if opts.RequireFilesExist && ~isfile(imageFilename(i))
        error("desmostorm:ml:detectorLabelTable:MissingFile", ...
            "Image file not found on disk: %s", imageFilename(i));
    end

    regs = img.RegionArray;
    if isempty(regs)
        boxesPerImage{i} = zeros(0,4);
        if opts.SkipEmptyImages
            keep(i) = false;
        end
        continue
    end

    % Convert each region center/box size into MATLAB detector [x y w h] boxes.
    B = zeros(numel(regs), 4);

    for r = 1:numel(regs)
        reg = regs(r);
        ctr = reg.Center;
        if isnan(opts.BoxSizeOverride)
            s = reg.BoxSize;
        else
            s = opts.BoxSizeOverride;
        end

        x = ctr(1) - s/2;
        y = ctr(2) - s/2;
        w = s;
        h = s;

        if opts.ClampToImage
            x = max(1, min(x, img.Width - w + 1));
            y = max(1, min(y, img.Height - h + 1));
        end

        B(r,:) = [x y w h];
    end

    boxesPerImage{i} = B;
end

T = table(imageFilename, 'VariableNames', {'imageFilename'});
T.(opts.ClassName) = boxesPerImage;
T = T(keep, :);

end
