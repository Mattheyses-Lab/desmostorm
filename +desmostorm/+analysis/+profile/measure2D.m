function out = measure2D(I, cx, cy, w, h, thetaDeg, varargin)
% desmostorm.analysis.profile.measure2D  Rectified "rectangular linescan" averaged across both directions.
% out = desmostorm.analysis.profile.measure2D(I, cx, cy, w, h, thetaDeg, 'Step', ds, 'Interp', 'linear', 'Fill', NaN)
%
% Inputs
%   I         : 2-D image (double/single/uint*)
%   cx, cy    : rectangle center in pixel-edge coordinates (x right, y down)
%   w, h      : rectangle width (x-span) and height (y-span), in pixels (edge-to-edge)
%   thetaDeg  : rotation angle (degrees), CCW in image coordinates (y increases downward)
%
% Name-Value
%   'Step'    : sampling step (default 1 px) for both width & height
%   'Interp'  : 'nearest' | 'linear' | 'cubic' (default 'linear')
%   'Fill'    : fill value outside image (default NaN so we can use nanmean)
%
% Outputs (struct)
%   out.patch                       : rectified patch (size nH-by-nW)
%   out.WidthDist, out.HeightDist   : distance axes (pixels) along width & height
%   out.WidthProfile                : mean over rows  (1-by-nW)  → signal vs distance along width
%   out.HeightProfile               : mean over cols  (nH-by-1)  → signal vs distance along height
%   out.Rin                         : imref2d for the input image (edge-referenced)
%   out.Rout                        : imref2d for the rectified patch (edge-referenced)
%   out.Tfwd                        : 3x3 affine mapping local→image (forward)
%   out.Tinv                        : 3x3 affine used in imwarp (output→input)
%   out.Step                        : sampling step used for width and height

% ---- Parse inputs
p = inputParser;
p.addParameter('Step', 1);
p.addParameter('Interp', 'linear');     % 'nearest'|'linear'|'cubic'
p.addParameter('Fill', NaN);
p.parse(varargin{:});
ds     = p.Results.Step;
interp = p.Results.Interp;
fillV  = p.Results.Fill;

% ---- Prepare image & references
Iclass = class(I);
I      = double(I);
[H,W]  = size(I);
Rin    = imref2d([H, W], [0.5, W+0.5], [0.5, H+0.5]);  % pixel-edge

% Sizes and step
nW = max(1, round(w/ds));
nH = max(1, round(h/ds));

% ---- Output (rectified) reference: pixel-edge; centers at integers
Rout = imref2d([nH, nW], [0.5, nW+0.5], [0.5, nH+0.5]);
u0   = (nW + 1)/2;    % output pixel-center origin
v0   = (nH + 1)/2;

% ---- Rotation: CCW in image coords (x→right, y→down)
theta = deg2rad(thetaDeg);
c = cos(theta); s = sin(theta);
R = [ c,  s;    % this is CCW in y-down coordinates
     -s,  c];

% ---- Affine mapping
% Output→Input (local→image) in world coords:
%   [x;y] = A*[u;v] + t   with (u,v) pixel-center indices
A = R * (ds * eye(2));
t = [cx; cy] - A * [u0; v0];
T_fwd = [A, t; 0 0 1];                 % local→image (for reference)

% imwarp needs Output→Input when 'OutputView' is used: pass the inverse
T_inv = inv(T_fwd);
tformInv = affine2d(T_inv.');          % row-vector convention

% ---- Warp to rectified patch
patch = imwarp(I, Rin, tformInv, interp, 'OutputView', Rout, 'FillValues', fillV);
patch = cast(patch, Iclass);

% ---- Profiles (averages across width/height)
WidthProfile  = mean(patch, 1, 'omitnan');   % avg rows → vs width (x')
HeightProfile = mean(patch, 2, 'omitnan');   % avg cols → vs height (y')
HeightProfile = HeightProfile(:);

% ---- Distance axes (centered so 0 at rect center)
WidthDist = ((1:nW) - u0) * ds;   % along width (columns)
HeightDist = ((1:nH) - v0) * ds;   % along height (rows)

% ---- Package outputs
out.patch  = patch;
out.WidthDist     = WidthDist;
out.HeightDist     = HeightDist;
out.WidthProfile  = WidthProfile;
out.HeightProfile = HeightProfile;
out.Rin    = Rin;
out.Rout   = Rout;
out.T_fwd  = T_fwd;    % local (rectified) → image
out.T_inv  = T_inv;    % output→input passed to imwarp
out.Step   = ds;

end
