classdef STORMImage < handle
% model.STORMImage - image data and ROIs

    %% Identity/ownership
    properties
        ID (1,1) string
        Parent (:,1) model.STORMProject
    end

    %% Metadata
    properties
        Name (1,1) string = ""
        SourcePath (1,1) string = ""
        FileType (1,1) string = ""    % 'tif','png',...
        CreatedAt datetime = datetime('now')
        % PixelSize (1,1) double = NaN  % typically um/px
        % PixelSizeUnit (1,:) char = 'px'
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
        SelfIdx % index in Parent's order
        RegionArray % [1×M model.STORMRegion] in RegionOrder
        ActiveRegion  % model.STORMRegion or []
    end

    properties (Dependent)
        RegionNames
    end


    %% Image data (simple for now, can move later towards a per-image ViewState class)
    properties
        CData = []                     % numeric image array
        CLim (1,2) double
        RawIntensityRange (1,2) = [NaN NaN]
        RawIntensityClass (1,:) char
        RawIntensityLimits (1,2)
    end

    properties (Access = private)
        DisplayCLim_ (1,2) double = [NaN NaN];  % backing store
    end

    properties (Dependent)
        DisplayCLim
    end


    %% (Optional) events for UI sync
    events
        RegionAdded
        RegionRemoved
        ActiveRegionChanged
    end

    %% 
    methods

        function obj = STORMImage(parent, name, sourcePath, cdata)
            % obj.ID = model.STORMImage.newID();
            % if nargin >= 1 && ~isempty(parent),     obj.Parent = parent; end
            % if nargin >= 2 && ~isempty(name),       obj.Name = string(name); end
            % if nargin >= 3 && ~isempty(sourcePath), obj.SourcePath = string(sourcePath); end
            % if nargin >= 4 && ~isempty(cdata),      obj.CData = cdata; end
            % 
            % if strlength(obj.FileType)==0 && strlength(obj.SourcePath)>0
            %     [~,~,ext] = fileparts(char(obj.SourcePath));
            %     obj.FileType = string(lower(strip(ext,'.')));
            % end
            % 
            % %obj.RegionsDict     = dictionary;
            % obj.RegionsDict = dictionary(string.empty(1,0), model.STORMRegion.empty(1,0));
            % obj.RegionOrder = string.empty(1,0);
            % 
            % obj.RawIntensityRange = [min(min(obj.CData)) max(max(obj.CData))]; % actual value range of intensity values
            % obj.RawIntensityClass = class(obj.CData); % data type of intensity image 
            % obj.RawIntensityLimits = getrangefromclass(obj.CData); % full range of possible intensity values, given its class
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
                obj.RawIntensityRange = [NaN NaN];
                obj.RawIntensityClass = '';
                obj.RawIntensityLimits = [NaN NaN];
            else
                obj.RawIntensityRange = [min(min(obj.CData)) max(max(obj.CData))]; % actual value range of intensity values
                obj.RawIntensityClass = class(obj.CData); % data type of intensity image
                obj.RawIntensityLimits = getrangefromclass(obj.CData); % full range of possible intensity values, given its class
            end


        end

        function i = get.SelfIdx(obj)
            i = [];
            P = obj.Parent;
            if isempty(P) || ~isvalid(P), return; end
            ord = P.ImageOrder;
            if isempty(ord), return; end
            idx = find(ord == obj.ID, 1, 'first');
            if ~isempty(idx), i = idx; end
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

        % function addRegion(obj, regionObj)
        %     regionID = regionObj.ID;
        %     if ~isKey(obj.RegionsDict, regionID)
        %         obj.RegionsDict(regionID) = regionObj;
        %         obj.RegionOrder(end+1) = regionID;
        % 
        %         % set unique name using NextRegionOrdinal
        %         obj.RegionsDict(regionID).Name = sprintf('REGION-%03d',obj.NextRegionOrdinal);
        %         % increment the counter
        %         obj.NextRegionOrdinal = obj.NextRegionOrdinal + 1;
        %         % notify self -> RegionAdded
        %         notify(obj,'RegionAdded');
        %     end
        % end


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

            % prevent unnecessary updates, return if region is already active
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

    %% Region processing
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
            % arguments
            %     obj model.STORMImage
            %     reg model.STORMRegion
            %     config app.config.RunConfig
            % end
            % 
            % if isempty(reg), return; end
            % 
            % % get region CData
            % I = obj.regionSubimage(reg);
            % 
            % % get linescan info
            % data = reg.Linescan;
            % 
            % LinescanResults = model.analysis.Analyzer.run(I,data,config);
            % 
            % if isempty(LinescanResults)
            %     return
            % end
            % 
            % reg.updateLinescanResults(LinescanResults);



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
                clim = obj.RawIntensityRange;
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
            clim(1) = max(clim(1), obj.RawIntensityRange(1));
            clim(2) = min(clim(2), obj.RawIntensityRange(2));

            obj.DisplayCLim_ = clim;
        end

    end





    %% Region processing

    methods

        function I = regionSubimage(obj,reg)
            I = [];

            if isempty(reg), return; end

            s = reg.BoxSize;
            XY = reg.Center;

            I = zeros(s);

            % columns
            c1 = ceil(XY(1)-s/2); c2 = floor(XY(1) + s/2);
            % rows
            r1 = ceil(XY(2)-s/2); r2 = floor(XY(2) + s/2);

            I(:,:) = obj.CData(r1:r2,c1:c2);
        end

    end

    %% Export data
    methods

        % function T = exportRegionTable(obj)
        %     regs = obj.RegionArray;
        %     rows = repmat(struct(), 0, 1);
        % 
        %     for k = 1:numel(regs)
        %         rows(end+1,1) = regs(k).exportRow(); %#ok<AGROW>
        %     end
        % 
        %     if isempty(rows)
        %         T = table();  % empty if no regions
        %     else
        %         T = struct2table(rows);
        %     end
        % end


        function T = exportRegionTable(obj)
            regs = obj.RegionArray;
            if isempty(regs)
                T = table();
                return
            end

            T = cell2mat(arrayfun(@(r) struct2table(r.exportRow()),regs','UniformOutput',false));
        end


    end


    %% Friendly display
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

