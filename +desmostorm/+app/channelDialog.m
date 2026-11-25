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

function [names,colors] = channelDialog(project,images,opts)
%CHANNELDIALOG Edit project definitions or map every source component on import.
arguments
    project (1,1) desmostorm.model.STORMProject
    images = desmostorm.model.STORMImage.empty()
    opts.ProgressDialog = []
    opts.Parent = []
end

names = {};
colors = {};
% Whether the dialog is mapping files into the project.
isImport = ~isempty(images);
definitions = project.Channels;
existingIDs = string({definitions.ID});
existingNames = string({definitions.Name});
palette = matlabx.image.componentColorNames();
title = "Channels";
windowStyle = "modal";
position = [100 100 720 400];
padding = desmostorm.app.UIStyle.DialogPadding;
spacing = desmostorm.app.UIStyle.RowSpacing;
% Reserved heights for the input list, mapping controls, and footer.
fixedRows = [110 190 53];
if isImport
    desmostorm.runtime.updateProgress(opts.ProgressDialog,"Preparing channel mappings...",.7);
    title = "Import Images";
    windowStyle = "alwaysontop";
    screen = get(groot,'ScreenSize');
    chrome = 2*matlabx.UICal.uipanelTopChromeHeightPx(12);
    % Fixed height.
    fixedHeight = sum(fixedRows) + 2*padding + 3*spacing;
    % Largest square preview side that fits the available space.
    side = max(1,floor(min([500,screen(3)-80-2*padding, ...
        screen(4)-120-fixedHeight-chrome])));
    position = [0 0 min(screen(3)-80,max(460,side+2*padding)) side+fixedHeight+chrome];
end
fig = uifigure('Name',title,'WindowStyle',windowStyle,'Visible','off', ...
    'Position',position,'Theme','dark','AutoResizeChildren','off', ...
    'Color',desmostorm.app.UIStyle.Background, ...
    'CloseRequestFcn',@(src,~) uiresume(src));
% Delete if valid when this scope exits.
cleanup = onCleanup(@() deleteIfValid(fig));
% Grid that arranges the dialog contents.
layout = uigridlayout(fig,[4 1], ...
    'RowHeight',{fixedRows(1),'1x',fixedRows(2),fixedRows(3)}, ...
    'Padding',padding,'RowSpacing',spacing,'BackgroundColor',desmostorm.app.UIStyle.Background);

columns = [ ...
    matlabx.ui.control.ControlTableColumn(Name="Name",Label="Name", ...
        Width="2x",ControlType="text"), ...
    matlabx.ui.control.ControlTableColumn(Name="Color",Label="Color", ...
        Width=110,ControlType="dropdown",Items=palette,ItemsData=palette)];
rows = cell(1,max(1,numel(images)));
% Index for file.
fileIndex = 0;
% Separate preview intensity limits for each file.
previewLimits = cell(size(rows));

if isImport
    listPanel = uipanel(layout,'Title','Input images');
    listPanel.Layout.Row = 1;
    listGrid = uigridlayout(listPanel,[1 1],'Padding',0);
    fileNames = string({images.Name});
    uilistbox(listGrid,'Items',cellstr(fileNames), ...
        'ItemsData',num2cell(1:numel(images)),'Value',1, ...
        'ValueChangedFcn',@(src,~) showFile(src.Value));

    viewerHost = uigridlayout(layout,[3 3], ...
        'RowHeight',{0,1,0},'ColumnWidth',{0,1,0}, ...
        'Padding',0,'RowSpacing',0,'ColumnSpacing',0, ...
        'BackgroundColor',[.12 .12 .12]);
    viewerHost.Layout.Row = 2;
    previewPanel = uipanel(viewerHost,'Title','Image preview', ...
        'BackgroundColor',[.12 .12 .12],'FontSize',12);
    previewPanel.Layout.Row = 2;
    previewPanel.Layout.Column = 2;
    previewGrid = uigridlayout(previewPanel,[1 1],'Padding',0);
    preview = matlabx.ui.axes.ImageAxes(previewGrid, ...
        'Tools',{'Zoom','DisplayLimits','Colorbar'},'ComponentColorMode','colors');
    % Visible dropdown labels, including the option to define a channel.
    targetChoices = ["New channel...", existingNames];
    % Stable values stored by the target dropdown.
    targetValues = ["new",existingIDs];
    % Only new mappings can edit the channel name and color.
    editNew = @(row,~,~) row.Target == "new";
    columns = [ ...
        matlabx.ui.control.ControlTableColumn(Name="Source",Label="Source channel", ...
            Width="2x",ControlType="text",Editable=false), ...
        matlabx.ui.control.ControlTableColumn(Name="Target",Label="Project channel", ...
            Width="2x",ControlType="dropdown",Items=targetChoices,ItemsData=targetValues), ...
        matlabx.ui.control.ControlTableColumn(Name="Name",Label="Name", ...
            Width="2x",ControlType="text",EnabledFcn=editNew), ...
        matlabx.ui.control.ControlTableColumn(Name="Color",Label="Color", ...
            Width=110,ControlType="dropdown",Items=palette,ItemsData=palette,EnabledFcn=editNew)];

    % Draft names used to keep color suggestions consistent across files.
    newNames = strings(1,0);
    % Process images in order.
    for i = 1:numel(images)
        img = images(i);
        source = strings(img.SizeC,1);
        % Filesystem path for names for.
        namesForFile = strings(img.SizeC,1);
        targets = repmat("new",img.SizeC,1);
        defaults = strings(img.SizeC,1);
        % Process each source channel in its original component order.
        for c = 1:img.SizeC
            source(c) = strtrim(string(img.ImageData.getComponentName(c)));
            namesForFile(c) = source(c);
            if ismissing(source(c)) || source(c) == ""
                source(c) = "Component " + c;
                namesForFile(c) = "Channel " + c;
            end
            % Keep trying until the candidate is unique.
            while any(strcmpi(namesForFile(c),namesForFile(1:c-1)))
                namesForFile(c) = namesForFile(c) + " (" + c + ")";
            end
            % Matching index or indices in the lookup.
            match = find(strcmpi(existingNames,namesForFile(c)),1);
            if ~isempty(match)
                targets(c) = existingIDs(match);
                namesForFile(c) = definitions(match).Name;
                defaults(c) = definitions(match).Color;
            else
                match = find(strcmpi(newNames,namesForFile(c)),1);
                if isempty(match)
                    newNames(end+1) = namesForFile(c);
                    match = numel(newNames);
                end
                defaults(c) = palette(1 + mod(numel(definitions)+match-1,numel(palette)));
            end
        end
        rows{i} = table(source,targets,namesForFile,defaults, ...
            'VariableNames',{'Source','Target','Name','Color'});
    end
else
    layout.RowHeight = {0,0,'1x','fit'};
    fileIndex = 1;
    rows{1} = table(existingNames(:),reshape(string({definitions.Color}),[],1), ...
        'VariableNames',{'Name','Color'});
end

mappingArea = uigridlayout(layout,[2 1],'RowHeight',{'fit','1x'},'Padding',0);
mappingArea.Layout.Row = 3;
if isImport
    instructions = uilabel(mappingArea,'Text', ...
        'Map source channels or name and color new channels.');
    instructions.Layout.Row = 1;
else
    mappingArea.RowHeight = {0,'1x'};
    mappingArea.RowSpacing = 0;
end
% Container for the controls or graphics created below.
host = uigridlayout(mappingArea,[1 1],'RowHeight',{'fit'},'Padding',0,'Scrollable','on');
host.Layout.Row = 2;
editor = matlabx.ui.control.ControlTable(host,Columns=columns,Data=rows{1});
editor.RowOperationRequestedFcn = @rejectRowOperation;
if isImport
    editor.CellEditedFcn = @mappingEdited;
    editor.SelectionChangedFcn = @(~,event) showComponent(event.NewActiveRow);
    addlistener(preview,'C','PostSet',@(~,~) syncPreviewRow());
    addlistener(preview,'ShowComposite','PostSet',@(~,~) syncPreviewRow());
end
% Button width.
buttonWidth = desmostorm.app.UIStyle.ButtonWidth;
footer = uigridlayout(layout,[2 4], ...
    'ColumnWidth',{'fit','1x',buttonWidth,buttonWidth},'RowHeight',{'fit','fit'}, ...
    'Padding',0,'RowSpacing',desmostorm.app.UIStyle.ButtonSpacing, ...
    'ColumnSpacing',desmostorm.app.UIStyle.ButtonSpacing, ...
    'BackgroundColor',desmostorm.app.UIStyle.Background);
footer.Layout.Row = 4;
if isImport
    autoApply = uicheckbox(footer,'Text','Automatically apply matching mappings', ...
        'Value',true,'Enable',numel(images)>1, ...
        'ValueChangedFcn',@(src,~) setManualMappingEnabled(src.Value));
    autoApply.FontColor = desmostorm.app.UIStyle.Text;
    autoApply.Layout.Row = 1;
    autoApply.Layout.Column = [1 4];
    autoApply.Tooltip = 'Apply each edited mapping to the same source channel name in other images.';
    applyMatching = desmostorm.app.UIStyle.button(footer,false,'Text','Apply mappings to matching channels', ...
        'Enable','off','ButtonPushedFcn',@applyMatchingMappings);
    applyMatching.Layout.Row = 2;
    applyMatching.Layout.Column = 1;
else
    footer.RowHeight = {0,'fit'};
    footer.RowSpacing = 0;
end
cancel = desmostorm.app.UIStyle.button(footer,false,'Text','Cancel','ButtonPushedFcn',@(~,~) uiresume(fig));
cancel.Layout.Row = 2;
cancel.Layout.Column = 3;
buttonText = "Apply";
if isImport, buttonText = "Import"; end
apply = desmostorm.app.UIStyle.button(footer,true,'Text',buttonText,'ButtonPushedFcn',@confirm);
apply.Layout.Row = 2;
apply.Layout.Column = 4;

movegui(fig,'center');
if isImport
    fig.SizeChangedFcn = @resizePreview;
    resizePreview(fig,[]);
    desmostorm.runtime.updateProgress(opts.ProgressDialog,"Loading the first image preview...",.9);
    showFile(1);
    if ~isempty(opts.ProgressDialog) && isvalid(opts.ProgressDialog)
        desmostorm.runtime.updateProgress(opts.ProgressDialog,"Import dialog ready.",1);
        close(opts.ProgressDialog);
    end
    if ~isempty(opts.Parent) && isvalid(opts.Parent), opts.Parent.Visible = 'off'; end
end
fig.Visible = 'on';
uiwait(fig);
deleteIfValid(fig);

    function rejectRowOperation(~,event)
    %REJECTROWOPERATION Disallow structural edits to the channel mapping table.
        event.Cancel = true;
    end

    function resizePreview(src,~)
    %RESIZEPREVIEW Fit the square image preview within the available dialog space.
        width = max(1,src.InnerPosition(3)-2*padding);
        height = max(1,src.InnerPosition(4)-fixedHeight);
        % Largest square preview side that fits the available space.
        side = max(1,floor(min(width,height-chrome)));
        % Panel height.
        panelHeight = side+chrome;
        horizontal = max(0,(width-side)/2);
        vertical = max(0,(height-panelHeight)/2);
        set(viewerHost,'ColumnWidth',{horizontal,side,horizontal}, ...
            'RowHeight',{vertical,panelHeight,vertical});
    end

    function showFile(index)
    %SHOWFILE Show file.
        if fileIndex ~= 0
            rows{fileIndex} = editor.Data;
            previewLimits{fileIndex} = preview.ComponentCLims;
        end
        % Index for file.
        fileIndex = index;
        editor.Data = rows{index};
        preview.ImageData = images(index).ImageData;
        if isempty(previewLimits{index})
            previewLimits{index} = initialPreviewLimits(images(index));
        end
        preview.ComponentCLims = previewLimits{index};
        updatePreview();
        showComponent(1);
        syncPreviewRow();
    end

    function setManualMappingEnabled(automatic)
    %SETMANUALMAPPINGENABLED Enable the batch mapping button when continuous mapping is off.
        applyMatching.Enable = ~automatic && numel(images)>1;
    end

    function applyMatchingMappings(~,~)
    %APPLYMATCHINGMAPPINGS Copy the current file’s mappings to matching source channels.
        [updatedChannels,updatedFiles] = propagateMappings(1:height(editor.Data));
        uialert(fig,sprintf('Applied %d matching channel mapping(s) across %d other file(s).', ...
            updatedChannels,updatedFiles),'Channel Mappings','Icon','info');
    end

    function [updatedChannels,updatedFiles] = propagateMappings(sourceRows)
    %PROPAGATEMAPPINGS Copy edited rows to uniquely matching source channels on other files.
        rows{fileIndex} = editor.Data;
        current = rows{fileIndex};
        sourceNames = lower(strtrim(current.Source));
        updatedChannels = 0;
        updatedFiles = 0;
        fields = {'Target','Name','Color'};

        % Visit each entry in rows.
        for k = 1:numel(rows)
            if k == fileIndex, continue, end
            otherNames = lower(strtrim(rows{k}.Source));
            changes = 0;
            % Process source rows in order.
            for c = sourceRows
                name = sourceNames(c);
                % Matching index or indices in the lookup.
                match = find(otherNames == name);
                if numel(match) == 1 && nnz(sourceNames == name) == 1
                    rows{k}(match,fields) = current(c,fields);
                    changes = changes+1;
                end
            end
            updatedChannels = updatedChannels+changes;
            updatedFiles = updatedFiles+(changes > 0);
        end
    end

    function mappingEdited(~,event)
    %MAPPINGEDITED Resolve a changed mapping, propagate it when enabled, and update the preview.
        if ismember(event.Name,["Target","Name"])
            data = editor.Data;
            row = event.Row;
            if event.Name == "Name" || data.Target(row) ~= "new"
                editor.replaceRow(row,reuseExistingChannel(data(row,:)));
            end
        end
        if autoApply.Value && numel(images)>1
            propagateMappings(event.Row);
        end
        updatePreview();
        showComponent(event.Row);
    end

    function row = reuseExistingChannel(row)
    %REUSEEXISTINGCHANNEL Map a matching name or target ID to its canonical project channel.
        if row.Target == "new"
            % Matching index or indices in the lookup.
            match = find(strcmpi(existingNames,strtrim(row.Name)),1);
        else
            match = find(existingIDs == row.Target,1);
        end
        if ~isempty(match)
            row.Target = existingIDs(match);
            row.Name = definitions(match).Name;
            row.Color = definitions(match).Color;
        end
    end

    function showComponent(row)
    %SHOWCOMPONENT Show the image component represented by the given table row.
        if row >= 1 && row <= preview.NumComponents
            preview.ShowComposite = 'off';
            preview.C = row;
        end
    end

    function syncPreviewRow()
    %SYNCPREVIEWROW Select the table row for the visible preview component.
        if preview.ShowComposite || preview.C > height(editor.Data)
            editor.ActiveRow = 0;
        else
            editor.ActiveRow = preview.C;
        end
    end

    function updatePreview()
    %UPDATEPREVIEW Update preview.
        preview.ComponentColors = cellstr(editor.Data.Color(:).');
    end

    function confirm(~,~)
    %CONFIRM Validate the dialog input and return the accepted values.
        rows{fileIndex} = editor.Data;
        if isImport
            % Visit each entry in rows.
            for k = 1:numel(rows)
                for c = 1:height(rows{k})
                    rows{k}(c,:) = reuseExistingChannel(rows{k}(c,:));
                end
            end
        end
        draftNames = cellfun(@(t) strtrim(string(t.Name)).',rows,'UniformOutput',false);
        draftColors = cellfun(@(t) string(t.Color).',rows,'UniformOutput',false);
        % Visit each entry in rows.
        for k = 1:numel(rows)
            values = draftNames{k};
            if any(ismissing(values) | strlength(values) == 0) || ...
                    numel(unique(lower(values))) ~= numel(values)
                uialert(fig,'Each channel needs a distinct, nonempty name.','Channels');
                return
            end
        end
        if isImport
            allNames = lower([draftNames{:}]);
            allColors = [draftColors{:}];
            for name = unique(allNames,'stable')
                if any(strcmpi(name,existingNames)), continue, end
                chosen = unique(allColors(allNames == name));
                if numel(chosen) > 1
                    uialert(fig,"Choose one color for the new channel " + name + ".",'Channels');
                    return
                end
            end
        end
        names = draftNames;
        colors = draftColors;
        uiresume(fig);
    end
end

function deleteIfValid(fig)
%DELETEIFVALID Delete if valid.
if isvalid(fig)
    delete(fig);
end
end

function limits = initialPreviewLimits(img)
%INITIALPREVIEWLIMITS Derive preview-only contrast from the displayed planes.
limits = cell(1,img.SizeC);
% Process each source channel in its original component order.
for c = 1:img.SizeC
    values = double(img.getPlane(c));
    values = values(isfinite(values));
    if isempty(values)
        limits{c} = [0 1];
        continue
    end

    range = prctile(values,[0.1 99.9]);
    if range(1) == range(2)
        range = [min(values),max(values)];
    end
    if range(1) == range(2)
        delta = max(0.5,eps(range(1)));
        range = range + [-delta,delta];
    end
    limits{c} = range;
end
end
