function idx = nearestIndex(x,value)
%NEARESTINDEX Robust index lookup for floating-point location vectors.

[~,idx] = min(abs(x - value));
end
