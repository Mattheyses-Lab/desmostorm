classdef sliderthumb < handle
%%  SLIDERTHUMB draggable thumb used by uislidereditfield

    properties(Dependent=true)
        Value
        FaceColor
        EdgeColor
        EdgeWidth
        YPosition
        ButtonDownFcn
        ID
        Size1
        Size2
    end

    properties(SetAccess=private)
        isSelected (1,1) logical = false
    end

    properties(Access=private)
        user_Size1
        user_Size2
    end

    properties(Access=private,Transient,NonCopyable)
        thumb matlab.graphics.primitive.Line
    end

    %% constructor and destructor

    methods

        % destructor
        function obj = sliderthumb(Parent,Options)
            % validate input args, set defaults
            arguments
                Parent (1,1) matlab.ui.control.UIAxes
                Options.Value (1,1) double = 1
                Options.FaceColor (1,3) = [0.5 0.5 0.5]
                Options.EdgeColor (1,3) = [0 0 0]
                Options.EdgeWidth (1,1) = 1
                Options.YPosition (1,1) = 25.5
                Options.ButtonDownFcn = '';
                Options.ID (1,1) = 1
                Options.Size1 (1,1) = 10
                Options.Size2 (1,1) = 12
            end
            % create the primitive line object which will show a single plot marker
            obj.thumb = line(Parent,...
                Options.Value,...
                Options.YPosition,...
                'ButtonDownFcn',Options.ButtonDownFcn,...
                'MarkerFaceColor',Options.FaceColor,...
                'MarkerEdgeColor',Options.EdgeColor,...
                'MarkerSize',Options.Size1,...
                'Marker','o',...
                'LineWidth',Options.EdgeWidth);
            addprop(obj.thumb,'ID');
            obj.thumb.ID = Options.ID;
            obj.user_Size1 = Options.Size1;
            obj.user_Size2 = Options.Size2;
        end

        % destructor
        function delete(obj)
            % delete the primitive line object
            delete(obj.thumb)
        end

    end

    %% context menus

    methods

        % add a context menu to the thumb
        function addContextMenu(obj,cm)
            obj.thumb.ContextMenu = cm;
        end

    end

    %% dependent Set and Get methods

    methods

        function Value = get.Value(obj)
            Value = obj.thumb.XData;
        end

        function set.Value(obj,val)
            obj.thumb.XData = val;
        end

        function YPosition = get.YPosition(obj)
            YPosition = obj.thumb.YData;
        end

        function set.YPosition(obj,val)
            obj.thumb.YData = val;
        end

        function set.ButtonDownFcn(obj,val)
            obj.thumb.ButtonDownFcn = val;
        end

        function ButtonDownFcn = get.ButtonDownFcn(obj)
            ButtonDownFcn = obj.thumb.ButtonDownFcn;
        end

        function Color = get.FaceColor(obj)
            Color = obj.thumb.MarkerFaceColor;
        end
        
        function set.FaceColor(obj,val)
            obj.thumb.MarkerFaceColor = val;
        end
        
        function EdgeColor = get.EdgeColor(obj)
            EdgeColor = obj.thumb.MarkerEdgeColor;
        end
        
        function set.EdgeColor(obj,val)
            obj.thumb.MarkerEdgeColor = val;
        end

        function EdgeWidth = get.EdgeWidth(obj)
            EdgeWidth = obj.thumb.LineWidth;
        end
        
        function set.EdgeWidth(obj,val)
            obj.thumb.LineWidth = val;
        end

        function ID = get.ID(obj)
            ID = obj.thumb.ID;
        end

        function set.ID(obj,val)
            obj.thumb.ID = val;
        end

        function Size1 = get.Size1(obj)
            Size1 = obj.user_Size1;
        end

        function set.Size1(obj,val)
            obj.user_Size1 = val;
            obj.thumb.MarkerSize = val;
        end

        function Size2 = get.Size2(obj)
            Size2 = obj.user_Size2;
        end

        function set.Size2(obj,val)
            obj.user_Size2 = val;
            obj.thumb.MarkerSize = val;
        end

    end

    % select and deselect thumbs
    methods

        function select(obj)
            obj.isSelected = true;
            obj.thumb.MarkerSize = obj.Size2;
        end

        function deselect(obj)
            obj.isSelected = false;
            obj.thumb.MarkerSize = obj.Size1;
        end

    end

end