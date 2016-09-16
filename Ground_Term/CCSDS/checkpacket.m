function flag = checkpacket(varargin)
%
%
%   checkpacket(data)
%
%
% return true if the byte array appears to be a valid packet, otherwise false
% checkpacket() does not check the length of _byte_buffer before casting it... 
% only call if _byte_buffer is longer than 8 elements
% packets are identified by having a recognized APID, having a secondary 
% header flag set to true, and a version flag set to 0
%
%
%   Changelog
%   2016-06-29  SPL     Initial version (converted from 900Relay C code)
%

    % setup the input validation
    p = inputParser;
    addRequired(p,'byte_buffer',@(x) isnumeric(x));
    addOptional(p,'verbose',1,@isnumeric);
    parse(p,varargin{:});

    % don't run if the array is too short
    if(length(p.Results.byte_buffer) < 8)
        flag = false;
        return
    end
    
    % assume that this is the beginning of a packet, extract the APID and SHDR flag
    [APID, SecHdr, PktType, CCSDSVer, SeqCnt, SegFlag, PktLen] = ExtractPriHdr(p.Results.byte_buffer, Endian.Little);

    % check if the APID matches 
    % FIXME: check against enumeration
    if(ismember(APID,1:20) )
        AP_ID_Match = true;
    else
        AP_ID_Match = false;
    end

    % check if all conditions are met
    if(AP_ID_Match && SecHdr && ~CCSDSVer) 
        if(p.Results.verbose > 0)
            fprintf('PACKET! \n');
        end
        flag = true;
    else
        flag = false;
    end
end