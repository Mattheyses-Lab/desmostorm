function [Pout,store] = materializePatchTable(P, outDir, boxSize, opts)
%MATERIALIZEPATCHTABLE Save patch-table rows as cropped image files.
%
%   [POUT,STORE] = MATERIALIZEPATCHTABLE(P, OUTDIR, BOXSIZE) crops each row
%   in P and writes a patch image under OUTDIR. POUT is the same patch table
%   with an added patchFilename column. Downstream training prefers that
%   materialized file and no longer needs to recrop from the original image.
%
%   Existing materialized rows are also accepted as input. If a row already
%   has a readable patchFilename, that image is copied into OUTDIR. Otherwise
%   the patch is cropped from imageFilename, centerX, and centerY.

arguments
    P table
    outDir (1,1) string
    boxSize (1,1) double {mustBePositive}
    opts.ManifestFile (1,1) string = fullfile(outDir,"patch_manifest.csv")
    opts.Overwrite (1,1) logical = true
    opts.ProgressDialog = []
end

matlabx.utils.files.ensureDir(outDir);

Pout = P;
n = height(Pout);
patchFilename = strings(n,1);

if n == 0
    Pout.patchFilename = patchFilename;
    store = makePatchStore(outDir,opts.ManifestFile,n);
    writetable(Pout,opts.ManifestFile);
    return
end

for i = 1:n
    desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
        sprintf("Materializing training patch %d/%d...",i,n), ...
        i / max(n,1));

    label = safeToken(string(Pout.label(i)));
    source = "unknown";
    if ismember("source",string(Pout.Properties.VariableNames))
        source = safeToken(string(Pout.source(i)));
    end

    patchFile = fullfile(outDir,sprintf("patch_%05d_%s_%s.tif",i,label,source));
    if ~opts.Overwrite && isfile(patchFile)
        patchFilename(i) = string(patchFile);
        continue
    end

    patch = readPatchForMaterialization(Pout,i,boxSize);
    imwrite(patch,patchFile);
    patchFilename(i) = string(patchFile);
end

Pout.patchFilename = patchFilename;
Pout.Properties.UserData.PatchRoot = string(outDir);

writetable(Pout,opts.ManifestFile);
store = makePatchStore(outDir,opts.ManifestFile,n);

desmostorm.Log.INFO(sprintf( ...
    "Materialized %d classifier training patch(es): %s",n,outDir));

end

function patch = readPatchForMaterialization(P,rowIndex,boxSize)
%READPATCHFORMATERIALIZATION Read from a prior patch file or crop source data.
    if ismember("patchFilename",string(P.Properties.VariableNames))
        existingFile = string(P.patchFilename(rowIndex));
        if ~isfile(existingFile) && isstruct(P.Properties.UserData) && ...
                isfield(P.Properties.UserData,"PatchRoot")
            existingFile = fullfile(string(P.Properties.UserData.PatchRoot),existingFile);
        end
        if strlength(existingFile) > 0 && isfile(existingFile)
            patch = imread(existingFile);
            patch = firstPlane(patch);
            patch = toWritableImage(patch);
            return
        end
    end

    imageFile = string(P.imageFilename(rowIndex));
    if ~isfile(imageFile)
        error("materializePatchTable:MissingSourceImage", ...
            "Cannot materialize patch %d. Source image is missing: %s", ...
            rowIndex,imageFile);
    end

    I = imread(imageFile);
    I = firstPlane(I);

    cx = P.centerX(rowIndex);
    cy = P.centerY(rowIndex);
    s = boxSize;

    c1 = ceil(cx - s/2); c2 = floor(cx + s/2);
    r1 = ceil(cy - s/2); r2 = floor(cy + s/2);

    if r1 < 1 || c1 < 1 || r2 > size(I,1) || c2 > size(I,2)
        error("materializePatchTable:PatchOutOfBounds", ...
            "Patch %d is outside source image bounds: center=(%.3f, %.3f), boxSize=%d.", ...
            rowIndex,cx,cy,s);
    end

    patch = I(r1:r2,c1:c2);
    patch = toWritableImage(patch);
end

function I = firstPlane(I)
%FIRSTPLANE Match current training behavior by using the first image plane.
    if ~ismatrix(I)
        I = I(:,:,1);
    end
end

function Iout = toWritableImage(I)
%TOWRITABLEIMAGE Convert common numeric image classes to TIFF-safe data.
    if isa(I,"uint8") || isa(I,"uint16")
        Iout = I;
    elseif isinteger(I)
        Iout = uint16(rescale(double(I),0,double(intmax("uint16"))));
    elseif isfloat(I)
        if isempty(I)
            Iout = uint16.empty();
        elseif max(I,[],"all","omitnan") <= 1 && min(I,[],"all","omitnan") >= 0
            Iout = im2uint16(I);
        else
            Iout = uint16(min(max(round(I),0),double(intmax("uint16"))));
        end
    else
        error("materializePatchTable:UnsupportedImageClass", ...
            "Unsupported patch image class: %s",class(I));
    end
end

function token = safeToken(str)
%SAFETOKEN Make labels/sources safe for filenames.
    token = regexprep(char(str),"[^A-Za-z0-9_+-]","_");
    if isempty(token)
        token = "unknown";
    end
end

function store = makePatchStore(outDir,manifestFile,n)
%MAKEPATCHSTORE Build package metadata describing the materialized patch set.
    store = struct();
    store.Mode = "materialized";
    store.Root = string(outDir);
    store.Manifest = string(manifestFile);
    store.NumPatches = n;
    store.Created = datetime("now");
end
