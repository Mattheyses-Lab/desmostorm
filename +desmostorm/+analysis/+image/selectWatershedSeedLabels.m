function mask = selectWatershedSeedLabels(I, bw, opts)
%SELECTWATERSHEDSEEDLABELS Select watershed objects touched by seed pixels.
%
% mask = selectWatershedSeedLabels(I, bw)
% mask = selectWatershedSeedLabels(I, bw, Threshold=10)
%
% Inputs
%   I   - grayscale image
%   bw  - logical seed mask, same size as I
%
% Name-Value
%   Threshold - minimum pixel value to include, default 0
%
% Output
%   mask - logical mask containing watershed objects touched by bw.
%
% The watershed ridges are assigned to the nearest labeled object before seed
% labels are selected. That avoids leaving thin foreground remnants after
% selected puncta/objects are removed.

arguments
    I (:,:) {mustBeNumeric}
    bw (:,:) logical
    opts.Threshold double = []
end

if ~isequal(size(I), size(bw))
    error("selectWatershedSeedLabels:SizeMismatch", ...
        "I and bw must have the same size.");
end

if isempty(opts.Threshold)
    thresh = graythresh(I);
    classRange = getrangefromclass(I);
    opts.Threshold = max(thresh * classRange(2), 0);
end

candidateMask = I > opts.Threshold;
if ~any(candidateMask(:)) || ~any(bw(:))
    mask = false(size(I));
    return
end

% Distance watershed splits nearby foreground puncta into object basins.
D = bwdist(~candidateMask);
L = watershed(-D);
L(~candidateMask) = 0;

if ~any(L(:) > 0)
    mask = false(size(I));
    return
end

% Watershed ridge pixels are 0 even when they lie inside the original
% foreground mask. Give each ridge pixel to the nearest labeled component so
% selected objects can be removed without leaving thin seams.
ridgeMask = candidateMask & L == 0;
if any(ridgeMask(:))
    [~,nearestIdx] = bwdist(L > 0);
    L(ridgeMask) = L(nearestIdx(ridgeMask));
end

selectedLabels = unique(L(bw & candidateMask));
selectedLabels(selectedLabels == 0) = [];

if isempty(selectedLabels)
    mask = false(size(I));
else
    mask = ismember(L,selectedLabels);
end

end
