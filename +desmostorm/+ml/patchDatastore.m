function ds = patchDatastore(P, boxSize, inputSize)
%PATCHDATASTORE Create a datastore that reads classifier patches on demand.
%
%   DS = PATCHDATASTORE(P, BOXSIZE, INPUTSIZE) returns a transformed datastore
%   yielding {X,Y}, where X is a resized H-by-W-by-3 single patch and Y is the
%   categorical label from the patch table row.
%
% The table P is expected to contain imageFilename, centerX, centerY, and label.
% If patchFilename is present, training reads the materialized patch file first
% and does not need the original source image for that row. Reading lazily keeps
% training memory use bounded by the mini-batch size.
    arguments
        P table
        boxSize (1,1) double {mustBePositive} = 300
        inputSize (1,2) double {mustBePositive} = [224 224]
    end
    
    % Store only row indices in the base datastore; localRead does the file I/O
    % and crop extraction for each requested sample.
    idxds = arrayDatastore((1:height(P))', "IterationDimension", 1);
    ds = transform(idxds, @(data) localRead(data, P, boxSize, inputSize));
end

function out = localRead(data, P, boxSize, inputSize)
%LOCALREAD Read one patch-table row and convert it to network-ready data.
    if iscell(data), idx = data{1}; else, idx = data; end
    row = P(idx,:);
    
    if ismember("patchFilename",string(P.Properties.VariableNames)) && ...
            strlength(string(row.patchFilename)) > 0
        patch = readMaterializedPatch(P,row);
    else
        patch = cropSourcePatch(row,boxSize);
    end
    
    % Resize to network input
    patch = imresize(patch, inputSize, "bilinear");
    
    % ResNet-style backbones expect three channels.
    X = repmat(patch, 1, 1, 3);
    Y = row.label(1);
    if ~iscategorical(Y), Y = categorical(Y); end
    
    out = {X, Y};
end

function patch = readMaterializedPatch(P,row)
%READMATERIALIZEDPATCH Read a pre-cropped patch image from the patch table.
    patchFile = string(row.patchFilename);
    if ~isfile(patchFile) && isstruct(P.Properties.UserData) && ...
            isfield(P.Properties.UserData,"PatchRoot")
        patchFile = fullfile(string(P.Properties.UserData.PatchRoot),patchFile);
    end
    if ~isfile(patchFile)
        error("patchDatastore:MissingPatchFile", ...
            "Materialized patch file is missing: %s",string(row.patchFilename));
    end

    patch = imread(patchFile);
    if ~ismatrix(patch)
        patch = patch(:,:,1);
    end
    patch = normalizePatchImage(patch);
end

function patch = cropSourcePatch(row,boxSize)
%CROPSOURCEPATCH Crop a patch from the original image path.
%
% This is the legacy path used by older classifier packages and by new project
% labels before they are materialized into the saved classifier package.
    I0 = imread(row.imageFilename);
    if ~ismatrix(I0)
        I0 = I0(:,:,1);
    end
    I0 = normalizePatchImage(I0);

    cx = row.centerX; cy = row.centerY; s = boxSize;

    c1 = ceil(cx - s/2); c2 = floor(cx + s/2);
    r1 = ceil(cy - s/2); r2 = floor(cy + s/2);

    % Crop in source-image coordinates before resizing to the network input.
    patch = I0(r1:r2, c1:c2);

    if size(patch,1) ~= s || size(patch,2) ~= s
        error("patchDatastore:BadCrop", "Crop mismatch at center=(%.3f,%.3f).", cx, cy);
    end
end

function I = normalizePatchImage(I)
%NORMALIZEPATCHIMAGE Convert image data to the single precision [0,1] range.
    if isa(I,"uint16")
        I = single(I) / single(intmax("uint16"));
    elseif isa(I,"uint8")
        I = single(I) / single(intmax("uint8"));
    elseif isinteger(I)
        I = single(I) / single(intmax(class(I)));
    else
        I = single(I);
        if ~isempty(I) && (max(I,[],"all","omitnan") > 1 || min(I,[],"all","omitnan") < 0)
            I = rescale(I,0,1);
        end
    end
end
