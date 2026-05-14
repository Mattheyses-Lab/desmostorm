function ROI = autofitRegionROI(I,config)

%% TEST BELOW

% --- preprocess image to improve fitting ---

I = model.analysis.image.removeIsolatedPuncta(I);


%% END TEST


[H,W] = size(I, [1 2]);

% starting ROI position
Height = H / 2;
Width = W / 2;
CenterX = (W / 2) + 0.5;
CenterY = (H / 2) + 0.5;
RotationAngle = 0;

% --- find RotationAngle ---

maxPeakDist = 0;

thetas = -90:1:89;
nPeaks = zeros(size(thetas));

% iterate to roughly estimate RotationAngle
for i = 1:numel(thetas)

    theta = thetas(i);

    % compute linescan
    linescanData = model.analysis.profile.measure2D(I,...
        CenterX,...
        CenterY,...
        Width,...
        Height,...
        theta,...
        'Interp','linear');

    % analyze peaks
    peaksData = model.analysis.PeaksData(linescanData.HeightProfile,linescanData.HeightDist,...
    "MinPeakDistance",config.MinPeakDistance, ...
    "MinPeakHeight",config.MinPeakHeight, ...
    "PeakSmoothing",config.PeakSmoothing);

    % % only consider scans with 2 peaks
    % if peaksData.nPeaks ~= 2
    %     continue
    % end
    % 
    % % if peak distance greater than current max, set RotationAngle=theta
    % if peaksData.PeakDistances(1) > maxPeakDist
    %     RotationAngle = theta;
    %     maxPeakDist = peaksData.PeakDistances;
    % end

    nPeaks(i) = peaksData.nPeaks;

end

% find longest consecutive stretch of thetas that yield 2 peaks
thetaIdxRange = matlabx.array.longestRunOfValue(nPeaks,2,"AllowWrap",true);

% none found -> exit
if isempty(thetaIdxRange)
    ROI = [];
    return
end

% central theta of range becomes our RotationAngle
centerThetaIdx = thetaIdxRange(ceil(numel(thetaIdxRange)/2));
RotationAngle = thetas(centerThetaIdx);



% --- locate local minima on outside of each peak

% recompute scan and peaks using best RotationAngle
linescanData = model.analysis.profile.measure2D(I,...
    CenterX,...
    CenterY,...
    Width,...
    Height,...
    RotationAngle,...
    'Interp','linear');
peaksData = model.analysis.PeaksData(linescanData.HeightProfile,linescanData.HeightDist,...
    "MinPeakDistance",config.MinPeakDistance, ...
    "MinPeakHeight",config.MinPeakHeight, ...
    "PeakSmoothing",config.PeakSmoothing);

% get non-normalized signal to make it easier to identify minima
% (normalizing to [0 1] means there will always be a signal value of 0 somewhere)
Yraw = peaksData.Y;
Ysmooth = model.analysis.PeaksData.smooth(Yraw,config.PeakSmoothing);

X = peaksData.X;                % distance vector
Y = Ysmooth;                    % signal vector
locs = peaksData.PeakLocations; % peak locations


% get peak idxs
peakIdxs = arrayfun(@(loc) find(X==loc,1),locs);
p1 = peakIdxs(1);
p2 = peakIdxs(2);

% first local minimum to the left of peak 1

% look for 0s first
leftIdx = find(Y(1:p1-1)==0, 1, 'last');

% none found -> look for local minima
if isempty(leftIdx)
    leftIdx = find( ...
        Y(2:p1-1) < Y(1:p1-2) & ...
        Y(2:p1-1) < Y(3:p1), ...
        1, 'last');

    if ~isempty(leftIdx)
        leftMinIdx = leftIdx + 1;  % offset because we searched Y(2:p1-1)
    end
else
    leftMinIdx = leftIdx;
end

% no local min or 0s found -> use first value
if isempty(leftIdx)
    leftMinIdx = 1;            % no local min found
end



% first local minimum to the right of peak 2

% look for 0s first
rightIdx = find(Y(p2+1:end)==0, 1, 'first');

% none found -> look for local minima
if isempty(rightIdx)
    rightIdx = find( ...
        Y(p2+1:end-1) < Y(p2:end-2) & ...
        Y(p2+1:end-1) < Y(p2+2:end), ...
        1, 'first');

    if ~isempty(rightIdx)
        rightMinIdx = rightIdx + p2; % offset because we searched Y(p2+1:end-1)
    end
else
    rightMinIdx = rightIdx + p2;
end

% no local min or 0s found -> use last value
if isempty(rightIdx)
    rightMinIdx = numel(X);            % no local min found
end

% --- adjust Height and Center so that scan runs from leftMin to rightMin ---


% left min first

% distance to adjust ROI height to trim from the "top"
dH_Top = X(leftMinIdx) - X(1);

% distance to shift center to account for changing height
dC_Top = dH_Top / 2;

% X and Y shifts, unsigned
dX_Top = cosd(90-abs(RotationAngle))*dC_Top;
dY_Top = sind(90-abs(RotationAngle))*dC_Top;




% right min

% distance to adjust ROI height to trim from the "bottom"
dH_Bot = X(end) - X(rightMinIdx);

% distance to shift center to account for changing height
dC_Bot = dH_Bot / 2;

% X and Y shifts, unsigned
dX_Bot = cosd(90-abs(RotationAngle))*dC_Bot;
dY_Bot = sind(90-abs(RotationAngle))*dC_Bot;

% apply signs
if RotationAngle < 0
    dX_Top = -dX_Top;
    dY_Bot = -dY_Bot;
else
    dX_Bot = -dX_Bot;
    dY_Bot = -dY_Bot;
end

% Adjust the ROI dimensions based on the calculated shifts
Height = Height - dH_Top - dH_Bot;
CenterX = CenterX + (dX_Top + dX_Bot);
CenterY = CenterY + (dY_Top + dY_Bot);


% collect output as struct
ROI = struct(...
    "CenterX",CenterX, ...
    "CenterY",CenterY, ...
    "Width",Width, ...
    "Height", Height, ...
    "RotationAngle", RotationAngle);

% matlabx.struct.prettyPrint(ROI);

end