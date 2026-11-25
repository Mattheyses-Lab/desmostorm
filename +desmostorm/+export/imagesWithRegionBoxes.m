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

function summary = imagesWithRegionBoxes(project,folderName,opts)
%IMAGESWITHREGIONBOXES Export full images with region box overlays.

arguments
    project                         (1,1) desmostorm.model.STORMProject
    folderName                      {mustBeTextScalar}
    opts.Scope                      (1,1) string {mustBeMember(opts.Scope,["active","all"])} = "active"
    opts.Channel                    (1,1) double {mustBeInteger,mustBePositive} = 1
    opts.DisplaySettings (1,1) desmostorm.config.Display = desmostorm.config.Display()
    opts.AutoScalingMethod (1,1) string = ""
    opts.ScalingMode                (1,1) string {mustBeMember(opts.ScalingMode,["data","auto","user"])} = "data"
    opts.Colormap                   (256,3) double = gray
    opts.ColorMode                  (1,1) string {mustBeMember(opts.ColorMode,["label","manual"])} = "label"
    opts.Color                      (1,3) double = [1 1 1]
    opts.RegionNamesVisible         (1,1) matlab.lang.OnOffSwitchState = "on"
    opts.BoxLineWidth               (1,1) double {mustBePositive} = 1
    opts.BoxFaceAlpha               (1,1) double {mustBeInRange(opts.BoxFaceAlpha,0,1)} = 0
    opts.FontSize                   (1,1) double {mustBePositive} = 7
    opts.Format (1,1) string {mustBeMember(opts.Format,["PNG","TIFF","JPEG"])} = "PNG"
    opts.Width (1,1) double {mustBeNonnegative,mustBeFinite} = 0
    opts.Height (1,1) double {mustBeNonnegative,mustBeFinite} = 0
    opts.PreserveAspectRatio (1,1) matlab.lang.OnOffSwitchState = "on"
    opts.OverlaySizing (1,1) string {mustBeMember(opts.OverlaySizing,["physical","scale"])} = "physical"
    opts.Resolution                 (1,1) double = 600
    opts.Size                       (1,1) double {mustBePositive} = 7
    opts.Units                      (1,:) char = 'inches'
    opts.ProgressDialog = matlab.ui.dialog.ProgressDialog.empty()
end

matlabx.utils.files.ensureDir(folderName);

imgs = collectImages(project,opts.Scope);
summary = struct("Attempted",numel(imgs),"Exported",0,"Skipped",0);
if isempty(imgs)
    return
end

[firstImage,I] = firstExportableImage(imgs,opts.Channel);
if isempty(firstImage)
    desmostorm.Log.WARN(sprintf( ...
        "No images with channel %d were available for region box overlay export.", ...
        opts.Channel));
    summary.Skipped = summary.Attempted;
    return
end

[ax,fig] = matlabx.app.quickshow(I, ...
    "Colormap",opts.Colormap, ...
    "Tools",{}, ...
    "WindowStyle","normal", ...
    "Visible","off", ...
    "Size",7, ...
    "Units","inches");
c = onCleanup(@() delete(fig));

ax.CLim = desmostorm.export.imageDisplayLimits(firstImage,firstImage.sourceChannelIndex(opts.Channel),opts.ScalingMode,opts.DisplaySettings,opts.AutoScalingMethod);
addRegionBoxOverlays(ax,project,firstImage,opts);

% Match the ROI overlay export behavior: show once so ImageAxes and overlay
% graphics realize cleanly, then hide before iterating through exports.
fig.Visible = "on";
drawnow
pause(0.5)
desmostorm.app.focusMainFigure();
fig.Visible = "off";

for k = 1:numel(imgs)
    img = imgs(k);

    desmostorm.runtime.updateProgress(opts.ProgressDialog, ...
        sprintf('Exporting region box overlay (%d/%d): %s',k,numel(imgs),img.Name), ...
        k-1,numel(imgs));

    sourceIndex = img.sourceChannelIndex(opts.Channel);
    if isempty(sourceIndex)
        summary.Skipped = summary.Skipped + 1;
        desmostorm.Log.WARN(sprintf( ...
            "Skipping region box overlay export for %s: channel %d does not exist.", ...
            img.Name,opts.Channel));
        continue
    end

    ax.CData = getImageChannel(img,sourceIndex);
    ax.CLim = desmostorm.export.imageDisplayLimits(img,sourceIndex,opts.ScalingMode,opts.DisplaySettings,opts.AutoScalingMethod);
    ax.Overlays.clear();
    addRegionBoxOverlays(ax,project,img,opts);

    drawnow
    if k == 1
        pause(0.5)
    else
        pause(0.05)
    end

    filename = fullfile(folderName,sprintf('%s_C%d_region-box-overlay.%s', ...
        safeFileStem(img.shortName),opts.Channel,lower(opts.Format)));
    [width,height] = imageExportSize(img,opts.Size);
    if opts.Width > 0, width = opts.Width; end
    if opts.Height > 0, height = opts.Height; end
    ax.exportView(filename,Units=opts.Units,Width=width,Height=height, ...
        PreserveAspectRatio=opts.PreserveAspectRatio,Resolution=opts.Resolution, ...
        OverlaySizing=opts.OverlaySizing);

    summary.Exported = summary.Exported + 1;
end

desmostorm.runtime.updateProgress(opts.ProgressDialog, ...
    sprintf('Region box overlay export complete: %d exported, %d skipped.', ...
    summary.Exported,summary.Skipped), ...
    numel(imgs),numel(imgs));

end

function imgs = collectImages(project,scope)
    if scope == "active"
        img = project.ActiveImage;
        if isempty(img)
            imgs = desmostorm.model.STORMImage.empty();
        else
            imgs = img;
        end
        return
    end

    imgs = project.ImageArray;
end

function [img,I] = firstExportableImage(imgs,channel)
    img = desmostorm.model.STORMImage.empty();
    I = [];
    for k = 1:numel(imgs)
        sourceIndex = imgs(k).sourceChannelIndex(channel);
        if ~isempty(sourceIndex)
            img = imgs(k);
            I = getImageChannel(img,sourceIndex);
            return
        end
    end
end

function I = getImageChannel(img,channel)
    I = img.ImageData.getPlane(channel);
end

function addRegionBoxOverlays(ax,project,img,opts)
    regs = img.RegionArray;
    for i = 1:numel(regs)
        reg = regs(i);
        color = resolveBoxColor(project,reg,opts);
        label = "";
        if opts.RegionNamesVisible == "on"
            label = string(reg.Name);
        end

        box = ax.Overlays.add("Box", ...
            "ID",sprintf("region-box-%d",i), ...
            "Center",reg.Center, ...
            "BoxSize",reg.BoxSize, ...
            "Label",label, ...
            "EdgeColor",color, ...
            "FaceColor",color, ...
            "FontSize",opts.FontSize);
        box.LineWidth = opts.BoxLineWidth;
        box.FaceAlpha = opts.BoxFaceAlpha;
    end
end

function color = resolveBoxColor(project,reg,opts)
    if opts.ColorMode == "manual"
        color = opts.Color;
        return
    end

    lbl = project.LabelBank.getByID(reg.LabelID);
    if isempty(lbl)
        color = opts.Color;
    else
        color = lbl.Color;
    end
end

function [W,H] = imageExportSize(img,longSide)
    if img.Width >= img.Height
        W = longSide;
        H = longSide * img.Height / img.Width;
    else
        H = longSide;
        W = longSide * img.Width / img.Height;
    end
end

function stem = safeFileStem(str)
    stem = regexprep(char(str),'[^A-Za-z0-9_.-]','_');
    if isempty(stem)
        stem = 'image';
    end
end
