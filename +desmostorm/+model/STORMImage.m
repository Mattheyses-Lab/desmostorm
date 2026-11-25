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

classdef STORMImage < handle & matlab.mixin.CustomDisplay
%STORMImage Stores image data, stores and manages regions

    %% Identity/ownership/meta
    properties
        % Stable identifier used to look up this record.
        ID (1,1) string = matlabx.utils.text.uniqueID()
        % Model object that owns this record.
        Parent (:,1) desmostorm.model.STORMProject
        % Display name shown in the application.
        Name (1,1) string = ""
        % Path to the source file.
        SourcePath (1,1) string = ""
        % File type.
        FileType (1,1) string = ""    % 'tif','png',...
        CreatedAt datetime = datetime('now')
        % Pixel size override.
        PixelSizeOverride desmostorm.model.units.PixelSize = desmostorm.model.units.PixelSize.empty
    end

    properties (Dependent=true)
        % Physical calibration for the image pixels.
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
            'DataRange', {}, ...
            'ContrastPercentiles', {})
    end


    properties (SetAccess=private)
        % Project channel IDs in source component order.
        ChannelIDs (1,:) string = strings(1,0)
    end

    properties (Dependent, SetAccess=private)
        % Whether pixel data is currently loaded.
        isLoaded (1,1) logical
        % Image height in pixels.
        SizeY (1,1) double
        % Image width in pixels.
        SizeX (1,1) double
        % Number of source image components.
        SizeC (1,1) double
    end

    properties (Access=private)
        % YXCZT
        ImageSize_ (1,5) double = [NaN NaN NaN NaN NaN]
    end

    methods

        % --- ImageData ---
        %GET.IMAGEDATA Return the image data.
        function v = get.ImageData(obj), v = obj.ImageData_; end
    
        function set.ImageData(obj, val)
        %SET.IMAGEDATA Set the image data.
            arguments
                obj
                val (1,1) matlabx.image.Image5D
            end
    
            obj.ImageData_ = val;
            obj.cacheImageInfoFromFile_();
        end


        % --- isLoaded ---
        %GET.ISLOADED Report whether the source pixel data is in memory.
        function tf = get.isLoaded(obj), tf = obj.ImageData_.IsLoaded; end
        % --- SizeY ---
        %GET.SIZEY Return the source height in pixels.
        function sizeY = get.SizeY(obj), sizeY = obj.ImageData_.SizeY; end
        % --- SizeX ---
        %GET.SIZEX Return the source width in pixels.
        function sizeX = get.SizeX(obj), sizeX = obj.ImageData_.SizeX; end
        % --- SizeC ---
        %GET.SIZEC Return the source component count.
        function sizeC = get.SizeC(obj), sizeC = obj.ImageData_.NumComponents; end

        % --- getPlane ---
        function I = getPlane(obj, c)
        %GETPLANE Return plane.
            % Pixel data for the image being processed.
            I = obj.ImageData_.getPlane(c);
        end

        % --- getDisplayRange ---
        function val = getDisplayRange(obj, c)
        %GETDISPLAYRANGE Return display range.
            if isempty(obj.Channels_(c).DisplayRange)
                obj.cacheImageInfoFromBuffer_();
            end
            val = obj.Channels_(c).DisplayRange;
        end

        % --- setDisplayRange ---
        function setDisplayRange(obj, val, c)
        %SETDISPLAYRANGE Set display range.
            arguments
                obj
                val (1,2) double
                c (1,1)
            end

            obj.Channels_(c).DisplayRange = sort(val);
        end

        % --- getDisplayRanges ---
        function out = getDisplayRanges(obj)
        %GETDISPLAYRANGES Return display ranges.
            out = cell(1,obj.SizeC);
            % Process each source channel in its original component order.
            for C = 1:obj.SizeC
                out{C} = obj.getDisplayRange(C);
            end
        end

        % --- getAutoDisplayRange ---
        function val = getAutoDisplayRange(obj, c)
        %GETAUTODISPLAYRANGE Return auto display range.
            if isempty(obj.Channels_(c).AutoDisplayRange)
                obj.cacheImageInfoFromBuffer_();
            end
            val = obj.Channels_(c).AutoDisplayRange;
        end

        % --- getAutoDisplayRanges ---
        function out = getAutoDisplayRanges(obj)
        %GETAUTODISPLAYRANGES Return auto display ranges.
            out = cell(1,obj.SizeC);
            % Process each source channel in its original component order.
            for C = 1:obj.SizeC
                out{C} = obj.getAutoDisplayRange(C);
            end
        end

        function [value,bounds,reset] = displayLimits(obj,c,policy)
        %DISPLAYLIMITS Resolve the visible bounds, slider range, and reset value for one source channel.
            bounds = obj.getDataRange(c);
            if any(~isfinite(bounds)), bounds = [0 1]; end
            if bounds(1) >= bounds(2)
                bounds(2) = bounds(1)+max(1,eps(bounds(1)));
            end
            bounds = obj.normalizeDisplayRange(c,bounds);
            reset = bounds;
            if policy.KeepAuto
                value = obj.automaticDisplayRange(c,policy.Method,bounds);
            elseif policy.Lock && ~isempty(policy.LockedRange)
                value = policy.LockedRange;
            else
                value = obj.getDisplayRange(c);
                if any(~isfinite(value)) || value(1) >= value(2)
                    value = bounds;
                end
            end
            value = obj.normalizeDisplayRange(c,value);
            bounds = [min(bounds(1),value(1)),max(bounds(2),value(2))];
        end

        function value = normalizeDisplayRange(obj,c,value)
        %NORMALIZEDISPLAYRANGE Normalize display range.
            if ~any(startsWith(string(obj.Channels_(c).Class),["int","uint"]))
                return
            end
            native = obj.Channels_(c).NativeDisplayRange;
            value = min(max(round(value),native(1)),native(2));
            if value(1) == value(2)
                if value(2) < native(2)
                    value(2) = value(2)+1;
                else
                    value(1) = value(1)-1;
                end
            end
        end

        function value = automaticDisplayRange(obj,c,method,bounds)
        %AUTOMATICDISPLAYRANGE Calculate intensity limits with the selected scaling method.
            switch string(method)
                case "Zero to max"
                    value = [0 bounds(2)];
                case "Data range"
                    value = bounds;
                otherwise
                    if isempty(obj.Channels_(c).ContrastPercentiles)
                        pixels = double(obj.getPlane(c));
                        pixels = pixels(isfinite(pixels));
                        if isempty(pixels), pixels = bounds; end
                        obj.Channels_(c).ContrastPercentiles = ...
                            prctile(pixels(:),[0.5 1 99.5 99.9 99.95]);
                    end
                    cuts = obj.Channels_(c).ContrastPercentiles;
                    switch string(method)
                        case "Light contrast"
                            value = cuts([1 5]);
                        case "Medium contrast"
                            value = cuts([1 4]);
                        case "Strong contrast"
                            value = cuts([2 3]);
                    end
            end
            if any(~isfinite(value)) || value(1) >= value(2)
                value = bounds;
            end
        end

        % --- getDataRange ---
        function val = getDataRange(obj, c)
        %GETDATARANGE Return data range.
            if isempty(obj.Channels_(c).DataRange)
                obj.cacheImageInfoFromBuffer_();
            end
            val = obj.Channels_(c).DataRange;
        end

    end

    % temporary wrappers during migration to Image5D
    properties (Dependent)
        % Pixel data for the current image component.
        CData
        % Pixel data split into a cell for each source component.
        CDataCell
        % Storage class of the source pixel data.
        CDataClass
        % Intensity bounds for the source pixel data.
        CDataRange
        % Display range.
        DisplayRange
        % Auto display range.
        AutoDisplayRange
        % Height.
        Height (1,1) double
        % Width.
        Width (1,1) double
    end

    %% Temporary legacy getters during transition to Image5D
    methods

        function val = get.Height(obj)
        %GET.HEIGHT Return the height.
            if any(isnan(obj.ImageSize_))
                obj.cacheImageInfoFromFile_();
            end
            val = obj.ImageData_.SizeY;
        end

        function val = get.Width(obj)
        %GET.WIDTH Return the width.
            if any(isnan(obj.ImageSize_))
                obj.cacheImageInfoFromFile_();
            end
            val = obj.ImageData_.SizeX;
        end

        function val = get.CDataClass(obj)
        %GET.CDATACLASS Return the storage class of the source pixels.
            if obj.SizeC < 1
                val = [];
                return
            end
            val = obj.ImageData_.Components(1).Class;
        end

        % first channel only
        function val = get.CData(obj)
        %GET.CDATA Return the source pixel array.
            if obj.SizeC < 1
                val = [];
                return
            end
            val = obj.getPlane(1);
        end

        function val = get.CDataCell(obj)
        %GET.CDATACELL Return source pixels in a separate cell for each component.
            if obj.SizeC < 1
                val = {};
                return
            end
            val = cell(1,obj.SizeC);
            % Process each source channel in its original component order.
            for c = 1:obj.SizeC
                val{c} = obj.getPlane(c);
            end
        end

        function val = get.CDataRange(obj)
        %GET.CDATARANGE Return the intensity bounds for the first component.
            if obj.SizeC < 1
                val = [];
                return
            end
            val = obj.Channels_(1).DataRange;
        end

        function val = get.DisplayRange(obj)
        %GET.DISPLAYRANGE Return the display range.
            if obj.SizeC < 1
                val = [];
                return
            end
            val = obj.getDisplayRange(1);
        end

        function val = get.AutoDisplayRange(obj)
        %GET.AUTODISPLAYRANGE Return the auto display range.
            if obj.SizeC < 1
                val = [];
                return
            end
            val = obj.getAutoDisplayRange(1);
        end

    end


    %% Regions (dictionary + order) and active selection
    properties (Access=private)
        % Lookup table for regions.
        RegionsDict = dictionary   % string id -> desmostorm.model.STORMRegion
    end

    properties
        % Region IDs in display order within the image.
        RegionOrder (:,1) string = string.empty(0,1)
        % ID of the region currently in focus.
        ActiveRegionID (:,1) string = string.empty(0,1)
        % IDs checked for batch region operations.
        SelectedRegionIDs (:,1) string = string.empty(0,1)
    end

    properties (Dependent, GetAccess=public, SetAccess=private)
        % Regions in display order within this image.
        RegionArray     % [Nx1 desmostorm.model.STORMRegion] in RegionOrder
        % Region currently in focus.
        ActiveRegion    % desmostorm.model.STORMRegion or []
    end

    properties(Access=?desmostorm.model.STORMProject)
        % monotonic counter used to set human-friendly unique region names
        NextRegionOrdinal (1,1) double = 1
    end

    properties (Dependent)
        % Region names.
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
        %STORMIMAGE Initialize an image record and its source-backed image data.
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

    methods
        function setChannelIDs(obj,ids)
        %SETCHANNELIDS Set channel IDs.
            ids = reshape(string(ids),1,[]);
            assert(numel(ids) == obj.SizeC && all(strlength(ids) > 0) && ...
                numel(unique(ids)) == numel(ids), ...
                'Each source component needs one distinct project channel ID.');
            obj.ChannelIDs = ids;
            obj.syncChannelNames();
        end

        function index = sourceChannelIndex(obj,channel)
        %SOURCECHANNELINDEX Find the source component that maps to the requested project channel.
            if isnumeric(channel)
                if channel > numel(obj.Parent.Channels)
                    index = [];
                    return
                end
                channel = obj.Parent.Channels(channel).ID;
            end
            index = find(obj.ChannelIDs == string(channel),1);
        end

        function name = channelName(obj,c)
        %CHANNELNAME Return the channel name.
            name = obj.Parent.getChannelName(obj.ChannelIDs(c));
        end

        function names = channelNames(obj)
        %CHANNELNAMES Return channel display names in source component order.
            names = strings(1,obj.SizeC);
            % Process each source channel in its original component order.
            for c = 1:obj.SizeC
                names(c) = obj.channelName(c);
            end
        end

        function syncChannelNames(obj)
        %SYNCCHANNELNAMES Synchronize channel names.
            components = obj.ImageData.Components;
            % Process components in order.
            for c = 1:numel(components)
                components(c).Name = obj.channelName(c);
            end
        end
    end

    %% CData lazy access + buffer management
    methods

        function clearImageDataBuffer(obj)
        %CLEARIMAGEDATABUFFER Clear image data buffer.
            obj.ImageData_.unload();
        end

        function bufferImageData(obj)
        %BUFFERIMAGEDATA Load the source pixels and cache statistics for display.
            obj.ImageData_.load();
            obj.cacheImageInfoFromBuffer_();
        end

    end


    %% Image data cache management
    methods (Access=private)

        function cacheImageInfoFromFile_(obj)
        %CACHEIMAGEINFOFROMFILE_ Cache image info from file.

            if obj.ImageData_.IsLoaded
                obj.cacheImageInfoFromBuffer_();
                return
            end

            % Process each source channel in its original component order.
            for c = 1:obj.SizeC
                obj.Channels_(c).Size = obj.ImageData_.Components(c).Size;
                obj.Channels_(c).Class = obj.ImageData_.Components(c).Class;
                obj.Channels_(c).NativeDisplayRange = obj.ImageData_.Components(c).NativeDisplayRange;
            end
            % assume same size per channel
            obj.ImageSize_ = obj.ImageData_.Components(1).Size;
        end

        function cacheImageInfoFromBuffer_(obj)
        %CACHEIMAGEINFOFROMBUFFER_ Cache image info from buffer.
            % Process each source channel in its original component order.
            for c = 1:obj.SizeC
                obj.Channels_(c).Size = obj.ImageData_.Components(c).Size;
                obj.Channels_(c).Class = obj.ImageData_.Components(c).Class;
                obj.Channels_(c).NativeDisplayRange = obj.ImageData_.Components(c).NativeDisplayRange;
                % Pixel data for the image being processed.
                I = obj.getPlane(c);
                obj.Channels_(c).AutoDisplayRange = (stretchlim(I,[0.1 0.9999])).' * obj.Channels_(c).NativeDisplayRange(2);
                finitePixels = I(isfinite(I));
                if isempty(finitePixels)
                    obj.Channels_(c).DataRange = [0 1];
                else
                    obj.Channels_(c).DataRange = double([min(finitePixels),max(finitePixels)]);
                end
                if isempty(obj.Channels_(c).DisplayRange)
                    obj.Channels_(c).DisplayRange = obj.Channels_(c).DataRange;
                end
            end
            % assume same size per channel
            obj.ImageSize_ = obj.ImageData_.Components(1).Size;
        end

        function regionID = nextActiveRegionID_(obj)
        %NEXTACTIVEREGIONID_ Return the first remaining region or empty.
            if isempty(obj.RegionOrder)
                regionID = strings(1,0);
            else
                regionID = obj.RegionOrder(1);
            end
        end
    end

    %% Region management (find, add, remove, set active, etc.)
    methods

        function addRegion(obj, ID, Center, BoxSize, LabelID, LabelSource, opts)
        %ADDREGION Add region.
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
                oldActiveID = obj.ActiveRegionID;
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
                % keep the first region active at the model layer
                if isempty(obj.ActiveRegionID)
                    obj.ActiveRegionID = ID;
                end
                % notify self -> RegionAdded
                if opts.Notify
                    notify(obj,'RegionAdded',desmostorm.model.events.RegionAdded(obj.ID,ID,obj.RegionsDict(ID).Name));
                    if ~isequal(obj.ActiveRegionID, oldActiveID)
                        notify(obj,'ActiveRegionChanged',desmostorm.model.events.ActiveRegionChanged(obj.ID,obj.ActiveRegionID,oldActiveID));
                    end
                end
            end
        end

        function addRegionSilent(obj, ID, Center, BoxSize)
        %ADDREGIONSILENT Add region silent.
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
                % keep classifier-created batches from leaving the model with no active region
                if isempty(obj.ActiveRegionID)
                    obj.ActiveRegionID = ID;
                end
            end
        end

        function removeRegion(obj, regionID)
        %REMOVEREGION Remove region.
            regionID = string(regionID);
            if isKey(obj.RegionsDict, regionID)
                oldActiveID = obj.ActiveRegionID;
                oldSelectedIDs = obj.SelectedRegionIDs;
                regionName = obj.RegionsDict(regionID).Name;

                obj.RegionsDict = obj.RegionsDict.remove(regionID);
                obj.RegionOrder = obj.RegionOrder(obj.RegionOrder ~= regionID);
                obj.SelectedRegionIDs = obj.SelectedRegionIDs(obj.SelectedRegionIDs ~= regionID);

                if isequal(oldActiveID, regionID)
                    obj.ActiveRegionID = obj.nextActiveRegionID_();
                end

                % notify app after mutation, with enough detail to avoid state inference
                notify(obj,'RegionRemoved',desmostorm.model.events.RegionRemoved(obj.ID,regionID,regionName));
                if ~isequal(obj.SelectedRegionIDs, oldSelectedIDs)
                    notify(obj,'RegionSelectionChanged', ...
                        desmostorm.model.events.RegionSelectionChanged(obj.ID,obj.SelectedRegionIDs,oldSelectedIDs));
                end
                if ~isequal(obj.ActiveRegionID, oldActiveID)
                    notify(obj,'ActiveRegionChanged', ...
                        desmostorm.model.events.ActiveRegionChanged(obj.ID,obj.ActiveRegionID,oldActiveID));
                end
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
        %SETACTIVEREGION Set active region.
            oldID = obj.ActiveRegionID;
            regionID = string(regionID);
            % return if region is already active
            if isequal(regionID, oldID), return; end
            % invalid ID -> set empty
            if ~isKey(obj.RegionsDict, regionID)
                regionID = strings(1,0);
            end
            if isequal(regionID, oldID), return; end
            % set active and notify
            obj.ActiveRegionID = regionID;
            notify(obj,'ActiveRegionChanged', ...
                desmostorm.model.events.ActiveRegionChanged(obj.ID,obj.ActiveRegionID,oldID));
        end



        % --- retrieve ---
        function tf = hasRegion(obj, regionID)
        %HASREGION Check whether region is present.
            tf = isKey(obj.RegionsDict, string(regionID));
        end

        function r = getRegion(obj, regionID)
        %GETREGION Return region.
            regionID = string(regionID);
            if isKey(obj.RegionsDict, regionID), r = obj.RegionsDict(regionID); else, r = []; end
        end

        function regs = getRegionsByLabelID(obj,labelID)
        %GETREGIONSBYLABELID Return regions by label ID.
            if isempty(obj.RegionArray), regs = []; return; end
            regs = obj.RegionArray([obj.RegionArray(:).LabelID]==labelID);
        end


        % --- select ---
        function setRegionSelection(obj,IDs)
        %SETREGIONSELECTION Set region selection.
            if isempty(IDs), obj.clearRegionSelection(); return; end
            oldIDs = obj.SelectedRegionIDs;
            validIDs = intersect(obj.RegionOrder,string(IDs(:)),'stable');
            if isequal(validIDs, oldIDs)
                return
            end
            obj.SelectedRegionIDs = validIDs;
            notify(obj,'RegionSelectionChanged', ...
                desmostorm.model.events.RegionSelectionChanged(obj.ID,obj.SelectedRegionIDs,oldIDs));
        end

        function clearRegionSelection(obj)
        %CLEARREGIONSELECTION Clear region selection.
            oldIDs = obj.SelectedRegionIDs;
            if isempty(oldIDs)
                return
            end
            obj.SelectedRegionIDs = string.empty(1,0);
            notify(obj,'RegionSelectionChanged', ...
                desmostorm.model.events.RegionSelectionChanged(obj.ID,obj.SelectedRegionIDs,oldIDs));
        end


    end

    %% Region-level processing
    methods

        % --- process Region linescans ---

        function processAll(obj, config, opts)
        %PROCESSALL Process all.
            arguments
                obj desmostorm.model.STORMImage
                config desmostorm.config.RunConfig
                opts.ProgressDialog = []
            end

            % get Region array
            arr = obj.RegionArray;
            % return if empty
            if isempty(arr), return; end
            valid = arrayfun(@(r) desmostorm.model.STORMRegion.hasValidROI(r.ROI),arr);
            arr = arr(valid);
            if isempty(arr), return; end

            % otherwise, process each region
            for i = 1:numel(arr)
                obj.processRegionLinescan(arr(i),config, ...
                    "ProgressDialog",opts.ProgressDialog);
            end
        end

        function processRegionLinescan(obj, reg, config, opts)
        %PROCESSREGIONLINESCAN Process region linescan.
            arguments
                obj desmostorm.model.STORMImage
                reg desmostorm.model.STORMRegion
                config desmostorm.config.RunConfig
                opts.ProgressDialog = []
                opts.ProgressMessagePrefix (1,1) string = ""
            end

            if isempty(reg), return; end
            data = reg.ROI;
            if ~desmostorm.model.STORMRegion.hasValidROI(data)
                reg.resetLinescanResults();
                return
            end

            % get region CData cell
            I = obj.regionSubimageCell(reg);

            % run region analyzer
            LinescanResults = desmostorm.analysis.Analyzer.analyzeRegionLinescan(I,data,config, ...
                "ProgressDialog",opts.ProgressDialog, ...
                "ProgressMessagePrefix",opts.ProgressMessagePrefix);

            if isempty(LinescanResults)
                return
            end

            reg.updateLinescanResults(LinescanResults);
        end

        function refreshRegionLinescanPixelSizes(obj)
        %REFRESHREGIONLINESCANPIXELSIZES Rescale existing linescan outputs only.
            arr = obj.RegionArray;
            % Visit each entry in arr.
            for i = 1:numel(arr)
                arr(i).refreshLinescanPixelSize();
            end
        end

        function resetRegionROI(~,reg)
            % reset ROI to default
            reg.resetROI();
        end

        % --- autofit Region ROIs ---

        function nFit = autofitAllRegionROIs(obj, config, opts)
        %AUTOFITALLREGIONROIS Fit linescan ROIs for the regions in the current project.
            arguments
                obj desmostorm.model.STORMImage
                config desmostorm.config.RunConfig
                opts.ProgressDialog = []
            end

            % get Region array
            arr = obj.RegionArray;
            % return if empty
            if isempty(arr)
                nFit = 0;
                return
            end

            % otherwise, process each region
            nFit = 0;
            % Visit each entry in arr.
            for i = 1:numel(arr)
                if obj.autofitRegionROI(arr(i),config, ...
                        "DebugOutput",false, ...
                        "ProgressDialog",opts.ProgressDialog)
                    nFit = nFit + 1;
                end
            end
        end

        function ok = autofitRegionROI(obj, reg, config, opts)
        %AUTOFITREGIONROI Fit a linescan rectangle to the supplied region image.
            arguments
                obj desmostorm.model.STORMImage
                reg desmostorm.model.STORMRegion
                config desmostorm.config.RunConfig
                opts.DebugOutput = []
                opts.ProgressDialog = []
                opts.ProgressMessagePrefix (1,1) string = ""
                opts.ProgressValueMode (1,1) string {mustBeMember(opts.ProgressValueMode,["stage","none"])} = "stage"
            end

            ok = false;
            if isempty(reg), return; end

            desmostorm.Log.INFO(sprintf("Auto-fitting ROI for %s.",reg.Name));

            % get region CData
            I = obj.regionSubimage(reg);
            % get linescan info
            ROI = desmostorm.analysis.Analyzer.autofitRegionROI(I,config, ...
                "DebugOutput",opts.DebugOutput, ...
                "ProgressDialog",opts.ProgressDialog, ...
                "ProgressMessagePrefix",opts.ProgressMessagePrefix, ...
                "ProgressValueMode",opts.ProgressValueMode);

            if isempty(ROI)
                desmostorm.Log.WARN(sprintf("Auto-fit ROI failed for %s.",reg.Name));
                return
            end

            reg.updateROI(ROI,"Source","autofit");
            ok = true;
            desmostorm.Log.INFO(sprintf( ...
                "Auto-fit ROI set for %s (theta %.1f deg, %.0f x %.0f px).", ...
                reg.Name,ROI.RotationAngle,ROI.Width,ROI.Height));
        end

        % --- retrieve Region subimage ---

        function I = regionSubimage(obj,reg)
        %REGIONSUBIMAGE Extract pixels inside the region box.
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
        %REGIONSUBIMAGECELL Extract the region box separately for each source component.
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
        %RUNCLASSIFIER Run the classifier and add the resulting region proposals.

            % remove any existing regions first
            obj.removeAllRegions();

            if ~isfield(propOpts,"CandidateMode")
                propOpts.CandidateMode = "grid";
            elseif string(propOpts.CandidateMode) == "cluster"
                propOpts.CandidateMode = "ClusterCentroid";
            end
            if ~isfield(propOpts,"PositiveClass")
                propOpts.PositiveClass = "object";
            end
            if ~isfield(propOpts,"ProgressDialog")
                propOpts.ProgressDialog = [];
            end
            if ~isfield(propOpts,"ProgressMessagePrefix")
                propOpts.ProgressMessagePrefix = "";
            end

            [ctrs,scores] = desmostorm.ml.proposePatchCenters(obj.SourcePath,net,...
                "BoxSize",          propOpts.BoxSize, ...
                "Stride",           propOpts.Stride, ...
                "ScoreThreshold",   propOpts.ScoreThreshold, ...
                "BatchSize",        propOpts.BatchSize, ...
                "NmsIoU",           propOpts.NmsIoU, ...
                "CandidateMode",    propOpts.CandidateMode, ...
                "PositiveClass",    propOpts.PositiveClass, ...
                "ProgressMessagePrefix", propOpts.ProgressMessagePrefix, ...
                "ProgressDialog",   propOpts.ProgressDialog);

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
        %GET.REGIONARRAY Return the region array.
            if numel(obj.RegionOrder)==0
                arr = desmostorm.model.STORMRegion.empty();
                return
            end
            arr = obj.RegionsDict(obj.RegionOrder);
        end

        function reg = get.ActiveRegion(obj)
        %GET.ACTIVEREGION Return the active region.
            reg = [];
            if isempty(obj.ActiveRegionID), return; end
            if isKey(obj.RegionsDict, obj.ActiveRegionID)
                reg = obj.RegionsDict(obj.ActiveRegionID);
            end
        end


        function names = get.RegionNames(obj)
        %GET.REGIONNAMES Return the region names.
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
                % Physical calibration used to convert pixel measurements.
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
        %IMAGEINFODISPLAYSTRING Format metadata for the current image display.
            str = sprintf('%s (%ix%i %s)',char(obj.Name),obj.Height,obj.Width,obj.CDataClass);
        end

        function name = shortName(obj)
        %SHORTNAME Return the short name.
            str = strsplit(obj.Name,'.');
            name = str{1};
        end

    end

    %% Friendlier Command Window / Variable Editor display
    methods (Access=protected)

        function groups = getPropertyGroups(obj)
        %GETPROPERTYGROUPS Return property groups.
            % Counts of attempted, successful, and skipped export records.
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
        %TOSTRUCT Serialize the current values into a plain MATLAB structure.

            if ~isfile(obj.SourcePath)
                error("model:STORMImage:toStruct:InvalidFile","Cannot find file: %s",obj.SourcePath)
            end

            I.ID         = obj.ID;
            I.Name       = obj.Name;
            I.SourcePath = obj.SourcePath;
            I.FileType   = obj.FileType;
            I.ChannelIDs = obj.ChannelIDs;
            I.DisplayRanges = {obj.Channels_.DisplayRange};
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
            I.ActiveRegionID = obj.ActiveRegionID;
            I.SelectedRegionIDs = obj.SelectedRegionIDs;

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
        %FROMSTRUCT Read saved values from a MATLAB structure.

            name = string(S.Name);
            path = string(S.SourcePath);

            img = desmostorm.model.STORMImage(proj, name, path, string(S.ID));

            % restore per-image settings/state
            img.CreatedAt = S.CreatedAt;

            if ~isempty(S.PixelSizeOverride)
                img.PixelSizeOverride = desmostorm.model.units.PixelSize(S.PixelSizeOverride.Value, S.PixelSizeOverride.Unit);
            end

            if isfield(S,'DisplayRanges')
                % Process each source channel in its original component order.
                for c = 1:min(img.SizeC,numel(S.DisplayRanges))
                    if ~isempty(S.DisplayRanges{c})
                        img.setDisplayRange(S.DisplayRanges{c},c);
                    end
                end
            end

            img.NextRegionOrdinal = S.NextRegionOrdinal;

            % rebuild regions
            if isfield(S,'Regions') && ~isempty(S.Regions)
                desmostorm.Log.DEBUG("Rebuilding regions...")
                % number of Regions (one struct entry each)
                nRegions = numel(S.Regions);
                % iterate over all entries
                for r = 1:nRegions
                    % get struct for this Region
                    R = S.Regions(r);
                    % update log
                    desmostorm.Log.DEBUG(sprintf("Region (%i/%i): %s",r,nRegions,R.Name));
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

            if isfield(S,'ActiveRegionID') && isscalar(S.ActiveRegionID)
                img.setActiveRegion(S.ActiveRegionID);
            end
            if isfield(S,'SelectedRegionIDs')
                img.setRegionSelection(S.SelectedRegionIDs);
            end

        end

    end

    %% Hidden debug entry point
    methods (Hidden)

        function debug(obj)
        %DEBUG Return debug.
            debug
        end

    end

end
