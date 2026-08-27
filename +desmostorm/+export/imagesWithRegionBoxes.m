function summary = imagesWithRegionBoxes(project,folderName,opts)
%IMAGESWITHREGIONBOXES Export full images with region box overlays.

arguments
    project                         (1,1) desmostorm.model.STORMProject
    folderName                      {mustBeTextScalar}
    opts.Scope                      (1,1) string {mustBeMember(opts.Scope,["active","all"])} = "active"
    opts.Channel                    (1,1) double {mustBeInteger,mustBePositive} = 1
    opts.ScalingMode                (1,1) string {mustBeMember(opts.ScalingMode,["data","auto","user"])} = "data"
    opts.Colormap                   (256,3) double = gray
    opts.ColorMode                  (1,1) string {mustBeMember(opts.ColorMode,["label","manual"])} = "label"
    opts.Color                      (1,3) double = [1 1 1]
    opts.RegionNamesVisible         (1,1) matlab.lang.OnOffSwitchState = "on"
    opts.BoxLineWidth               (1,1) double {mustBePositive} = 1
    opts.BoxFaceAlpha               (1,1) double {mustBeInRange(opts.BoxFaceAlpha,0,1)} = 0
    opts.FontSize                   (1,1) double {mustBePositive} = 10
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
    "Size",opts.Size, ...
    "Units",opts.Units);
c = onCleanup(@() delete(fig));

ax.CLim = imageExportCLim(firstImage,opts.Channel,opts.ScalingMode);
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

    updateProgress(opts.ProgressDialog, ...
        sprintf('Exporting region box overlay (%d/%d): %s',k,numel(imgs),img.Name), ...
        k-1,numel(imgs));

    if opts.Channel > img.SizeC
        summary.Skipped = summary.Skipped + 1;
        desmostorm.Log.WARN(sprintf( ...
            "Skipping region box overlay export for %s: channel %d does not exist.", ...
            img.Name,opts.Channel));
        continue
    end

    ax.CData = getImageChannel(img,opts.Channel);
    ax.CLim = imageExportCLim(img,opts.Channel,opts.ScalingMode);
    ax.Overlays.clear();
    addRegionBoxOverlays(ax,project,img,opts);

    drawnow
    if k == 1
        pause(0.5)
    else
        pause(0.05)
    end

    filename = fullfile(folderName,sprintf('%s_C%d_region-box-overlay.png', ...
        safeFileStem(img.shortName),opts.Channel));

    [exportW,exportH] = imageExportSize(img,opts.Size);
    exportAxesImage(ax.getAxes(),filename, ...
        "HideToolbar",          true, ...
        "PreserveAspectRatio",  'off', ...
        "Resolution",           opts.Resolution, ...
        "Units",                opts.Units, ...
        "Width",                exportW, ...
        "Height",               exportH);

    summary.Exported = summary.Exported + 1;
end

updateProgress(opts.ProgressDialog, ...
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
        if channel <= imgs(k).SizeC
            img = imgs(k);
            I = getImageChannel(img,channel);
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

function clim = imageExportCLim(img,channel,scalingMode)
    switch string(scalingMode)
        case "data"
            clim = img.getDataRange(channel);
        case "auto"
            clim = img.getAutoDisplayRange(channel);
        case "user"
            clim = img.getDisplayRange(channel);
    end

    clim = double(clim);
    if any(~isfinite(clim)) || clim(1) == clim(2)
        v = clim(find(isfinite(clim),1,'first'));
        if isempty(v), v = 0; end
        clim = [v-0.5 v+0.5];
    end
    clim = sort(clim);
end

function stem = safeFileStem(str)
    stem = regexprep(char(str),'[^A-Za-z0-9_.-]','_');
    if isempty(stem)
        stem = 'image';
    end
end

function exportAxesImage(ax,filename,opts)
    arguments
        ax                          (1,1) matlab.ui.control.UIAxes
        filename                    (1,:) char
        opts.Units                  (1,:) char = 'inches'
        opts.Width                  (1,1) double = 7
        opts.Height                 (1,1) double = 7
        opts.BackgroundColor        (1,3) double = [0 0 0]
        opts.PreserveAspectRatio    (1,:) char = 'on'
        opts.Resolution             (1,1) double = 600
        opts.HideToolbar            (1,1) logical = true
    end

    toolbarVisible = ax.Toolbar.Visible;
    toolbarCleanup = onCleanup(@() set(ax.Toolbar,'Visible',toolbarVisible));
    if opts.HideToolbar
        ax.Toolbar.Visible = 'off';
    end

    exportgraphics(ax,filename, ...
        "ContentType","image", ...
        "Units",opts.Units, ...
        "Width",opts.Width, ...
        "Height",opts.Height, ...
        "Colorspace","rgb", ...
        "Padding",0, ...
        "PreserveAspectRatio",opts.PreserveAspectRatio, ...
        "BackgroundColor",opts.BackgroundColor, ...
        "Resolution",opts.Resolution);
end

function updateProgress(h,msg,idx,total)
    if isempty(h) || ~isvalid(h)
        return
    end

    h.Message = msg;
    if total > 0
        h.Indeterminate = 'off';
        h.Value = idx/total;
    end
    drawnow limitrate
end
