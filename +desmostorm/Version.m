classdef Version
    methods(Static)
        function c = compare(v1,v2)
            a = sscanf(char(v1),'%d.%d.%d');
            b = sscanf(char(v2),'%d.%d.%d');
            a(end+1:3)=0; b(end+1:3)=0;
            c = sign(dot([1 0.01 0.0001], a-b)); % returns -1,0,1
        end
    end
end