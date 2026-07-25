function tf = hasMainFigure()
%HASMAINFIGURE True when a live DesmoSTORM GUI figure exists.

fig = desmostorm.app.getMainFigure();
tf = ~isempty(fig);

end
