function [pkg, out] = trainNewClassifierFromProject(project, opts)
%TRAINNEWCLASSIFIERFROMPROJECT Train and save a new patch classifier package.
%
% This is the GUI-facing orchestration layer for initial classifier training.
% It converts reviewed project regions into a patch table, splits that table
% into train/validation subsets, trains a transfer-learning classifier, then
% saves a versioned classifier package and CSV audit tables.
%
% Outputs
% -------
% pkg : classifier package struct
% out : struct with saved file paths and useful metadata

    arguments
        project (1,1) desmostorm.model.STORMProject
    
        opts.BaseName (1,1) string
        opts.BoxSize (1,1) double {mustBePositive} = 300
    
        opts.PositiveLabel (1,1) string = "object"
        opts.NegativeLabel (1,1) string = "background"
        opts.RequiredLabelSource (1,1) string = "user"
    
        opts.NegPerPos (1,1) double {mustBeNonnegative} = 6
        opts.IoUMax (1,1) double {mustBeGreaterThanOrEqual(opts.IoUMax,0), mustBeLessThanOrEqual(opts.IoUMax,1)} = 0.05
        opts.ValFrac (1,1) double {mustBeGreaterThan(opts.ValFrac,0), mustBeLessThan(opts.ValFrac,1)} = 0.2
    
        opts.SaveDir (1,1) string = desmostorm.Paths.ml
    
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
        "Preparing classifier training...");
    matlabx.utils.files.ensureDir(opts.SaveDir);
    
    % Build current project patch table
    desmostorm.Log.INFO("Building patch table from current project...")
    desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
        "Building patch table from current project...",0.05);
    patchTableProject = desmostorm.ml.buildPatchTableFromProject(project, ...
        BoxSize=opts.BoxSize, ...
        NegPerPos=opts.NegPerPos, ...
        IoUMax=opts.IoUMax, ...
        PositiveLabel=opts.PositiveLabel, ...
        NegativeLabel=opts.NegativeLabel, ...
        RequiredLabelSource=opts.RequiredLabelSource);
    
    % For fresh training, project table == training table
    patchTableTraining = patchTableProject;
    desmostorm.Log.INFO(sprintf( ...
        "Patch table built: %d patch(es) from current project.", ...
        height(patchTableProject)));
    
    desmostorm.Log.INFO("Splitting patch table into training and validation sets...")
    desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
        "Splitting patches into training and validation sets...",0.15);
    [Ptrain, Pval] = desmostorm.ml.splitByImage(patchTableTraining, opts.ValFrac);
    desmostorm.Log.INFO(sprintf( ...
        "Patch split complete: %d training patch(es), %d validation patch(es).", ...
        height(Ptrain),height(Pval)));
    
    % Training options
    trainOpts = struct;
    trainOpts.BaseNet = "resnet18";
    trainOpts.ContinueTraining = false;
    trainOpts.MaxEpochs = opts.MaxEpochs;
    trainOpts.MiniBatchSize = opts.MiniBatchSize;
    trainOpts.InitialLearnRate = opts.InitialLearnRate;
    trainOpts.ExecutionEnvironment = opts.ExecutionEnvironment;
    trainOpts.Augment = opts.Augment;
    trainOpts.ValidationFrequency = opts.ValidationFrequency;
    
    % Train the classifier
    desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
        "Training classifier network...");
    net = desmostorm.ml.trainPatchClassifier(Ptrain, Pval, opts.BoxSize, ...
        "BaseNet", trainOpts.BaseNet, ...
        "ContinueTraining", trainOpts.ContinueTraining, ...
        "MaxEpochs", trainOpts.MaxEpochs, ...
        "MiniBatchSize", trainOpts.MiniBatchSize, ...
        "InitialLearnRate", trainOpts.InitialLearnRate, ...
        "ExecutionEnvironment", trainOpts.ExecutionEnvironment, ...
        "Augment", trainOpts.Augment, ...
        "ValidationFrequency", trainOpts.ValidationFrequency, ...
        "ProgressDialog", opts.ProgressDialog);
    
    % Proposal options
    propOpts = struct;
    propOpts.BoxSize = opts.BoxSize;
    propOpts.Stride = 96;
    propOpts.ScoreThreshold = 0.6;
    propOpts.NmsIoU = 0.2;
    propOpts.BatchSize = 64;
    propOpts.PositiveClass = opts.PositiveLabel;
    propOpts.CandidateMode = "grid";
    
    % Determine version number for this iteration
    desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
        "Preparing classifier package filenames...");
    [nextVersion, stem] = desmostorm.ml.nextClassifierVersion(opts.SaveDir, opts.BaseName);

    % Build filenames before packaging so the materialized patch folder can sit
    % next to the classifier MAT-file using the same versioned stem.
    classifierFile = fullfile(opts.SaveDir, sprintf("classifier_%s_v%03d.mat", stem, nextVersion));
    projectPatchFile = fullfile(opts.SaveDir, sprintf("patchTable_%s_v%03d_project.csv", stem, nextVersion));
    trainingPatchFile = fullfile(opts.SaveDir, sprintf("patchTable_%s_v%03d_training.csv", stem, nextVersion));
    patchDir = fullfile(opts.SaveDir, sprintf("classifier_%s_v%03d_patches", stem, nextVersion));
    manifestFile = fullfile(patchDir,"patch_manifest.csv");

    % Materialize the exact training table used for this classifier version.
    % Future continued-training runs can then read these patches even if the
    % original source images are moved.
    desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
        "Materializing classifier training patches...");
    [patchTableTraining,patchStore] = desmostorm.ml.materializePatchTable( ...
        patchTableTraining,patchDir,opts.BoxSize, ...
        "ManifestFile",manifestFile, ...
        "ProgressDialog",opts.ProgressDialog);
    
    % Package everything for saving
    desmostorm.Log.INFO("Packaging classifier and saving files...")
    desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
        "Packaging classifier and saving files...");
    pkg = desmostorm.ml.makeClassifierPackage( ...
        net, opts.BoxSize, trainOpts, propOpts, patchTableTraining, ...
        PositiveClass=opts.PositiveLabel, ...
        SourceModel="", ...
        Notes=opts.Notes, ...
        PatchStore=patchStore);
    
    % Save files
    desmostorm.ml.saveClassifierPackage(classifierFile, pkg);
    desmostorm.Log.INFO(sprintf("Saved classifier package: %s",classifierFile))
    writetable(patchTableProject, projectPatchFile);
    desmostorm.Log.INFO(sprintf("Saved project patch table: %s",projectPatchFile))
    writetable(patchTableTraining, trainingPatchFile);
    desmostorm.Log.INFO(sprintf("Saved training patch table: %s",trainingPatchFile))
    desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
        "Classifier training complete.",1);
    
    % Collect struct output
    out = struct();
    out.ClassifierFile = string(classifierFile);
    out.ProjectPatchFile = string(projectPatchFile);
    out.TrainingPatchFile = string(trainingPatchFile);
    out.SaveDir = string(opts.SaveDir);
    out.Version = nextVersion;
    out.BaseName = stem;
    out.NumProjectPatches = height(patchTableProject);
    out.NumTrainingPatches = height(patchTableTraining);
end
