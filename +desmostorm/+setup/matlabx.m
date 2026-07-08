function matlabx()
%MATLABX  Sets up matlabx for use by desmostorm

disp('Setting up matlabx...');

% add matlabx to search path
addpath(desmostorm.Paths.external('matlabx'));
savepath();

% run matlabx setup
matlabx.setup.run();

end