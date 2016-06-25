function sendCmd(APID,FcnCode)
% SENDCMD
%
%   sendCmd(APID,FcnCode)
%       sends a command, selected by FcnCode, to APID
%
% Changelog:
%   2016-04-21  SPL     Initial Version
%   2016-06-24  SPL     Removed option for sending parameters with command,
%                       will be handled by seperate function
%

    % check that streams exist in base workspace
    if(~evalin('base','exist(''serConn'',''var'')'))
        error('sendCmd:serConnDoesntExist','serConn doesn''t exist is base workspace, are you sure the serial connection is open?');
    end
    if(~evalin('base','exist(''logfile'',''var'')'))
        error('sendCmd:logfileDoesntExist','logfile doesn''t exist is base workspace, are you sure the serial connection is open?');
    end
    
    % get the streams from the base workspace
    serConn = evalin('base','serConn');
    logfile = evalin('base','logfile');

    % make sure the FcnCode is an integer (in case user is using
    % enumerations)
    FcnCode = uint8(FcnCode);
    
    % create the command header
    SeqCnt = 2;     % FIXME: update to actually increment the count
    SegFlag = 3;    % indicates that this is a complete packet
    PktLen = 8;     % a command with no arguments is 8 bytes
    arr = CreateCmdHdr(APID, SeqCnt, SegFlag, PktLen, FcnCode);
    
    % update the length of the packet
    arr(5:6) = typecast(swapbytes(uint16(length(arr)-7)),'uint8');
    
    % update the packet checksum
    arr(7) = calcChecksum(arr);
arr
    % write the packet
    fwrite(serConn,arr);

    % print the packet to the command line
    fprintf('S %s: ', datestr(now,'HH:MM:SS.FFF'));
    fprintf('%X ', arr);
    fprintf('\n');
    
    % log the packet
    fprintf(logfile,'S %s: ', datestr(now,'HH:MM:SS.FFF'));
    fprintf(logfile,'%X ', arr);
    fprintf(logfile,'\n');
    
end