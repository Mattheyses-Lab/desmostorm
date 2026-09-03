function [pkgNew,out] = retrainClassifierFromPackage(classifierFile, opts)
%RETRAINCLASSIFIERFROMPACKAGE Train a fresh network from an existing package.
%
%   RETRAINCLASSIFIERFROMPACKAGE(CLASSIFIERFILE) loads the accumulated patch
%   table from an existing classifier package, initializes a fresh ResNet-18
%   transfer-learning model, trains from that table, materializes the final
%   patch table, and saves the result as a new classifier lineage.
%
% This differs from continueClassifierTrainingFromProject:
%   - no current project labels are added
%   - the old network weights are not reused
%   - the old package only provides the curated training dataset/provenance
%   - BaseName defaults to "<source>_scratch", so numbering starts at v001
%     unless that new lineage already exists in SaveDir

arguments
    classifierFile (1,1) string

    opts.ValFrac (1,1) double {mustBeGreaterThan(opts.ValFrac,0), mustBeLessThan(opts.ValFrac,1)} = 0.2

    opts.SaveDir (1,1) string = ""
    opts.BaseName (1,1) string = ""
    opts.MaxEpochs (1,1) double {mustBePositive} = 15
    opts.MiniBatchSize (1,1) double {mustBePositive} = 8
    opts.InitialLearnRate (1,1) double {mustBePositive} = 3e-4
    opts.ExecutionEnvironment (1,1) string = "cpu"
    opts.Augment (1,1) logical = true
    opts.ValidationFrequency (1,1) double {mustBePositive} = 50

    opts.Notes (1,1) string = ""
    opts.ProgressDialog = []
end

desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
    "Loading classifier package...");
desmostorm.Log.INFO(sprintf("Loading classifier package for fresh retraining: %s",classifierFile));
pkgOld = desmostorm.ml.loadClassifierPackage(classifierFile);

if ~isfield(pkgOld,"PatchTable") || isempty(pkgOld.PatchTable)
    error("retrainClassifierFromPackage:MissingPatchTable", ...
        "Classifier package does not contain a non-empty PatchTable.");
end
if ~isfield(pkgOld,"BoxSize") || isempty(pkgOld.BoxSize)
    error("retrainClassifierFromPackage:MissingBoxSize", ...
        "Classifier package does not contain BoxSize.");
end

if opts.SaveDir == ""
    saveDir = string(fileparts(classifierFile));
else
    saveDir = opts.SaveDir;
end
matlabx.utils.files.ensureDir(saveDir);

sourceBaseName = desmostorm.ml.classifierBaseNameFromFile(classifierFile);
if strlength(opts.BaseName) == 0
    baseName = sourceBaseName + "_scratch";
else
    baseName = opts.BaseName;
end
patchTableTraining = pkgOld.PatchTable;

desmostorm.Log.INFO(sprintf( ...
    "Retraining fresh classifier '%s' from %d accumulated patch(es).", ...
    baseName,height(patchTableTraining)));

desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
    "Splitting accumulated patches into training and validation sets...",0.10);
[Ptrain,Pval] = desmostorm.ml.splitByImage(patchTableTraining,opts.ValFrac);
desmostorm.Log.INFO(sprintf( ...
    "Patch split complete: %d training patch(es), %d validation patch(es).", ...
    height(Ptrain),height(Pval)));

trainOpts = struct;
trainOpts.BaseNet = "resnet18";
trainOpts.ContinueTraining = false;
trainOpts.MaxEpochs = opts.MaxEpochs;
trainOpts.MiniBatchSize = opts.MiniBatchSize;
trainOpts.InitialLearnRate = opts.InitialLearnRate;
trainOpts.ExecutionEnvironment = opts.ExecutionEnvironment;
trainOpts.Augment = opts.Augment;
trainOpts.ValidationFrequency = opts.ValidationFrequency;

desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
    "Training fresh classifier network...");
netNew = desmostorm.ml.trainPatchClassifier(Ptrain,Pval,pkgOld.BoxSize, ...
    "BaseNet",trainOpts.BaseNet, ...
    "ContinueTraining",trainOpts.ContinueTraining, ...
    "MaxEpochs",trainOpts.MaxEpochs, ...
    "MiniBatchSize",trainOpts.MiniBatchSize, ...
    "InitialLearnRate",trainOpts.InitialLearnRate, ...
    "ExecutionEnvironment",trainOpts.ExecutionEnvironment, ...
    "Augment",trainOpts.Augment, ...
    "ValidationFrequency",trainOpts.ValidationFrequency, ...
    "ProgressDialog",opts.ProgressDialog);

if isfield(pkgOld,"PropOpts") && ~isempty(pkgOld.PropOpts)
    propOpts = pkgOld.PropOpts;
else
    propOpts = struct();
end
if ~isfield(propOpts,"CandidateMode")
    propOpts.CandidateMode = "grid";
elseif string(propOpts.CandidateMode) == "cluster"
    propOpts.CandidateMode = "ClusterCentroid";
end
if isfield(pkgOld,"PositiveClass")
    positiveClass = string(pkgOld.PositiveClass);
else
    positiveClass = "object";
end
propOpts.PositiveClass = positiveClass;

[nextVersion,stem] = desmostorm.ml.nextClassifierVersion(saveDir,baseName);

classifierOut = fullfile(saveDir,sprintf("classifier_%s_v%03d.mat",stem,nextVersion));
trainingPatchOut = fullfile(saveDir,sprintf("patchTable_%s_v%03d_training.csv",stem,nextVersion));
patchDir = fullfile(saveDir,sprintf("classifier_%s_v%03d_patches",stem,nextVersion));
manifestFile = fullfile(patchDir,"patch_manifest.csv");

desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
    "Materializing classifier training patches...");
[patchTableTraining,patchStore] = desmostorm.ml.materializePatchTable( ...
    patchTableTraining,patchDir,pkgOld.BoxSize, ...
    "ManifestFile",manifestFile, ...
    "ProgressDialog",opts.ProgressDialog);

desmostorm.Log.INFO("Packaging freshly retrained classifier and saving files...");
desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
    "Packaging classifier and saving files...");
pkgNew = desmostorm.ml.makeClassifierPackage( ...
    netNew,pkgOld.BoxSize,trainOpts,propOpts,patchTableTraining, ...
    PositiveClass=positiveClass, ...
    SourceModel=string(classifierFile), ...
    Notes=opts.Notes, ...
    PatchStore=patchStore);

desmostorm.ml.saveClassifierPackage(classifierOut,pkgNew);
desmostorm.Log.INFO(sprintf("Saved freshly retrained classifier package: %s",classifierOut));
writetable(patchTableTraining,trainingPatchOut);
desmostorm.Log.INFO(sprintf("Saved training patch table: %s",trainingPatchOut));

desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
    "Fresh classifier retraining complete.",1);

out = struct();
out.ClassifierFile = string(classifierOut);
out.TrainingPatchFile = string(trainingPatchOut);
out.SaveDir = string(saveDir);
out.Version = nextVersion;
out.BaseName = stem;
out.SourceClassifierFile = string(classifierFile);
out.NumTrainingPatches = height(patchTableTraining);

end
