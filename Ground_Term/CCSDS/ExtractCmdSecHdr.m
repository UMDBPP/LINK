function [FcnCode, Checksum, Reserved] = ExtractCmdSecHdr(arr, endianness)

% 
%    uint16  Command;      /* command secondary header */
%       /*  bits  shift   ------------ description ---------------- */
%       /* 0x00FF    0  : checksum, calculated by ground system     */
%       /* 0x7F00    8  : command function code                     */
%       /* 0x8000   15  : reserved, set to 0    
   
    % type cast to int
    if(endianness == Endian.Little)
        arr = typecast(arr(end:1),'uint16');
    else
        arr = typecast(arr,'uint16');
    end
    
    % bitbust the values
    Checksum = bitshift(bitand(arr,hex2dec('00FF')),0);
    FcnCode = bitshift(bitand(arr,hex2dec('7F00')),-8);
    Reserved = bitshift(bitand(arr,hex2dec('8001')),-15);
    
end