function setupSearchPath()
%SETUPSEARCHPATH  Adds required folders to MATLAB search path

% add project root to MATLAB search path
addpath(desmostorm.app.Paths.root());

% add external libraries to MATLAB search path
addpath(genpath(desmostorm.app.Paths.external()));
savepath();

end