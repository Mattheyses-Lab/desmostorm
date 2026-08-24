function out = augmentPatch(in)
%AUGMENTPATCH Apply stochastic image-only augmentation to one patch sample.
%
%   OUT = AUGMENTPATCH(IN) accepts the cell payload emitted by patchDatastore:
%   {X,Y}, where X is an image patch and Y is its categorical label. The label
%   is passed through unchanged; only the image receives augmentation.
%
%   Augmentations intentionally preserve plaque/background semantics:
%       - arbitrary in-plane rotation
%       - horizontal/vertical flips
%       - mild translation/scale jitter
%       - mild linear intensity jitter clipped to [0,1]

X = in{1};
Y = in{2};

% Random rotation makes plaque orientation non-informative to the classifier.
theta = 360 * rand();
tform = randomAffine2d(Rotation=[theta theta]);

% Keep the augmented patch the same pixel size as the network input sample.
R = affineOutputView(size(X,[1 2]), tform, BoundsStyle="CenterOutput");
X = imwarp(X, tform, OutputView=R);

% Flips are safe because labels are object/background, not orientation classes.
if rand() < 0.5, X = fliplr(X); end
if rand() < 0.5, X = flipud(X); end

% Optional small affine jitter reduces sensitivity to hand-drawn ROI centering.
if rand() < 0.35
    scMin = 0.95; scMax = 1.05;
    dxMax = 6;    % +/- pixels
    dyMax = 6;

    t2 = randomAffine2d( ...
        Scale=[scMin scMax], ...
        XTranslation=[-dxMax dxMax], ...
        YTranslation=[-dyMax dyMax]);

    R2 = affineOutputView(size(X,[1 2]), t2, BoundsStyle="CenterOutput");
    X = imwarp(X, t2, OutputView=R2);
end

% Mild intensity jitter helps tolerate sample-to-sample display/intensity range
% differences without manufacturing unrealistic contrast.
if rand() < 0.5
    a = 0.90 + 0.20*rand();
    b = -0.04 + 0.08*rand();
    X = min(max(a*X + b, 0), 1);
end

out = {X, Y};
end
