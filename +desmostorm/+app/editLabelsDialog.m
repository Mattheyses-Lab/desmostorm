% DesmoSTORM - MATLAB app for desmosomal plaque protein analysis.
% Copyright (C) 2026 William Dean
% SPDX-License-Identifier: GPL-2.0-or-later

function [draft,originalIDs] = editLabelsDialog(labels)
%EDITLABELSDIALOG Stage changes to project labels until Apply is selected.
draft = [];
originalIDs = strings(0,1);
fig = uifigure('Name','Edit labels','WindowStyle','modal','Theme','dark', ...
    'AutoResizeChildren','off','Position',[0 0 640 420], ...
    'Color',desmostorm.app.UIStyle.Background, ...
    'CloseRequestFcn',@(src,~) uiresume(src));
% Grid that arranges the dialog contents.
layout = uigridlayout(fig,[2 1],'RowHeight',{'1x','fit'}, ...
    'Padding',desmostorm.app.UIStyle.DialogPadding,'RowSpacing',desmostorm.app.UIStyle.RowSpacing, ...
    'BackgroundColor',desmostorm.app.UIStyle.Background);
% Container for the controls or graphics created below.
host = uigridlayout(layout,[1 1],'Padding',0,'RowHeight',{'fit'},'Scrollable','on');
data = struct2table(labels(:),'AsArray',true);
data.ID = string(data.ID);
data.OriginalID = data.ID;
data.Name = string(data.Name);
data.Hotkey = string(data.Hotkey);
columns = [ ...
    matlabx.ui.control.ControlTableColumn(Name="Name",Label="Name",Width="2x"), ...
    matlabx.ui.control.ControlTableColumn(Name="ID",Label="ID",Width="2x", ...
        EnabledFcn=@(row,~,~) row.OriginalID ~= "unlabeled"), ...
    matlabx.ui.control.ControlTableColumn(Name="Hotkey",Label="Hotkey",Width=85), ...
    matlabx.ui.control.ControlTableColumn(Name="Color",Label="Color",Width=100,ControlType="color")];
editor = matlabx.ui.control.ControlTable(host,Columns=columns,Data=data, ...
    SelectionMode="multiple",Reorderable=true,NewRowFcn=@newLabel);
editor.RowOperationRequestedFcn = @checkRowOperation;

% Button width.
buttonWidth = desmostorm.app.UIStyle.ButtonWidth;
buttons = uigridlayout(layout,[1 5], ...
    'ColumnWidth',{'fit','fit','1x',buttonWidth,buttonWidth},'RowHeight',{'fit'}, ...
    'Padding',0,'ColumnSpacing',desmostorm.app.UIStyle.ButtonSpacing, ...
    'BackgroundColor',desmostorm.app.UIStyle.Background);
desmostorm.app.UIStyle.button(buttons,false,'Text','New label','ButtonPushedFcn',@(~,~) editor.addNewRow());
desmostorm.app.UIStyle.button(buttons,false,'Text','Delete selected','ButtonPushedFcn',@(~,~) editor.removeSelectedRows());
cancel = desmostorm.app.UIStyle.button(buttons,false,'Text','Cancel','ButtonPushedFcn',@(~,~) uiresume(fig));
cancel.Layout.Column = 4;
apply = desmostorm.app.UIStyle.button(buttons,true,'Text','Apply','ButtonPushedFcn',@confirm);
apply.Layout.Column = 5;

movegui(fig,'center');
uiwait(fig);
if isvalid(fig), delete(fig); end

    function row = newLabel(tableControl)
    %NEWLABEL Create a draft row with an unused label name and ID.
        data = tableControl.Data;
        number = max(1,height(data));
        name = "Label " + number;
        id = "label-" + number;
        % Keep trying until the candidate is unique.
        while any(strcmpi(name,data.Name)) || ismember(id,data.ID)
            number = number+1;
            name = "Label " + number;
            id = "label-" + number;
        end
        row = table(id,name,"",[1 1 1],datetime('now'),"", ...
            'VariableNames',{'ID','Name','Hotkey','Color','CreatedAt','OriginalID'});
        row = row(:,data.Properties.VariableNames);
    end

    function checkRowOperation(~,event)
    %CHECKROWOPERATION Validate a requested edit to the label table rows.
        protected = any(editor.Data.OriginalID(event.Rows) == "unlabeled");
        event.Cancel = event.Operation == "duplicate" || protected || ...
            (event.Operation == "reorder" && event.DestinationRow == 1);
    end

    function confirm(~,~)
    %CONFIRM Validate the dialog input and return the accepted values.
        data = editor.Data;
        data.Name = strtrim(data.Name);
        data.ID = strtrim(data.ID);
        if any(ismissing(data.ID) | strlength(data.ID) == 0) || ...
                numel(unique(data.ID)) ~= height(data)
            uialert(fig,'Label IDs must be nonempty and unique.','Labels');
            return
        end
        data.Hotkey = lower(strtrim(data.Hotkey));
        keys = data.Hotkey(strlength(data.Hotkey)>0);
        validKeys = cellfun(@(key) ~isempty(regexp(key,'^[a-z0-9]$','once')),cellstr(keys));
        if any(ismissing(data.Name) | strlength(data.Name) == 0) || ...
                numel(unique(lower(data.Name))) ~= height(data)
            uialert(fig,'Label names must be nonempty and unique.','Labels');
            return
        end
        if any(ismissing(data.Hotkey)) || any(~validKeys) || numel(unique(keys)) ~= numel(keys)
            uialert(fig,'Hotkeys must be unique single letters or digits, or blank.','Labels');
            return
        end
        removed = nnz(~ismember(string({labels.ID}),data.OriginalID));
        if removed > 0
            choice = uiconfirm(fig,'Regions using deleted labels will become Unlabeled.', ...
                'Apply label changes?','Options',{'Apply','Cancel'}, ...
                'DefaultOption',2,'CancelOption',2,'Icon','warning');
            if choice ~= "Apply", return, end
        end
        originalIDs = data.OriginalID;
        data.OriginalID = [];
        draft = table2struct(data);
        uiresume(fig);
    end
end
