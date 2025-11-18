function [xL,xR,borderLineXY] = getFWHMCoordinates(x,y,pks,locs)
% GETFWHMCOORDINATES  helper function for findpeaks output, finds coordinates of FWHM line
%
% Inputs:
%   x - location vector
%   y - input signal
%   pks - peak heights returned by findpeaks()
%   locs - peak locations returned by findpeaks()
%   w - peak widths returned by findpeaks() (with WidthReference='halfheight')

% number of peaks
nPeaks = numel(locs);

% number of sample points
nSamples = numel(x);

% Initialize arrays to store FWHM coordinates
xL = zeros(size(locs));
xR = zeros(size(locs));

% convert distance vector to idxs
locs = arrayfun(@(loc) find(x==loc,1),locs);

% find peak border idxs (idx to x position of lowest valley between peaks)
borderIdx = 1:(nPeaks-1);
borders = arrayfun(@(idx) find(y==min(y(locs(idx):locs(idx+1))),1,'first'),borderIdx);
borders = [1,borders,nSamples];


borderX = x(borders);
borderY = y(borders);
nBorders = numel(borders);

% Store the calculated FWHM coordinates in a structured format for plotting with line()
borderLineXY = zeros(2,nBorders*3);

for i = 1:nBorders
    lineIdx = 3*(i-1)+1;
    borderLineXY(1,lineIdx:lineIdx+2) = [borderX(i),borderX(i),NaN];
    borderLineXY(2,lineIdx:lineIdx+2) = [0,borderY(i),NaN];
end

% % testing below
% borders = islocalmin(y,...
%     'FlatSelection','first');


% Calculate FWHM coordinates for each peak
for i = 1:length(locs)
    halfHeight = pks(i)/2;

    % find left and right border idxs for this peak
    leftBorder = borders(i); rightBorder = borders(i+1);

    % find last sample to left of peak below half height
    idxL = find(y(leftBorder:locs(i)) <= halfHeight, 1, 'last');
    idxL = idxL + borders(i) - 1; % Adjust index to original array
    idxL = max(idxL,leftBorder); % clamp to border

    % interpolate with next point to find intersection x location
    if isempty(idxL) || idxL == leftBorder 
        % guard for edge/plateau
        xL(i) = x(leftBorder);
    else
        % linear interpolation between (idxL, idxL+1)
        xL(i) = interp1(y(idxL:idxL+1), x(idxL:idxL+1), halfHeight, 'linear');
    end

    % % find first sample to right of peak below half height
    % idxR = find(y(locs(i):end) <= halfHeight, 1, 'first');
    % idxR = idxR + locs(i) - 1; % Adjust index to original array
    % idxR = min(idxR,rightBorder); % clamp to border
    % find first sample to right of peak below half height
    idxR = find(y(locs(i):rightBorder) <= halfHeight, 1, 'first');
    idxR = idxR + locs(i) - 1; % Adjust index to original array
    idxR = min(idxR,rightBorder); % clamp to border


    % interpolate with next point to find intersection x location
    if isempty(idxR) || idxR == rightBorder 
        % guard for edge/plateau
        xR(i) = x(rightBorder);
    else
        % linear interpolation between (idxR, idxR-1)
        xR(i) = interp1(y(idxR-1:idxR), x(idxR-1:idxR), halfHeight, 'linear');
    end


end


end