function net = trainPatchClassifier(Ptrain, Pval, boxSize, opts)
%TRAINPATCHCLASSIFIER Train or continue training a binary patch classifier.
%
% Fresh training:
%   net = desmostorm.ml.trainPatchClassifier(Ptrain, Pval, 300, ...
%       BaseNet="resnet18", ContinueTraining=false)
%
% Continue training:
%   net = desmostorm.ml.trainPatchClassifier(Ptrain, Pval, 300, ...
%       BaseNet=oldNet, ContinueTraining=true)
%
% Notes
% -----
% - Patches are cropped at boxSize in image space, then resized to the
%   network input size inside patchDatastore.
% - Fresh training starts from a pretrained backbone and replaces the head.
% - Continued training starts from an existing trained net and keeps its head.

    arguments
        Ptrain table
        Pval table
        boxSize (1,1) double {mustBePositive} = 300
    
        opts.BaseNet = "resnet18"
        opts.ContinueTraining (1,1) logical = false
    
        opts.MaxEpochs (1,1) double {mustBePositive} = 15
        opts.MiniBatchSize (1,1) double {mustBePositive} = 8
        opts.InitialLearnRate (1,1) double {mustBePositive} = 3e-4
        opts.ExecutionEnvironment (1,1) string = "cpu"
        opts.Augment (1,1) logical = true
        opts.ValidationFrequency (1,1) double {mustBePositive} = 50
        opts.ProgressDialog = []
    end
    
    % ---- Basic checks ----
    if isempty(Ptrain)
        error("trainPatchClassifier:EmptyTrain", "Ptrain is empty.");
    end
    if isempty(Pval)
        error("trainPatchClassifier:EmptyVal", "Pval is empty.");
    end
    if ~ismember("label", Ptrain.Properties.VariableNames) || ~ismember("label", Pval.Properties.VariableNames)
        error("trainPatchClassifier:MissingLabel", "Patch tables must contain a 'label' column.");
    end
    
    if ~iscategorical(Ptrain.label), Ptrain.label = categorical(Ptrain.label); end
    if ~iscategorical(Pval.label),   Pval.label   = categorical(Pval.label);   end
    
    % Keep categories aligned
    allCats = union(categories(Ptrain.label), categories(Pval.label));
    Ptrain.label = categorical(string(Ptrain.label), allCats);
    Pval.label   = categorical(string(Pval.label),   allCats);
    
    if numel(allCats) ~= 2
        error("trainPatchClassifier:BadClasses", ...
            "Expected exactly 2 classes, found %d.", numel(allCats));
    end
    
    % ---- Choose starting network ----
    desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
        "Preparing classifier network architecture...");
    if opts.ContinueTraining
        if ~(isa(opts.BaseNet, "SeriesNetwork") || isa(opts.BaseNet, "DAGNetwork"))
            error("trainPatchClassifier:BadBaseNet", ...
                "For continued training, opts.BaseNet must be a trained SeriesNetwork or DAGNetwork.");
        end
    
        lgraph = layerGraph(opts.BaseNet);
        doReplaceHead = false;

        % force class order to match that of the loaded network
        netClasses = string(lgraph.Layers(end).Classes);
        Ptrain.label = categorical(string(Ptrain.label), netClasses);
        Pval.label   = categorical(string(Pval.label),   netClasses);
        
        if any(isundefined(Ptrain.label))
            error("trainPatchClassifier:BadTrainLabels", ...
                "Ptrain contains labels not present in the existing network classes.");
        end
        
        if any(isundefined(Pval.label))
            error("trainPatchClassifier:BadValLabels", ...
                "Pval contains labels not present in the existing network classes.");
        end
    
    else
        if ~(isstring(opts.BaseNet) || ischar(opts.BaseNet))
            error("trainPatchClassifier:BadBaseNet", ...
                "For fresh training, opts.BaseNet must be a string like ""resnet18"".");
        end
    
        baseName = lower(string(opts.BaseNet));
        switch baseName
            case "resnet18"
                lgraph = layerGraph(resnet18);
            otherwise
                error("trainPatchClassifier:UnsupportedBackbone", ...
                    "Unsupported backbone: %s", baseName);
        end
    
        doReplaceHead = true;
    end
    
    % ---- Input size ----
    inputLayer = lgraph.Layers(1);
    if ~isprop(inputLayer, "InputSize")
        error("trainPatchClassifier:BadInputLayer", "Could not determine network input size.");
    end
    netInputSize = inputLayer.InputSize(1:2);
    
    % ---- Datastores ----
    desmostorm.Log.INFO("Building training datastore...")
    desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
        "Building training datastore...");
    dsTrain = desmostorm.ml.patchDatastore(Ptrain, boxSize, netInputSize);
    desmostorm.Log.INFO("Building validation datastore...")
    desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
        "Building validation datastore...");
    dsVal   = desmostorm.ml.patchDatastore(Pval,   boxSize, netInputSize);
    
    desmostorm.Log.INFO("Building augmentation datastore...")
    if opts.Augment
        dsTrain = transform(dsTrain, @desmostorm.ml.augmentPatch);
    end
    
    % ---- Validation sanity check ----
    desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
        "Checking validation datastore...");
    try
        v = read(dsVal);
        Xv = v{1};
        Yv = v{2};
    
        assert(isnumeric(Xv) && isa(Xv,'single') && ndims(Xv)==3 && size(Xv,3)==3, ...
            "Validation X must be HxWx3 single.");
        assert(isequal(size(Xv,1), netInputSize(1)) && isequal(size(Xv,2), netInputSize(2)), ...
            "Validation X size mismatch.");
        assert(iscategorical(Yv) && isscalar(Yv), ...
            "Validation Y must be a categorical scalar.");
    catch ME
        error("trainPatchClassifier:BadValidationDatastore", ...
            "Validation datastore is invalid: %s", ME.message);
    end
    reset(dsVal);
    
    % ---- Replace head for fresh training only ----
    if doReplaceHead
        numClasses = 2;
    
        [learnableLayer, classLayer] = findLayersToReplaceLocal(lgraph);
    
        newFC      = fullyConnectedLayer(numClasses, ...
            Name="fc_new", ...
            WeightLearnRateFactor=10, ...
            BiasLearnRateFactor=10);
    
        newSoftmax = softmaxLayer(Name="softmax");
        newClass   = classificationLayer(Name="classoutput");
    
        % Replace final learnable layer
        lgraph = replaceLayer(lgraph, learnableLayer.Name, newFC);
    
        % Find what feeds into the classification layer
        conn = lgraph.Connections;
        srcToClass = conn.Source(strcmp(conn.Destination, classLayer.Name));
    
        if isempty(srcToClass)
            error("trainPatchClassifier:BadGraph", ...
                "Could not find source feeding into classification layer '%s'.", classLayer.Name);
        end
    
        srcName = string(srcToClass(end));
        srcLayer = lgraph.Layers(strcmp({lgraph.Layers.Name}, srcName));
    
        if ~isempty(srcLayer) && isa(srcLayer, "nnet.cnn.layer.SoftmaxLayer")
            % Replace actual terminal softmax and class layer
            lgraph = replaceLayer(lgraph, srcName, newSoftmax);
            lgraph = replaceLayer(lgraph, classLayer.Name, newClass);
        else
            % No softmax directly before class layer: insert one
            lgraph = removeLayers(lgraph, classLayer.Name);
            lgraph = addLayers(lgraph, [newSoftmax newClass]);
    
            % [newSoftmax newClass] already includes softmax -> classoutput
            lgraph = connectLayers(lgraph, "fc_new", "softmax");
        end
    end
    
    % ---- Freeze strategy ----
    if ~opts.ContinueTraining
        % Fresh transfer learning: freeze most layers, unfreeze tail
        layers = lgraph.Layers;
        connections = lgraph.Connections;
    
        for i = 1:numel(layers)
            if isprop(layers(i),"WeightLearnRateFactor")
                layers(i).WeightLearnRateFactor = 0;
            end
            if isprop(layers(i),"BiasLearnRateFactor")
                layers(i).BiasLearnRateFactor = 0;
            end
        end
    
        k = max(1, numel(layers)-20);
        for i = k:numel(layers)
            if isprop(layers(i),"WeightLearnRateFactor")
                layers(i).WeightLearnRateFactor = 1;
            end
            if isprop(layers(i),"BiasLearnRateFactor")
                layers(i).BiasLearnRateFactor = 1;
            end
        end
    
        lgraph = createLgraphUsingConnectionsLocal(layers, connections);
    else
        % Continued training: leave existing learn-rate factors as-is
        % and rely on a smaller learning rate.
    end
    
    % ---- Training options ----
    options = trainingOptions("adam", ...
        InitialLearnRate=opts.InitialLearnRate, ...
        MaxEpochs=opts.MaxEpochs, ...
        MiniBatchSize=opts.MiniBatchSize, ...
        Shuffle="every-epoch", ...
        ValidationData=dsVal, ...
        ValidationFrequency=opts.ValidationFrequency, ...
        Verbose=true, ...
        Plots="training-progress", ...
        ExecutionEnvironment=opts.ExecutionEnvironment);
    
    desmostorm.Log.INFO(sprintf([ ...
        'Training options: ContinueTraining=%s, BoxSize=%d, MaxEpochs=%d, ' ...
        'MiniBatchSize=%d, InitialLearnRate=%.3g, ExecutionEnvironment=%s, ' ...
        'Augment=%s, ValidationFrequency=%d, TrainPatches=%d, ValPatches=%d, ' ...
        'TrainClasses=%s, ValClasses=%s'], ...
        string(opts.ContinueTraining), ...
        boxSize, ...
        opts.MaxEpochs, ...
        opts.MiniBatchSize, ...
        opts.InitialLearnRate, ...
        opts.ExecutionEnvironment, ...
        string(opts.Augment), ...
        opts.ValidationFrequency, ...
        height(Ptrain), ...
        height(Pval), ...
        strjoin(string(categories(Ptrain.label)), ', '), ...
        strjoin(string(categories(Pval.label)), ', ')));

    % ---- Train ----
    desmostorm.Log.INFO("Training network...")
    desmostorm.ml.updateProgressDialog(opts.ProgressDialog, ...
        "Training network. MATLAB training progress may open separately...");
    net = trainNetwork(dsTrain, lgraph, options);
    desmostorm.Log.INFO("Network training complete.")

end

% =====================================================================
% Local helpers
% =====================================================================

function [learnableLayer, classLayer] = findLayersToReplaceLocal(lgraph)
    layers = lgraph.Layers;
    
    classLayer = [];
    for i = numel(layers):-1:1
        if isa(layers(i), "nnet.cnn.layer.ClassificationOutputLayer")
            classLayer = layers(i);
            break
        end
    end
    if isempty(classLayer)
        error("findLayersToReplaceLocal:NoClassLayer", ...
            "Could not find classification layer.");
    end
    
    conn = lgraph.Connections;
    srcName = conn.Source(strcmp(conn.Destination, classLayer.Name));
    if isempty(srcName)
        srcName = "";
        for i = numel(layers):-1:1
            if isa(layers(i), "nnet.cnn.layer.FullyConnectedLayer")
                srcName = layers(i).Name;
                break
            end
        end
    else
        srcName = srcName(end);
    end
    
    learnableLayer = lgraph.Layers(strcmp({layers.Name}, string(srcName)));
    if isempty(learnableLayer)
        error("findLayersToReplaceLocal:NoLearnableLayer", ...
            "Could not find learnable layer to replace.");
    end
end

function lgraph = createLgraphUsingConnectionsLocal(layers, connections)
    lgraph = layerGraph();
    for i = 1:numel(layers)
        lgraph = addLayers(lgraph, layers(i));
    end
    
    src = connections.Source;
    dst = connections.Destination;
    
    for c = 1:height(connections)
        if iscell(src)
            s = src{c};
            d = dst{c};
        else
            s = src(c);
            d = dst(c);
        end
    
        s = string(s); s = s(1);
        d = string(d); d = d(1);
    
        lgraph = connectLayers(lgraph, s, d);
    end
end
