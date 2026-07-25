function imagesOut = resolveImagePaths(imagesIn, projectFolder, opts)
%RESOLVEIMAGEPATHS Resolve serialized project image paths without UI code.

arguments
    imagesIn
    projectFolder (1,1) string = ""
    opts.MissingImageResolver = []
end

imagesOut = imagesIn;

while true
    [imagesOut, missing] = findMissingImages(imagesOut, projectFolder);

    if ~any(missing)
        return
    end

    if isempty(opts.MissingImageResolver)
        logMissingImages(imagesOut, missing);
        imagesOut = [];
        return
    end

    missingNames = [imagesOut(missing).SourcePath]';
    searchRoot = opts.MissingImageResolver(missingNames, projectFolder);

    if isempty(searchRoot) || isequal(searchRoot, 0) || strlength(string(searchRoot)) == 0
        imagesOut = [];
        return
    end

    imagesOut = resolveFromSearchRoot(imagesOut, missing, string(searchRoot));
end

end

function [imagesOut, missing] = findMissingImages(imagesOut, projectFolder)
    missing = false(1, numel(imagesOut));

    for k = 1:numel(imagesOut)
        p = string(imagesOut(k).SourcePath);
        if strlength(p) > 0 && isfile(p)
            continue
        end

        if strlength(projectFolder) > 0 && isfield(imagesOut(k),'FileName')
            candidate = fullfile(projectFolder, imagesOut(k).FileName + imagesOut(k).Ext);
            if isfile(candidate)
                imagesOut(k).SourcePath = string(candidate);
                continue
            end
        end

        missing(k) = true;
    end
end

function imagesOut = resolveFromSearchRoot(imagesOut, missing, searchRoot)
    files = dir(fullfile(searchRoot, "**", "*"));
    files = files(~[files.isdir]);

    for k = find(missing)
        targetName = imagesOut(k).FileName + imagesOut(k).Ext;
        hits = files(string({files.name}) == targetName);

        if isempty(hits)
            continue
        end

        if isscalar(hits)
            imagesOut(k).SourcePath = string(fullfile(hits.folder, hits.name));
            continue
        end

        sz = imagesOut(k).FileSizeBytes;
        if ~isnan(sz)
            szHits = hits([hits.bytes] == sz);
            if isscalar(szHits)
                imagesOut(k).SourcePath = string(fullfile(szHits.folder, szHits.name));
                continue
            elseif ~isempty(szHits)
                hits = szHits;
            end
        end

        [~, idx] = max([hits.datenum]);
        imagesOut(k).SourcePath = string(fullfile(hits(idx).folder, hits(idx).name));
    end
end

function logMissingImages(imagesOut, missing)
    desmostorm.Log.WARN("Project is missing " + nnz(missing) + " image file(s).");

    missingNames = [imagesOut(missing).SourcePath]';
    for i = 1:numel(missingNames)
        desmostorm.Log.WARN("Missing image file: " + missingNames(i));
    end
end
