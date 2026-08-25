function [pkgNew, out] = continueClassifierTrainingFromProject(project, classifierFile, opts)
%CONTINUECLASSIFIERTRAININGFROMPROJECT Retrain an existing classifier package.
%
% This orchestration layer preserves the previous classifier package as
% provenance, merges newly reviewed project labels with the older training
% table, continues training from the saved network, and writes a new versioned
% classifier package next to the source package by default.
%
% Workflow:
%   - load existing package
%   - build project patch table from current project
%   - merge old training table with current project table (new wins)
%   - continue training from old net
%   - auto-save next version in same folder (default)

    arguments
        project (1,1) desmostorm.model.STORMProject
        classifierFile (1,1) string
    
        opts.PositiveLabel (1,1) string = "object"
        opts.NegativeLabel (1,1) string = "background"
        opts.RequiredLabelSource (1,1) string = "user"
    
        opts.NegPerPos (1,1) double {mustBeNonnegative} = 6
        opts.IoUMax (1,1) double {mustBeGreaterThanOrEqual(opts.IoUMax,0), mustBeLessThanOrEqual(opts.IoUMax,1)} = 0.05
        opts.ValFrac (1,1) double {mustBeGreaterThan(opts.ValFrac,0), mustBeLessThan(opts.ValFrac,1)} = 0.2
    
        opts.SaveDir (1,1) string = ""
        opts.MaxEpochs (1,1) double {mustBePositive} = 5
        opts.MiniBatchSize (1,1) double {mustBePositive} = 8
        opts.InitialLearnRate (1,1) double {mustBePositive} = 1e-4
        opts.ExecutionEnvironment (1,1) string = "cpu"
        opts.Augment (1,1) logical = true
        opts.ValidationFrequency (1,1) double {mustBePositive} = 50
    
        opts.Notes (1,1) string = ""
        opts.ProgressDialog = []
    end
    
    desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
        "Loading classifier package...");
    desmostorm.Log.INFO(sprintf("Loading classifier package: %s",classifierFile))
    pkgOld = desmostorm.ml.loadClassifierPackage(classifierFile);
    
    if opts.SaveDir == ""
        saveDir = string(fileparts(classifierFile));
    else
        saveDir = opts.SaveDir;
    end
    matlabx.utils.files.ensureDir(saveDir);
    
    baseName = desmostorm.ml.classifierBaseNameFromFile(classifierFile);
    
    % Build project patch table from current project
    desmostorm.Log.INFO("Building patch table from current project...")
    desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
        "Building patch table from current project...",0.05);
    patchTableProject = desmostorm.ml.buildPatchTableFromProject(project, ...
        BoxSize=pkgOld.BoxSize, ...
        NegPerPos=opts.NegPerPos, ...
        IoUMax=opts.IoUMax, ...
        PositiveLabel=opts.PositiveLabel, ...
        NegativeLabel=opts.NegativeLabel, ...
        RequiredLabelSource=opts.RequiredLabelSource);
    
    % Merge old training table with new project table
    desmostorm.Log.INFO("Merging patch table with existing training data...")
    desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
        "Merging project labels with existing training data...",0.12);
    patchTableTraining = desmostorm.ml.mergePatchTables(pkgOld.PatchTable, patchTableProject);
    desmostorm.Log.INFO(sprintf( ...
        "Merged patch table: %d project patch(es), %d total training patch(es).", ...
        height(patchTableProject),height(patchTableTraining)));
    
    desmostorm.Log.INFO("Splitting patch table into training and validation sets...")
    desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
        "Splitting patches into training and validation sets...",0.18);
    [Ptrain, Pval] = desmostorm.ml.splitByImage(patchTableTraining, opts.ValFrac);
    desmostorm.Log.INFO(sprintf( ...
        "Patch split complete: %d training patch(es), %d validation patch(es).", ...
        height(Ptrain),height(Pval)));
    
    trainOpts = pkgOld.TrainOpts;
    trainOpts.BaseNet = pkgOld.Net;
    trainOpts.ContinueTraining = true;
    trainOpts.MaxEpochs = opts.MaxEpochs;
    trainOpts.MiniBatchSize = opts.MiniBatchSize;
    trainOpts.InitialLearnRate = opts.InitialLearnRate;
    trainOpts.ExecutionEnvironment = opts.ExecutionEnvironment;
    trainOpts.Augment = opts.Augment;
    trainOpts.ValidationFrequency = opts.ValidationFrequency;
    
    % netNew = desmostorm.ml.trainPatchClassifier(Ptrain, Pval, pkgOld.BoxSize, trainOpts);

    desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
        "Continuing classifier network training...");
    netNew = desmostorm.ml.trainPatchClassifier(Ptrain, Pval, pkgOld.BoxSize, ...
        "BaseNet",trainOpts.BaseNet,...
        "ContinueTraining",trainOpts.ContinueTraining,...
        "MaxEpochs",trainOpts.MaxEpochs,...
        "MiniBatchSize",trainOpts.MiniBatchSize,...
        "InitialLearnRate",trainOpts.InitialLearnRate,...
        "ExecutionEnvironment",trainOpts.ExecutionEnvironment,...
        "Augment",trainOpts.Augment,...
        "ValidationFrequency",trainOpts.ValidationFrequency, ...
        "ProgressDialog",opts.ProgressDialog);
    
    propOpts = pkgOld.PropOpts;
    propOpts.PositiveClass = opts.PositiveLabel;
    if ~isfield(propOpts,"CandidateMode")
        propOpts.CandidateMode = "grid";
    elseif string(propOpts.CandidateMode) == "cluster"
        propOpts.CandidateMode = "ClusterCentroid";
    end
    
    [nextVersion, stem] = desmostorm.ml.nextClassifierVersion(saveDir, baseName);

    classifierOut = fullfile(saveDir, sprintf("classifier_%s_v%03d.mat", stem, nextVersion));
    projectPatchOut = fullfile(saveDir, sprintf("patchTable_%s_v%03d_project.csv", stem, nextVersion));
    trainingPatchOut = fullfile(saveDir, sprintf("patchTable_%s_v%03d_training.csv", stem, nextVersion));
    patchDir = fullfile(saveDir, sprintf("classifier_%s_v%03d_patches", stem, nextVersion));
    manifestFile = fullfile(patchDir,"patch_manifest.csv");

    % Save/copy the exact merged training table as cropped patch files for this
    % new package version. Rows inherited from an older materialized package can
    % be copied from their patchFilename; newly reviewed rows are cropped from
    % the current project images.
    desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
        "Materializing classifier training patches...");
    [patchTableTraining,patchStore] = desmostorm.ml.materializePatchTable( ...
        patchTableTraining,patchDir,pkgOld.BoxSize, ...
        "ManifestFile",manifestFile, ...
        "ProgressDialog",opts.ProgressDialog);
    
    desmostorm.Log.INFO("Packaging classifier and saving files...")
    desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
        "Packaging classifier and saving files...");
    pkgNew = desmostorm.ml.makeClassifierPackage( ...
        netNew, pkgOld.BoxSize, trainOpts, propOpts, patchTableTraining, ...
        PositiveClass=opts.PositiveLabel, ...
        SourceModel=string(classifierFile), ...
        Notes=opts.Notes, ...
        PatchStore=patchStore);
    
    desmostorm.ml.saveClassifierPackage(classifierOut, pkgNew);
    desmostorm.Log.INFO(sprintf("Saved classifier package: %s",classifierOut))
    writetable(patchTableProject, projectPatchOut);
    desmostorm.Log.INFO(sprintf("Saved project patch table: %s",projectPatchOut))
    writetable(patchTableTraining, trainingPatchOut);
    desmostorm.Log.INFO(sprintf("Saved training patch table: %s",trainingPatchOut))
    desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
        "Classifier retraining complete.",1);
    
    out = struct();
    out.ClassifierFile = string(classifierOut);
    out.ProjectPatchFile = string(projectPatchOut);
    out.TrainingPatchFile = string(trainingPatchOut);
    out.SaveDir = string(saveDir);
    out.Version = nextVersion;
    out.BaseName = stem;
    out.SourceClassifierFile = string(classifierFile);
    out.NumProjectPatches = height(patchTableProject);
    out.NumTrainingPatches = height(patchTableTraining);
end
