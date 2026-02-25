classdef STORMProject < handle & matlab.mixin.CustomDisplay
%STORMProject Stores project metadata, stores and manages images

    %% Identity/metadata
    properties
        ID (1,1) string = utils.uniqueID()
        Name (1,1) string = "untitled"
        SourcePath (1,1) string = ""
        CreatedAt datetime = datetime('now')
        Version (1,1) string = app.Info.Version
        isOnDisk (1,1) logical = false
    end

    %% Label bank
    properties
        LabelBank model.LabelRegistry = model.LabelRegistry.default()
    end

    %% Images (dictionary + order) and active selection
    properties (Access=private)
        ImagesDict = dictionary   % string ID -> model.STORMImage
        ImageOrder (1,:) string = string.empty(1,0)
        ActiveImageID (1,1) string = ""
    end

    properties (Access=private)
        CDataCacheSize (1,1) double {mustBeNonnegative, mustBeInteger} = 2  % active + 1 previous
        RecentImageIDs (1,:) string = string.empty(1,0)
    end

    properties (Dependent)
        ImageNames
        ImageIDs
    end

    %% ergonomic array view, public, editor-friendly
    properties (Dependent, GetAccess=public, SetAccess=private)
        ImageArray   % [1×N model.STORMImage] in ImageOrder
        ActiveImage (:,1) model.STORMImage
    end

    %% Project-wide defaults
    properties
        DefaultPixelSize model.units.PixelSize = model.units.PixelSize(1, 'px');
    end

    %% Events and listeners

    % (GUI controller listens)
    events
        ImageAdded
        ImageRemoved
        ActiveImageChanged
    end

    % (Project and GUI controller listen)
    events
        RegionAdded
        RegionRemoved
        ActiveRegionChanged
        LabelsChanged
    end

    properties
        ActiveImageListener event.listener
        RegionListeners event.listener
        LabelsChangedListener event.listener
    end

    %% Dependent getters 
    methods

        function arr = get.ImageArray(obj)
            if numel(obj.ImageOrder)==0
                arr = model.STORMImage.empty(); return;
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

            % dictionary of string ID -> model.STORMImage
            obj.ImagesDict = dictionary(string.empty(1,0), model.STORMImage.empty(1,0));

            % order of ImagesDict, empty string to start because our dictionary is empty
            obj.ImageOrder = string.empty(1,0);

            % add a listener for the ActiveImageChanged event
            obj.ActiveImageListener = addlistener(obj,'ActiveImageChanged',@(~,~) obj.onActiveImageChanged());

            % add a listener for the LabelsChanged event
            obj.LabelsChangedListener = addlistener(obj.LabelBank,'LabelsChanged',@(~,~) notify(obj,'LabelsChanged'));
        end

    end

    %% Image management
    methods

        function imageID = addImageFromPath(obj, filePath)
            % get file name and extension
            [~,name,ext] = fileparts(filePath);
            % create a STORMImage object with new unique ID
            img = model.STORMImage(obj, string(name)+string(ext), string(filePath), utils.uniqueID());  % NO imread

            % bind to dictionary and emit ImageAdded
            obj.ImagesDict(img.ID) = img;
            obj.ImageOrder(end+1) = img.ID;
            notify(obj,'ImageAdded');
        
            if strlength(obj.ActiveImageID)==0
                obj.setActiveImage(img.ID);
            end
            imageID = img.ID;
        end

        % add a new model.STORMImage for each of the images located at the paths in the cell array, filePaths
        function addImagesFromPaths(obj, filePaths)
            % convert char/string to cell if not already cell
            if ~iscell(filePaths)
                filePaths = cellstr(filePaths);
            end
            % for each path in the cell, add a new model.STORMImage
            for i = 1:numel(filePaths)
                obj.addImageFromPath(filePaths{i});
            end
        end

        function removeImage(obj, imageID)
            imageID = string(imageID);
            if ~isKey(obj.ImagesDict, imageID), return; end

            % Clear active if removing it
            if obj.ActiveImageID == imageID
                obj.ActiveImageID = "";
                notify(obj,'ActiveImageChanged');
            end

            remove(obj.ImagesDict, imageID);
            obj.ImageOrder = obj.ImageOrder(obj.ImageOrder ~= imageID);
            notify(obj,'ImageRemoved');
        end

        function setActiveImage(obj, imageID)
            imageID = string(imageID);

            % prevent unnecessary updates, return if image is already active
            if imageID == obj.ActiveImageID, return; end

            if strlength(imageID)==0
                obj.ActiveImageID = "";
                notify(obj,'ActiveImageChanged');
                return
            end
            if isKey(obj.ImagesDict, imageID)
                obj.ActiveImageID = imageID;
                notify(obj,'ActiveImageChanged');
            end
        end

        function tf = hasImage(obj, imageID)
            tf = isKey(obj.ImagesDict, string(imageID));
        end

        function im = getImage(obj, imageID)
            imageID = string(imageID);
            if isKey(obj.ImagesDict, imageID), im = obj.ImagesDict(imageID);
            else, im = []; end
        end

        function n = numImages(obj)
            n = numEntries(obj.ImagesDict);
        end

        function IDs = imageIDs(obj)
            IDs = keys(obj.ImagesDict);
        end

    end

    %% Region management
    methods

        function removeAllRegions(obj)
            arr = obj.ImageArray;

            if isempty(arr), return; end
            % remove all Regions from each Image one by one
            for i = 1:numel(arr)
                arr(i).removeAllRegions();
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

        function detectRegions(obj, config, progressdlg)
            arguments
                obj (1,1) model.STORMProject
                config (1,1) app.config.RunConfig
                progressdlg (:,1) matlab.ui.dialog.ProgressDialog = matlab.ui.dialog.ProgressDialog.empty()
            end

            % get Image array
            arr = obj.ImageArray;
            % return if empty
            if isempty(arr), return; end

            % total to process
            N = numel(arr);

            % process each image
            for i = 1:numel(arr)
                % update progrgess dialog
                if ~isempty(progressdlg)
                    set(progressdlg,...
                        "Title","Processing",...
                        "Indeterminate","off",...
                        "Message",sprintf('Autopicking regions (image %i/%i)',i,N),...
                        "Value",0);
                end

                % detect region in this image
                arr(i).detectRegions(config);
            end

        end

    end

    %% Listener callbacks
    methods

        function onActiveImageChanged(obj)

            % --- buffer clearing policy: keep active + last N-1 ---
            imgID = obj.ActiveImageID;
        
            % Update LRU list
            if strlength(imgID) > 0
                obj.RecentImageIDs(obj.RecentImageIDs == imgID) = [];
                obj.RecentImageIDs = [imgID, obj.RecentImageIDs];
                if numel(obj.RecentImageIDs) > obj.CDataCacheSize
                    obj.RecentImageIDs = obj.RecentImageIDs(1:obj.CDataCacheSize);
                end
            end
        
            % Clear anything not in cache list
            imgIDs = obj.ImageOrder;
            keep = obj.RecentImageIDs;
            toClear = imgIDs(~ismember(imgIDs, keep));
        
            for k = 1:numel(toClear)
                if isKey(obj.ImagesDict, toClear(k))
                    try
                        obj.ImagesDict(toClear(k)).clearCDataBuffer();
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
            obj.RegionListeners(1) = addlistener(img,'RegionAdded',@(~,~) notify(obj,'RegionAdded'));
            obj.RegionListeners(2) = addlistener(img,'RegionRemoved',@(~,~) notify(obj,'RegionRemoved'));
            obj.RegionListeners(3) = addlistener(img,'ActiveRegionChanged',@(~,~) notify(obj,'ActiveRegionChanged'));

        end

    end

    %% Helpers
    methods

        function setDefaultPixelSize(obj, ps)
            arguments
                obj
                ps (1,1) model.units.PixelSize
            end
            % set project default
            obj.DefaultPixelSize = ps;
            % Reset all image overrides
            imgs = obj.ImageArray;
            for k = 1:numel(imgs)
                imgs(k).PixelSizeOverride = model.units.PixelSize.empty;
            end
        end

    end

    % Export data
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


        function T = exportRegionTable(obj)
            T = cell2mat(arrayfun(@(img) img.exportRegionTable(),obj.ImageArray','UniformOutput',false));
        end

        function exportRegionTableToXlsx(obj, filename)
            % grab table for export
            T = obj.exportRegionTable();
            % empty -> warn and return
            if isempty(T)
                warning('No regions to export.');
                return;
            end

            desc = cellfun(@utils.formatColumnName, T.Properties.VariableNames, 'UniformOutput', false);
            T.Properties.VariableNames = desc;

            % write table to the given filename - will overwrite if file already exists
            writetable(T, filename, 'WriteMode', 'replacefile', 'WriteVariableNames', true);
        end

        function exportRegionImages(obj,folderName)

            % for each image
            for i = 1:numel(obj.ImageArray)
                img = obj.ImageArray(i);

                % for each region
                for j = 1:numel(img.RegionArray)
                    reg = img.RegionArray(j);

                    % build image file name
                    fileName = sprintf('%s_%s.tif',img.shortName,reg.Name);

                    % full path
                    fullName = fullfile(folderName,fileName);

                    % save each region image
                    switch img.CDataClass
                        case 'uint16'
                            imtools.write16BitTiff(img.regionSubimage(reg),fullName);
                        otherwise
                            error('Could not export region images')
                    end

                end

            end


        end

        function T = exportDetectorLabelTable(obj, opts)
            %exportDetectorLabelTable  Build training labels table for MATLAB object detectors.
            %
            % Output table schema:
            %   T.imageFilename : string scalar per row (full path)
            %   T.<ClassName>   : cell per row, each cell is [N x 4] double of [x y w h]
            %
            % Notes:
            % - Uses each STORMImage.RegionArray as the labeled objects.
            % - Assumes Region.Center is in image pixel coordinates (x right, y down).
            % - Uses Region.BoxSize (scalar) unless overridden by opts.BoxSizeOverride.
            %
            arguments
                obj (1,1) model.STORMProject

                opts.ClassName (1,1) string = "plaque_pair"

                % If you want to force a fixed square box size (e.g., 300) regardless of Region.BoxSize
                opts.BoxSizeOverride (1,1) double = NaN

                % Safety: clamp boxes to image bounds (you said you already enforce this)
                opts.ClampToImage (1,1) logical = true

                % Skip images that have no regions
                opts.SkipEmptyImages (1,1) logical = true

                % Throw if any image path is missing on disk
                opts.RequireFilesExist (1,1) logical = true
            end

            imgs = obj.ImageArray;
            if isempty(imgs)
                T = table();
                return
            end

            n = numel(imgs);
            imageFilename = strings(n,1);
            boxesPerImage = cell(n,1);

            keep = true(n,1);

            for i = 1:n
                img = imgs(i);

                imageFilename(i) = string(img.SourcePath);

                if opts.RequireFilesExist && ~isfile(imageFilename(i))
                    error("exportDetectorLabelTable:MissingFile", ...
                        "Image file not found on disk: %s", imageFilename(i));
                end

                regs = img.RegionArray;
                if isempty(regs)
                    boxesPerImage{i} = zeros(0,4);
                    if opts.SkipEmptyImages
                        keep(i) = false;
                    end
                    continue
                end

                B = zeros(numel(regs), 4);

                for r = 1:numel(regs)
                    reg = regs(r);

                    ctr = reg.Center;         % [x y]
                    if isnan(opts.BoxSizeOverride)
                        s = reg.BoxSize;      % scalar
                    else
                        s = opts.BoxSizeOverride;
                    end

                    % Convert center -> [x y w h] (top-left + size)
                    x = ctr(1) - s/2;
                    y = ctr(2) - s/2;
                    w = s;
                    h = s;

                    if opts.ClampToImage
                        % Clamp top-left so box stays fully inside the image
                        x = max(1, min(x, img.Width  - w + 1));
                        y = max(1, min(y, img.Height - h + 1));
                    end

                    B(r,:) = [x y w h];
                end

                boxesPerImage{i} = B;
            end

            % Build table
            T = table(imageFilename, 'VariableNames', {'imageFilename'});
            T.(opts.ClassName) = boxesPerImage;

            % Optionally drop empty-image rows
            T = T(keep, :);
        end

    end


    methods

        function save(obj, file, settings)
            %SAVE Save project + regions + settings to a .mat file.
            arguments
                obj
                file (1,1) string
                settings (1,1) app.config.Settings
            end

            [folder,name,~] = fileparts(file);
            if strlength(folder) > 0 && ~exist(folder,'dir')
                mkdir(folder);
            end

            % set Name to match file short name
            obj.Name = name;
            obj.SourcePath = file;

            % get save struct
            Project = obj.toStruct(settings);

            % save it
            save(file, 'Project', '-mat');

            % indicate that it is now on disk
            obj.isOnDisk = true;

        end

    end

    methods (Static)

        function [proj, settings] = load(file)
            %LOAD Loads a project file created by STORMProject.save()
            arguments
                file (1,1) string % name of the saved file
            end

            % load the mat file
            S = load(file, 'Project', '-mat');

            % ensure file contains a variable named "Project"
            if ~isfield(S,'Project')
                error('STORMProject:InvalidProjectFile', 'Cannot load project file: no variable named "Project" found')
            end

            [proj, settings] = model.STORMProject.fromStruct(S.Project, file);
        end

        function [proj, settings] = fromStruct(P, file)

            projectFolder = string(fileparts(file));

            % Settings restore
            % (migrations handled in Settings.load, here we restore directly from struct)
            settings = app.config.Settings();
            if isfield(P,'Settings') && ~isempty(P.Settings)
                settings.Analysis.fromStruct(P.Settings.Analysis);
                settings.Display.fromStruct(P.Settings.Display);
                settings.IO.fromStruct(P.Settings.IO);
                settings.PeaksPlot.fromStruct(P.Settings.PeaksPlot);
                settings.Box.fromStruct(P.Settings.Box);
            end

            % Project
            proj = model.STORMProject(P.Project.Name);
            proj.ID = string(P.Project.ID);
            proj.CreatedAt = P.Project.CreatedAt;
            proj.Version = string(P.Project.Version);
            proj.SourcePath = file;

            if isfield(P.Project,'DefaultPixelSize')
                ps = P.Project.DefaultPixelSize;
                proj.DefaultPixelSize = model.units.PixelSize(ps.Value, ps.Unit);
            end

            if isfield(P.Project,'LabelBank') && ~isempty(P.Project.LabelBank)
                proj.LabelBank = model.LabelRegistry.fromStruct(P.Project.LabelBank);
            else
                proj.LabelBank = model.LabelRegistry.default();
            end

            % Resolve image paths
            resolved = model.STORMProject.resolveImagePaths(P.Images, projectFolder);

            % If resolved comes back empty -> return empty, load fails
            if isempty(resolved)
                delete(proj); delete(settings);
                proj = []; settings = [];
                return
            end

            % Rebuild images/regions without eager pixel loads
            proj.ImagesDict = dictionary(string.empty(1,0), model.STORMImage.empty(1,0));
            proj.ImageOrder = string.empty(1,0);

            for k = 1:numel(resolved)
                img = model.STORMImage.fromStruct(resolved(k),proj);
                proj.ImagesDict(img.ID) = img;
                proj.ImageOrder(end+1) = img.ID;
            end

            % Restore active selection
            if isfield(P,'ActiveImageID') && strlength(string(P.ActiveImageID))>0
                proj.setActiveImage(string(P.ActiveImageID));
            end

            % indicate file exists on disk at SourcePath
            proj.isOnDisk = true;

        end

        function imagesOut = resolveImagePaths(imagesIn, projectFolder)
            imagesOut = imagesIn;

            % First pass: keep paths that still exist; also try project folder + filename.
            missing = false(1, numel(imagesOut));
            for k = 1:numel(imagesOut)
                p = string(imagesOut(k).SourcePath);
                if strlength(p) > 0 && isfile(p)
                    continue
                end

                % Try project folder + filename
                if strlength(projectFolder) > 0 && isfield(imagesOut(k),'FileName')
                    candidate = fullfile(projectFolder, imagesOut(k).FileName + imagesOut(k).Ext);
                    if isfile(candidate)
                        imagesOut(k).SourcePath = string(candidate);
                        continue
                    end
                end

                % not found -> mark as missing
                missing(k) = true;
            end

            if ~any(missing)
                return
            end

            % get cell array of missing filenames
            missingNames = [imagesOut(missing).SourcePath]';

            % user prompt (Command Window)
            msg = sprintf('Locate missing image files (%d missing):', nnz(missing));
            disp(msg);
            for i = 1:numel(missingNames)
                fprintf('%s\n',missingNames{i});
            end

            % find the GUI window
            fig = app.GUI.findGUI();

            % user prompt (modal dialog)
            selection = uiconfirm(fig,...
                [msg;"";missingNames],...
                'Image files missing',...
                "Options",["Locate","Cancel"],...
                "DefaultOption",1,...
                "CancelOption",2,...
                "Icon","warning");

            switch selection
                case "Locate"
                    fig.Visible = "off";
                    searchRoot = uigetdir(projectFolder, msg);
                    fig.Visible = "on";
                case "Cancel" % -> return empty
                    imagesOut = [];
                    return
            end

            % user cancels -> return empty, load fails
            if isequal(searchRoot, 0)
                imagesOut = [];
                return
            end

            % root path for search
            searchRoot = string(searchRoot);

            % Build filename->paths map via recursive dir
            files = dir(fullfile(searchRoot, "**", "*"));
            files = files(~[files.isdir]);

            % Resolve each missing entry by filename, prefer matching file size if available
            for k = find(missing)
                targetName = imagesOut(k).FileName + imagesOut(k).Ext;
                hits = files(string({files.name}) == targetName);

                if isempty(hits), continue, end

                % If only one hit, take it
                if isscalar(hits)
                    imagesOut(k).SourcePath = string(fullfile(hits.folder, hits.name));
                    continue
                end

                % Prefer matching file size if recorded
                sz = imagesOut(k).FileSizeBytes;
                if ~isnan(sz)
                    szHits = hits([hits.bytes] == sz);
                    if isscalar(szHits)
                        imagesOut(k).SourcePath = string(fullfile(szHits.folder, szHits.name));
                        continue
                    elseif ~isempty(szHits)
                        hits = szHits; % narrow
                    end
                end

                % Fallback: take most recently modified
                [~,idx] = max([hits.datenum]);
                imagesOut(k).SourcePath = string(fullfile(hits(idx).folder, hits(idx).name));
            end

            % recurse until all files found or empty returned (user cancels)
            imagesOut = model.STORMProject.resolveImagePaths(imagesOut, projectFolder);

        end

    end

    methods (Access=private)

        function P = toStruct(obj, settings)
            % Project meta
            P.Project.ID           = obj.ID;
            P.Project.Name         = obj.Name;
            P.Project.CreatedAt    = obj.CreatedAt;
            P.Project.Version      = obj.Version;
            P.Project.SourcePath   = obj.SourcePath;
            P.Project.DefaultPixelSize = struct('Value', obj.DefaultPixelSize.Value, 'Unit', obj.DefaultPixelSize.Unit);

            % Label bank
            P.Project.LabelBank = obj.LabelBank.toStruct();

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

end
