function setupSearchPath()
%SETUPSEARCHPATH  Adds required folders to MATLAB search path

% add project root to MATLAB search path
addpath(desmostorm.Paths.root());

% add external libraries to MATLAB search path
% matlabx
addpath(desmostorm.Paths.external('matlabx'));

% save path
savepath();

end