function setupSearchPath()
%SETUPSEARCHPATH Adds necessary folder to MATLAB search path

% add project root to MATLAB search path
addpath(app.Paths.root());

% add external libraries to MATLAB search path
addpath(genpath(app.Paths.external()));
savepath();

end