function [pkg,out] = materializeClassifierPatches(classifierFile, opts)
%MATERIALIZECLASSIFIERPATCHES Add portable cropped patches to a classifier package.
%
%   PKG = MATERIALIZECLASSIFIERPATCHES(CLASSIFIERFILE) loads an existing
%   classifier package, crops every row in pkg.PatchTable into a patch TIFF
%   folder next to the package, updates pkg.PatchTable.patchFilename, adds
%   pkg.PatchStore metadata, and saves the package in place.
%
%   This is useful for older packages whose training tables only reference
%   original source images. After materialization, continued training can read
%   from the saved patch files even if the original training images move.

arguments
    classifierFile (1,1) string
    opts.OutputClassifierFile (1,1) string = classifierFile
    opts.PatchDir (1,1) string = ""
    opts.OverwritePatches (1,1) logical = true
    opts.SavePackage (1,1) logical = true
    opts.ProgressDialog = []
end

pkg = desmostorm.ml.loadClassifierPackage(classifierFile);

if ~isfield(pkg,"PatchTable") || isempty(pkg.PatchTable)
    error("materializeClassifierPatches:MissingPatchTable", ...
        "Classifier package does not contain a non-empty PatchTable.");
end
if ~isfield(pkg,"BoxSize") || isempty(pkg.BoxSize)
    error("materializeClassifierPatches:MissingBoxSize", ...
        "Classifier package does not contain BoxSize.");
end

if opts.PatchDir == ""
    [folder,stem] = fileparts(opts.OutputClassifierFile);
    opts.PatchDir = fullfile(folder,stem + "_patches");
end

manifestFile = fullfile(opts.PatchDir,"patch_manifest.csv");

desmostorm.Log.INFO(sprintf( ...
    "Materializing classifier patches for package: %s",classifierFile));
desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
    "Materializing classifier training patches...",0.05);

[patchTable,patchStore] = desmostorm.ml.materializePatchTable( ...
    pkg.PatchTable, ...
    opts.PatchDir, ...
    pkg.BoxSize, ...
    "ManifestFile",manifestFile, ...
    "Overwrite",opts.OverwritePatches, ...
    "ProgressDialog",opts.ProgressDialog);

pkg.PatchTable = patchTable;
pkg.PatchStore = patchStore;

if opts.SavePackage
    desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
        "Saving updated classifier package...",0.95);
    desmostorm.ml.saveClassifierPackage(opts.OutputClassifierFile,pkg);
    desmostorm.Log.INFO(sprintf( ...
        "Saved materialized classifier package: %s",opts.OutputClassifierFile));
end

desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
    "Classifier patch materialization complete.",1);

out = struct();
out.SourceClassifierFile = classifierFile;
out.OutputClassifierFile = opts.OutputClassifierFile;
out.PatchDir = string(opts.PatchDir);
out.ManifestFile = string(manifestFile);
out.NumPatches = height(patchTable);

end
