function ds = patchDatastore(P, boxSize, inputSize)
%PATCHDATASTORE Create a datastore that reads classifier patches on demand.
%
%   DS = PATCHDATASTORE(P, BOXSIZE, INPUTSIZE) returns a transformed datastore
%   yielding {X,Y}, where X is a resized H-by-W-by-3 single patch and Y is the
%   categorical label from the patch table row.
%
% The table P is expected to contain imageFilename, centerX, centerY, and label.
% Reading lazily keeps training memory use bounded by the mini-batch size.
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
    
    % Current training uses channel 1 / grayscale images replicated to RGB for
    % compatibility with pretrained image-classification backbones.
    I0 = imread(row.imageFilename);
    I0 = single(I0) / 65535;
    
    cx = row.centerX; cy = row.centerY; s = boxSize;
    
    c1 = ceil(cx - s/2); c2 = floor(cx + s/2);
    r1 = ceil(cy - s/2); r2 = floor(cy + s/2);
    
    % Crop in source-image coordinates before resizing to the network input.
    patch = I0(r1:r2, c1:c2);
    
    if size(patch,1) ~= s || size(patch,2) ~= s
        error("patchDatastore:BadCrop", "Crop mismatch at center=(%.3f,%.3f).", cx, cy);
    end
    
    % Resize to network input
    patch = imresize(patch, inputSize, "bilinear");
    
    % ResNet-style backbones expect three channels.
    X = repmat(patch, 1, 1, 3);
    Y = row.label(1);
    if ~iscategorical(Y), Y = categorical(Y); end
    
    out = {X, Y};
end
