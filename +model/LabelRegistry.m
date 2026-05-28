classdef LabelRegistry < handle
%LabelRegistry  Project-level label bank (lookup by id/hotkey, active label, serialization).

    properties (Access=private)
        LabelsDict = dictionary(string.empty(1,0), model.RegionLabel.empty(1,0))  % ID -> RegionLabel
        Order (1,:) string = string.empty(1,0)
        HotkeyMap = dictionary(string.empty(1,0), string.empty(1,0))            % hotkey -> ID
    end

    properties
        ActiveLabelID (1,1) string = ""
    end

    events
        LabelsChanged
        ActiveChanged
    end

    methods
        function obj = LabelRegistry()
            obj.LabelsDict = dictionary(string.empty(1,0), model.RegionLabel.empty(1,0));
            obj.HotkeyMap  = dictionary(string.empty(1,0), string.empty(1,0));
            obj.Order      = string.empty(1,0);
        end

        function ids = ids(obj)
            ids = obj.Order;
        end

        function arr = labels(obj)
            if isempty(obj.Order)
                arr = model.RegionLabel.empty();
            else
                arr = obj.LabelsDict(obj.Order);
            end
        end

        function lbl = getByID(obj, id)
            id = string(id);
            if strlength(id)==0 || ~isKey(obj.LabelsDict, id)
                lbl = [];
            else
                lbl = obj.LabelsDict(id);
            end
        end

        function lbl = getByHotkey(obj, key)
            key = lower(string(key));
            if strlength(key)==0 || ~isKey(obj.HotkeyMap, key)
                lbl = [];
            else
                lbl = obj.getByID(obj.HotkeyMap(key));
            end
        end

        function setActiveByID(obj, id)
            id = string(id);
            if id == obj.ActiveLabelID, return; end

            if strlength(id)==0
                obj.ActiveLabelID = "";
                notify(obj,'ActiveChanged');
                return
            end

            if isKey(obj.LabelsDict, id)
                obj.ActiveLabelID = id;
                notify(obj,'ActiveChanged');
            end
        end

        function setActiveByHotkey(obj, key)
            lbl = obj.getByHotkey(key);
            if ~isempty(lbl)
                obj.setActiveByID(lbl.ID);
            end
        end

        function lbl = active(obj)
            lbl = obj.getByID(obj.ActiveLabelID);
        end

        function id = add(obj, name, opts)
            arguments
                obj
                name (1,1) string
                opts.ID (1,1) string = ""
                opts.Hotkey (1,1) string = ""
                opts.Color (1,3) double = [1 1 1]
                opts.MakeActive (1,1) logical = false
            end

            lbl = model.RegionLabel(name, "ID",opts.ID, "Hotkey",opts.Hotkey, "Color",opts.Color);

            % ensure unique hotkey mapping (last-wins)
            if lbl.hasHotkey()
                obj.HotkeyMap(lbl.Hotkey) = lbl.ID;
            end

            obj.LabelsDict(lbl.ID) = lbl;
            obj.Order(end+1) = lbl.ID;

            notify(obj,'LabelsChanged');

            if opts.MakeActive
                obj.setActiveByID(lbl.ID);
            end

            id = lbl.ID;
        end

        function remove(obj, id)
            id = string(id);
            if ~isKey(obj.LabelsDict, id), return; end

            lbl = obj.LabelsDict(id);

            if lbl.hasHotkey() && isKey(obj.HotkeyMap, lbl.Hotkey)
                % remove only if it still points to this label
                if obj.HotkeyMap(lbl.Hotkey) == id
                    remove(obj.HotkeyMap, lbl.Hotkey);
                end
            end

            remove(obj.LabelsDict, id);
            obj.Order(obj.Order == id) = [];

            if obj.ActiveLabelID == id
                obj.ActiveLabelID = "";
                notify(obj,'ActiveChanged');
            end

            notify(obj,'LabelsChanged');
        end



        function edit(obj, id, opts)
            arguments
                obj
                id
                opts.Name string = string.empty()
                opts.ID string = string.empty()
                opts.Hotkey string = string.empty()
                opts.Color double = []
            end

            % get label by its id
            id = string(id);
            if ~isKey(obj.LabelsDict, id), return; end
            lbl = obj.LabelsDict(id);

            % Name
            if ~isempty(opts.Name)
                lbl.Name = opts.Name;
            end
            
            % ID
            if ~isempty(opts.ID)
                oldID = lbl.ID;
                lbl.ID = opts.ID;
                % remove entry keyed by oldID
                remove(obj.LabelsDict,oldID);
                % replace oldID in Order
                obj.Order(obj.Order == oldID) = opts.ID;
            end

            % Hotkey
            if ~isempty(opts.Hotkey)
                oldHotkey = lbl.Hotkey;
                lbl.Hotkey = opts.Hotkey;
                % remove entry keyed by oldHotkey
                remove(obj.HotkeyMap,oldHotkey);
            end

            % Color
            if ~isempty(opts.Color)
                lbl.Color = opts.Color;
            end

            % ensure unique hotkey mapping (last-wins)
            if lbl.hasHotkey()
                obj.HotkeyMap(lbl.Hotkey) = lbl.ID;
            end

            % add to LabelsDict
            obj.LabelsDict(lbl.ID) = lbl;

            notify(obj,'LabelsChanged');
        end


        function S = toStruct(obj)
            arr = obj.labels();
            S = struct();
            S.ActiveLabelID = obj.ActiveLabelID;

            S.Labels = repmat(struct(), 1, numel(arr));
            for k = 1:numel(arr)
                L = arr(k);
                S.Labels(k).ID = L.ID;
                S.Labels(k).Name = L.Name;
                S.Labels(k).Hotkey = L.Hotkey;
                S.Labels(k).Color = L.Color;
                S.Labels(k).CreatedAt = L.CreatedAt;
            end

            S.Order = obj.Order;
        end
    end

    methods (Static)
        function bank = fromStruct(S)
            bank = model.LabelRegistry();

            if isfield(S,'Labels') && ~isempty(S.Labels)
                for k = 1:numel(S.Labels)
                    L = S.Labels(k);
                    id = bank.add(string(L.Name), ...
                        "ID",string(L.ID), ...
                        "Hotkey",string(L.Hotkey), ...
                        "Color",double(L.Color), ...
                        "MakeActive",false);
                    lbl = bank.getByID(id);
                    if isfield(L,'CreatedAt') && ~isempty(L.CreatedAt)
                        lbl.CreatedAt = L.CreatedAt;
                    end
                end
            end

            if isfield(S,'Order') && ~isempty(S.Order)
                bank.Order = string(S.Order);
            end

            if isfield(S,'ActiveLabelID')
                bank.ActiveLabelID = string(S.ActiveLabelID);
            end
        end


        function obj = default()
            obj = model.LabelRegistry();
            obj.add("Unlabeled","ID","unlabeled","Hotkey","u","Color",[0.7 0.7 0.7]);
            % Examples (edit/remove as you like)
            obj.add("Object","ID","object","Hotkey","1","Color",[0.2 0.8 0.2]);
            obj.add("Background","ID","background","Hotkey","2","Color",[0.9 0.2 0.2]);
            obj.setActiveByID("unlabeled");
        end


    end

end