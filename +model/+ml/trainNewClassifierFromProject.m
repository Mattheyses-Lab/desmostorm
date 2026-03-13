function [pkg, out] = trainNewClassifierFromProject(project, opts)
%trainNewClassifierFromProject Build patch table from current project, train
% a fresh classifier from pretrained backbone, and save package + patch tables.
%
% Outputs
% -------
% pkg : classifier package struct
% out : struct with saved file paths and useful metadata

    arguments
        project (1,1) model.STORMProject
    
        opts.BaseName (1,1) string
        opts.BoxSize (1,1) double {mustBePositive} = 300
    
        opts.PositiveLabel (1,1) string = "object"
        opts.NegativeLabel (1,1) string = "background"
        opts.RequiredLabelSource (1,1) string = "user"
    
        opts.NegPerPos (1,1) double {mustBeNonnegative} = 6
        opts.IoUMax (1,1) double {mustBeGreaterThanOrEqual(opts.IoUMax,0), mustBeLessThanOrEqual(opts.IoUMax,1)} = 0.05
        opts.ValFrac (1,1) double {mustBeGreaterThan(opts.ValFrac,0), mustBeLessThan(opts.ValFrac,1)} = 0.2
    
        opts.SaveDir (1,1) string = app.Paths.ml
    
        opts.MaxEpochs (1,1) double {mustBePositive} = 15
        opts.MiniBatchSize (1,1) double {mustBePositive} = 8
        opts.InitialLearnRate (1,1) double {mustBePositive} = 3e-4
        opts.ExecutionEnvironment (1,1) string = "cpu"
        opts.Augment (1,1) logical = true
        opts.ValidationFrequency (1,1) double {mustBePositive} = 50
    
        opts.Notes (1,1) string = ""
    end
    
    matlabx.utils.files.ensureDir(opts.SaveDir);
    
    % Build current project patch table
    patchTableProject = model.ml.buildPatchTableFromProject(project, ...
        BoxSize=opts.BoxSize, ...
        NegPerPos=opts.NegPerPos, ...
        IoUMax=opts.IoUMax, ...
        PositiveLabel=opts.PositiveLabel, ...
        NegativeLabel=opts.NegativeLabel, ...
        RequiredLabelSource=opts.RequiredLabelSource);
    
    % For fresh training, project table == training table
    patchTableTraining = patchTableProject;
    
    [Ptrain, Pval] = model.ml.splitByImage(patchTableTraining, opts.ValFrac);
    
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
    net = model.ml.trainPatchClassifier(Ptrain, Pval, opts.BoxSize, ...
        "BaseNet", trainOpts.BaseNet, ...
        "ContinueTraining", trainOpts.ContinueTraining, ...
        "MaxEpochs", trainOpts.MaxEpochs, ...
        "MiniBatchSize", trainOpts.MiniBatchSize, ...
        "InitialLearnRate", trainOpts.InitialLearnRate, ...
        "ExecutionEnvironment", trainOpts.ExecutionEnvironment, ...
        "Augment", trainOpts.Augment, ...
        "ValidationFrequency", trainOpts.ValidationFrequency);
    
    % Proposal options
    propOpts = struct;
    propOpts.BoxSize = opts.BoxSize;
    propOpts.Stride = 96;
    propOpts.ScoreThreshold = 0.6;
    propOpts.NmsIoU = 0.2;
    propOpts.BatchSize = 64;
    propOpts.PositiveClass = opts.PositiveLabel;
    
    % Determine version number for this iteration
    [nextVersion, stem] = model.ml.nextClassifierVersion(opts.SaveDir, opts.BaseName);
    
    % Package everything for saving
    pkg = model.ml.makeClassifierPackage( ...
        net, opts.BoxSize, trainOpts, propOpts, patchTableTraining, ...
        PositiveClass=opts.PositiveLabel, ...
        SourceModel="", ...
        Notes=opts.Notes);
    
    % Build filenames
    classifierFile = fullfile(opts.SaveDir, sprintf("classifier_%s_v%03d.mat", stem, nextVersion));
    projectPatchFile = fullfile(opts.SaveDir, sprintf("patchTable_%s_v%03d_project.csv", stem, nextVersion));
    trainingPatchFile = fullfile(opts.SaveDir, sprintf("patchTable_%s_v%03d_training.csv", stem, nextVersion));
    
    % Save files
    model.ml.saveClassifierPackage(classifierFile, pkg);
    writetable(patchTableProject, projectPatchFile);
    writetable(patchTableTraining, trainingPatchFile);
    
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