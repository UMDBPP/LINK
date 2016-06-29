function flag = validateBaudRate(baud)
% validateBaudRate
%
%   validateBaudRate(baud)
%       checks an SerPort for validity
%
%   Returns true is the Baud Rate is numeric, scalar, and is in the list:
%   110, 300, 600, 1200, 2400, 4800, 9600, 14400, 19200, 38400, 57600, ...
%      115200, 128000, 256000
% 
%   example:
%   validateBaudRate(9600)
%
% Changelog:
%   2016-06-29  SPL     Initial Version
%

    valid_rates = [300, 600, 1200, 2400, 4800, 9600, ...
        14400, 19200, 28800, 38400, 57600, 115200, 250000];

    if(isnumeric(baud) && isscalar(baud) && ismember(baud,valid_rates))
        flag = true;
    else
        flag = false;
    end

end