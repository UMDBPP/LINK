function [arr, char_arr, str_arr] = CreateTlmHdr(APID, SeqCnt, SegFlag, PktLen)
% 
%   arr= CreateTlmHdr(APID, SeqCnt, SegFlag, PktLen)
%       returns an array containing the bytes of the CCSDS header
%
%   Author: Steve Lentine
%   2016/03/24
%

    % initalize the output
    arr = uint8(zeros(12,1));
    
    % create primary header
    arr(1:6) = CreatePriHdr(APID, 1, 0, 0, SeqCnt, SegFlag, PktLen);
    
    % create telemetry secondary header
    arr(7:12) = CreateTlmSecHdr();
       
    % file the array to a row
    arr = arr.';
    
    % convert to characters
    char_arr = char(arr.');
    
    % convert to string of number
    str_arr = strrep(regexprep(num2str([100 0 1 0 3 0 0 10]),' +',' '),' ',',');
end

