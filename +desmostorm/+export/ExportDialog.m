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
    methods (Static)
        function options = prompt(name,sections,plotHost)
        %PROMPT Collect menubar export settings in a tabbed modal dialog.
            if nargin < 3, plotHost = []; end
            background = [.12 .12 .12];
            paneColor = [.18 .18 .18];
            controlColor = [.3 .3 .3];
            fontColor = [.85 .85 .85];
            controlFontColor = [.9 .9 .9];
            options = [];
            fields = struct();
            controls = struct();

            fig = uifigure(Visible="off",Name=name, ...
                InnerPosition=[0 0 470 420],Resize="off", ...
                WindowStyle="modal",Color=background);
            fig.CloseRequestFcn = @(~,~) closeDialog();
            cleanup = onCleanup(@() deleteDialog(fig));
            root = uigridlayout(fig,[2 1],Padding=[10 10 10 10], ...
                RowSpacing=10,ColumnSpacing=0,BackgroundColor=background, ...
                RowHeight={'1x','fit'},ColumnWidth={'1x'});
            tabs = uitabgroup(root);
            tabs.Layout.Row = 1;
            readAxes = [];
            for section = 1:size(sections,1)
                if section == 2 && ~isempty(plotHost)
                    readAxes = matlabx.ui.axes.internal.plotAxesControlTabs(tabs,plotHost,@() [],true);
                end
                specs = sections{section,2};
                tab = uitab(tabs,Title=sections{section,1},BackgroundColor=paneColor, ...
                    ForegroundColor=fontColor);
                pane = uigridlayout(tab,[numel(specs)+1 2],ColumnWidth={'fit','1x'}, ...
                    RowHeight=[repmat({'fit'},1,numel(specs)),{'1x'}], ...
                    Padding=[5 5 5 5],ColumnSpacing=5,RowSpacing=5, ...
                    BackgroundColor=paneColor,Scrollable="on");
                for row = 1:numel(specs)
                    spec = specs{row};
                    label = uilabel(pane,Text=spec.Label,FontColor=fontColor);
                    label.Layout.Row = row;
                    label.Layout.Column = 1;
                    if isfield(spec,"Companion")
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
            end

            buttons = uigridlayout(root,[1 3],Padding=0,RowSpacing=0, ...
                ColumnSpacing=5,ColumnWidth={'1x',80,80},RowHeight={'fit'}, ...
                BackgroundColor=background);
            buttons.Layout.Row = 2;
            cancel = uibutton(buttons,Text="Cancel", ...
                BackgroundColor=controlColor,FontColor=controlFontColor, ...
                ButtonPushedFcn=@(~,~) closeDialog());
            cancel.Layout.Column = 2;
            proceed = uibutton(buttons,Text="Continue", ...
                BackgroundColor=[.18 .42 .68],FontColor=[1 1 1], ...
                ButtonPushedFcn=@(~,~) acceptDialog());
            proceed.Layout.Column = 3;
            if isfield(controls,"StyleSizing") && isfield(controls,"PreserveAspectRatio")
                controls.StyleSizing.ValueChangedFcn = @(~,~) updateAspectControl();
                updateAspectControl();
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
                deleteDialog(fig);
            end

            function control = registerControl(pane,spec)
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

            function updateAspectControl()
                aspect = controls.PreserveAspectRatio;
                physical = string(controls.StyleSizing.Value) == "Preserve physical sizes";
                if physical, aspect.Value = true; end
                aspect.Enable = ~physical;
            end

            function updateScalingControl()
                controls.AutoScalingMethod.Enable = string(controls.ScalingMode.Value) == "Auto";
            end

            function acceptDialog()
                values = struct();
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
    if isgraphics(fig), delete(fig); end
end
