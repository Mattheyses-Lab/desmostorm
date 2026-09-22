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

function Iout = removeIsolatedPuncta(I,opts)
%DETECTPLAQUES Detects individual plaques within an individual STORMRegion

arguments
    I (:,:) {mustBeNumeric(I)}
    opts.MinPunctaPerCluster (1,1) double = 15
    opts.DebugOutput (1,1) logical = false
    opts.DisplayOutput (1,1) logical = false
end

debugOutput = opts.DebugOutput || opts.DisplayOutput;

% Locate puncta, then cluster them. PointClusters now performs only the
% initial clustering in its constructor; reclustering is an explicit pipeline
% step so callers can decide which stages are appropriate.
[seedPts,~] = matlabx.image.measure.detectPuncta(I);

% use DBSCAN to coalesce puncta locations into clusters
clustData = matlabx.analysis.cluster.PointClusters(seedPts,...
    "MinPointsPerCluster",opts.MinPunctaPerCluster);
clustData.recluster();

% keep only isolated (unclustered) points
isolatedPts = clustData.UnclusteredPoints;

% make seed mask
seedMask = matlabx.image.mask.fromPoints(isolatedPts,size(I));
% % grow to cover puncta
%punctaMask = matlabx.image.mask.growSeedMask(I,seedMask,"Threshold",0);
% select full watershed components containing isolated-puncta seeds
punctaMask = desmostorm.analysis.image.selectWatershedSeedLabels(I, ...
    seedMask, ...
    "Threshold",0);

% initialize output image
Iout = I;
% remove isolated puncta by setting their intensity to zero
Iout(punctaMask) = 0;

if debugOutput

    imgCell1 = {I,seedMask,punctaMask,Iout};
    names1 = ["Input","Remove Seeds","Remove Mask","Output"];
    img1 = matlabx.image.Image5D.fromComponents(imgCell1,"Names",names1);

    imgCell2 = {I,Iout};
    names2 = ["Input","Output"];
    img2 = matlabx.image.Image5D.fromComponents(imgCell2,"Names",names2);


    ax1 = matlabx.app.quickshow(img1,"Title","removeIsolatedPuncta Results");
    %ax1.ComponentColorMode = 'luts';
    ax1.setComponentColormap(turbo,1);
    ax1.setComponentColormap(turbo,4);


    ax2 = matlabx.app.quickshow(img2,"Title","removeIsolatedPuncta Results");
    %ax2.ComponentColorMode = 'luts';
    ax2.setComponentColormap(turbo,1);
    ax2.setComponentColormap(turbo,2);

    ax2.Overlays.add("PointClusters", ...
        "ClusterData", clustData, ...
        "C", 1);

    T = clustData.exportClusterMetrics;
    desmostorm.Log.DEBUG(sprintf( ...
        "removeIsolatedPuncta: %d seed point(s), %d cluster(s), %d isolated point(s).", ...
        size(seedPts,1), ...
        height(T), ...
        size(isolatedPts,1)));
end


end
