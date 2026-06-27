function regionSubimageWithROI(region,filename,opts)
%REGIONSUBIMAGEWITHROI  Export region subimage with ROI overlay
    arguments
        region                          (1,1) desmostorm.model.STORMRegion
        filename                        (1,:) char
        opts.Colormap                   (256,3) double = gray
        opts.AutoScaleDisplayIntensity  (1,1) logical = false
        opts.Resolution                 (1,1) double = 600
        opts.ROIFaceAlpha               (1,1) double = 0
        opts.Size                       (1,1) double = 3
        opts.Units                      (1,:) char = 'inches'
        opts.FontSize                   (1,1) double = 12
    end

    % --- get region image and ROI data ---
    parentImage = region.Parent;

    Icell = parentImage.regionSubimageCell(region);
    I = Icell{1}; % first channel only (for now, add other channels later)

    ROI = region.ROI;

    % ensure ROI is valid
    if any(isnan([ROI.CenterX,ROI.CenterY,ROI.Width,ROI.Height,ROI.RotationAngle]))
        error('desmostorm:export:regionSubimageWithROI:ROINotFound','No ROI exists for %s',region.Name);
    end

    % --- create figure with ImageAxes for export ---
    [ax,fig] = matlabx.app.quickshow(I, ...
        "Colormap",opts.Colormap, ...
        "Tools",{'DrawRectangle'}, ...
        "WindowStyle","normal", ...
        "Visible","off", ...
        "Size",opts.Size, ...
        "Units",opts.Units);

    % close figure on function completion
    c = onCleanup(@() delete(fig));

    % set CLim
    switch opts.AutoScaleDisplayIntensity
        case true
            ax.CLim = parentImage.AutoDisplayRange;
        case false
            ax.CLim = parentImage.DisplayRange;
    end

    % set options for RegionViewer DrawRectangle tool
    ax.Tools.DrawRectangle.RotationAngleMode = 'half-circle';
    ax.Tools.DrawRectangle.FontSize = opts.FontSize;
    ax.Tools.DrawRectangle.ROIFaceAlpha = opts.ROIFaceAlpha;
    ax.Tools.DrawRectangle.setROIPosition(region.ROI);

    % show figure, draw, and pause briefly for graphics to render
    fig.Visible = "on";
    drawnow
    pause(1)

    % --- export axes content as image to specified file location ---
    matlabx.ui.export.axes2image(ax.getAxes(),filename, ...
        "HideToolbar",          true, ...
        "PreserveAspectRatio",  'off', ...
        "Resolution",           opts.Resolution, ...
        "Units",                opts.Units, ...
        "Width",                opts.Size, ...
        "Height",               opts.Size);

end