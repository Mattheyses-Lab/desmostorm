function [Ptrain, Pval] = splitByImage(P, valFrac)
%splitByImage Split by imageFilename, ensuring validation is non-empty and has both classes if possible.
    arguments
        P table
        valFrac (1,1) double {mustBeGreaterThan(valFrac,0), mustBeLessThan(valFrac,1)} = 0.2
    end
    
    imgs = unique(P.imageFilename);
    nImgs = numel(imgs);
    nValTarget = max(1, round(valFrac * nImgs));
    
    % For each image, determine if it contains object and/or background
    hasObject = false(nImgs,1);
    hasBack   = false(nImgs,1);
    
    for i = 1:nImgs
        Pi = P(P.imageFilename == imgs(i), :);
        hasObject(i) = any(Pi.label == "object");
        hasBack(i)   = any(Pi.label == "background");
    end
    
    % Prefer validation images that collectively cover both classes
    idxAll = randperm(nImgs);
    
    valSet = false(nImgs,1);
    needObject = true;
    needBack   = true;
    
    for k = idxAll
        if sum(valSet) >= nValTarget
            break
        end
    
        ok = true;
    
        % greedily satisfy missing classes first
        if needObject && hasObject(k)
            ok = true;
        elseif needBack && hasBack(k)
            ok = true;
        elseif ~(needObject || needBack)
            ok = true;
        else
            % if still missing a class, avoid picking images that don't help unless needed
            ok = false;
        end
    
        if ok
            valSet(k) = true;
            if hasObject(k), needObject = false; end
            if hasBack(k),   needBack   = false; end
        end
    end
    
    % If we still don't have enough validation images, fill randomly
    if sum(valSet) < nValTarget
        remaining = find(~valSet);
        fill = remaining(randperm(numel(remaining), min(nValTarget - sum(valSet), numel(remaining))));
        valSet(fill) = true;
    end
    
    valImgs = imgs(valSet);
    
    isVal = ismember(P.imageFilename, valImgs);
    Pval   = P(isVal,:);
    Ptrain = P(~isVal,:);
    
    % As a last resort: if validation ended up empty, force 1 image into validation
    if isempty(Pval) && nImgs > 0
        valImgs = imgs(1);
        isVal = ismember(P.imageFilename, valImgs);
        Pval   = P(isVal,:);
        Ptrain = P(~isVal,:);
    end
end