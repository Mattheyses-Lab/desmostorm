function pkg = makeClassifierPackage(net, boxSize, trainOpts, propOpts, patchTable, opts)
%makeClassifierPackage Create classifier package struct for saving/loading.

    arguments
        net
        boxSize (1,1) double
        trainOpts
        propOpts
        patchTable table
    
        opts.PositiveClass (1,1) string = "object"
        opts.SourceModel (1,1) string = ""
        opts.Notes (1,1) string = ""
        opts.Version (1,1) string = "1.0"
    end
    
    pkg = struct();
    pkg.Version = opts.Version;
    pkg.Net = net;
    pkg.BoxSize = boxSize;
    pkg.TrainOpts = trainOpts;
    pkg.PropOpts = propOpts;
    pkg.PatchTable = patchTable;
    pkg.PositiveClass = opts.PositiveClass;
    pkg.Created = datetime("now");
    pkg.SourceModel = opts.SourceModel;
    pkg.Notes = opts.Notes;

end