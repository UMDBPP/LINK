function [arr, char_arr, str_arr] = CreateCmdHdr(APID, SeqCnt, SegFlag, PktLen, FcnCode)

% 
%    uint16  Command;      /* command secondary header */
%       /*  bits  shift   ------------ description ---------------- */
%       /* 0x00FF    0  : checksum, calculated by ground system     */
%       /* 0x7F00    8  : command function code                     */
%       /* 0x8000   15  : reserved, set to 0    

    % initalize the output
    arr = uint8(zeros(8,1));
   
    % create primary header
    arr(1:6) = CreatePriHdr(APID, 1, 1, 0, SeqCnt, SegFlag, PktLen);
    % create command secondary header
    arr(7:8) = CreateCmdSecHdr(FcnCode);

    % flip to a row array
    arr = arr.';
    
    % convert to characters
    char_arr = char(arr.');
    
    % convert to string of number
    str_arr = strrep(regexprep(num2str(arr),' +',' '),' ',',');
end