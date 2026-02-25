classdef STORMImage < handle & matlab.mixin.CustomDisplay
%STORMImage Stores image data, stores and manages regions

    %% Identity/ownership/meta
    properties
        ID (1,1) string = utils.uniqueID()
        Parent (:,1) model.STORMProject
        Name (1,1) string = ""
        SourcePath (1,1) string = ""
        FileType (1,1) string = ""    % 'tif','png',...
        CreatedAt datetime = datetime('now')
        PixelSizeOverride model.units.PixelSize = model.units.PixelSize.empty
    end

    properties (Dependent=true)
        PixelSize model.units.PixelSize
    end

    %% Regions (dictionary + order) and active selection
    properties (Access=private)
        RegionsDict = dictionary   % string id -> model.STORMRegion
    end

    properties
        RegionOrder (1,:) string = string.empty(1,0)
        ActiveRegionID (1,1) string = ""
    end

    properties (Dependent, GetAccess=public, SetAccess=private)
        % SelfIdx % index in Parent's order
        RegionArray % [1×M model.STORMRegion] in RegionOrder
        ActiveRegion  % model.STORMRegion or []
    end

    properties(Access=?model.STORMProject)
        % monotonic counter used to set human-friendly unique region names
        NextRegionOrdinal (1,1) double = 1
    end

    properties (Dependent)
        RegionNames
    end

    %% Image data (LAZY) and display settings
    properties (Dependent)
        CData                  % numeric image array (lazy-loaded)
        Height (1,1) double
        Width (1,1) double
    end

    properties
        CLim (1,2) double
        CDataRange (1,2) = [NaN NaN]     % filled after first load
        CDataLimits (1,2) = [NaN NaN]    % filled after first load
        CDataClass (1,:) char = ''       % filled after first load
    end

    properties (Access=private)
        CDataBuffer = []                % backing store
        CDataState (1,1) string = "unloaded"  % "unloaded"|"loaded"|"failed"
        CDataLoadError = []             % store last exception, if failed

        ImageSize_ (1,2) double = [NaN NaN]   % [H W] from imfinfo (cheap), if available

        DisplayCLim_ (1,2) double = [NaN NaN]  % backing store
        AutoDisplayCLim_ (1,2) double = [NaN NaN]
    end

    properties (Dependent)
        DisplayCLim
        AutoDisplayCLim
    end

    %% Events for UI sync
    events
        RegionAdded
        RegionRemoved
        ActiveRegionChanged
    end

    %% Constructor
    methods

        function obj = STORMImage(parent, name, sourcePath, ID)
            arguments
                parent (:,1) model.STORMProject = model.STORMProject.empty()
                name (1,1) string = ""
                sourcePath (1,1) string = ""
                ID (1,1) string = ""     % allow ID injection on reload
            end

            if strlength(ID) > 0
                obj.ID = ID;
            else
                %obj.ID = model.STORMImage.newID();
                obj.ID = utils.uniqueID();
            end

            obj.Parent = parent;
            obj.Name = name;
            obj.SourcePath = sourcePath;

            if strlength(obj.FileType)==0 && strlength(obj.SourcePath)>0
                [~,~,ext] = fileparts(char(obj.SourcePath));
                obj.FileType = string(lower(strip(ext,'.')));
            end

            obj.RegionsDict = dictionary(string.empty(1,0), model.STORMRegion.empty(1,0));
            obj.RegionOrder = string.empty(1,0);

            % cache image size from file
            obj.cacheImageSizeFromFile();

        end

    end



    %% CData lazy access + buffer management
    methods
        function I = get.CData(obj)
            % Lazy-load raw image data on first access.
            if obj.CDataState == "loaded"
                I = obj.CDataBuffer;
                return
            end
            if obj.CDataState == "failed"
                rethrow(obj.CDataLoadError);
            end

            % Attempt load
            try
                if strlength(obj.SourcePath)==0
                    error('STORMImage:CDataMissingPath', 'Cannot load CData: SourcePath is empty.');
                end
                if ~isfile(obj.SourcePath)
                    error('STORMImage:CDataMissingFile', 'Cannot load CData: file not found: %s', obj.SourcePath);
                end

                obj.CDataBuffer = imread(obj.SourcePath);
                obj.CDataState = "loaded";
                obj.updateCDataStatsFromBuffer();
                I = obj.CDataBuffer;

            catch ME
                obj.CDataState = "failed";
                obj.CDataLoadError = ME;
                rethrow(ME);
            end
        end

        function clearCDataBuffer(obj)
            obj.CDataBuffer = [];
            obj.CDataState = "unloaded";
            obj.CDataLoadError = [];
            % Keep cached ImageSize_ (so Height/Width still cheap)
        end

        function bufferCData(obj)
            obj.CDataBuffer = imread(obj.SourcePath);
            obj.CDataState = "loaded";
        end

        function updateCDataStats(obj)
            switch obj.CDataState
                case "loaded"
                    obj.updateCDataStatsFromBuffer();
                case "unloaded"
                    obj.updateCDataStatsFromFile();
                case "failed"
                    rethrow(obj.CDataLoadError);
            end
        end

    end

    %% Dependent getters/setters related to CData
    methods

        function val = get.Height(obj)
            if ~any(isnan(obj.ImageSize_))
                val = obj.ImageSize_(1);
            elseif obj.CDataState == "loaded"
                val = size(obj.CDataBuffer,1);
            else
                obj.cacheImageSizeFromFile();
                val = obj.ImageSize_(1);
            end
        end

        function val = get.Width(obj)
            if ~any(isnan(obj.ImageSize_))
                val = obj.ImageSize_(2);
            elseif obj.CDataState == "loaded"
                val = size(obj.CDataBuffer,2);
            else
                obj.cacheImageSizeFromFile();
                val = obj.ImageSize_(2);
            end
        end

        function clim = get.DisplayCLim(obj)
            if any(isnan(obj.DisplayCLim_))
                clim = obj.CDataRange;  % if still NaN, UI can decide how to handle
            else
                clim = obj.DisplayCLim_;
            end
        end

        function set.DisplayCLim(obj, clim)

            arguments
                obj
                clim (1,2) double
            end

            clim = sort(clim);

            % If CDataRange known, clamp; otherwise accept as-is.
            if ~any(isnan(obj.CDataRange))
                clim(1) = max(clim(1), obj.CDataRange(1));
                clim(2) = min(clim(2), obj.CDataRange(2));
            end

            obj.DisplayCLim_ = clim;
        end

        function clim = get.AutoDisplayCLim(obj)

            if any(isnan(obj.AutoDisplayCLim_))
                obj.updateCDataStats();
            end

            clim = obj.AutoDisplayCLim_;
        end

    end

    %% Private helpers
    methods (Access=private)
        
        function cacheImageSizeFromFile(obj)
            if strlength(obj.SourcePath)==0 || ~isfile(obj.SourcePath)
                return
            end
            try
                info = imfinfo(obj.SourcePath);
                obj.ImageSize_ = [info(1).Height, info(1).Width];
            catch
                % leave as NaN; worst case size forces a load later
            end
        end

        function updateCDataStatsFromBuffer(obj)
            if isempty(obj.CDataBuffer)
                obj.CDataRange = [NaN NaN];
                obj.CDataClass = '';
                obj.CDataLimits = [NaN NaN];
                return
            end

            % store image info
            obj.ImageSize_ = [size(obj.CDataBuffer,1), size(obj.CDataBuffer,2)];
            obj.CDataClass = class(obj.CDataBuffer);
            obj.CDataLimits = getrangefromclass(obj.CDataBuffer);
            obj.CDataRange = [min(obj.CDataBuffer(:)), max(obj.CDataBuffer(:))];

            % store display autolimits
            obj.AutoDisplayCLim_ = stretchlim(obj.CDataBuffer,[0.1 0.9999])*obj.CDataLimits(2);
        end

        function updateCDataStatsFromFile(obj)
            obj.bufferCData();
            obj.updateCDataStatsFromBuffer();
            obj.clearCDataBuffer();
        end

    end

    %% Region management (find, add, remove, set active, etc.)
    methods

        function arr = get.RegionArray(obj)
            if numel(obj.RegionOrder)==0
                arr = model.STORMRegion.empty();
                return
            end
            arr = obj.RegionsDict(obj.RegionOrder);
        end

        function addRegion(obj, ID, Center, BoxSize, LabelID)
            if ~isKey(obj.RegionsDict, ID)
                % create new STORMRegion
                reg = model.STORMRegion(obj,ID,Center,BoxSize,LabelID);
                % add it to the Regions dictionary
                obj.RegionsDict(ID) = reg;
                % add its ID to RegionOrder array
                obj.RegionOrder(end+1) = ID;
                % set unique name using NextRegionOrdinal
                obj.RegionsDict(ID).Name = sprintf('REGION-%03d',obj.NextRegionOrdinal);
                % increment the counter
                obj.NextRegionOrdinal = obj.NextRegionOrdinal + 1;
                % notify self -> RegionAdded
                notify(obj,'RegionAdded');
            end
        end

        function addRegionSilent(obj, ID, Center, BoxSize)
            if ~isKey(obj.RegionsDict, ID)
                % create new STORMRegion
                reg = model.STORMRegion(obj,ID,Center,BoxSize);
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
                    obj.ActiveRegionID = "";
                    notify(obj,'ActiveRegionChanged');
                end

                remove(obj.RegionsDict, regionID);
                obj.RegionOrder = obj.RegionOrder(obj.RegionOrder ~= regionID);
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

            if strlength(regionID)==0
                obj.ActiveRegionID = "";
                notify(obj,'ActiveRegionChanged');
                return
            end
            if isKey(obj.RegionsDict, regionID)
                obj.ActiveRegionID = regionID;
                notify(obj,'ActiveRegionChanged');
            end
        end

        function tf = hasRegion(obj, regionID)
            tf = isKey(obj.RegionsDict, string(regionID));
        end

        function r = getRegion(obj, regionID)
            regionID = string(regionID);
            if isKey(obj.RegionsDict, regionID), r = obj.RegionsDict(regionID); else, r = []; end
        end

    end

    %% Region-level processing
    methods

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
                obj model.STORMImage
                reg model.STORMRegion
                config app.config.RunConfig
            end

            if isempty(reg), return; end

            % get region CData
            I = obj.regionSubimage(reg);
            % get linescan info
            data = reg.Linescan;

            % run region analyzer
            LinescanResults = model.analysis.Analyzer.run(I,data,config);

            if isempty(LinescanResults)
                return
            end

            reg.updateLinescanResults(LinescanResults);
        end

        function resetRegionLinescan(~,reg)
            % reset all linescan params to NaN
            reg.resetLinescan();
        end

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

    end

    %% Image-level processing
    methods

        function detectRegions(obj, config)
            arguments
                obj model.STORMImage
                config app.config.RunConfig
            end

            % remove any existing regions first
            obj.removeAllRegions();

            % detect new region locations
            ctrs = model.analysis.image.detectRegions(obj.CData,"BoxSize",config.BoxSize);

            % return if none found
            if isempty(ctrs)
                return
            end

            % add a new region for each location
            for i = 1:size(ctrs,1)
                ctr = ctrs(i,:);
                obj.addRegionSilent(string(char(java.util.UUID.randomUUID())), ctr, config.BoxSize);
            end

            % notify self -> RegionAdded
            notify(obj,'RegionAdded');

        end

    end

    %% Dependent getters/setters
    methods

        function reg = get.ActiveRegion(obj)
            reg = [];
            if strlength(obj.ActiveRegionID)==0, return; end
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
            ps = model.units.PixelSize(1, 'px');
        end

        function set.PixelSize(obj, ps)
            % convenience: assigning PixelSize sets the override
            obj.PixelSizeOverride = ps;
        end

    end

    %% Export data
    methods

        function T = exportRegionTable(obj)
            regs = obj.RegionArray;
            if isempty(regs)
                T = table();
                return
            end

            T = cell2mat(arrayfun(@(r) struct2table(r.exportRow()),regs','UniformOutput',false));
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
                'CDataState', obj.CDataState, ...
                'NumRegions', numEntries(obj.RegionsDict), ...
                'RegionOrder', obj.RegionOrder, ...
                'RegionArray', obj.RegionArray );
            groups = matlab.mixin.util.PropertyGroup(summary, 'STORMImage');
        end

    end

    %% Serialization helpers
    methods(Access=?model.STORMProject)

        function I = toStruct(obj)
            I.ID         = obj.ID;
            I.Name       = obj.Name;
            I.SourcePath = obj.SourcePath;
            I.FileType   = obj.FileType;
            I.CreatedAt  = obj.CreatedAt;

            % Fingerprint hints
            I.FileName = string.empty;
            I.Ext = string.empty;
            I.FileSizeBytes = NaN;
            I.ModifiedDatenum = NaN;

            if strlength(obj.SourcePath) > 0
                [~,nm,ex] = fileparts(obj.SourcePath);
                I.FileName = string(nm);
                I.Ext = string(ex);
                if isfile(obj.SourcePath)
                    d = dir(obj.SourcePath);
                    I.FileSizeBytes = d.bytes;
                    I.ModifiedDatenum = d.datenum;
                end
            end

            % Pixel size override (if set)
            if ~isempty(obj.PixelSizeOverride)
                I.PixelSizeOverride = struct('Value', obj.PixelSizeOverride.Value, 'Unit', obj.PixelSizeOverride.Unit);
            else
                I.PixelSizeOverride = [];
            end

            % Display limits
            I.DisplayCLim = obj.DisplayCLim;

            % Regions / naming counter
            I.NextRegionOrdinal = obj.NextRegionOrdinal;
            I.RegionOrder = obj.RegionOrder;

            regs = obj.RegionArray;
            I.Regions = repmat(struct(), 1, numel(regs));
            for r = 1:numel(regs)
                reg = regs(r);
                I.Regions(r).ID      = reg.ID;
                I.Regions(r).Name    = reg.Name;
                I.Regions(r).CreatedAt = reg.CreatedAt;
                I.Regions(r).Center  = reg.Center;
                I.Regions(r).BoxSize = reg.BoxSize;
                I.Regions(r).Linescan = reg.Linescan;
                I.Regions(r).LabelId = reg.LabelId;
            end
        end

    end

    %% Static
    methods (Static)

        function img = fromStruct(S,proj)

            name = string(S.Name);
            path = string(S.SourcePath);

            img = model.STORMImage(proj, name, path, string(S.ID));

            % restore per-image settings/state
            img.CreatedAt = S.CreatedAt;

            if ~isempty(S.PixelSizeOverride)
                img.PixelSizeOverride = model.units.PixelSize(S.PixelSizeOverride.Value, S.PixelSizeOverride.Unit);
            end

            img.DisplayCLim = S.DisplayCLim;

            img.NextRegionOrdinal = S.NextRegionOrdinal;

            % update CData stats
            img.updateCDataStats();

            % rebuild regions
            if isfield(S,'Regions') && ~isempty(S.Regions)
                for r = 1:numel(S.Regions)
                    R = S.Regions(r);
                    img.addRegionSilent(string(R.ID), R.Center, R.BoxSize);
                    reg = img.getRegion(string(R.ID));
                    reg.Name = string(R.Name);

                    if isfield(R,'CreatedAt') && ~isempty(R.CreatedAt)
                        reg.CreatedAt = R.CreatedAt;
                    end

                    if isfield(R,'Linescan') && ~isempty(R.Linescan)
                        reg.Linescan = R.Linescan;
                    end

                    if isfield(R,'LabelId') && ~isempty(R.LabelId)
                        reg.LabelId = string(R.LabelId);
                    end
                end
                % restore region order exactly
                if isfield(S,'RegionOrder')
                    img.RegionOrder = string(S.RegionOrder);
                end
            end

        end

    end

end

