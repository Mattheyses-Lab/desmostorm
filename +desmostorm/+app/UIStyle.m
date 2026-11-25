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

classdef UIStyle
    %UISTYLE Shared palette and spacing for DesmoSTORM controls.
    properties (Constant)
        % Background.
        Background = [.12 .12 .12]
        % Pane.
        Pane = [.18 .18 .18]
        % Neutral background color for editable controls and secondary buttons.
        Control = [.30 .30 .30]
        % Foreground color for control captions.
        Caption = [.85 .85 .85]
        % Text.
        Text = [.90 .90 .90]
        % Accent color for the action that accepts a dialog.
        Primary = [.18 .42 .68]
        % Outer padding in pixels inside custom dialogs.
        DialogPadding = 10
        % Vertical gap in pixels between dialog content and footer.
        RowSpacing = 10
        % Horizontal gap in pixels between adjacent dialog buttons.
        ButtonSpacing = 5
        % Width in pixels of the standard dialog action buttons.
        ButtonWidth = 70
    end

    methods (Static)
        function control = button(parent,primary,varargin)
        %BUTTON Return button.
            % Canvas or container background color.
            background = desmostorm.app.UIStyle.Control;
            foreground = desmostorm.app.UIStyle.Text;
            if primary
                background = desmostorm.app.UIStyle.Primary;
                foreground = [1 1 1];
            end
            control = uibutton(parent,'BackgroundColor',background,'FontColor',foreground,varargin{:});
        end

        function styleSettingsControls(parent)
            % Apply the settings input palette to standard MATLAB controls.
            classes = ["DropDown","NumericEditField","EditField","CheckBox","Button","StateButton"];
            controls = findall(parent,'-property','FontColor');
            % Process controls in order.
            for k = 1:numel(controls)
                control = controls(k);
                if ~any(string(class(control)) == "matlab.ui.control." + classes)
                    continue
                end
                control.FontColor = desmostorm.app.UIStyle.Text;
                if isprop(control,'BackgroundColor')
                    control.BackgroundColor = desmostorm.app.UIStyle.Control;
                end
            end
        end
    end
end
