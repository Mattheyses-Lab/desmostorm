function out = augmentPatch(in)
%augmentPatch Training-only augmentation for {X,Y}.
% Rotation (0-360), flips, mild translation/scale, mild intensity jitter.

X = in{1};
Y = in{2};

% Random rotation 0-360
theta = 360 * rand();
tform = randomAffine2d(Rotation=[theta theta]);

R = affineOutputView(size(X,[1 2]), tform, BoundsStyle="CenterOutput");
X = imwarp(X, tform, OutputView=R);

% Random flips
if rand() < 0.5, X = fliplr(X); end
if rand() < 0.5, X = flipud(X); end

% Optional translation/scale
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

% Mild intensity jitter
if rand() < 0.5
    a = 0.90 + 0.20*rand();
    b = -0.04 + 0.08*rand();
    X = min(max(a*X + b, 0), 1);
end

out = {X, Y};
end