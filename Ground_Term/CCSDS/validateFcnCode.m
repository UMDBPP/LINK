function flag = validateFcnCode(FcnCode)
% validateFcnCode
%
%   validateFcnCode(FcnCode)
%       checks an FcnCode for validity
%
%   Returns true is the FcnCode is numeric, scalar, and is in the range 
%   0 to 128
% 
%   example:
%   validateFcnCode(1)
%
% Changelog:
%   2016-06-29  SPL     Initial Version
%

    if(isnumeric(FcnCode) && isscalar(FcnCode) && FcnCode > 0 && FcnCode < 128)
        flag = true;
    else
        flag = false;
    end

end