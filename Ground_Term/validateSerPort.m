function flag = validateSerPort(SerPort)
% validateSerPort
%
%   validateSerPort(SerPort)
%       checks an SerPort for validity
%
%   Returns true is the SerPort is numeric, scalar, and is in the range 
%   1 to 12
% 
%   example:
%   validateSerPort(1)
%
% Changelog:
%   2016-06-29  SPL     Initial Version
%

    if(isnumeric(SerPort) && isscalar(SerPort) && SerPort >= 1 && SerPort <= 12)
        flag = true;
    else
        flag = false;
    end

end