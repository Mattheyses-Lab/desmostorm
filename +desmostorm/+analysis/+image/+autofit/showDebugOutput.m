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

function showDebugOutput(Iraw,Ifit,ROI,diagnostics)
%SHOWDEBUGOUTPUT Display final auto-fit diagnostics.
%
% This intentionally does not animate the angle sweep. The complete angle
% table is stored in diagnostics.AngleScores; the figure only summarizes the
% final selected ROI and the score landscape.

T = diagnostics.AngleScores;
choice = diagnostics.AngleChoice;

desmostorm.Log.DEBUG(sprintf( ...
    "Auto-fit ROI debug: selected theta %.2f using %s.", ...
    ROI.RotationAngle, ...
    choice.Method));

fig = uifigure( ...
    "WindowStyle","alwaysontop", ...
    "OuterPosition",matlabx.UICal.centeredFigOuterPosition(1100,500), ...
    "Name","Auto-fit ROI diagnostics");
layout = uigridlayout(fig,[1 2], ...
    "ColumnWidth",{"1.2x","1x"}, ...
    "RowHeight",{"1x"});

img = matlabx.image.Image5D.fromComponents( ...
    {Iraw,Ifit}, ...
    "Names",["Raw","Preprocessed"]);

imageAx = matlabx.ui.axes.ImageAxes(layout, ...
    "Name","Auto-fit image", ...
    "Tools",{'DrawRectangle'}, ...
    "ImageData",img, ...
    "Colormap",turbo);
imageAx.setComponentColormap(turbo,1);
imageAx.setComponentColormap(turbo,2);
imageAx.Tools.DrawRectangle.RotationAngleMode = 'half-circle';
if ~isnan(ROI.RotationAngle)
    imageAx.Tools.DrawRectangle.setROIPosition(ROI);
end

scoreAx = uiaxes(layout);
if isnan(choice.SelectedTheta)
    titleText = sprintf("Auto-fit failed (%s)",choice.Method);
    selectedTheta = NaN;
else
    titleText = sprintf("Selected %.1f deg (%s)",choice.SelectedTheta,choice.Method);
    selectedTheta = choice.SelectedTheta;
end
desmostorm.analysis.image.autofit.plotAngleScores(scoreAx,T, ...
    "SelectedTheta",selectedTheta, ...
    "Title",titleText);
end
