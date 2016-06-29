function sendCmd(varargin)
% SENDCMD
%
%   sendCmd(APID,FcnCode)
%       sends a command, selected by FcnCode, to APID. Will print packet to
%       command line.
%   sendCmd(APID,FcnCode,0)
%       sends a command, selected by FcnCode, to APID. Will suppress
%       outputs to command line.
%
%   This function expects that the variables serConn and logfile will exist
%   in the base workspace.
% 
%   example:
%   sendCmd(1,10)
%   sendCmd(apid.scorch,scorch.armstatus)
%
% Changelog:
%   2016-04-21  SPL     Initial Version
%   2016-06-24  SPL     Removed option for sending parameters with command,
%                       will be handled by seperate function
%

    % setup the input validation
    p = inputParser;
    addRequired(p,'APID',@(x) validateAPID(x));
    addRequired(p,'FcnCode',@(x) validateFcnCode(x));
    addOptional(p,'verbose',1,@isnumeric);
    parse(p,varargin{:});

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

    % make sure APID and FcnCode are integers (in case user is using
    % enumerations)
    FcnCode = uint8(p.Results.FcnCode);
    APID = uint8(p.Results.APID);
    
    % create the command header
    SeqCnt = 2;     % FIXME: update to actually increment the count
    SegFlag = 3;    % indicates that this is a complete packet
    PktLen = 8;     % a command with no arguments is 8 bytes
    arr = CreateCmdHdr(APID, SeqCnt, SegFlag, PktLen, FcnCode);
    
    % update the length of the packet
    arr(5:6) = typecast(swapbytes(uint16(length(arr)-7)),'uint8');
    
    % update the packet checksum
    arr(7) = calcChecksum(arr);

    % write the packet
    fwrite(serConn,arr);

    % print the packet to the command line
    if(p.Results.verbose > 0)
        fprintf('S %s: ', datestr(now,'HH:MM:SS.FFF'));
        fprintf('%X ', arr);
        fprintf('\n');
    end
    
    % log the packet
    fprintf(logfile,'S %s: ', datestr(now,'HH:MM:SS.FFF'));
    fprintf(logfile,'%X ', arr);
    fprintf(logfile,'\n');
    
end