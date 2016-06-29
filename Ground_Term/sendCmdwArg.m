function arr = sendCmdwArg(APID,FcnCode,varargin)
% SENDCMD
%
%   DO NOT USE - argument interpretation needs reworking
%
%   sendCmd(APID,FcnCode)
%       sends a command, selected by FcnCode, to APID
%
%   sendCmd(APID,FcnCode,varargin)
%       sends a command, selected by FcnCode, to APID including parameters
%   
% Changelog:
%   SPL     2016-04-21  Initial Version
%

%     % get streams from base workspace
%     if(~evalin('base','exist(''serConn'',''var'')'))
%         error('sendCmd:serConnDoesntExist','serConn doesn''t exist is base workspace, are you sure the serial connection is open?');
%     end
%     if(~evalin('base','exist(''logfile'',''var'')'))
%         error('sendCmd:logfileDoesntExist','logfile doesn''t exist is base workspace, are you sure the serial connection is open?');
%     end
%     
%     serConn = evalin('base','serConn');
%     logfile = evalin('base','logfile');
%     
    % create the command header
    SeqCnt = 2;
    SegFlag = 3;
    PktLen = 8; 
    arr = CreateCmdHdr(APID, SeqCnt, SegFlag, PktLen, FcnCode);

    % command definitions
    CMD_NoOp = hex2dec('00');
    CMD_SetTlmCtrl = hex2dec('01');
    CMD_SetCycTime = hex2dec('02');
    CMD_SetTargetNED = hex2dec('03');
    CMD_SetIMU2BODY = hex2dec('04');
    CMD_SetServoEnable = hex2dec('05');
    CMD_SetRWEnable = hex2dec('06');
    CMD_RequestTlmPt = hex2dec('07');
    CMD_SendTestPkt =  	hex2dec('08');
	CMD_SetTlmAddr =	hex2dec('09');
	CMD_SetElPolarity = hex2dec('0A');
    CMD_SetMode = hex2dec('0B');

    % associate commands with how many commands they take
    uint32_arg = [CMD_SetTlmCtrl CMD_RequestTlmPt];
    uint16_arg = [CMD_SetCycTime];
    uint8_arg = [CMD_SetServoEnable CMD_SetRWEnable CMD_SetElPolarity CMD_SetTlmAddr];
    no_arg = [CMD_SendTestPkt CMD_NoOp];
    three_float_args = [CMD_SetTargetNED];
    four_float_args = [CMD_SetIMU2BODY];
    tlm_ctrl = [CMD_SetTlmCtrl CMD_RequestTlmPt];
    uint8_float_arg = [CMD_SetMode];
    
    % tlmctrl arg
%     if(ismember(FcnCode,tlm_ctrl))
%         if(nargin ~= 3)
%            error('sendCmd:IncorrectNumberOfFcnArg','Incorrect number of arguments for fcncode %d',FcnCode);
%         end
%         tlmctrl_val = 0;
%         arg = varargin{1};
%         for i=1:length(arg)
%             tlmctrl_val = tlmctrl_val + 2^arg(i);
%         end
%         tlmctrl_val
%         arr(12:-1:9) = typecast(uint32(tlmctrl_val),'uint8')
%         arr(13) = uint8(0);
%     end
%     
%     return
    % 1 uint32 argument
    if(ismember(FcnCode,uint32_arg))
        if(nargin ~= 3)
           error('sendCmd:IncorrectNumberOfFcnArg','Incorrect number of arguments for fcncode %d',FcnCode);
        end
        arr(12:-1:9) = typecast(uint32(varargin{1}),'uint8');
        arr(13) = uint8(0);
    end
    % 1 uint16 argument
    if(ismember(FcnCode,uint16_arg))
        if(nargin ~= 3)
           error('sendCmd:IncorrectNumberOfFcnArg','Incorrect number of arguments for fcncode %d',FcnCode);
        end
        arr(9:10) = typecast(swapbytes(uint16(varargin{1})),'uint8');
    end
    % 1 uint8 argument
    if(ismember(FcnCode,uint8_arg))
        if(nargin ~= 3)
           error('sendCmd:IncorrectNumberOfFcnArg','Incorrect number of arguments for fcncode %d',FcnCode);
        end
        arr(9) = typecast(uint8(varargin{1}),'uint8');
    end
    % no arguments
    if(ismember(FcnCode,no_arg))
        if(nargin ~= 2)
           error('sendCmd:IncorrectNumberOfFcnArg','Incorrect number of arguments for fcncode %d',FcnCode);
        end
    end
    if(ismember(FcnCode,uint8_float_arg))
        if(nargin ~= 4)
           error('sendCmd:IncorrectNumberOfFcnArg','Incorrect number of arguments for fcncode %d',FcnCode);
        end
        arr(9) = typecast(uint8(varargin{1}),'uint8');
        arr(10:13) = typecast(typecast(varargin{2},'uint32'),'uint8');
    end
    
    
    % update the length of the packet
    arr(5:6) = typecast(swapbytes(uint16(length(arr)-7)),'uint8');
    
    % update the packet checksum
    class(arr)
    calcChecksum(arr)
    arr(7) = calcChecksum(arr);
            
    % write the packet
%     fwrite(serConn,arr);

    % log the packet
%     fprintf('S %s: ', datestr(now,'HH:MM:SS.FFF'));
%     fprintf(logfile,'S %s: ', datestr(now,'HH:MM:SS.FFF'));

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