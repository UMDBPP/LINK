function flag = validateAPID(APID)
% validateAPID
%
%   validateAPID(APID)
%       checks an APID for validity
%
%   Returns true is the APID is numeric, scalar, and is in the range 0 to
%   4096
% 
%   example:
%   validateAPID(1)
%
% Changelog:
%   2016-06-29  SPL     Initial Version
%

    if(isnumeric(APID) && isscalar(APID) && APID > 0 && APID < 4096)
        flag = true;
    else
        flag = false;
    end

end