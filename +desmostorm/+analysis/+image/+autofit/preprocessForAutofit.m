function [Iout,info] = preprocessForAutofit(I,debugOutput)
%PREPROCESSFORAUTOFIT Return the image used by angle/extent fitting.
%
% This helper is intentionally small so alternative cleanup approaches
% (foreground masks, morphology, cluster-guided filtering) can be swapped in
% without disturbing the fitting code.

arguments
    I
    debugOutput (1,1) logical = false
end

info = struct("Methods",["removeIsolatedPuncta","removeEdgeClusters"]);

Iout = desmostorm.analysis.image.removeIsolatedPuncta(I, ...
    "DebugOutput",debugOutput);

Iout = desmostorm.analysis.image.removeEdgeClusters(Iout, ...
    "DebugOutput",debugOutput);
end
