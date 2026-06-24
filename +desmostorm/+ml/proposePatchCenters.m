function [centers, scores] = proposePatchCenters(imgOrPath, net, opts)
%proposePatchCenters Sliding-window proposal generator using patch classifier.
% High-recall defaults: Stride=96, ScoreThreshold=0.6, NmsIoU=0.2.
%
% Outputs:
%   centers: Nx2 [x y] full-image coords (pixel-center convention)
%   scores : Nx1 positive patch probability/score
    arguments
        imgOrPath
        net
        opts.BoxSize (1,1) double {mustBePositive} = 300
        opts.Stride  (1,1) double {mustBePositive} = 96
        opts.ScoreThreshold (1,1) double {mustBeGreaterThanOrEqual(opts.ScoreThreshold,0), mustBeLessThanOrEqual(opts.ScoreThreshold,1)} = 0.6
        opts.NmsIoU (1,1) double {mustBeGreaterThanOrEqual(opts.NmsIoU,0), mustBeLessThanOrEqual(opts.NmsIoU,1)} = 0.2
        opts.BatchSize (1,1) double {mustBePositive} = 64
        opts.PositiveClass (1,1) string = "object"
    end

    % Network input size (e.g. [224 224])
    netInputSize = net.Layers(1).InputSize(1:2);
    Hn = netInputSize(1);
    Wn = netInputSize(2);
    
    % Load image
    if isa(imgOrPath, "desmostorm.model.STORMImage")
        I0 = imgOrPath.CData;
        H = imgOrPath.Height;
        W = imgOrPath.Width;
    else
        fn = string(imgOrPath);
        I0 = imread(fn);
        [H,W] = size(I0);
    end
    
    I0 = single(I0) / 65535;
    s = opts.BoxSize;
    
    % Valid center bounds (ensures sxs crop fits)
    xMin = 1 + (s-1)/2;
    xMax = W - (s-1)/2;
    yMin = 1 + (s-1)/2;
    yMax = H - (s-1)/2;
    
    if xMax < xMin || yMax < yMin
        error("proposePatchCenters:BoxTooLarge", ...
            "BoxSize=%d does not fit inside image (%dx%d).", s, H, W);
    end
    
    xs = xMin : opts.Stride : xMax;
    ys = yMin : opts.Stride : yMax;
    [XX,YY] = meshgrid(xs, ys);
    C = [XX(:) YY(:)];
    M = size(C,1);
    
    % Determine positive class index (if possible)
    posIdx = 2;
    try
        classNames = net.Layers(end).Classes;
        posIdxFound = find(string(classNames) == opts.PositiveClass, 1);
        if ~isempty(posIdxFound)
            posIdx = posIdxFound;
        end
    catch
        % ignore; keep fallback
    end
    
    scoresAll = zeros(M,1);
    
    bs = opts.BatchSize;
    for k = 1:bs:M
        k2 = min(M, k+bs-1);
        idx = k:k2;
        nb = numel(idx);
    
        % Allocate batch at NETWORK input size, not crop size
        X = zeros(Hn, Wn, 3, nb, "single");
    
        for j = 1:nb
            cx = C(idx(j),1);
            cy = C(idx(j),2);
    
            c1 = ceil(cx - s/2); c2 = floor(cx + s/2);
            r1 = ceil(cy - s/2); r2 = floor(cy + s/2);
    
            patch = I0(r1:r2, c1:c2); % s x s
    
            % Resize to network input
            patch = imresize(patch, netInputSize, "bilinear"); % Hn x Wn
    
            X(:,:,1,j) = patch;
            X(:,:,2,j) = patch;
            X(:,:,3,j) = patch;
        end
    
        % Prefer predict for scores
        try
            P = predict(net, X);        % nb x numClasses (probabilities if softmax present)
            scoresAll(idx) = P(:,posIdx);
        catch
            Y = classify(net, X);
            scoresAll(idx) = double(string(Y) == opts.PositiveClass);
        end

    end
    
    keep = scoresAll >= opts.ScoreThreshold;
    Ck = C(keep,:);
    Sk = scoresAll(keep);
    
    if isempty(Ck)
        centers = zeros(0,2);
        scores  = zeros(0,1);
        return
    end
    
    B = centerToBBox(Ck, s);
    keepIdx = nmsFixedBoxes(B, Sk, opts.NmsIoU);
    
    centers = Ck(keepIdx,:);
    scores  = Sk(keepIdx);

end

% ---- helpers ----

function B = centerToBBox(C, s)
    x = C(:,1) - s/2;
    y = C(:,2) - s/2;
    B = [x y repmat([s s], size(C,1), 1)];
end

function keepIdx = nmsFixedBoxes(B, S, iouThr)
    [~, order] = sort(S, "descend");
    keep = true(numel(order),1);
    
    for ii = 1:numel(order)
        if ~keep(ii), continue; end
        bi = B(order(ii),:);
    
        jj = find(keep);
        jj = jj(jj > ii);
        if isempty(jj), continue; end
    
        Bj = B(order(jj),:);
        iou = bboxIoU(bi, Bj);
    
        keep(jj(iou > iouThr)) = false;
    end
    
    keepIdx = order(keep);
end

function iou = bboxIoU(b1, B)
    x1 = max(b1(1), B(:,1));
    y1 = max(b1(2), B(:,2));
    x2 = min(b1(1)+b1(3), B(:,1)+B(:,3));
    y2 = min(b1(2)+b1(4), B(:,2)+B(:,4));
    
    w = max(0, x2 - x1);
    h = max(0, y2 - y1);
    inter = w .* h;
    
    a1 = b1(3) * b1(4);
    a2 = B(:,3) .* B(:,4);
    
    iou = inter ./ (a1 + a2 - inter + eps);
end