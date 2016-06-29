function displayPkt(varargin)
% displays the contents of a packet
%
% displayPkt(pkt_bytes)
%   decommutates and displays the contents of the packet
%
%   example:
%   displayPkt([0 0 0 0 0 0 0 0 0 0 0 0])
%
% Changelog:
% 2016-06-29    SPL     Initial Version
%

    p = inputParser;
    addRequired(p,'pkt',@(x) isnumeric(x) && isvector(x));
    addOptional(p,'verbose',1,@isnumeric);
    parse(p,varargin{:});

    % extract the primary header fields
    [APID, SecHdr, PktType, CCSDSVer, SeqCnt, SegFlag, PktLen] = ExtractPriHdr(p.Results.pkt(1:6), Endian.Little);
    
    % print the primary header
    fprintf('APID: %d, SHdr: %d, PktType: %d, SeqCnt: %d, SegFlag: %d, PktLen: %d \n',...
        APID, SecHdr, PktType, CCSDSVer, SeqCnt, SegFlag, PktLen);
    
    % process the secondary header depending on what type of packet it is
    if(PktType)
        % extract the command secondary header fields
        [FcnCode, Checksum, Reserved] = ExtractCmdSecHdr(p.Results.pkt(7:8), Endian.Little);
        fprintf('FcnCode: %d, Checksum: %d, Reserved: %d \n',...
            FcnCode, Checksum, Reserved);
        param_start = 8;
    else
        % extract the telemetry secondary header fields
        Time = ExtractTlmSecHdr(p.Results.pkt(7:12), Endian.Little);
        fprintf('Time: %d \n',Time);
        param_start = 12;
    end
    
    % print the packet payload
    if(length(p.Results.pkt) > param_start)
        fprintf('Payload: %02s,',dec2hex(p.Results.pkt(param_start:end)));
    end
    
end