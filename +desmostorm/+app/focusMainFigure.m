function fig = focusMainFigure()
%FOCUSMAINFIGURE Bring the DesmoSTORM GUI figure to the front.

fig = desmostorm.app.getMainFigure();

if isempty(fig)
    return
end

figure(fig);
drawnow

end
