function fig = getMainFigure()
%GETMAINFIGURE Return the current DesmoSTORM GUI figure, if one exists.

fig = desmostorm.app.GUI.findGUI();

if isempty(fig) || ~isvalid(fig)
    fig = matlab.ui.Figure.empty();
end

end
