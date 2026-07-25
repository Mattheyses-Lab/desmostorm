function searchRoot = promptMissingImageRoot(missingNames, projectFolder)
%PROMPTMISSINGIMAGEROOT Ask the user where missing project images live.

arguments
    missingNames (:,1) string
    projectFolder (1,1) string = ""
end

searchRoot = "";
fig = desmostorm.app.focusMainFigure();

if isempty(fig)
    return
end

msg = sprintf('Locate missing image files (%d missing):', numel(missingNames));
desmostorm.Log.WARN(msg);
for i = 1:numel(missingNames)
    desmostorm.Log.WARN(sprintf("Missing image file: %s", missingNames(i)));
end

selection = uiconfirm(fig, ...
    [msg; ""; missingNames], ...
    'Image files missing', ...
    "Options", ["Locate", "Cancel"], ...
    "DefaultOption", 1, ...
    "CancelOption", 2, ...
    "Icon", "warning");

switch selection
    case "Locate"
        wasVisible = fig.Visible;
        fig.Visible = "off";
        cleanupFig = onCleanup(@() restoreFigureVisibility(fig, wasVisible));
        selectedRoot = uigetdir(projectFolder, msg);
    otherwise
        return
end

if isequal(selectedRoot, 0)
    return
end

searchRoot = string(selectedRoot);

end

function restoreFigureVisibility(fig, visibleState)
    if ~isempty(fig) && isvalid(fig)
        fig.Visible = visibleState;
        desmostorm.app.focusMainFigure();
    end
end
