function P = buildPatchTableFromProject(project, opts)
%BUILDPATCHTABLEFROMPROJECT Build a classifier patch table from project regions.
%
% Uses only USER-labeled regions:
%   Label == "object"     & LabelSource == "user"  -> positive
%   Label == "background" & LabelSource == "user"  -> negative
%
% Then tops up with random negatives if needed to reach negPerPos.
%
% Output columns:
%   imageFilename : string
%   centerX       : double
%   centerY       : double
%   label         : categorical
%   source        : categorical   ("user","random")
%
% Notes
% -----
% - Unreviewed classifier proposals should be:
%     Label="unlabeled", LabelSource="classifier"
%   and are ignored here.
% - Random negatives are sampled per image, from valid box centers, rejecting
%   overlap with user-labeled positives and user-labeled backgrounds.

arguments
    project (1,1) desmostorm.model.STORMProject

    opts.BoxSize (1,1) double {mustBePositive} = 300
    opts.NegPerPos (1,1) double {mustBeNonnegative} = 6
    opts.IoUMax (1,1) double {mustBeGreaterThanOrEqual(opts.IoUMax,0), mustBeLessThanOrEqual(opts.IoUMax,1)} = 0.05

    opts.PositiveLabel (1,1) string = "object"
    opts.NegativeLabel (1,1) string = "background"
    opts.RequiredLabelSource (1,1) string = "user"
end

imgs = project.ImageArray;
if isempty(imgs)
    P = emptyPatchTable();
    return
end

rows = cell(0,5);
s = opts.BoxSize;

totalPos = 0;
totalNegUser = 0;

for i = 1:numel(imgs)
    img = imgs(i);
    fn = string(img.SourcePath);
    regs = img.RegionArray;

    if isempty(regs)
        continue
    end

    % Collect user-reviewed positives and negatives from this image. Classifier
    % proposals and unlabeled regions are intentionally excluded so training
    % data only reflects user-reviewed labels.
    Cpos = zeros(0,2);
    CnegUser = zeros(0,2);

    for r = 1:numel(regs)
        reg = regs(r);

        % tolerate missing properties while you wire this up
        if ~isprop(reg, "LabelID") || ~isprop(reg, "LabelSource")
            continue
        end

        lbl = string(reg.LabelID);
        src = string(reg.LabelSource);

        if src ~= opts.RequiredLabelSource
            continue
        end

        if lbl == opts.PositiveLabel
            Cpos(end+1,:) = reg.Center; %#ok<AGROW>
        elseif lbl == opts.NegativeLabel
            CnegUser(end+1,:) = reg.Center; %#ok<AGROW>
        end
    end

    nPos = size(Cpos,1);
    nNegUser = size(CnegUser,1);

    totalPos = totalPos + nPos;
    totalNegUser = totalNegUser + nNegUser;

    % Add user positives exactly at their reviewed region centers.
    if nPos > 0
        rowsPos = [repmat({fn}, nPos, 1), ...
                   num2cell(Cpos(:,1)), num2cell(Cpos(:,2)), ...
                   repmat({char(opts.PositiveLabel)}, nPos, 1), ...
                   repmat({"user"}, nPos, 1)];
        rows = [rows; rowsPos]; %#ok<AGROW>
    end

    % Add user negatives exactly at their reviewed region centers.
    if nNegUser > 0
        rowsNeg = [repmat({fn}, nNegUser, 1), ...
                   num2cell(CnegUser(:,1)), num2cell(CnegUser(:,2)), ...
                   repmat({char(opts.NegativeLabel)}, nNegUser, 1), ...
                   repmat({"user"}, nNegUser, 1)];
        rows = [rows; rowsNeg]; %#ok<AGROW>
    end

    % Top up random negatives only if there are positives in this image. This
    % keeps the automatically sampled background near images known to contain
    % true objects while avoiding empty-image dominance.
    if nPos == 0
        continue
    end

    nNegTarget = round(opts.NegPerPos * nPos);
    nNegNeeded = max(0, nNegTarget - nNegUser);

    if nNegNeeded == 0
        continue
    end

    % Reject overlap with both user positives and user negatives. User-labeled
    % background boxes are also protected because the user may have placed them
    % around informative hard negatives.
    Cblock = [Cpos; CnegUser];
    if isempty(Cblock)
        Bblock = zeros(0,4);
    else
        Bblock = centerToBBox(Cblock, s);
    end

    xMin = 1 + (s-1)/2;
    xMax = img.Width  - (s-1)/2;
    yMin = 1 + (s-1)/2;
    yMax = img.Height - (s-1)/2;

    if xMax < xMin || yMax < yMin
        error("buildPatchTableFromProject:BoxTooLarge", ...
            "BoxSize=%d does not fit inside image (%dx%d): %s", s, img.Height, img.Width, fn);
    end

    CnegRand = zeros(0,2);
    tries = 0;
    maxTries = max(100, nNegNeeded * 100);

    while size(CnegRand,1) < nNegNeeded && tries < maxTries
        tries = tries + 1;

        cx = xMin + (xMax - xMin) * rand();
        cy = yMin + (yMax - yMin) * rand();

        b = centerToBBox([cx cy], s);

        if all(bboxIoU(b, Bblock) <= opts.IoUMax)
            CnegRand(end+1,:) = [cx cy]; %#ok<AGROW>
        end
    end

    if ~isempty(CnegRand)
        nNegRand = size(CnegRand,1);
        rowsRand = [repmat({fn}, nNegRand, 1), ...
                    num2cell(CnegRand(:,1)), num2cell(CnegRand(:,2)), ...
                    repmat({char(opts.NegativeLabel)}, nNegRand, 1), ...
                    repmat({"random"}, nNegRand, 1)];
        rows = [rows; rowsRand]; %#ok<AGROW>
    end
end

P = cell2table(rows, 'VariableNames', ...
    {'imageFilename','centerX','centerY','label','source'});

if isempty(P)
    P = emptyPatchTable();
    return
end

P.imageFilename = string(P.imageFilename);
P.label = categorical(string(P.label), [opts.PositiveLabel opts.NegativeLabel]);
P.source = categorical(string(P.source), ["user","random","classifier"]);

% Stable sort is nice for reproducibility and makes CSV audit files easier to
% diff across training runs.
P = sortrows(P, ["imageFilename","label","source"]);

if ~any(P.label == opts.PositiveLabel)
    error("buildPatchTableFromProject:NoPositives", ...
        "No user-labeled positive regions ('%s') were found in the project.", opts.PositiveLabel);
end

desmostorm.Log.INFO(sprintf( ...
    "Patch table summary: %d total patch(es), %d positive, %d user negative, %d random negative.", ...
    height(P), ...
    sum(P.label == opts.PositiveLabel), ...
    totalNegUser, ...
    sum(P.source == "random")));

end

% -------------------------------------------------------------------------

function P = emptyPatchTable()
%EMPTYPATCHTABLE Return an empty table with the canonical patch schema.
P = table( ...
    strings(0,1), zeros(0,1), zeros(0,1), ...
    categorical(strings(0,1), ["object","background"]), ...
    categorical(strings(0,1), ["user","random","classifier"]), ...
    'VariableNames', {'imageFilename','centerX','centerY','label','source'});
end

function B = centerToBBox(C, s)
%CENTERTOBBOX Convert center coordinates into fixed-size [x y w h] boxes.
    x = C(:,1) - s/2;
    y = C(:,2) - s/2;
    B = [x y repmat([s s], size(C,1), 1)];
end

function iou = bboxIoU(b1, B)
%BBOXIOU Compute IoU between one box and an array of boxes.
    if isempty(B)
        iou = zeros(0,1);
        return
    end
    
    x1 = max(b1(1), B(:,1));
    y1 = max(b1(2), B(:,2));
    x2 = min(b1(1)+b1(3), B(:,1)+B(:,3));
    y2 = min(b1(2)+b1(4), B(:,2)+B(:,4));
    
    w = max(0, x2 - x1);
    h = max(0, y2 - y1);
    inter = w .* h;
    
    a1 = b1(3) * b1(4);
    a2 = B(:,3) .* B(:,4);
    
    iou = inter ./ (a1 + a2 - inter + eps);
end
