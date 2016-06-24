function [arr, char_arr, str_arr] = CreateCmdSecHdr(FcnCode)

% 
%    uint16  Command;      /* command secondary header */
%       /*  bits  shift   ------------ description ---------------- */
%       /* 0x00FF    0  : checksum, calculated by ground system     */
%       /* 0x7F00    8  : command function code                     */
%       /* 0x8000   15  : reserved, set to 0    

    % initalize the output
    arr = uint8(zeros(2,1));
   
    % compile the command field
    Reserved = 0;
    Checksum = 0;
    
    % check inputs
    if(FcnCode > 127)
       warning('CreateCmdSecHdr:FcnCodeOutOfRange','Function code is out of range and may be truncated');
    end
    
    
    command_tmp = uint16(0);

    command_tmp = bitor(bitand(bitshift(uint16(Checksum),0),hex2dec('00FF')),command_tmp);
    command_tmp = bitor(bitand(bitshift(uint16(FcnCode),8),hex2dec('7F00')),command_tmp);
    command_tmp = bitor(bitand(bitshift(uint16(Reserved),15),hex2dec('8000')),command_tmp);
    
    command = typecast(command_tmp,'uint8');

    arr(1) = command(1);
    arr(2) = command(2);
    
    arr = arr.';
    
    % convert to characters
    char_arr = char(arr.');
    
    % convert to string of number
    str_arr = strrep(regexprep(num2str([100 0 1 0 3 0 0 10]),' +',' '),' ',',');
end