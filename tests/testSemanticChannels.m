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

function tests = testSemanticChannels
%TESTSEMANTICCHANNELS Verify source-order mappings and project migration.
tests = functiontests(localfunctions);
end

function testMappedChannelsRoundTrip(testCase)
%TESTMAPPEDCHANNELSROUNDTRIP Verify mapped channels round trip.
[project,images,folder] = makeProject(testCase);
project.importImages(images,{["DSG2","DP"],["DP","DSG2"],"DP"}, ...
    {["green","magenta"],["magenta","green"],"magenta"});

ids = string({project.Channels.ID});
verifyEqual(testCase,images(1).ChannelIDs,ids);
verifyEqual(testCase,images(2).ChannelIDs,fliplr(ids));
verifyEqual(testCase,images(3).ChannelIDs,ids(2));
verifyEqual(testCase,images(2).sourceChannelIndex(ids(1)),2);
verifyEmpty(testCase,images(3).sourceChannelIndex(ids(1)));

project.editChannels(["Desmoglein","DP"],["cyan","magenta"]);
verifyEqual(testCase,images(2).channelName(2),"Desmoglein");
verifyEqual(testCase,project.getChannelColorName(ids(1)),"cyan");
images(2).setDisplayRange([10,100],2);

file = fullfile(folder,"semantic.mat");
project.save(file,desmostorm.config.Settings());
loaded = desmostorm.model.STORMProject.load(file);
testCase.addTeardown(@() delete(loaded));

verifyEqual(testCase,loaded.Channels,project.Channels);
verifyEqual(testCase,loaded.ImageArray(2).ChannelIDs,fliplr(ids));
verifyEqual(testCase,loaded.ImageArray(2).getDisplayRange(2),[10,100]);
verifyEmpty(testCase,loaded.ImageArray(3).sourceChannelIndex(ids(1)));
end

function testLegacyChannelsUseOriginalIndices(testCase)
%TESTLEGACYCHANNELSUSEORIGINALINDICES Verify legacy channels use original indices.
[project,images,folder] = makeProject(testCase);
project.importImages(images,{["A","B"],["A","B"],"A"}, ...
    {["green","magenta"],["green","magenta"],"green"});
file = fullfile(folder,"legacy.mat");
project.save(file,desmostorm.config.Settings());

saved = load(file,"Project");
Project = saved.Project;
Project.Project = rmfield(Project.Project,"Channels");
Project.Project.Version = "1.1.1";
Project.Project.ChannelDisplay = struct( ...
    'ColorNames',["green","magenta"], ...
    'ColormapNames',["gray","turbo"], ...
    'ColormapCategories',["MATLAB","MATLAB"]);
Project.Images = rmfield(Project.Images,["ChannelIDs","DisplayRanges"]);
save(file,"Project");

loaded = desmostorm.model.STORMProject.load(file);
testCase.addTeardown(@() delete(loaded));
verifyEqual(testCase,string({loaded.Channels.Name}),["Channel 1","Channel 2"]);
verifyEqual(testCase,string({loaded.Channels.Color}),["green","magenta"]);
verifyEqual(testCase,string({loaded.Channels.ColormapName}),["gray","turbo"]);
verifyEqual(testCase,loaded.ImageArray(2).sourceChannelIndex(2),2);
verifyEmpty(testCase,loaded.ImageArray(3).sourceChannelIndex(2));
end

function testDisplayPoliciesFollowSemanticChannel(testCase)
%TESTDISPLAYPOLICIESFOLLOWSEMANTICCHANNEL Verify display policies follow semantic channel.
[project,images,folder] = makeProject(testCase);
project.importImages(images,{["DSG2","DP"],["DP","DSG2"],"DP"}, ...
    {["green","magenta"],["magenta","green"],"magenta"});
id = project.Channels(1).ID;

settings = desmostorm.config.Settings();
legacy = settings.toStruct();
legacy.SettingsSchemaVersion = "1.1.0";
legacy.Display = rmfield(legacy.Display,["DefaultKeepAuto","ChannelPolicies"]);
legacy.Display.AutoScaleDisplayIntensity = false;
settings.fromStruct(legacy);
policy = settings.Display.channelPolicy(id);
verifyFalse(testCase,policy.KeepAuto);
verifyFalse(testCase,policy.Lock);

policy.Lock = true;
policy.LockedRange = [10 100];
policy.Method = "Strong contrast";
settings.Display.setChannelPolicy(policy);

file = fullfile(folder,"settings.json");
settings.save(file);
restored = desmostorm.config.Settings.load(file);
restoredPolicy = restored.Display.channelPolicy(id);
verifyTrue(testCase,restoredPolicy.Lock);
verifyEqual(testCase,string(restoredPolicy.Method),"Strong contrast");

verifyEqual(testCase,images(1).displayLimits(1,restoredPolicy),[10 100]);
verifyEqual(testCase,images(2).displayLimits(2,restoredPolicy),[10 100]);
restoredPolicy.Lock = false;
verifyEqual(testCase,images(2).displayLimits(2,restoredPolicy),[0 255]);
verifyTrue(testCase,settings.Display.channelPolicy(project.Channels(1).ID).Lock);
verifyFalse(testCase,settings.Display.channelPolicy(project.Channels(2).ID).Lock);
end

function testNavigationSelectionsAndLabelReplacement(testCase)
%TESTNAVIGATIONSELECTIONSANDLABELREPLACEMENT Verify navigation selections and label replacement.
[project,images,folder] = makeProject(testCase);
project.importImages(images,{["A","B"],["A","B"],"A"}, ...
    {["green","magenta"],["green","magenta"],"green"});
images(1).addRegion("r1",[8 8],4,"object");
images(1).addRegion("r2",[10 10],4,"background");
images(1).setActiveRegion("r1");
images(1).setRegionSelection("r2");
project.setImageSelection([images(2).ID;"missing"]);
verifyEqual(testCase,project.ActiveImage.ID,images(1).ID);
verifyEqual(testCase,project.SelectedImageIDs,images(2).ID);
verifyEqual(testCase,images(1).ActiveRegion.ID,"r1");

% Project registry for region labels.
bank = project.LabelBank;
bank.setSelection("object");
snapshot = bank.toStruct();
labels = snapshot.Labels;
labels(2).ID = "renamed";
project.replaceLabels(labels,SourceIDs="object",TargetIDs="renamed");
verifyEqual(testCase,images(1).getRegion("r1").LabelID,"renamed");
verifyEqual(testCase,project.LabelBank.SelectedLabelIDs,"renamed");
project.replaceLabels(labels(1:2));
verifyEqual(testCase,images(1).getRegion("r2").LabelID,"unlabeled");
verifyEqual(testCase,project.LabelBank.getByID("unlabeled").Color,[1 1 1]);

file = fullfile(folder,"navigation.mat");
project.save(file,desmostorm.config.Settings());
loaded = desmostorm.model.STORMProject.load(file);
testCase.addTeardown(@() delete(loaded));
verifyEqual(testCase,loaded.SelectedImageIDs,images(2).ID);
verifyEqual(testCase,loaded.ActiveImage.ActiveRegion.ID,"r1");
verifyEqual(testCase,loaded.ActiveImage.SelectedRegionIDs,"r2");
loaded.removeImage(images(2).ID);
verifyEmpty(testCase,loaded.SelectedImageIDs);
end

function [project,images,folder] = makeProject(testCase)
%MAKEPROJECT Create project.
testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
    desmostorm.Paths.external("matlabx")));
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture());
folder = string(fixture.Folder);
project = desmostorm.model.STORMProject("channels");
testCase.addTeardown(@() delete(project));

names = {["DSG2","DP"],["DP","DSG2"],"DP"};
images = desmostorm.model.STORMImage.empty();
pixels = reshape(uint16(0:255),16,16);
% Process names in order.
for k = 1:numel(names)
    file = fullfile(folder,"image" + k + ".ome.tiff");
    data = repmat({pixels},1,numel(names{k}));
    input = matlabx.image.Image5D.fromComponents(data,Names=names{k});
    matlabx.image.io.writeOmeTiff(file,input);
    images(k) = desmostorm.model.STORMImage(project,"Image " + k,file, ...
        matlabx.utils.text.uniqueID());
end
end
