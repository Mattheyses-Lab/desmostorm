function Iout = suppressHotPuncta(I, pHigh, dilateRadius, medWin)
%SUPPRESSHOTPUNCTA Mask extreme bright puncta and replace locally.
% pHigh: percentile defining "hot" (e.g. 99.95)
% dilateRadius: in pixels (e.g. 2 to 4)
% medWin: median filter window (odd, e.g. 9 or 11)

    if nargin < 2 || isempty(pHigh),        pHigh = 99.99; end
    if nargin < 3 || isempty(dilateRadius), dilateRadius = 7; end
    if nargin < 4 || isempty(medWin),       medWin = 11; end

    I = im2double(I);

    hi = prctile(I(:), pHigh);
    mask = I >= hi;

    % opening to remove very small objects
    mask = imopen(mask,strel('disk',1,0));

    % Dilate to cover the full bright blob
    se = strel('disk', dilateRadius, 0);
    mask = imdilate(mask, se);

    % --- method 1 ---
    % set mask pixels to 0 in I
    I(mask) = 0;
    % Apply median filtering to smooth the image after masking
    Imed = medfilt2(I, [medWin medWin]);
    % replace masked pixels in input with median filtered pixels
    I(mask) = Imed(mask);


    % % ---method 2 ---
    % Iopen = imgaussfilt(I,25);
    % % replace masked pixels in input with median filtered pixels
    % I(mask) = Iopen(mask);

    Iout = rescale(I);
end