% DesmoSTORM - MATLAB app for desmosomal plaque protein analysis.
% Copyright (C) 2026 William Dean
%
% This program is free software; you can redistribute it and/or modify it
% under the terms of the GNU General Public License as published by the Free
% Software Foundation; either version 2 of the License, or (at your option)
% any later version.
%
% This program is distributed in the hope that it will be useful, but WITHOUT
% ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
% FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
% details.
%
% You should have received a copy of the GNU General Public License along
% with this program; if not, see <https://www.gnu.org/licenses/>.

function pkg = makeClassifierPackage(net, boxSize, trainOpts, propOpts, patchTable, opts)
%MAKECLASSIFIERPACKAGE Assemble a versioned classifier package struct.
%
% The package intentionally keeps the trained network, training settings,
% proposal settings, and patch table together. That makes each saved .mat file
% a portable unit that can be applied by downstream users and audited later.

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
        opts.PatchStore struct = struct()
    end
    
    % Keep top-level fields simple; packages are saved as a single struct so
    % future schema migration can happen in loadClassifierPackage if needed.
    pkg = struct();
    pkg.Version = opts.Version;
    pkg.Net = net;
    pkg.BoxSize = boxSize;
    pkg.TrainOpts = trainOpts;
    pkg.PropOpts = propOpts;
    pkg.PatchTable = patchTable;
    pkg.PatchStore = opts.PatchStore;
    pkg.PositiveClass = opts.PositiveClass;
    pkg.Created = datetime("now");
    pkg.SourceModel = opts.SourceModel;
    pkg.Notes = opts.Notes;

end
