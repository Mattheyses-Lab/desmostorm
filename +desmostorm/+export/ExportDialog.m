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

classdef ExportDialog
%EXPORTDIALOG Collect export options in a tabbed modal dialog.
    methods (Static)
        function options = prompt(name,sections,plotHost)
        %PROMPT Collect menubar export settings in a tabbed modal dialog.
            if nargin < 3, plotHost = []; end
            % Canvas or container background color.
            background = desmostorm.app.UIStyle.Background;
            % Background color for the settings tab or panel.
            paneColor = desmostorm.app.UIStyle.Pane;
            % Background color for editable controls.
            controlColor = desmostorm.app.UIStyle.Control;
            % Foreground color for labels and captions.
            fontColor = desmostorm.app.UIStyle.Caption;
            % Foreground color for editable control values.
            controlFontColor = desmostorm.app.UIStyle.Text;
            options = [];
            fields = struct();
            controls = struct();

            % Whether the dialog needs the PlotAxes export controls.
            isPlotExport = any(cellfun(@(spec) isfield(spec,"Name") && ...
                spec.Name == "ContentType",sections{1,2}));
            dialogSize = [470 420];
            if isPlotExport, dialogSize = [520 600]; end
            fig = uifigure(Visible="off",Name=name, ...
                InnerPosition=[0 0 dialogSize],Resize="off", ...
                WindowStyle="modal",Color=background);
            fig.CloseRequestFcn = @(~,~) closeDialog();
            % Delete dialog when this scope exits.
            cleanup = onCleanup(@() deleteDialog(fig));
            root = uigridlayout(fig,[2 1],Padding=desmostorm.app.UIStyle.DialogPadding, ...
                RowSpacing=desmostorm.app.UIStyle.RowSpacing,ColumnSpacing=0,BackgroundColor=background, ...
                RowHeight={'1x','fit'},ColumnWidth={'1x'});
            tabs = uitabgroup(root);
            tabs.Layout.Row = 1;
            readAxes = [];
            for section = 1:size(sections,1)
                specs = sections{section,2};
                tab = uitab(tabs,Title=sections{section,1},BackgroundColor=paneColor, ...
                    ForegroundColor=fontColor);
                pane = uigridlayout(tab,[numel(specs)+1 2],ColumnWidth={'fit','1x'}, ...
                    RowHeight=[repmat({'fit'},1,numel(specs)),{'1x'}], ...
                    Padding=[5 5 5 5],ColumnSpacing=5,RowSpacing=5, ...
                    BackgroundColor=paneColor,Scrollable="on");
                % Process specs in order.
                for row = 1:numel(specs)
                    spec = specs{row};
                    label = uilabel(pane,Text=spec.Label,FontColor=fontColor);
                    label.Layout.Row = row;
                    label.Layout.Column = 1;
                    if spec.Type == "note"
                        label.Layout.Column = [1 2];
                    elseif isfield(spec,"Companion")
                        pair = uigridlayout(pane,[1 2],Padding=0,ColumnSpacing=5, ...
                            RowHeight={'fit'},ColumnWidth={'1x','fit'},BackgroundColor=paneColor);
                        pair.Layout.Row = row;
                        pair.Layout.Column = 2;
                        control = registerControl(pair,spec);
                        control.Layout.Column = 1;
                        picker = registerControl(pair,spec.Companion);
                        picker.Layout.Column = 2;
                        picker.Tooltip = spec.Label;
                        picker.Enable = string(control.Value) == "manual";
                        control.ValueChangedFcn = @(src,~) set(picker,'Enable',string(src.Value) == "manual");
                    else
                        control = registerControl(pane,spec);
                        control.Layout.Row = row;
                        control.Layout.Column = 2;
                    end
                end
                if section == 1 && ~isempty(plotHost)
                    readAxes = matlabx.ui.axes.internal.plotAxesControlTabs( ...
                        tabs,plotHost,@() [],true,pane);
                end
            end

            % Button width.
            buttonWidth = desmostorm.app.UIStyle.ButtonWidth;
            % Flexible spacer followed by the two fixed-width actions.
            columns = {'1x',buttonWidth,buttonWidth};
            buttons = uigridlayout(root,[1 numel(columns)],Padding=0,RowSpacing=0, ...
                ColumnSpacing=desmostorm.app.UIStyle.ButtonSpacing,ColumnWidth=columns,RowHeight={'fit'}, ...
                BackgroundColor=background);
            buttons.Layout.Row = 2;
            cancel = desmostorm.app.UIStyle.button(buttons,false,'Text',"Cancel", ...
                'ButtonPushedFcn',@(~,~) closeDialog());
            cancel.Layout.Column = numel(columns)-1;
            proceed = desmostorm.app.UIStyle.button(buttons,true,'Text',"Continue", ...
                'ButtonPushedFcn',@(~,~) acceptDialog());
            proceed.Layout.Column = numel(columns);
            if isfield(controls,"Units") && isfield(controls,"Width") && isfield(controls,"Height")
                currentUnits = string(controls.Units.Value);
                controls.Units.ValueChangedFcn = @(~,~) convertDimensions();
            end
            if isPlotExport
                controls.ContentType.ValueChangedFcn = @(~,~) updateOutputType();
                updateOutputType();
            end
            if isfield(controls,"ScalingMode") && isfield(controls,"AutoScalingMethod")
                controls.ScalingMode.ValueChangedFcn = @(~,~) updateScalingControl();
                updateScalingControl();
            end
            movegui(fig,"center");
            fig.Visible = "on";
            uiwait(fig);
            closeDialog();

            function closeDialog()
            %CLOSEDIALOG Close the dialog figure if it still exists.
                deleteDialog(fig);
            end

            function control = registerControl(pane,spec)
            %REGISTERCONTROL Create an export control and register it for value collection.
                switch spec.Type
                    case "choice"
                        control = uidropdown(pane,Items=cellstr(spec.Items),Value=char(spec.Value), ...
                            BackgroundColor=controlColor,FontColor=controlFontColor);
                    case "dimension"
                        control = uieditfield(pane,"text",Value=spec.Value,Placeholder="Auto", ...
                            BackgroundColor=controlColor,FontColor=controlFontColor);
                    case "number"
                        control = uieditfield(pane,"numeric",Value=spec.Value, ...
                            Limits=spec.Limits,LowerLimitInclusive=spec.LowerLimitInclusive, ...
                            BackgroundColor=controlColor,FontColor=controlFontColor);
                    case "toggle"
                        control = uicheckbox(pane,Text="",Value=spec.Value,FontColor=fontColor);
                    case "color"
                        control = uicolorpicker(pane,Value=spec.Value);
                end
                controls.(spec.Name) = control;
                fields.(spec.Name) = spec;
            end

            function updateOutputType()
            %UPDATEOUTPUTTYPE Update file formats, units, and resolution for the selected output type.
                vector = string(controls.ContentType.Value) == "Vector";
                units = ["inches","centimeters","points"];
                formats = ["PDF","SVG"];
                format = "SVG";
                if ~vector
                    units(end+1) = "pixels";
                    formats = ["PNG","TIFF"];
                    format = "PNG";
                elseif currentUnits == "pixels"
                    if ~convertDimensions("inches")
                        controls.ContentType.Value = 'Image';
                        return
                    end
                end
                controls.Units.Items = cellstr(units);
                controls.Units.Value = char(currentUnits);
                fields.Units.Items = units;
                fields.Units.OutputValues = units;
                controls.Format.Items = cellstr(formats);
                controls.Format.Value = char(format);
                fields.Format.Items = formats;
                fields.Format.OutputValues = formats;
                controls.Resolution.Enable = ~vector;
            end

            function updateScalingControl()
            %UPDATESCALINGCONTROL Enable the autoscale method only when the export uses automatic limits.
                controls.AutoScalingMethod.Enable = string(controls.ScalingMode.Value) == "Auto";
            end

            function ok = convertDimensions(nextUnits)
            %CONVERTDIMENSIONS Convert entered dimensions while retaining the physical output size.
                if nargin < 1, nextUnits = string(controls.Units.Value); end
                ok = false;
                dpi = 300;
                if isfield(controls,"Resolution"), dpi = controls.Resolution.Value; end
                if any([currentUnits nextUnits] == "pixels") && (~isfinite(dpi) || dpi <= 0)
                    controls.Units.Value = char(currentUnits);
                    uialert(fig,"Enter a positive resolution before converting pixel dimensions.","Invalid Resolution");
                    return
                end
                factor = matlabx.ui.axes.internal.exportUnitsPerInch(nextUnits,dpi) / ...
                    matlabx.ui.axes.internal.exportUnitsPerInch(currentUnits,dpi);
                for key = ["Width","Height"]
                    control = controls.(key);
                    if fields.(key).Type == "dimension"
                        value = str2double(control.Value);
                        if isreal(value) && isfinite(value) && value > 0
                            control.Value = compose("%.9g",value * factor);
                        end
                    else
                        control.Value = control.Value * factor;
                    end
                end
                currentUnits = nextUnits;
                ok = true;
            end

            function acceptDialog()
            %ACCEPTDIALOG Validate the controls and return the accepted export options.
                values = struct();
                % Process the named fields in fields.
                for key = reshape(string(fieldnames(fields)),1,[])
                    spec = fields.(key);
                    value = controls.(key).Value;
                    switch spec.Type
                        case "choice"
                            value = spec.OutputValues(spec.Items == string(value));
                        case "toggle"
                            value = matlab.lang.OnOffSwitchState(value);
                        case "dimension"
                            input = strtrim(string(value));
                            value = [];
                            if strlength(input) > 0
                                value = str2double(input);
                                if ~isreal(value) || ~isfinite(value) || value <= 0
                                    uialert(fig,spec.Label + " must be positive or blank.","Invalid export option");
                                    return
                                end
                            end
                        case "number"
                            if ~isfinite(value)
                                uialert(fig,spec.Label + " must be finite.","Invalid export option");
                                return
                            end
                    end
                    values.(key) = value;
                end
                if isfield(values,"Width") && isfield(values,"Height") && ...
                        isempty(values.Width) && isempty(values.Height)
                    uialert(fig,"Specify a width or height.","Invalid export option");
                    return
                end
                if isPlotExport && values.ContentType == "Image" && ...
                        values.Resolution ~= fix(values.Resolution)
                    uialert(fig,"Resolution must be a positive whole number.","Invalid export option");
                    return
                end
                if ~isempty(readAxes)
                    [style,view,message] = readAxes();
                    if strlength(message) > 0
                        uialert(fig,message,"Invalid axes options");
                        return
                    end
                    if isfield(view,"XLim") && isempty(view.XLim) && plotHost.Axes.XLimMode == "manual"
                        view.XLim = plotHost.Axes.XLim;
                    end
                    values.AxesAppearance = style;
                    values.AxesView = view;
                end
                options = values;
                uiresume(fig);
            end
        end
    end
end

function deleteDialog(fig)
%DELETEDIALOG Delete the dialog figure if it still exists.
    if isgraphics(fig), delete(fig); end
end
