function out = measure(ProfileX,ProfileY,PeakValues,PeakLocations,PeakWidths)
% model.analysis.peaks.measure  Measures the distance between peaks, FWHM, 
%   and retrieves coordinates for plotting annotation lines in linescan plot

    % if we do not have exactly 2 peaks
    if numel(PeakValues)~=2
        % set all output to NaN, Valid=false
        PeakX1=NaN;
        PeakY1=NaN;
        PeakX2=NaN;
        PeakY2=NaN;
        PeakDistance=NaN;
        PeakWidth1=NaN;
        PeakWidth2=NaN;
        PeakWidthxL1=NaN;
        PeakWidthxR1=NaN;
        PeakWidthxL2=NaN;
        PeakWidthxR2=NaN;
        BorderLineXY=NaN;
        Valid=false;
    else
        PeakX1=PeakLocations(1);
        PeakY1=PeakValues(1);
        PeakX2=PeakLocations(2);
        PeakY2=PeakValues(2);
        PeakDistance=abs(PeakLocations(2)-PeakLocations(1));
        PeakWidth1=PeakWidths(1);
        PeakWidth2=PeakWidths(2);
        % get FWHM line coordinates
        [xL,xR,BorderLineXY] = model.analysis.peaks.getFWHMCoordinates(ProfileX,ProfileY,PeakValues,PeakLocations);
        PeakWidthxL1=xL(1);
        PeakWidthxR1=xR(1);
        PeakWidthxL2=xL(2);
        PeakWidthxR2=xR(2);
        Valid=true;
    end

    % collect results
    out = struct(...
        'PeakX1',PeakX1,...
        'PeakY1',PeakY1,...
        'PeakX2',PeakX2,...
        'PeakY2',PeakY2,...
        'PeakDistance',PeakDistance,...
        'PeakWidth1',PeakWidth1,...
        'PeakWidth2',PeakWidth2,...
        'PeakWidthxL1',PeakWidthxL1,...
        'PeakWidthxR1',PeakWidthxR1,...
        'PeakWidthxL2',PeakWidthxL2,...
        'PeakWidthxR2',PeakWidthxR2,...
        'BorderLineXY',BorderLineXY,...
        'Valid',Valid);

end