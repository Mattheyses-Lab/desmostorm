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
        ActiveImageID (:,1) string = string.empty(0,1)
    end

    properties (Access=private)
        ImageDataCacheSize (1,1) double {mustBeNonnegative, mustBeInteger} = 2  % active + 1 previous
        RecentImageIDs (:,1) string = string.empty(0,1)
    end

    properties (Dependent)
        ImageNames
        ImageIDs
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

    properties
        ChannelColormapNames (1,:) string = string.empty(1,0)
        ChannelColormapCategories (1,:) string = string.empty(1,0)
        ChannelColorNames (1,:) string = string.empty(1,0)
    end

    %% Events and listeners

    % (Project and GUI controller listen)
    events
        ImageAdded
        ImageRemoved
        ActiveImageChanged
        MaxSizeCChanged

        RegionAdded
        RegionRemoved
        ActiveRegionChanged
        RegionSelectionChanged

        LabelsChanged

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

            % bind to dictionary and emit ImageAdded
            obj.ImagesDict(img.ID) = img;
            obj.ImageOrder(end+1) = img.ID;

            imageID = img.ID;
            notify(obj,'ImageAdded',desmostorm.model.events.ImageAdded(imageID));
            obj.markDirty();
        end

        % add a new desmostorm.model.STORMImage for each of the images located at the paths in the cell array, filePaths
        function addImagesFromPaths(obj, filePaths)
            %ADDIMAGESFROMPATHS Add a new STORMImage for each of the images specified by filePath
            % convert char/string to cell if not already cell
            if ~iscell(filePaths)
                filePaths = cellstr(filePaths);
            end
            % for each path in the cell, add a new desmostorm.model.STORMImage
            for i = 1:numel(filePaths)
                obj.addImageFromPath(filePaths{i});
            end
        end

        function removeImage(obj, imageID)
            %REMOVEIMAGE Remove image by ID

            imageID = string(imageID);
            if ~isKey(obj.ImagesDict, imageID), return; end

            obj.ImagesDict = obj.ImagesDict.remove(imageID);
            obj.ImageOrder = obj.ImageOrder(obj.ImageOrder ~= imageID);

            notify(obj,'ImageRemoved',desmostorm.model.events.ImageRemoved(imageID));
            obj.markDirty();
        end

        function setActiveImage(obj, imageID)
        %SETACTIVEIMAGE Set image as active by ID

            % store current active ID
            oldID = obj.ActiveImageID;

            % ID we are going to make active
            newID = string(imageID);

            % prevent unnecessary updates, return if image is already active
            if newID == obj.ActiveImageID, return; end

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

            regs = [];

            imgs = obj.ImageArray;

            for i = 1:numel(imgs)
                regs = [regs;imgs(i).getRegionsByLabelID(labelID)];
            end


        end



    end


    %% Processing hooks
    methods

        % process all Regions (compute and analyze linescans from drawn ROIs)
        function processAll(obj, config)
            % get Image array
            arr = obj.ImageArray;
            % return if empty
            if isempty(arr), return; end
            % otherwise, process each image
            for i = 1:numel(arr)
                arr(i).processAll(config);
            end
        end

        % process all Regions (compute and analyze linescans from drawn ROIs)
        function autofitAllRegionROIs(obj, config)
            % get Image array
            arr = obj.ImageArray;
            % return if empty
            if isempty(arr), return; end
            % otherwise, process each image
            for i = 1:numel(arr)
                arr(i).autofitAllRegionROIs(config);
            end
        end

    end

    %% Listener callbacks
    methods

        function onMaxSizeCPostSet(obj)

            obj.ensureChannelColormapCount();
            notify(obj,'MaxSizeCChanged');

        end

        function onImageAdded(obj,evt)

            obj.updateImageStats();



            % set new image as active if none exists
            if strlength(obj.ActiveImageID)==0
                obj.setActiveImage(evt.ImageID);
            end

        end

        function onImageRemoved(obj,evt)

            obj.updateImageStats();

            % if removed image was active, clear active image ID
            if obj.ActiveImageID == evt.ImageID
                obj.setActiveImage("");
            end

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

        function ensureChannelColormapCount(obj)
        %ENSURECHANNELCOLORMAPCOUNT Keep project channel colormap storage sized to MaxSizeC
            n = max(obj.MaxSizeC,0);
            defaultColors = string(matlabx.ui.axes.ImageAxes.getColorNames());

            obj.ChannelColormapNames = obj.ChannelColormapNames(:).';
            obj.ChannelColormapCategories = obj.ChannelColormapCategories(:).';
            obj.ChannelColorNames = desmostorm.model.STORMProject.normalizeChannelColorNames_( ...
                obj.ChannelColorNames(:).');

            if numel(obj.ChannelColormapNames) > n
                obj.ChannelColormapNames = obj.ChannelColormapNames(1:n);
            end
            if numel(obj.ChannelColormapCategories) > n
                obj.ChannelColormapCategories = obj.ChannelColormapCategories(1:n);
            end
            if numel(obj.ChannelColorNames) > n
                obj.ChannelColorNames = obj.ChannelColorNames(1:n);
            end

            if numel(obj.ChannelColormapNames) < n
                obj.ChannelColormapNames(end+1:n) = "gray";
            end
            if numel(obj.ChannelColormapCategories) < n
                obj.ChannelColormapCategories(end+1:n) = "MATLAB";
            end
            for c = numel(obj.ChannelColorNames)+1:n
                obj.ChannelColorNames(c) = defaultColors(1 + mod(c-1,numel(defaultColors)));
            end
        end

        function setChannelColormap(obj,c,name,category)
        %SETCHANNELCOLORMAP Store the selected colormap for one project channel
            arguments
                obj
                c (1,1) double {mustBeInteger, mustBePositive}
                name (1,1) string
                category (1,1) string
            end

            obj.ensureChannelColormapCount();
            if c > numel(obj.ChannelColormapNames), return; end

            assert(matlabx.colors.maps.Registry.has(name, category), ...
                'Colormap "%s" not found in category "%s".', name, category);

            if obj.ChannelColormapNames(c) == name && obj.ChannelColormapCategories(c) == category
                return
            end

            obj.ChannelColormapNames(c) = name;
            obj.ChannelColormapCategories(c) = category;
            obj.markDirty();
        end

        function [name,category] = getChannelColormapInfo(obj,c)
        %GETCHANNELCOLORMAPINFO Return saved colormap name/category for one channel
            arguments
                obj
                c (1,1) double {mustBeInteger, mustBePositive}
            end

            obj.ensureChannelColormapCount();
            if c > numel(obj.ChannelColormapNames)
                name = "gray";
                category = "MATLAB";
                return
            end

            name = obj.ChannelColormapNames(c);
            category = obj.ChannelColormapCategories(c);
        end

        function cmap = getChannelColormap(obj,c)
        %GETCHANNELCOLORMAP Resolve one channel's saved colormap
            [name,category] = obj.getChannelColormapInfo(c);
            cmap = matlabx.colors.maps.Registry.map(name,category);
        end

        function cmaps = getChannelColormaps(obj,n)
        %GETCHANNELCOLORMAPS Resolve saved colormaps for channels 1:n
            arguments
                obj
                n (1,1) double {mustBeInteger, mustBeNonnegative} = obj.MaxSizeC
            end

            obj.ensureChannelColormapCount();
            cmaps = cell(1,n);
            for c = 1:n
                cmaps{c} = obj.getChannelColormap(c);
            end
        end

        function setChannelColor(obj,c,name)
        %SETCHANNELCOLOR Store the selected color name for one project channel
            arguments
                obj
                c (1,1) double {mustBeInteger, mustBePositive}
                name (1,1) string
            end

            obj.ensureChannelColormapCount();
            if c > numel(obj.ChannelColorNames), return; end

            name = desmostorm.model.STORMProject.normalizeChannelColorName_(name);
            if obj.ChannelColorNames(c) == name
                return
            end

            obj.ChannelColorNames(c) = name;
            obj.markDirty();
        end

        function name = getChannelColorName(obj,c)
        %GETCHANNELCOLORNAME Return saved color name for one channel
            arguments
                obj
                c (1,1) double {mustBeInteger, mustBePositive}
            end

            obj.ensureChannelColormapCount();
            if c > numel(obj.ChannelColorNames)
                defaultColors = string(matlabx.ui.axes.ImageAxes.getColorNames());
                name = defaultColors(1 + mod(c-1,numel(defaultColors)));
                return
            end

            name = obj.ChannelColorNames(c);
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

            [folder,name,~] = fileparts(file);
            if strlength(folder) > 0 && ~exist(folder,'dir')
                mkdir(folder);
            end

            % set Name to match file short name
            obj.Name = name;
            obj.SourcePath = file;

            % update log
            desmostorm.Log.INFO(sprintf("Saving project: %s",obj.Name))
            % attempt to save the project
            try
                % get save struct
                Project = obj.toStruct(settings);
                % save it
                save(file, 'Project', '-mat');
            catch ME
                desmostorm.Log.EXCEPTION(ME);
                rethrow(ME);
            end

            % indicate that it is now on disk
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
            else
                proj.LabelBank = desmostorm.model.LabelRegistry.default();
            end
            proj.attachLabelBankListener();

            % Resolve image paths
            desmostorm.Log.DEBUG("Resolving image paths...")
            resolved = desmostorm.io.resolveImagePaths(P.Images, projectFolder, ...
                "MissingImageResolver", opts.MissingImageResolver);

            % If resolved comes back empty -> return empty, load fails
            if isempty(resolved)
                delete(proj); delete(settings);
                proj = []; settings = [];
                return
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

            % Restore active selection
            if isfield(P,'ActiveImageID') && strlength(string(P.ActiveImageID))>0
                proj.setActiveImage(string(P.ActiveImageID));
            end

            % update project-wide image stats
            proj.updateImageStats();

            if isfield(P.Project,'ChannelDisplay') && ~isempty(P.Project.ChannelDisplay)
                if isfield(P.Project.ChannelDisplay,'ColormapNames')
                    proj.ChannelColormapNames = string(P.Project.ChannelDisplay.ColormapNames);
                end
                if isfield(P.Project.ChannelDisplay,'ColormapCategories')
                    proj.ChannelColormapCategories = string(P.Project.ChannelDisplay.ColormapCategories);
                end
                if isfield(P.Project.ChannelDisplay,'ColorNames')
                    proj.ChannelColorNames = desmostorm.model.STORMProject.normalizeChannelColorNames_( ...
                        string(P.Project.ChannelDisplay.ColorNames));
                end
            elseif isfield(P.Project,'ChannelColormaps') && ~isempty(P.Project.ChannelColormaps)
                if isfield(P.Project.ChannelColormaps,'Names')
                    proj.ChannelColormapNames = string(P.Project.ChannelColormaps.Names);
                end
                if isfield(P.Project.ChannelColormaps,'Categories')
                    proj.ChannelColormapCategories = string(P.Project.ChannelColormaps.Categories);
                end
            else
                proj.ChannelColormapNames = repmat("gray",1,proj.MaxSizeC);
                proj.ChannelColormapCategories = repmat("MATLAB",1,proj.MaxSizeC);
            end
            proj.ensureChannelColormapCount();

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

            % Project-wide per-channel display choices
            obj.ensureChannelColormapCount();
            P.Project.ChannelDisplay = struct( ...
                'ColormapNames',obj.ChannelColormapNames, ...
                'ColormapCategories',obj.ChannelColormapCategories, ...
                'ColorNames',obj.ChannelColorNames);

            % Settings snapshot (portable)
            P.Settings = settings.toStruct();

            % Images
            imgs = obj.ImageArray;
            P.ImageOrder     = obj.ImageOrder;
            P.ActiveImageID  = obj.ActiveImageID;

            for k = 1:numel(imgs)
                im = imgs(k);
                P.Images(k) = im.toStruct();
            end
        end

    end

    methods (Static, Access=private)

        function names = normalizeChannelColorNames_(names)
        %NORMALIZECHANNELCOLORNAMES_ Canonicalize saved channel color names.
            names = string(names);
            for i = 1:numel(names)
                names(i) = desmostorm.model.STORMProject.normalizeChannelColorName_(names(i));
            end
        end

        function name = normalizeChannelColorName_(name)
        %NORMALIZECHANNELCOLORNAME_ Delegate channel color policy to ImageAxes.
            name = matlabx.ui.axes.ImageAxes.canonicalComponentColorName(name);
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
