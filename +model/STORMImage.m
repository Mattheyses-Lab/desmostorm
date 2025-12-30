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
        % monotonic counter used to set human-friendly unique region names
        NextRegionOrdinal (1,1) double = 1
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

    properties (Dependent)
        RegionNames
    end


    %% Image data and display settings
    properties
        CData = []                     % numeric image array
        CLim (1,2) double
        CDataRange (1,2) = [NaN NaN]
        CDataClass (1,:) char = ''
        CDataLimits (1,2) = [NaN NaN]
    end

    properties (Access = private)
        DisplayCLim_ (1,2) double = [NaN NaN];  % backing store
    end

    properties (Dependent)
        DisplayCLim
        Height (1,1) double
        Width (1,1) double
    end

    %% Events for UI sync
    events
        RegionAdded
        RegionRemoved
        ActiveRegionChanged
    end

    %% Constructor
    methods

        function obj = STORMImage(parent, name, sourcePath, cdata)
            arguments
                parent (:,1) model.STORMProject = model.STORMProject.empty()
                name (1,1) string = ""
                sourcePath (1,1) string = ""
                cdata = []
            end

            obj.ID = model.STORMImage.newID();
            obj.Parent = parent;
            obj.Name = name;
            obj.SourcePath = sourcePath;
            obj.CData = cdata;

            if strlength(obj.FileType)==0 && strlength(obj.SourcePath)>0
                [~,~,ext] = fileparts(char(obj.SourcePath));
                obj.FileType = string(lower(strip(ext,'.')));
            end

            obj.RegionsDict = dictionary(string.empty(1,0), model.STORMRegion.empty(1,0));
            obj.RegionOrder = string.empty(1,0);

            if isempty(obj.CData)
                obj.CDataRange = [NaN NaN];
                obj.CDataClass = '';
                obj.CDataLimits = [NaN NaN];
            else
                obj.CDataRange = [min(min(obj.CData)) max(max(obj.CData))]; % actual value range of intensity values
                obj.CDataClass = class(obj.CData); % data type of intensity image
                obj.CDataLimits = getrangefromclass(obj.CData); % full range of possible intensity values, given its class
            end


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

        function addRegion(obj, ID, Center, BoxSize)
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

    % Image-level processing
    methods

        function detectRegions(obj,config)
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

        function clim = get.DisplayCLim(obj)
            % If user has never set it, fall back to raw range:
            if any(isnan(obj.DisplayCLim_))
                clim = obj.CDataRange;
            else
                clim = obj.DisplayCLim_;
            end
        end

        function set.DisplayCLim(obj, clim)
            arguments
                obj
                clim (1,2) double
            end

            % optional: clamp & sort
            clim = sort(clim);
            clim(1) = max(clim(1), obj.CDataRange(1));
            clim(2) = min(clim(2), obj.CDataRange(2));

            obj.DisplayCLim_ = clim;
        end

        function val = get.Height(obj)
            if isempty(obj.CData)
                val = NaN;
            else
                val = size(obj.CData,1);
            end
        end

        function val = get.Width(obj)
            if isempty(obj.CData)
                val = NaN;
            else
                val = size(obj.CData,2);
            end
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


    % Display helpers
    methods

        function str = ImageInfoDisplayString(obj)
            str = sprintf('%s (%ix%i %s)',char(obj.Name),obj.Height,obj.Width,obj.CDataClass);
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
                'Size', size(obj.CData), ...
                'NumRegions', numEntries(obj.RegionsDict), ...
                'RegionOrder', obj.RegionOrder, ...
                'RegionArray', obj.RegionArray );
            groups = matlab.mixin.util.PropertyGroup(summary, 'STORMImage');
        end

    end


    methods (Static)

        function id = newID()
            id = string(char(java.util.UUID.randomUUID()));
        end

    end

end

