classdef STORMProject < handle & matlab.mixin.CustomDisplay
%STORMProject Stores project metadata, stores and manages images

    %% Identity/metadata
    properties
        ID (1,1) string = utils.uniqueID()
        Name (1,1) string = "Untitled"
        CreatedAt datetime = datetime('now')
        SchemaVersion (1,1) double = 1
        Version (1,1) string = app.Info.Version
    end

    %% Images (dictionary + order) and active selection
    properties (Access=private)
        ImagesDict = dictionary   % string ID -> model.STORMImage

        ActiveImageListener event.listener
        RegionListeners event.listener
    end

    properties
        ImageOrder (1,:) string = string.empty(1,0)
        ActiveImageID (1,1) string = ""
    end

    properties (Dependent)
        ImageNames
    end

    %% ergonomic array view, public, editor-friendly
    properties (Dependent, GetAccess=public, SetAccess=private)
        ImageArray   % [1×N model.STORMImage] in ImageOrder
        ActiveImage  % model.STORMImage or []
    end

    %% Project-wide defaults
    properties
        DefaultPixelSize model.units.PixelSize = model.units.PixelSize(1, 'px');
    end

    %% Events 

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
        end

    end

    %% Image management
    methods

        % add a new model.STORMImage for the image data located at filePath
        function imageID = addImageFromPath(obj, filePath)
            cdata = imread(filePath);
            [~,name,ext] = fileparts(filePath);
            img = model.STORMImage(obj, string(name)+string(ext), filePath, cdata);

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

    end

    %% Listener callbacks
    methods

        function onActiveImageChanged(obj)

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
