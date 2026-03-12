function ds = patchDatastore(P, boxSize, inputSize)
%patchDatastore Datastore yielding {X,Y} where X matches network input size.
%  boxSize   : crop size in the original image (e.g. 300)
%  inputSize : network input size [H W] (e.g. [224 224])
    arguments
        P table
        boxSize (1,1) double {mustBePositive} = 300
        inputSize (1,2) double {mustBePositive} = [224 224]
    end
    
    idxds = arrayDatastore((1:height(P))', "IterationDimension", 1);
    ds = transform(idxds, @(data) localRead(data, P, boxSize, inputSize));
end

function out = localRead(data, P, boxSize, inputSize)
    if iscell(data), idx = data{1}; else, idx = data; end
    row = P(idx,:);
    
    I0 = imread(row.imageFilename);
    I0 = single(I0) / 65535;
    
    cx = row.centerX; cy = row.centerY; s = boxSize;
    
    c1 = ceil(cx - s/2); c2 = floor(cx + s/2);
    r1 = ceil(cy - s/2); r2 = floor(cy + s/2);
    
    patch = I0(r1:r2, c1:c2);
    
    if size(patch,1) ~= s || size(patch,2) ~= s
        error("patchDatastore:BadCrop", "Crop mismatch at center=(%.3f,%.3f).", cx, cy);
    end
    
    % Resize to network input
    patch = imresize(patch, inputSize, "bilinear");
    
    X = repmat(patch, 1, 1, 3);
    Y = row.label(1);
    if ~iscategorical(Y), Y = categorical(Y); end
    
    out = {X, Y};
end