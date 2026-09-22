% DesmoSTORM - MATLAB app for desmosomal plaque protein analysis.
% Copyright (C) 2026 William Dean
%
% This program is free software; you can redistribute it and/or modify it
% under the terms of the GNU General Public License as published by the Free
% Software Foundation; either version 2 of the License, or (at your option)
% any later version.
%
% This program is distributed in the hope that it will be useful, but WITHOUT
% ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
% FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
% details.
%
% You should have received a copy of the GNU General Public License along
% with this program; if not, see <https://www.gnu.org/licenses/>.

function [theta,choice] = chooseRotationAngle(T)
%CHOOSEROTATIONANGLE Choose the center of the best high-score plateau.

theta = NaN;
choice = struct( ...
    "Method","score-plateau", ...
    "ScoreThreshold",NaN, ...
    "SelectedThetaIdx",NaN, ...
    "SelectedTheta",NaN);

if isempty(T) || all(T.SmoothedScore <= 0)
    choice.Method = "failed-empty-score";
    return
end

valid = T.HasCentralPair & T.SmoothedScore > 0;
if ~any(valid)
    choice.Method = "failed-no-central-pair";
    return
end

maxScore = max(T.SmoothedScore(valid));
threshold = 0.80 * maxScore;
mask = valid & T.SmoothedScore >= threshold;

% Prefer a clean two-peak plateau when available. Extra peaks are often
% peripheral puncta or bridge signal that should not dominate angle selection.
cleanMask = mask & T.NPeaks == 2;
if any(cleanMask)
    mask = cleanMask;
end

runIdx = longestCircularTrueRun(mask);
if isempty(runIdx)
    [~,idx] = max(T.SmoothedScore);
else
    idx = runIdx(ceil(numel(runIdx) / 2));
end

theta = T.Theta(idx);
choice.ScoreThreshold = threshold;
choice.SelectedThetaIdx = idx;
choice.SelectedTheta = theta;
end

function idx = longestCircularTrueRun(mask)
%LONGESTCIRCULARTRUERUN Return indices for the longest true run with wrap.
mask = reshape(logical(mask),1,[]);
n = numel(mask);
idx = [];

if n == 0 || ~any(mask)
    return
end

if all(mask)
    idx = 1:n;
    return
end

doubled = [mask mask];
bestStart = 1;
bestLen = 0;
currentStart = 1;
currentLen = 0;

for i = 1:numel(doubled)
    if doubled(i)
        if currentLen == 0
            currentStart = i;
        end
        currentLen = currentLen + 1;
        if currentLen > bestLen && currentLen <= n
            bestLen = currentLen;
            bestStart = currentStart;
        end
    else
        currentLen = 0;
    end
end

idx = mod((bestStart:bestStart+bestLen-1)-1,n) + 1;
end
