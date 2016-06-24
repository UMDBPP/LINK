function sendCmd2(APID,FcnCode)
% SENDCMD
%
%   sendCmd(APID,FcnCode)
%       sends a command, selected by FcnCode, to APID
%
%   sendCmd(APID,FcnCode,varargin)
%       sends a command, selected by FcnCode, to APID including parameters
%
%   Steve Lentine
%   4/21/16
%

%     % get streams from base workspace
%     if(~evalin('base','exist(''serConn'',''var'')'))
%         error('sendCmd:serConnDoesntExist','serConn doesn''t exist is base workspace, are you sure the serial connection is open?');
%     end
%     if(~evalin('base','exist(''logfile'',''var'')'))
%         error('sendCmd:logfileDoesntExist','logfile doesn''t exist is base workspace, are you sure the serial connection is open?');
%     end
%     
    serConn = evalin('base','serConn');
    logfile = evalin('base','logfile');
%     
    % create the command header
    SeqCnt = 2;
    SegFlag = 3;
    PktLen = 8; 
    arr = CreateCmdHdr(APID, SeqCnt, SegFlag, PktLen, FcnCode);

    % command definitions
    
    % update the length of the packet
    arr(5:6) = typecast(swapbytes(uint16(length(arr)-7)),'uint8');
    
    % update the packet checksum
    calcChecksum(arr)
    arr(7) = calcChecksum(arr);

    % write the packet
    fwrite(serConn,arr);

    % log the packet
    fprintf('S %s: ', datestr(now,'HH:MM:SS.FFF'));
    fprintf('%X ', arr);
    fprintf('\n');
    fprintf(logfile,'S %s: ', datestr(now,'HH:MM:SS.FFF'));

    % print the packet to the command line and log file
%     for i=1:length(arr)
%         fprintf('%02s',dec2hex(arr(i)));
%         fprintf(logfile,'%02s',dec2hex(arr(i)));
%         if(i~=length(arr))
%             fprintf(',');
%             fprintf(logfile,',');
%         end
%     end
%     fprintf('\n');
%     fprintf(logfile,'\n');
    
end