classdef PixelSize
% desmostorm.model.units.PixelSize

    properties (SetAccess = immutable)
        Value (1,1) double {mustBePositive} = 1  % units per pixel
        Unit  (1,:) char = 'px'                  % 'px','nm','µm'
    end

    methods
        function obj = PixelSize(Value, Unit)
            arguments
                Value (1,1) double {mustBePositive} = 1
                Unit  (1,:) char = 'px'
            end

            Unit = desmostorm.model.units.PixelSize.normalizeUnit(Unit);

            % obj = desmostorm.model.units.PixelSize.empty;
            obj.Value = Value;
            obj.Unit  = Unit;
        end

        function lenPhys = px2phys(obj, lenPx)
            lenPhys = lenPx .* obj.Value;
        end

        function s = formatLength(obj, lenPx, mode)
            if nargin < 3
                mode = 'physical';
            end

            if isempty(lenPx) % default to NaN if length is empty
                lenPx = NaN;
            end

            switch obj.Unit
                case 'px'
                    s = sprintf('%.3g px', lenPx);
                otherwise
                    switch mode
                        case 'px'
                            s = sprintf('%.3g px', lenPx);
                        case 'physical'
                            lenPhys = obj.px2phys(lenPx);
                            s = sprintf('%.3g %s', lenPhys, obj.Unit);
                        otherwise
                            error('Unknown mode "%s".', mode);
                    end
            end
        end

        function s = stringDisplay(obj)
            % s = sprintf('%.3g %s/px', obj.Value, obj.Unit);
            s = string(obj.charDisplay);
        end

        function c = charDisplay(obj)
            c = sprintf('%.3g %s/px', obj.Value, obj.Unit);
        end

    end

    methods (Static, Access = private)
        function unitOut = normalizeUnit(unitIn)
            unitIn = strtrim(lower(unitIn));
            switch unitIn
                case {'px','pixel','pixels'}
                    unitOut = 'px';
                case {'nm','nanometer','nanometers'}
                    unitOut = 'nm';
                case {'um','µm','micron','microns','micrometer','micrometers'}
                    unitOut = 'µm';
                otherwise
                    error('Unsupported pixel size unit "%s".', unitIn);
            end
        end
    end
end