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

classdef STORMProject < handle & matlab.mixin.CustomDisplay
%STORMProject Stores project metadata, stores and manages images

    %% Identity/metadata
    properties
        ID (1,1) string = matlabx.utils.text.uniqueID()
        Name (1,1) string = "untitled"
        SourcePath (1,1) string = ""
        CreatedAt datetime = datetime('now')
        Version (1,1) string = desmostorm.Info.Version
        isOnDisk (1,1) logical = false
        HasUnsavedChanges (1,1) logical = false
    end

    %% Label bank
    properties
        LabelBank desmostorm.model.LabelRegistry
    end

    %% Images (dictionary + order) and active selection
    properties (Access=private)
        ImagesDict = dictionary   % string ID -> desmostorm.model.STORMImage
        ImageOrder (:,1) string = string.empty(0,1)
        ActiveImageID (1,1) string = ""
    end

    properties (Access=private)
        ImageDataCacheSize (1,1) double {mustBeNonnegative, mustBeInteger} = 2  % active + 1 previous
        RecentImageIDs (:,1) string = string.empty(0,1)
    end

    properties (Dependent)
        ImageNames
        ImageIDs
    end

    properties (SetAccess=private)
        SelectedImageIDs (:,1) string = strings(0,1)
    end

    %% ergonomic array view, public, editor-friendly
    properties (Dependent, GetAccess=public, SetAccess=private)
        ImageArray   % [Nx1 desmostorm.model.STORMImage] in ImageOrder
        ActiveImage (:,1) desmostorm.model.STORMImage
        ActiveRegion (:,1) desmostorm.model.STORMRegion
    end

    %% Project-wide info
    properties
        DefaultPixelSize desmostorm.model.units.PixelSize = desmostorm.model.units.PixelSize(1, 'px');
    end

    properties (SetObservable, AbortSet)
        MaxSizeC (1,1) double = 0
    end

    properties (SetAccess=private)
        % Registry order is independent of each image's source component order.
        Channels struct = struct('ID',{},'Name',{},'Color',{}, ...
            'ColormapName',{},'ColormapCategory',{})
    end

    properties (Access=private)
        DefaultChannelColormapName (1,1) string = "gray"
        DefaultChannelColormapCategory (1,1) string = "MATLAB"
    end

    %% Events and listeners

    % (Project and GUI controller listen)
    events
        ImageAdded
        ImageRemoved
        ActiveImageChanged
        ImageSelectionChanged
        MaxSizeCChanged

        RegionAdded
        RegionRemoved
        ActiveRegionChanged
        RegionSelectionChanged

        LabelsChanged
        ChannelsChanged

        DirtyStateChanged
    end

    properties
        RegionListeners event.listener
        ImageListeners event.listener
        MaxSizeCListener event.listener
        LabelsChangedListener event.listener
    end

    %% Dependent getters 
    methods

        function arr = get.ImageArray(obj)
            if numel(obj.ImageOrder)==0
                arr = desmostorm.model.STORMImage.empty(); return;
            end

            arr = obj.ImagesDict(obj.ImageOrder);   % -> array of STORMImage
        end

        function img = get.ActiveImage(obj)
            img = [];
            if strlength(obj.ActiveImageID)==0, return; end
            if isKey(obj.ImagesDict, obj.ActiveImageID)
                img = obj.ImagesDict(obj.ActiveImageID);
            end
        end

        function reg = get.ActiveRegion(obj)
            reg = [];
            if isempty(obj.ActiveImage), return; end
            reg = obj.ActiveImage.ActiveRegion;
        end

        function names = get.ImageNames(obj)
            arr = obj.ImageArray;
            if isempty(arr)
                names = string.empty(1,0);
            else
                names = arrayfun(@(im) im.Name, arr);
            end
        end

        function IDs = get.ImageIDs(obj)
            arr = obj.ImageArray;
            if isempty(arr)
                IDs = string.empty(1,0);
            else
                IDs = arrayfun(@(im) im.ID, arr);
            end
        end


    end

    %% Constructor
    methods

        function obj = STORMProject(name)
            if nargin >= 1 && ~isempty(name), obj.Name = string(name); end

            % dictionary of string ID -> desmostorm.model.STORMImage
            obj.ImagesDict = dictionary(string.empty(1,0), desmostorm.model.STORMImage.empty(1,0));

            % order of ImagesDict, empty string to start because our dictionary is empty
            obj.ImageOrder = string.empty(1,0);

            % add listeners for image-associated events
            obj.ImageListeners(1) = addlistener(obj,'ImageAdded',@(~,evt) obj.onImageAdded(evt));
            obj.ImageListeners(2) = addlistener(obj,'ImageRemoved',@(~,evt) obj.onImageRemoved(evt));
            obj.ImageListeners(3) = addlistener(obj,'ActiveImageChanged',@(~,evt) obj.onActiveImageChanged(evt));

            obj.MaxSizeCListener = addlistener(obj,'MaxSizeC','PostSet',@(~,~) obj.onMaxSizeCPostSet());

            % label registry, default labels to start
            obj.LabelBank = desmostorm.model.LabelRegistry.default();            

            % forward label-bank mutations through the project
            obj.attachLabelBankListener();
        end

    end

    %% Image management
    methods

        function imageID = addImageFromPath(obj, filePath)
            %ADDIMAGEFROMPATH Add a new STORMImage for the image specified by filePath
            % get file name and extension
            [~,name,ext] = fileparts(filePath);

            desmostorm.Log.INFO(sprintf("Loading image: %s",filePath));

            % create a STORMImage object with new unique ID
            img = desmostorm.model.STORMImage(obj, string(name)+string(ext), string(filePath), matlabx.utils.text.uniqueID());  % NO imread

            names = "Channel " + (1:img.SizeC);
            obj.importImages(img,{names},{strings(size(names))});
            imageID = img.ID;
        end

        function addImagesFromPaths(obj, filePaths)
            for filePath = reshape(string(filePaths),1,[])
                obj.addImageFromPath(filePath);
            end
        end

        function importImages(obj,images,names,colors)
            % Validate the complete mapping before changing the project.
            if isempty(images), return, end
            assert(numel(images) == numel(names) && numel(images) == numel(colors), ...
                'Each imported image needs one channel mapping.');
            assert(numel(unique(string({images.ID}))) == numel(images), ...
                'Each imported image must have a distinct image ID.');
            channels = obj.Channels;
            originalCount = numel(channels);
            assignments = cell(size(images));
            palette = matlabx.image.componentColorNames();
            for i = 1:numel(images)
                names{i} = reshape(strtrim(string(names{i})),1,[]);
                colors{i} = reshape(string(colors{i}),1,[]);
                assert(images(i).Parent == obj && ~isKey(obj.ImagesDict,images(i).ID), ...
                    'Imported images must be new images owned by this project.');
                assert(numel(names{i}) == images(i).SizeC && ...
                    numel(colors{i}) == images(i).SizeC && ...
                    all(~ismissing(names{i}) & strlength(names{i}) > 0) && ...
                    numel(unique(lower(names{i}))) == images(i).SizeC, ...
                    'Each source component needs a distinct channel name.');

                ids = strings(1,images(i).SizeC);
                for c = 1:images(i).SizeC
                    name = names{i}(c);
                    index = find(strcmpi(string({channels.Name}),name),1);
                    color = colors{i}(c);
                    if color ~= ""
                        color = matlabx.image.normalizeComponentColor(color);
                    end
                    if isempty(index)
                        index = numel(channels) + 1;
                        if color == ""
                            color = palette(1 + mod(index-1,numel(palette)));
                        end
                        channels(index) = struct('ID',matlabx.utils.text.uniqueID(), ...
                            'Name',name,'Color',color, ...
                            'ColormapName',obj.DefaultChannelColormapName, ...
                            'ColormapCategory',obj.DefaultChannelColormapCategory);
                    elseif index > originalCount && color ~= "" && color ~= channels(index).Color
                        error('desmostorm:import:ConflictingColor', ...
                            'Choose one color for the new channel "%s".',name);
                    end
                    ids(c) = channels(index).ID;
                end
                assignments{i} = ids;
            end

            changed = ~isequal(channels,obj.Channels);
            obj.Channels = channels;
            for i = 1:numel(images)
                img = images(i);
                img.setChannelIDs(assignments{i});
                obj.ImagesDict(img.ID) = img;
                obj.ImageOrder(end+1) = img.ID;
                notify(obj,'ImageAdded',desmostorm.model.events.ImageAdded(img.ID));
            end
            if changed
                notify(obj,'ChannelsChanged');
            end
            obj.markDirty();
        end

        function editChannels(obj,names,colors)
            names = reshape(strtrim(string(names)),1,[]);
            colors = reshape(string(colors),1,[]);
            assert(numel(names) == numel(obj.Channels) && numel(colors) == numel(names) && ...
                all(~ismissing(names) & strlength(names) > 0) && ...
                numel(unique(lower(names))) == numel(names), ...
                'Channel names must be nonempty and unique.');

            channels = obj.Channels;
            for c = 1:numel(channels)
                channels(c).Name = names(c);
                channels(c).Color = matlabx.image.normalizeComponentColor(colors(c));
            end
            if ~isequal(obj.Channels,channels)
                obj.Channels = channels;
                images = obj.ImageArray;
                for i = 1:numel(images)
                    images(i).syncChannelNames();
                end
                obj.markDirty();
                notify(obj,'ChannelsChanged');
            end
        end

        function index = channelIndex(obj,channel)
            if isnumeric(channel)
                index = channel;
            else
                index = find(string({obj.Channels.ID}) == string(channel),1);
            end
        end

        function name = getChannelName(obj,channel)
            name = obj.Channels(obj.channelIndex(channel)).Name;
        end

        function replaceLabels(obj,labels,opts)
            arguments
                obj
                labels struct
                opts.SourceIDs string = strings(1,0)
                opts.TargetIDs string = strings(1,0)
                opts.ActivateID (1,1) string = ""
            end
            old = obj.LabelBank.toStruct();
            ids = string({labels.ID});
            oldIDs = string({old.Labels.ID});
            assert(ismember("unlabeled",ids) && ~ismember("unlabeled",opts.SourceIDs), ...
                'The Unlabeled entry is required and must retain its ID.');
            assert(numel(unique(ids)) == numel(ids) && ...
                numel(opts.SourceIDs) == numel(opts.TargetIDs) && ...
                all(ismember(opts.SourceIDs,oldIDs)) && all(ismember(opts.TargetIDs,ids)), ...
                'Label IDs and their replacements must be valid.');

            targets = oldIDs;
            targets(~ismember(oldIDs,ids)) = "unlabeled";
            [~,indices] = ismember(opts.SourceIDs,oldIDs);
            targets(indices) = opts.TargetIDs;
            active = old.ActiveLabelID;
            [found,index] = ismember(active,oldIDs);
            if found, active = targets(index); end
            [~,indices] = ismember(old.SelectedLabelIDs,oldIDs);
            selected = targets(indices(indices > 0));
            if opts.ActivateID ~= ""
                active = opts.ActivateID;
                selected = opts.ActivateID;
            end
            bank = desmostorm.model.LabelRegistry.fromStruct(struct( ...
                'Labels',labels,'Order',ids,'ActiveLabelID',active,'SelectedLabelIDs',selected));

            images = obj.ImageArray;
            for i = 1:numel(images)
                regs = images(i).RegionArray;
                for k = 1:numel(regs)
                    [found,index] = ismember(regs(k).LabelID,oldIDs);
                    if found && targets(index) ~= regs(k).LabelID
                        regs(k).LabelID = targets(index);
                        regs(k).LabelSource = "user";
                    end
                end
            end
            obj.LabelBank = bank;
            obj.attachLabelBankListener();
            obj.onLabelBankChanged();
        end

        function setImageSelection(obj,ids)
            ids = intersect(obj.ImageOrder,string(ids(:)),'stable');
            if ~isequal(obj.SelectedImageIDs,ids)
                obj.SelectedImageIDs = ids;
                notify(obj,'ImageSelectionChanged');
            end
        end

        function removeImage(obj, imageID)
            %REMOVEIMAGE Remove image by ID

            imageID = string(imageID);
            if ~isKey(obj.ImagesDict, imageID), return; end

            obj.ImagesDict = obj.ImagesDict.remove(imageID);
            obj.ImageOrder = obj.ImageOrder(obj.ImageOrder ~= imageID);
            obj.setImageSelection(obj.SelectedImageIDs);
            if ismember(imageID,obj.ActiveImageID)
                if isempty(obj.ImageOrder)
                    obj.setActiveImage("");
                else
                    obj.setActiveImage(obj.ImageOrder(1));
                end
            end

            notify(obj,'ImageRemoved',desmostorm.model.events.ImageRemoved(imageID));
            obj.markDirty();
        end

        function setActiveImage(obj, imageID)
        %SETACTIVEIMAGE Set image as active by ID

            % store current active ID
            oldID = obj.ActiveImageID;
            if isempty(oldID), oldID = ""; end

            % ID we are going to make active
            newID = string(imageID);

            % prevent unnecessary updates, return if image is already active
            if newID == oldID, return; end

            if strlength(newID)==0
                obj.ActiveImageID = "";
                notify(obj,'ActiveImageChanged',desmostorm.model.events.ActiveImageChanged("",oldID));
                return
            end
            if isKey(obj.ImagesDict, newID)
                obj.ActiveImageID = newID;

                % get the STORMImage
                img = obj.getImage(newID);

                % buffer image data if not already
                if ~img.isLoaded
                    img.bufferImageData();
                end

                % if no active region, set first in region array as active
                if isempty(img.ActiveRegion) && numel(img.RegionArray)>0
                    img.ActiveRegionID = img.RegionArray(1).ID;
                end

                notify(obj,'ActiveImageChanged',desmostorm.model.events.ActiveImageChanged(newID,oldID));
            end
        end

        function tf = hasImage(obj, imageID)
            %HASIMAGE Check if image exists by ID
            tf = isKey(obj.ImagesDict, string(imageID));
        end

        function im = getImage(obj, imageID)
            %GETIMAGE Retrieve image by ID
            imageID = string(imageID);
            if isKey(obj.ImagesDict, imageID), im = obj.ImagesDict(imageID);
            else, im = []; end
        end

        function n = numImages(obj)
            %NUMIMAGES Return number of images in the project
            n = numEntries(obj.ImagesDict);
        end

        function IDs = imageIDs(obj)
            %IMAGEIDS Return list of image IDs
            IDs = keys(obj.ImagesDict);
        end

    end

    %% Region management
    methods

        function removeAllRegions(obj)
            %REMOVEALLREGIONS Remove all regions from all images
            arr = obj.ImageArray;
            if isempty(arr), return; end
            % remove all Regions from each Image one by one
            for i = 1:numel(arr)
                arr(i).removeAllRegions();
            end
        end


        % needs to be optimized
        function regs = getRegionsByLabelID(obj,labelID)
            regs = desmostorm.model.STORMRegion.empty(0,1);
            imgs = obj.ImageArray;
            for i = 1:numel(imgs)
                matches = imgs(i).getRegionsByLabelID(labelID);
                if ~isempty(matches), regs = [regs;matches(:)]; end
            end
        end



    end


    %% Processing hooks
    methods

        % process all Regions (compute and analyze linescans from drawn ROIs)
        function processAll(obj, config, opts)
            arguments
                obj (1,1) desmostorm.model.STORMProject
                config desmostorm.config.RunConfig
                opts.ProgressDialog = []
            end

            % get Image array
            arr = obj.ImageArray;
            % return if empty
            if isempty(arr), return; end

            total = 0;
            for i = 1:numel(arr)
                regs = arr(i).RegionArray;
                valid = arrayfun(@(r) desmostorm.model.STORMRegion.hasValidROI(r.ROI),regs);
                total = total + nnz(valid);
            end
            if total == 0, return; end

            % otherwise, process each image and region
            n = 0;
            for i = 1:numel(arr)
                regs = arr(i).RegionArray;
                valid = arrayfun(@(r) desmostorm.model.STORMRegion.hasValidROI(r.ROI),regs);
                regs = regs(valid);
                for j = 1:numel(regs)
                    n = n + 1;
                    desmostorm.runtime.updateProgress(opts.ProgressDialog, ...
                        sprintf("Analyzing region %d/%d: %s",n,total,regs(j).Name), ...
                        (n - 1) / total);
                    arr(i).processRegionLinescan(regs(j),config, ...
                        "ProgressDialog",opts.ProgressDialog, ...
                        "ProgressMessagePrefix",sprintf("Region %d/%d: ",n,total));
                    desmostorm.runtime.updateProgress(opts.ProgressDialog, ...
                        sprintf("Analyzed region %d/%d: %s",n,total,regs(j).Name), ...
                        n / total);
                end
            end
        end

        function refreshRegionLinescanPixelSizes(obj)
        %REFRESHREGIONLINESCANPIXELSIZES Apply current pixel size to stored measurements.
            arr = obj.ImageArray;
            for i = 1:numel(arr)
                arr(i).refreshRegionLinescanPixelSizes();
            end
        end

        % process all Regions (compute and analyze linescans from drawn ROIs)
        function summary = autofitAllRegionROIs(obj, config, opts)
            arguments
                obj (1,1) desmostorm.model.STORMProject
                config desmostorm.config.RunConfig
                opts.ProgressDialog = []
            end

            % get Image array
            arr = obj.ImageArray;
            % return if empty
            summary = struct("Attempted",0,"Succeeded",0,"Failed",0);
            if isempty(arr), return; end

            total = 0;
            for i = 1:numel(arr)
                total = total + numel(arr(i).RegionArray);
            end
            if total == 0, return; end

            % Update the GUI-owned progress dialog between regions. Each
            % region-level fit can still update the same dialog with stage
            % details while it is running.
            for i = 1:numel(arr)
                regs = arr(i).RegionArray;
                for j = 1:numel(regs)
                    summary.Attempted = summary.Attempted + 1;
                    progressPrefix = string(sprintf( ...
                        "Region %d/%d: %s", ...
                        summary.Attempted,total,regs(j).Name));
                    desmostorm.runtime.updateProgress(opts.ProgressDialog, ...
                        progressPrefix + newline + "Starting ROI auto-fit...", ...
                        (summary.Attempted - 1) / total);

                    ok = arr(i).autofitRegionROI(regs(j),config, ...
                        "DebugOutput",false, ...
                        "ProgressDialog",opts.ProgressDialog, ...
                        "ProgressMessagePrefix",progressPrefix, ...
                        "ProgressValueMode","none");
                    if ok
                        summary.Succeeded = summary.Succeeded + 1;
                        finalMessage = progressPrefix + newline + "ROI auto-fit complete.";
                    else
                        summary.Failed = summary.Failed + 1;
                        finalMessage = progressPrefix + newline + "ROI auto-fit failed.";
                    end
                    desmostorm.runtime.updateProgress(opts.ProgressDialog, ...
                        finalMessage, ...
                        summary.Attempted / total);
                end
            end

            desmostorm.runtime.updateProgress(opts.ProgressDialog, ...
                sprintf("ROI auto-fit complete: %d/%d succeeded.",summary.Succeeded,total), ...
                1);
        end

    end

    %% Listener callbacks
    methods

        function onMaxSizeCPostSet(obj)

            notify(obj,'MaxSizeCChanged');

        end

        function onImageAdded(obj,evt)

            obj.updateImageStats();



            % set new image as active if none exists
            if strlength(obj.ActiveImageID)==0
                obj.setActiveImage(evt.ImageID);
            end

        end

        function onImageRemoved(obj,~)

            obj.updateImageStats();

        end

        function onActiveImageChanged(obj,evt)

            % --- buffer clearing policy: keep active + last N-1 ---
            % imageID = obj.ActiveImageID;
            imageID = evt.NewID;

            % Update LRU list
            if strlength(imageID) > 0
                obj.RecentImageIDs(obj.RecentImageIDs == imageID) = [];
                obj.RecentImageIDs = [imageID; obj.RecentImageIDs];
                if numel(obj.RecentImageIDs) > obj.ImageDataCacheSize
                    obj.RecentImageIDs = obj.RecentImageIDs(1:obj.ImageDataCacheSize);
                end
            end
        
            % Clear anything not in cache list
            imageIDs = obj.ImageOrder;
            keep = obj.RecentImageIDs;
            toClear = imageIDs(~ismember(imageIDs, keep));
        
            for k = 1:numel(toClear)
                if isKey(obj.ImagesDict, toClear(k))
                    try
                        obj.ImagesDict(toClear(k)).clearImageDataBuffer();
                    catch
                    end
                end
            end

            % remove listeners first
            if ~isempty(obj.RegionListeners)
                delete(obj.RegionListeners(isvalid(obj.RegionListeners))); 
            end
            % replace listener property with empty array of event.listener
            obj.RegionListeners = event.listener.empty;

            % get the new ActiveImage
            img = obj.ActiveImage;

            % exit early if no ActiveImage
            if isempty(img), return; end

            % add new set of region listeners for the current ActiveImage
            obj.RegionListeners(1) = addlistener(img,'RegionAdded',             @(~,evt) notify(obj,'RegionAdded',evt));
            obj.RegionListeners(2) = addlistener(img,'RegionRemoved',           @(~,evt) notify(obj,'RegionRemoved',evt));
            obj.RegionListeners(3) = addlistener(img,'ActiveRegionChanged',     @(~,evt) notify(obj,'ActiveRegionChanged',evt));
            obj.RegionListeners(4) = addlistener(img,'RegionSelectionChanged',  @(~,evt) notify(obj,'RegionSelectionChanged',evt));

        end

        function onLabelBankChanged(obj)
            notify(obj,'LabelsChanged');
            obj.markDirty();
        end

    end

    %% Helpers
    methods

        function markDirty(obj)
            if obj.HasUnsavedChanges
                return
            end

            obj.HasUnsavedChanges = true;
            notify(obj,'DirtyStateChanged');
        end

        function markClean(obj)
            if ~obj.HasUnsavedChanges
                return
            end

            obj.HasUnsavedChanges = false;
            notify(obj,'DirtyStateChanged');
        end

        function attachLabelBankListener(obj)
            delete(obj.LabelsChangedListener);
            obj.LabelsChangedListener = addlistener(obj.LabelBank,'LabelsChanged',@(~,~) obj.onLabelBankChanged());
        end

        function setDefaultPixelSize(obj, ps)
            arguments
                obj
                ps (1,1) desmostorm.model.units.PixelSize
            end
            % set project default
            obj.DefaultPixelSize = ps;
            % Reset all image overrides
            imgs = obj.ImageArray;
            for k = 1:numel(imgs)
                imgs(k).PixelSizeOverride = desmostorm.model.units.PixelSize.empty;
            end
        end

        function updateImageStats(obj)

            imgs = obj.ImageArray;

            % Assigning MaxSizeC fires MaxSizeCChanged via the property listener.
            if isempty(imgs)
                obj.MaxSizeC = 0;
            else
                obj.MaxSizeC = max([imgs(:).SizeC]);
            end


        end

        function setDefaultChannelColormap(obj,name,category)
            assert(matlabx.colors.maps.Registry.has(name,category), ...
                'Colormap "%s" not found in category "%s".',name,category);
            obj.DefaultChannelColormapName = name;
            obj.DefaultChannelColormapCategory = category;
        end

        function setChannelColormap(obj,channel,name,category)
            index = obj.channelIndex(channel);
            assert(matlabx.colors.maps.Registry.has(name,category), ...
                'Colormap "%s" not found in category "%s".',name,category);
            if obj.Channels(index).ColormapName ~= name || ...
                    obj.Channels(index).ColormapCategory ~= category
                obj.Channels(index).ColormapName = string(name);
                obj.Channels(index).ColormapCategory = string(category);
                obj.markDirty();
            end
        end

        function [name,category] = getChannelColormapInfo(obj,channel)
            definition = obj.Channels(obj.channelIndex(channel));
            name = definition.ColormapName;
            category = definition.ColormapCategory;
        end

        function cmap = getChannelColormap(obj,channel)
            [name,category] = obj.getChannelColormapInfo(channel);
            cmap = matlabx.colors.maps.Registry.map(name,category);
        end

        function cmaps = getChannelColormaps(obj,n)
            if nargin < 2, n = numel(obj.Channels); end
            cmaps = arrayfun(@(c) obj.getChannelColormap(c),1:n,'UniformOutput',false);
        end

        function setChannelColor(obj,channel,color)
            index = obj.channelIndex(channel);
            color = matlabx.image.normalizeComponentColor(color);
            if obj.Channels(index).Color ~= color
                obj.Channels(index).Color = color;
                obj.markDirty();
                notify(obj,'ChannelsChanged');
            end
        end

        function color = getChannelColorName(obj,channel)
            color = obj.Channels(obj.channelIndex(channel)).Color;
        end

        function rgb = getChannelRGB(obj,channel)
            [~,rgb] = matlabx.image.normalizeComponentColor(obj.getChannelColorName(channel));
        end

    end

    %% Export data
    methods

        function T = imagesTable(obj)
            if numel(obj.ImageOrder)==0, T = table(); return; end
            imgs = obj.ImagesDict(obj.ImageOrder);  % -> array of STORMImage
            T = table( ...
                obj.ImageOrder(:), ...
                arrayfun(@(im) im.Name, imgs, 'uni',0).', ...
                arrayfun(@(im) im.SourcePath, imgs, 'uni',0).', ...
                'VariableNames', {'ID','Name','Path'});
        end


    end


    methods

        function save(obj, file, settings)
            %SAVE Save project + regions + settings to a .mat file.
            arguments
                obj
                file (1,1) string
                settings (1,1) desmostorm.config.Settings
            end

            [folder,name,extension] = fileparts(file);
            if extension == "", file = file + ".mat"; end
            if isfolder(file)
                error('desmostorm:project:SaveFailed','The destination is a folder: %s',file);
            end
            if strlength(folder) > 0 && ~exist(folder,'dir')
                mkdir(folder);
            end

            desmostorm.Log.INFO(sprintf("Saving project: %s",name));
            Project = obj.toStruct(settings);
            Project.Project.Name = name;
            Project.Project.SourcePath = file;

            if folder == "", folder = string(pwd); end
            temporary = string(tempname(folder)) + ".mat";
            cleanup = onCleanup(@() deleteTemporaryProjectFile(temporary));
            save(temporary,'Project','-mat');
            [written,message] = movefile(temporary,file,'f');
            if ~written
                error('desmostorm:project:SaveFailed','%s',message);
            end

            obj.Name = name;
            obj.SourcePath = file;
            obj.isOnDisk = true;
            obj.markClean();

        end

    end

    methods (Static)

        function [proj, settings] = load(file, opts)
            %LOAD Loads a project file created by STORMProject.save()
            arguments
                file (1,1) string % name of the saved file
                opts.MissingImageResolver = []
            end

            % load the mat file
            desmostorm.Log.INFO(sprintf("Loading project file: %s",file))
            saveStruct = load(file, 'Project', '-mat');

            % ensure file contains a variable named "Project"
            if ~isfield(saveStruct,'Project')
                error('STORMProject:InvalidProjectFile', 'Cannot load project file: no variable named "Project" found')
            else
                S = saveStruct.Project;
            end


            % warn on version mismatch
            if desmostorm.Version.compare(S.Project.Version, desmostorm.Info.Version) < 0
                desmostorm.Log.WARN(sprintf("Project version (%s) does not match current app version (%s)",S.Project.Version,desmostorm.Info.Version));
            end

            desmostorm.Log.DEBUG("Rebuilding project...")
            try
                [proj, settings] = desmostorm.model.STORMProject.fromStruct(S, file, ...
                    "MissingImageResolver", opts.MissingImageResolver);
            catch ME
                desmostorm.Log.EXCEPTION(ME);
                rethrow(ME);
            end
        end

        function [proj, settings] = fromStruct(P, file, opts)
            arguments
                P
                file (1,1) string
                opts.MissingImageResolver = []
            end

            projectFolder = string(fileparts(file));

            % Settings restore
            settings = desmostorm.config.Settings();
            settings.fromStruct(P.Settings);

            % Project
            proj = desmostorm.model.STORMProject(P.Project.Name);
            proj.ID = string(P.Project.ID);
            proj.CreatedAt = P.Project.CreatedAt;
            proj.Version = string(P.Project.Version);
            proj.SourcePath = file;

            if isfield(P.Project,'DefaultPixelSize')
                ps = P.Project.DefaultPixelSize;
                proj.DefaultPixelSize = desmostorm.model.units.PixelSize(ps.Value, ps.Unit);
            end

            if isfield(P.Project,'LabelBank') && ~isempty(P.Project.LabelBank)
                proj.LabelBank = desmostorm.model.LabelRegistry.fromStruct(P.Project.LabelBank);
                fallback = proj.LabelBank.getByID("unlabeled");
                if desmostorm.Version.compare(proj.Version,"1.2.0") < 0 && ...
                        isequal(fallback.Color,[0.7 0.7 0.7])
                    fallback.Color = [1 1 1];
                end
            else
                proj.LabelBank = desmostorm.model.LabelRegistry.default();
            end
            proj.attachLabelBankListener();

            resolved = struct.empty();
            if isfield(P,'Images') && ~isempty(P.Images)
                desmostorm.Log.DEBUG("Resolving image paths...");
                resolved = desmostorm.io.resolveImagePaths(P.Images, projectFolder, ...
                    "MissingImageResolver", opts.MissingImageResolver);
                if isempty(resolved)
                    delete(proj);
                    delete(settings);
                    proj = [];
                    settings = [];
                    return
                end
            end

            % Rebuild images/regions without eager pixel loads
            proj.ImagesDict = dictionary(string.empty(1,0), desmostorm.model.STORMImage.empty(1,0));
            proj.ImageOrder = string.empty(1,0);

            desmostorm.Log.DEBUG("Rebuilding images...")
            nResolved = numel(resolved);
            for k = 1:nResolved
                desmostorm.Log.DEBUG(sprintf("Image (%i/%i): %s",k,nResolved,resolved(k).Name))
                img = desmostorm.model.STORMImage.fromStruct(resolved(k),proj);
                proj.ImagesDict(img.ID) = img;
                proj.ImageOrder(end+1) = img.ID;
            end

            proj.updateImageStats();
            if isfield(P.Project,'Channels')
                proj.Channels = P.Project.Channels;
            else
                proj.Channels = proj.legacyChannels(P.Project);
            end

            for k = 1:nResolved
                img = proj.ImagesDict(proj.ImageOrder(k));
                if isfield(resolved,'ChannelIDs')
                    ids = resolved(k).ChannelIDs;
                else
                    ids = string({proj.Channels(1:img.SizeC).ID});
                end
                assert(all(ismember(ids,string({proj.Channels.ID}))), ...
                    'An image refers to an unknown project channel.');
                img.setChannelIDs(ids);
            end

            if isfield(P,'SelectedImageIDs')
                proj.setImageSelection(P.SelectedImageIDs);
            end
            if isfield(P,'ActiveImageID') && strlength(string(P.ActiveImageID)) > 0
                proj.setActiveImage(string(P.ActiveImageID));
            end

            % indicate file exists on disk at SourcePath
            proj.isOnDisk = true;
            proj.markClean();

        end

    end

    methods (Access=private)

        function P = toStruct(obj, settings)
            % Project meta
            P.Project.ID           = obj.ID;
            P.Project.Name         = obj.Name;
            P.Project.CreatedAt    = obj.CreatedAt;
            P.Project.Version      = desmostorm.Info.Version;
            P.Project.SourcePath   = obj.SourcePath;
            P.Project.DefaultPixelSize = struct('Value', obj.DefaultPixelSize.Value, 'Unit', obj.DefaultPixelSize.Unit);

            % Label bank
            P.Project.LabelBank = obj.LabelBank.toStruct();

            P.Project.Channels = obj.Channels;

            % Settings snapshot (portable)
            P.Settings = settings.toStruct();

            % Images
            imgs = obj.ImageArray;
            P.ImageOrder     = obj.ImageOrder;
            P.ActiveImageID  = obj.ActiveImageID;
            P.SelectedImageIDs = obj.SelectedImageIDs;

            if isempty(imgs)
                P.Images = struct.empty();
            else
                P.Images = arrayfun(@(img) img.toStruct(),imgs);
            end
        end

    end

    methods (Access=private)

        function channels = legacyChannels(obj,project)
            channels = obj.Channels;
            display = struct();
            if isfield(project,'ChannelDisplay') && isstruct(project.ChannelDisplay) && ...
                    isscalar(project.ChannelDisplay)
                display = project.ChannelDisplay;
            elseif isfield(project,'ChannelColormaps') && isstruct(project.ChannelColormaps) && ...
                    isscalar(project.ChannelColormaps)
                maps = project.ChannelColormaps;
                if isfield(maps,'Names'), display.ColormapNames = maps.Names; end
                if isfield(maps,'Categories'), display.ColormapCategories = maps.Categories; end
            end
            palette = matlabx.image.componentColorNames();
            for c = 1:obj.MaxSizeC
                color = palette(1 + mod(c-1,numel(palette)));
                if isfield(display,'ColorNames') && numel(string(display.ColorNames)) >= c
                    colors = string(display.ColorNames);
                    color = matlabx.image.normalizeComponentColor(colors(c));
                end
                name = "gray";
                category = "MATLAB";
                if isfield(display,'ColormapNames') && isfield(display,'ColormapCategories')
                    names = string(display.ColormapNames);
                    categories = string(display.ColormapCategories);
                    if c <= min(numel(names),numel(categories))
                        name = names(c);
                        category = categories(c);
                    end
                end
                channels(c) = struct('ID',matlabx.utils.text.uniqueID(), ...
                    'Name',"Channel " + c,'Color',color, ...
                    'ColormapName',name,'ColormapCategory',category);
            end
        end

    end

    %% Friendlier Command Window / Variable Editor display
    methods (Access=protected)
        function groups = getPropertyGroups(obj)
            summary = struct( ...
                'Name', obj.Name, ...
                'CreatedAt', obj.CreatedAt, ...
                'NumImages', obj.numImages(), ...
                'ActiveImageID', obj.ActiveImageID, ...
                'ImageOrder', obj.ImageOrder, ...
                'ImageArray', obj.ImageArray);   % editor-friendly
            groups = matlab.mixin.util.PropertyGroup(summary, 'STORMProject');
        end
    end

    methods

        function groups = getPropGroups(obj)

            groups = obj.getPropertyGroups();
        end

    end

end

function deleteTemporaryProjectFile(file)
    if isfile(file), delete(file); end
end
