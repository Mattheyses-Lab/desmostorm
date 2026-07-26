classdef STORMImage < handle & matlab.mixin.CustomDisplay
%STORMImage Stores image data, stores and manages regions

    %% Identity/ownership/meta
    properties
        ID (1,1) string = matlabx.utils.text.uniqueID()
        Parent (:,1) desmostorm.model.STORMProject
        Name (1,1) string = ""
        SourcePath (1,1) string = ""
        FileType (1,1) string = ""    % 'tif','png',...
        CreatedAt datetime = datetime('now')
        PixelSizeOverride desmostorm.model.units.PixelSize = desmostorm.model.units.PixelSize.empty
    end

    properties (Dependent=true)
        PixelSize desmostorm.model.units.PixelSize
    end

    %% Image Data properties

    
    properties (Dependent)
        % 5D image container, note: assume all slices have same class and kind
        ImageData (1,1) matlabx.image.Image5D
    end


    properties (Access=private)
        % small internal view state
        ViewState_ struct = struct( ...
            'C', 1)
        % image data structure
        ImageData_ (:,1) matlabx.image.Image5D = matlabx.image.Image5D.empty()
        % per-channel info store
        Channels_ (1,:) struct = struct( ...
            'Size', {}, ...
            'Class', {}, ...
            'NativeDisplayRange', {}, ...
            'AutoDisplayRange', {}, ...
            'DisplayRange', {}, ...
            'DataRange', {})
    end


    properties (Dependent, SetAccess=private)
        isLoaded (1,1) logical
        SizeY (1,1) double
        SizeX (1,1) double
        SizeC (1,1) double
    end

    properties (Access=private)
        % YXCZT
        ImageSize_ (1,5) double = [NaN NaN NaN NaN NaN]
    end

    methods

        % --- ImageData ---
        function v = get.ImageData(obj), v = obj.ImageData_; end
    
        function set.ImageData(obj, val)
            arguments
                obj
                val (1,1) matlabx.image.Image5D
            end
    
            obj.ImageData_ = val;
            obj.cacheImageInfoFromFile_();
        end


        % --- isLoaded ---
        function tf = get.isLoaded(obj), tf = obj.ImageData_.IsLoaded; end
        % --- SizeY ---
        function sizeY = get.SizeY(obj), sizeY = obj.ImageData_.SizeY; end
        % --- SizeX ---
        function sizeX = get.SizeX(obj), sizeX = obj.ImageData_.SizeX; end
        % --- SizeC ---
        function sizeC = get.SizeC(obj), sizeC = obj.ImageData_.NumComponents; end

        % --- getPlane ---
        function I = getPlane(obj, c)
            I = obj.ImageData_.getPlane(c);
        end

        % --- getDisplayRange ---
        function val = getDisplayRange(obj, c)
            if isempty(obj.Channels_(c).DisplayRange)
                obj.cacheImageInfoFromBuffer_();
            end
            val = obj.Channels_(c).DisplayRange;
        end

        % --- setDisplayRange ---
        function setDisplayRange(obj, val, c)
            arguments
                obj
                val (1,2) double
                c (1,1)
            end

            val = sort(val);
            nativeRange = obj.Channels_(c).NativeDisplayRange;

            % If NativeDisplayRange known, clamp; otherwise accept as-is.
            if ~any(isnan(nativeRange))
                val(1) = max(val(1), nativeRange(1));
                val(2) = min(val(2), nativeRange(2));
            end

            obj.Channels_(c).DisplayRange = val;
        end

        % --- getDisplayRanges ---
        function out = getDisplayRanges(obj)
            out = cell(1,obj.SizeC);
            for C = 1:obj.SizeC
                out{C} = obj.getDisplayRange(C);
            end
        end

        % --- getAutoDisplayRange ---
        function val = getAutoDisplayRange(obj, c)
            if isempty(obj.Channels_(c).AutoDisplayRange)
                obj.cacheImageInfoFromBuffer_();
            end
            val = obj.Channels_(c).AutoDisplayRange;
        end

        % --- getAutoDisplayRanges ---
        function out = getAutoDisplayRanges(obj)
            out = cell(1,obj.SizeC);
            for C = 1:obj.SizeC
                out{C} = obj.getAutoDisplayRange(C);
            end
        end

        % --- getDataRange ---
        function val = getDataRange(obj, c)
            if isempty(obj.Channels_(c).DataRange)
                obj.cacheImageInfoFromBuffer_();
            end
            val = obj.Channels_(c).DataRange;
        end

    end

    % temporary wrappers during migration to Image5D
    properties (Dependent)
        CData
        CDataCell
        CDataClass
        CDataRange
        DisplayRange
        AutoDisplayRange
        Height (1,1) double
        Width (1,1) double
    end

    %% Temporary legacy getters during transition to Image5D
    methods

        function val = get.Height(obj)
            if any(isnan(obj.ImageSize_))
                obj.cacheImageInfoFromFile_();
            end
            val = obj.ImageData_.SizeY;
        end

        function val = get.Width(obj)
            if any(isnan(obj.ImageSize_))
                obj.cacheImageInfoFromFile_();
            end
            val = obj.ImageData_.SizeX;
        end

        function val = get.CDataClass(obj)
            if obj.SizeC < 1
                val = [];
                return
            end
            val = obj.ImageData_.Components(1).Class;
        end

        % first channel only
        function val = get.CData(obj)
            if obj.SizeC < 1
                val = [];
                return
            end
            val = obj.getPlane(1);
        end

        function val = get.CDataCell(obj)
            if obj.SizeC < 1
                val = {};
                return
            end
            val = cell(1,obj.SizeC);
            for c = 1:obj.SizeC
                val{c} = obj.getPlane(c);
            end
        end

        function val = get.CDataRange(obj)
            if obj.SizeC < 1
                val = [];
                return
            end
            val = obj.Channels_(1).DataRange;
        end

        function val = get.DisplayRange(obj)
            if obj.SizeC < 1
                val = [];
                return
            end
            val = obj.getDisplayRange(1);
        end

        function val = get.AutoDisplayRange(obj)
            if obj.SizeC < 1
                val = [];
                return
            end
            val = obj.getAutoDisplayRange(1);
        end

    end


    %% Regions (dictionary + order) and active selection
    properties (Access=private)
        RegionsDict = dictionary   % string id -> desmostorm.model.STORMRegion
    end

    properties
        RegionOrder (:,1) string = string.empty(0,1)
        ActiveRegionID (:,1) string = string.empty(0,1)
        SelectedRegionIDs (:,1) string = string.empty(0,1)
    end

    properties (Dependent, GetAccess=public, SetAccess=private)
        RegionArray     % [Nx1 desmostorm.model.STORMRegion] in RegionOrder
        ActiveRegion    % desmostorm.model.STORMRegion or []
    end

    properties(Access=?desmostorm.model.STORMProject)
        % monotonic counter used to set human-friendly unique region names
        NextRegionOrdinal (1,1) double = 1
    end

    properties (Dependent)
        RegionNames
    end

    %% Events for UI sync
    events
        RegionAdded
        RegionRemoved
        ActiveRegionChanged
        RegionSelectionChanged
    end

    %% Constructor
    methods

        function obj = STORMImage(parent, name, sourcePath, ID)
            arguments
                parent (:,1) desmostorm.model.STORMProject = desmostorm.model.STORMProject.empty()
                name (1,1) string = ""
                sourcePath (1,1) string = ""
                ID (1,1) string = ""     % allow ID injection on reload
            end

            if strlength(ID) > 0
                obj.ID = ID;
            else
                obj.ID = matlabx.utils.text.uniqueID();
            end

            obj.Parent = parent;
            obj.Name = name;
            obj.SourcePath = sourcePath;

            if strlength(obj.FileType)==0 && strlength(obj.SourcePath)>0
                [~,~,ext] = fileparts(char(obj.SourcePath));
                obj.FileType = string(lower(strip(ext,'.')));
            end

            obj.RegionsDict = dictionary(string.empty(1,0), desmostorm.model.STORMRegion.empty(1,0));
            obj.RegionOrder = string.empty(1,0);

            % create Image5D object from file
            obj.ImageData = matlabx.image.Image5D.fromFile(obj.SourcePath,"LoadOnCreate",false);
        end

    end

    %% CData lazy access + buffer management
    methods

        function clearImageDataBuffer(obj)
            obj.ImageData_.unload();
        end

        function bufferImageData(obj)
            obj.ImageData_.load();
            obj.cacheImageInfoFromBuffer_();
        end

    end


    %% Image data cache management
    methods (Access=private)

        function cacheImageInfoFromFile_(obj)

            if obj.ImageData_.IsLoaded
                obj.cacheImageInfoFromBuffer_();
                return
            end

            for c = 1:obj.SizeC
                obj.Channels_(c).Size = obj.ImageData_.Components(c).Size;
                obj.Channels_(c).Class = obj.ImageData_.Components(c).Class;
                obj.Channels_(c).NativeDisplayRange = obj.ImageData_.Components(c).NativeDisplayRange;
            end
            % assume same size per channel
            obj.ImageSize_ = obj.ImageData_.Components(1).Size;
        end

        function cacheImageInfoFromBuffer_(obj)
            for c = 1:obj.SizeC
                obj.Channels_(c).Size = obj.ImageData_.Components(c).Size;
                obj.Channels_(c).Class = obj.ImageData_.Components(c).Class;
                obj.Channels_(c).NativeDisplayRange = obj.ImageData_.Components(c).NativeDisplayRange;
                I = obj.getPlane(c);
                obj.Channels_(c).AutoDisplayRange = stretchlim(I,[0.1 0.9999])*obj.Channels_(c).NativeDisplayRange(2)';
                obj.Channels_(c).DataRange = [min(I(:)) max(I(:))];
                if isempty(obj.Channels_(c).DisplayRange)
                    obj.Channels_(c).DisplayRange = obj.Channels_(c).DataRange;
                end
            end
            % assume same size per channel
            obj.ImageSize_ = obj.ImageData_.Components(1).Size;
        end
    end

    %% Region management (find, add, remove, set active, etc.)
    methods

        function addRegion(obj, ID, Center, BoxSize, LabelID, LabelSource, opts)
            arguments
                obj             (1,1) desmostorm.model.STORMImage
                ID              (1,1) string
                Center          (1,2) double
                BoxSize         (1,1) double
                LabelID         (1,1) string = "unlabeled"
                LabelSource     (1,1) string = "user"
                opts.Score      (1,1) double = NaN
                opts.Notify     (1,1) logical = true
            end

            if ~isKey(obj.RegionsDict, ID)
                % create new STORMRegion
                reg = desmostorm.model.STORMRegion(obj,ID,Center,BoxSize,LabelID,LabelSource,opts.Score);
                % add it to the Regions dictionary
                obj.RegionsDict(ID) = reg;
                % add its ID to RegionOrder array
                obj.RegionOrder(end+1) = ID;
                % set unique name using NextRegionOrdinal
                obj.RegionsDict(ID).Name = sprintf('REGION-%03d',obj.NextRegionOrdinal);
                % increment the counter
                obj.NextRegionOrdinal = obj.NextRegionOrdinal + 1;
                % notify self -> RegionAdded
                if opts.Notify, notify(obj,'RegionAdded'); end
            end
        end

        function addRegionSilent(obj, ID, Center, BoxSize)
            if ~isKey(obj.RegionsDict, ID)
                % create new STORMRegion
                reg = desmostorm.model.STORMRegion(obj,ID,Center,BoxSize,"unlabeled","classifier");
                % add it to the Regions dictionary
                obj.RegionsDict(ID) = reg;
                % add its ID to RegionOrder array
                obj.RegionOrder(end+1) = ID;
                % set unique name using NextRegionOrdinal
                obj.RegionsDict(ID).Name = sprintf('REGION-%03d',obj.NextRegionOrdinal);
                % increment the counter
                obj.NextRegionOrdinal = obj.NextRegionOrdinal + 1;
            end
        end

        function removeRegion(obj, regionID)
            regionID = string(regionID);
            if isKey(obj.RegionsDict, regionID)
                % Clear active if removing it
                if obj.ActiveRegionID == regionID
                    obj.ActiveRegionID = strings(1,0);
                    notify(obj,'ActiveRegionChanged');
                end

                % remove(obj.RegionsDict, regionID);
                obj.RegionsDict = obj.RegionsDict.remove(regionID);
                
                obj.RegionOrder = obj.RegionOrder(obj.RegionOrder ~= regionID);
                obj.SelectedRegionIDs = obj.SelectedRegionIDs(obj.SelectedRegionIDs ~= regionID);
                % notify app that region was removed *after* mutating RegionOrder
                notify(obj,'RegionRemoved');
            end
        end

        function removeAllRegions(obj)
            % get Region array
            arr = obj.RegionArray;
            % remove one by one
            for i = 1:numel(arr)
                obj.removeRegion(arr(i).ID);
            end
        end

        function setActiveRegion(obj, regionID)
            regionID = string(regionID);
            % return if region is already active
            if regionID == obj.ActiveRegionID, return; end
            % invalid ID -> set empty
            if ~isKey(obj.RegionsDict, regionID)
                regionID = strings(1,0);
            end
            % set active and notify
            obj.ActiveRegionID = regionID;
            notify(obj,'ActiveRegionChanged');
        end



        % --- retrieve ---
        function tf = hasRegion(obj, regionID)
            tf = isKey(obj.RegionsDict, string(regionID));
        end

        function r = getRegion(obj, regionID)
            regionID = string(regionID);
            if isKey(obj.RegionsDict, regionID), r = obj.RegionsDict(regionID); else, r = []; end
        end

        function regs = getRegionsByLabelID(obj,labelID)
            if isempty(obj.RegionArray), regs = []; return; end
            regs = obj.RegionArray([obj.RegionArray(:).LabelID]==labelID);
        end


        % --- select ---
        function setRegionSelection(obj,IDs)
            if isempty(IDs), obj.clearRegionSelection(); return; end
            validIDs = IDs(obj.hasRegion(IDs));
            obj.SelectedRegionIDs = validIDs;
            notify(obj,'RegionSelectionChanged');
        end

        function clearRegionSelection(obj)
            obj.SelectedRegionIDs = string.empty(1,0);
            notify(obj,'RegionSelectionChanged');
        end


    end

    %% Region-level processing
    methods

        % --- process Region linescans ---

        function processAll(obj, config)
            % get Region array
            arr = obj.RegionArray;
            % return if empty
            if isempty(arr), return; end

            % otherwise, process each region
            for i = 1:numel(arr)
                obj.processRegionLinescan(arr(i),config);
            end
        end

        function processRegionLinescan(obj, reg, config)
            arguments
                obj desmostorm.model.STORMImage
                reg desmostorm.model.STORMRegion
                config desmostorm.config.RunConfig
            end

            if isempty(reg), return; end

            % get region CData cell
            I = obj.regionSubimageCell(reg);
            % get linescan info
            data = reg.ROI;

            % run region analyzer
            LinescanResults = desmostorm.analysis.Analyzer.run(I,data,config);

            if isempty(LinescanResults)
                return
            end

            reg.updateLinescanResults(LinescanResults);
        end

        function resetRegionROI(~,reg)
            % reset ROI to default
            reg.resetROI();
        end

        % --- autofit Region ROIs ---

        function autofitAllRegionROIs(obj, config)
            % get Region array
            arr = obj.RegionArray;
            % return if empty
            if isempty(arr), return; end

            % otherwise, process each region
            for i = 1:numel(arr)
                obj.autofitRegionROI(arr(i),config);
            end
        end

        function autofitRegionROI(obj, reg, config)
            arguments
                obj desmostorm.model.STORMImage
                reg desmostorm.model.STORMRegion
                config desmostorm.config.RunConfig
            end

            if isempty(reg), return; end

            % get region CData
            I = obj.regionSubimage(reg);
            % get linescan info
            ROI = desmostorm.analysis.Analyzer.autofitRegionROI(I, config);

            if isempty(ROI), return; end

            reg.updateROI(ROI);
        end

        % --- retrieve Region subimage ---

        function I = regionSubimage(obj,reg)
            if isempty(reg), I = []; return; end
            % region box size and center coordinates
            s = reg.BoxSize; XY = reg.Center;

            % preallocate array of zeros, type matched to raw intensity class
            I = zeros(s,obj.CDataClass);
            % columns
            c1 = ceil(XY(1)-s/2); c2 = floor(XY(1) + s/2);
            % rows
            r1 = ceil(XY(2)-s/2); r2 = floor(XY(2) + s/2);
            % extract region roi
            I(:,:) = obj.CData(r1:r2,c1:c2);
        end

        function I = regionSubimageCell(obj,reg)
            if isempty(reg), I = []; return; end
            % region box size and center coordinates
            s = reg.BoxSize; XY = reg.Center;
            % cell array of channels
            I = cell(1,obj.SizeC);
            % columns
            c1 = ceil(XY(1)-s/2); c2 = floor(XY(1) + s/2);
            % rows
            r1 = ceil(XY(2)-s/2); r2 = floor(XY(2) + s/2);
            % extract region ROI per channel
            for c = 1:obj.SizeC
                I{c} = zeros(s,obj.Channels_(c).Class);
                cPlane = obj.ImageData_.getPlane(c);
                I{c}(:,:) = cPlane(r1:r2,c1:c2);
            end
        end

    end

    %% Image-level processing
    methods

        function runClassifier(obj, net, propOpts)

            % remove any existing regions first
            obj.removeAllRegions();

            [ctrs,scores] = desmostorm.ml.proposePatchCenters(obj.SourcePath,net,...
                "BoxSize",          propOpts.BoxSize, ...
                "Stride",           propOpts.Stride, ...
                "ScoreThreshold",   propOpts.ScoreThreshold, ...
                "BatchSize",        propOpts.BatchSize, ...
                "NmsIoU",           propOpts.NmsIoU);

            % number of positive patches detected
            nFound = size(ctrs,1);

            desmostorm.Log.INFO(sprintf("Detected %d region(s) containing class: %s",nFound,propOpts.PositiveClass));

            % return if none found
            if isempty(ctrs)
                return
            end

            % add a new region for each location
            for i = 1:size(ctrs,1)
                ctr = ctrs(i,:);
                obj.addRegion(...
                    matlabx.utils.text.uniqueID(), ...
                    ctr, ...
                    propOpts.BoxSize, ...
                    "unlabeled", ...
                    "classifier", ...
                    "Notify", false, ...
                    "Score", scores(i));
            end

        end

    end

    %% Dependent getters/setters
    methods

        function arr = get.RegionArray(obj)
            if numel(obj.RegionOrder)==0
                arr = desmostorm.model.STORMRegion.empty();
                return
            end
            arr = obj.RegionsDict(obj.RegionOrder);
        end

        function reg = get.ActiveRegion(obj)
            reg = [];
            if isempty(obj.ActiveRegionID), return; end
            if isKey(obj.RegionsDict, obj.ActiveRegionID)
                reg = obj.RegionsDict(obj.ActiveRegionID);
            end
        end


        function names = get.RegionNames(obj)
            arr = obj.RegionArray;
            if isempty(arr)
                names = string.empty(1,0);
            else
                % names = arrayfun(@(reg) reg.ID, arr);
                names = arrayfun(@(reg) reg.Name, arr);
            end
        end

        function ps = get.PixelSize(obj)
            % 1) per-image override
            if ~isempty(obj.PixelSizeOverride)
                ps = obj.PixelSizeOverride;
                return;
            end

            % 2) project default
            if ~isempty(obj.Parent) && ~isempty(obj.Parent.DefaultPixelSize)
                ps = obj.Parent.DefaultPixelSize;
                return;
            end

            % 3) factory fallback (should rarely be hit)
            ps = desmostorm.model.units.PixelSize(1, 'px');
        end

        function set.PixelSize(obj, ps)
            % convenience: assigning PixelSize sets the override
            obj.PixelSizeOverride = ps;
        end

    end

    %% Display helpers
    methods

        function str = ImageInfoDisplayString(obj)
            str = sprintf('%s (%ix%i %s)',char(obj.Name),obj.Height,obj.Width,obj.CDataClass);
        end

        function name = shortName(obj)
            str = strsplit(obj.Name,'.');
            name = str{1};
        end

    end

    %% Friendlier Command Window / Variable Editor display
    methods (Access=protected)

        function groups = getPropertyGroups(obj)
            summary = struct( ...
                'Name', obj.Name, ...
                'SourcePath', obj.SourcePath, ...
                'FileType', obj.FileType, ...
                'PixelSize', obj.PixelSize.stringDisplay(), ...
                'Size', obj.ImageSize_, ...
                'NumRegions', numEntries(obj.RegionsDict), ...
                'RegionOrder', obj.RegionOrder, ...
                'RegionArray', obj.RegionArray );
            groups = matlab.mixin.util.PropertyGroup(summary, 'STORMImage');
        end

    end

    %% Serialization helpers
    methods(Access=?desmostorm.model.STORMProject)

        function I = toStruct(obj)

            if ~isfile(obj.SourcePath)
                error("model:STORMImage:toStruct:InvalidFile","Cannot find file: %s",obj.SourcePath)
            end

            I.ID         = obj.ID;
            I.Name       = obj.Name;
            I.SourcePath = obj.SourcePath;
            I.FileType   = obj.FileType;
            I.CreatedAt  = obj.CreatedAt;

            % Fingerprint hints in case we need to locate missing image files on load
            [~,nm,ex] = fileparts(obj.SourcePath);
            d = dir(obj.SourcePath);
            I.FileName          = string(nm);
            I.Ext               = string(ex);
            I.FileSizeBytes     = d.bytes;
            I.ModifiedDatenum   = d.datenum;

            % Pixel size override (if set)
            if ~isempty(obj.PixelSizeOverride)
                I.PixelSizeOverride = struct('Value', obj.PixelSizeOverride.Value, 'Unit', obj.PixelSizeOverride.Unit);
            else
                I.PixelSizeOverride = [];
            end

            % Regions
            I.NextRegionOrdinal = obj.NextRegionOrdinal;
            I.RegionOrder = obj.RegionOrder;

            % get Region objects
            regs = obj.RegionArray;
            % initialize empty Regions struct
            % nRegions = numel(regs);
            % 
            % if nRegions == 0
            %     I.Regions = struct.empty();
            %     return
            % end

            % I.Regions = struct.empty();

            if numel(regs)==0
                I.Regions = struct.empty();
                return
            end

            % populate with struct for each Region
            for r = 1:numel(regs)
                reg = regs(r);
                I.Regions(r) = reg.toStruct();
            end

        end

    end

    %% Static
    methods (Static)

        function img = fromStruct(S,proj)

            name = string(S.Name);
            path = string(S.SourcePath);

            img = desmostorm.model.STORMImage(proj, name, path, string(S.ID));

            % restore per-image settings/state
            img.CreatedAt = S.CreatedAt;

            if ~isempty(S.PixelSizeOverride)
                img.PixelSizeOverride = desmostorm.model.units.PixelSize(S.PixelSizeOverride.Value, S.PixelSizeOverride.Unit);
            end

            img.NextRegionOrdinal = S.NextRegionOrdinal;

            % rebuild regions
            if isfield(S,'Regions') && ~isempty(S.Regions)
                desmostorm.Log.INFO("Rebuilding regions...")
                % number of Regions (one struct entry each)
                nRegions = numel(S.Regions);
                % iterate over all entries
                for r = 1:nRegions
                    % get struct for this Region
                    R = S.Regions(r);
                    % update log
                    desmostorm.Log.INFO(sprintf("Region (%i/%i): %s",r,nRegions,R.Name));
                    % create Region from struct
                    reg = desmostorm.model.STORMRegion.fromStruct(R,img);
                    % add it to the Regions dictionary
                    img.RegionsDict(reg.ID) = reg;
                end
                % restore region order exactly
                if isfield(S,'RegionOrder')
                    img.RegionOrder = string(S.RegionOrder);
                end
            end

        end

    end

    %% Hidden debug entry point
    methods (Hidden)

        function debug(obj)
            debug
        end

    end

end
