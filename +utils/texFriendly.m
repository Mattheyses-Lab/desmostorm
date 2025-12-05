function out = texFriendly(str)
    nameSplit = strsplit(str,'_');
    out = convertCharsToStrings(strjoin(nameSplit,"\_"));
end