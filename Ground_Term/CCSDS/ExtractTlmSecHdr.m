function Time = ExtractTlmSecHdr(arr, endianness)
% 
%   Time = ExtractTlmSecHdr(arr)
%       extracts the time from a byte array formatted as a ccsds time
%       structure
%
%   Author: Steve Lentine
%   2016/03/24
%

    % check that array is correct length
    if(length(arr) ~= 6)
        error('ExtractTlmSecHdr:IncorrectLen','byte array should be 6 elements long.')
    end

    % extract the seconds and subseconds field
    if(endianness == Endian.Little)
        sec = double(typecast(arr(4:-1:1),'uint32'));
    else
        sec = double(typecast(arr(1:4),'uint32'));
    end
    
    if(endianness == Endian.Little)
        subsec = double(typecast(arr(6:-1:5),'uint16')/65535);
    else
        subsec = double(typecast(arr(5:6),'uint16')/65535);
    end
    % calculate time
    Time = sec + subsec;
    
end