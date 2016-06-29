function start_serial_monitor(varargin)
% starts the telemetry monitor
%
%   start_serial_monitor()
%       starts the telemetry monitor on COM8 at 9600 baud
%   start_serial_monitor(serPortn)
%       starts the telemetry monitor on the specified serial port at 9600
%       baud
%   start_serial_monitor(serPortn, baud)
%       starts the telemetry monitor of the specified serial port at the
%       specified baud rate
%
%   Sets up a timer callback to periodically poll the serial port for new
%   input. Will attempt to identify the beginning of the packet and parse
%   the byte-stream for a CCSDS header and packet format. Will read the
%   telemetry into a database to allow processing.
%

    % add necessary folders to path
    setupPath()

    % set default inputs
    serPortn = 8;
    baud = 9600;
    
    % check for inputs, override defaults with function inputs
    if(nargin > 0)
        serPortn = varargin{1};
    elseif(nargin > 1)
        baud = varargin{2};
    elseif(nargin > 2)
        error('start_serial_monitor:Too many arguments','Too many arguments supplied');
    end

    % define strings corresponding to serial ports
    serList = [{'COM1'} ; ...
         {'COM2'} ; ...
         {'COM3'} ; ...
         {'COM4'} ; ...
         {'COM5'} ; ...
         {'COM6'} ; ...
         {'COM7'} ; ...
         {'COM8'} ; ...
         {'COM9'} ; ...
         {'COM10'} ; ...
         {'COM11'} ; ...
         {'COM12'} ];

    % get the user-specified port
    serPort = serList{serPortn};
    fprintf('Connecting to serial %s \n',serPort);
    
    % create the serial object
    serConn = serial(serPort);

    % check that the user-entered baud rate makes sense
    valid_baudrates = [300, 600, 1200, 2400, 4800, 9600, 14400, 19200, 28800, 38400, 57600, 115200, 250000];
    if(isnumeric(baud))
        if(~ismember(baud,valid_baudrates))
            warning('BADASSCmdTlmMonitor:connectBtnCallback:NonStandardBaud', 'The entered baud rate, ''%d'' is not a standard baud rate and may not work, connecting...',baud)
        else
            fprintf('Using baud rate %d \n',baud);
        end
        set(serConn,'BaudRate',uint32(baud));       
    else
        warning('BADASSCmdTlmMonitor:connectBtnCallback:NonIntBaud', 'The entered baud rate, ''%d'' is not an numeric value, enter a integer value and connect again.',baud)
        return
    end

    % try opening the serial port, if it doesn't work, try closing and
    % reopening
    try
        fopen(serConn);
    catch
        fclose(serConn);
        fopen(serConn);
    end
    
    % open a log file
    if(~exist(fullfile(fileparts(mfilename('fullpath')),'logs'),'dir'))
        warning('start_serial_monitor:LogsDirMissing','Ground_Term/logs does not exist, creating it');
        mkdir(fullfile(fileparts(mfilename('fullpath')),'logs'));
        addpath(fullfile(fileparts(mfilename('fullpath')),'logs'));
    end
    logfile = fopen('logs/log.txt','a');
    rawlogfile = fopen('logs/rawlog.txt','a');

    % create timer object
    t=timer;
    t.StartFcn = @initTimer;
    t.TimerFcn = {@timerCallback, serConn, logfile, rawlogfile};
    t.StopFcn = {@closeTimer, serConn, logfile};
    t.Period   = 0.25;
    t.ExecutionMode  = 'fixedRate';
    t.ErrorFcn = {@ecallback, serConn, logfile};
    start(t);
    
    % assign timer and serial ports into base workspace 
    assignin('base','timer_obj',t);
    assignin('base','serConn',serConn);
    assignin('base','logfile',logfile);
end

function ecallback(~, ~, serConn, logfile)
%
% timer error callback. Gets the error are prints it for the user (since
% error messages don't get printed to the command line if they occur in
% timer callbacks). Also closes the serial connection and logfile and
% cleans up the workspace.
% 
    disp(getReport(ME))
    err = lasterror();
    disp(err.message);

    for i = 1:length(err.stack)
        fprintf('Error in %s on line %d \n',err.stack(i,1).name,err.stack(i,1).line)
    end
    
    % close the serial connection
    fclose(serConn);
    delete(serConn)
    evalin('base','clear serConn');

    % close the log file
    fclose(logfile);
    evalin('base','clear logfile');

    % clear the serial and timer objects from the base workspace
    evalin('base','clear timer_obj');
    
end

function initTimer(src, ~)
%
%   initalizes the timer callback's userdata used to store bytes read from
%   the serial port
% 

    % get userdata structure 
    UserData = get(src, 'UserData');
    
    % create the byte buffer
    UserData.ByteBuffer = 0.';
    
    disp('Initialised bytebuffer')
    
    % save the userdata structure back into the callback
    set(src, 'UserData',UserData);
    
end

function closeTimer(~, ~, serConn, logfile)
%
% timer close function callback. Closes the serial connection and log file
% and cleans up the workspace.
%

    % close the serial connection
    fclose(serConn);
    delete(serConn);
    evalin('base','clear serConn');

    % close the log file
    fclose(logfile);
    evalin('base','clear logfile');

    % clear the serial and timer objects from the base workspace
    evalin('base','clear timer_obj');
    
end

function timerCallback(src, ~, serConn, logfile, rawlogfile)
% called at timer frequency, reads data from serial port, processes it, and
% saves it into the telemetry database

    try
    % get the userdata structure from the timer callback
	UserData = get(src, 'UserData');
    total_pktlen = 0;
    
    % if there are bytes to read, read them
    if(serConn.BytesAvailable > 0)
        RxText = fread(serConn,serConn.BytesAvailable);
        
        % convert it from char to integer
        data = uint8(RxText);
        
        % make sure the data is a row
        if(size(data,1) > size(data,2))
            data = data.';
        end
        
        % log everything received to the raw log file
        fprintf(rawlogfile,'R %s: ', datestr(now,'yyyy-mm-dd HH:MM:SS.FFF'));
        
        % append the new data to what we've read previously
        UserData.ByteBuffer = [UserData.ByteBuffer data];
        
        % define the length of an xbee header
        xbee_hdr_len = 6;

        % look for link responses
        link_respond = strfind(UserData.ByteBuffer, [hex2dec('08') hex2dec('03')]);
        
        % look for header bytes
        pkt_loc = strfind(UserData.ByteBuffer, [hex2dec('08') hex2dec('02')]);
        
        % combine the results from looking for packets
        pkt_loc = [pkt_loc link_respond];
        
        % if a packet was found
        if(~isempty(pkt_loc))
            
            % take the first packet found in the buffer
            pkt_loc = pkt_loc(1);
            
            fprintf('Found pkt at %d \n',pkt_loc);
            
            % extract the packet header
            if(pkt_loc+xbee_hdr_len < length(UserData.ByteBuffer))

                pkthdr = UserData.ByteBuffer(pkt_loc:pkt_loc+xbee_hdr_len);
                
                % extract the packet length
                [~, ~, ~, ~, ~, ~, PktLen] = ExtractPriHdr(pkthdr, Endian.Little);
 
                total_pktlen = PktLen+7-1;
   
                % if we've received the entire packet, process it
                if(pkt_loc+total_pktlen < length(UserData.ByteBuffer))
 
                    % output it to the command line
                    fprintf('R %s: ', datestr(now,'yyyy-mm-dd HH:MM:SS.FFF'));
                    fprintf(logfile,'R %s: ', datestr(now,'yyyy-mm-dd HH:MM:SS.FFF'));

                    for i=pkt_loc:pkt_loc+total_pktlen
                        fprintf('%02s',dec2hex(UserData.ByteBuffer(i)));
                        fprintf(logfile,'%02s',dec2hex(UserData.ByteBuffer(i)));
                        if(i~=length(UserData.ByteBuffer))
                            fprintf(',');
                            fprintf(logfile,',');
                        end
                    end
                    fprintf('\n');
                    fprintf(logfile,'\n');
                    
                    % extract the packet for processing
                    pkt = UserData.ByteBuffer(pkt_loc:pkt_loc+total_pktlen);

                    % remove the pkt bytes from the buffer
                    UserData.ByteBuffer = UserData.ByteBuffer(pkt_loc+total_pktlen:end); 

                    % parse the telemetry
                    msg = parseMsg(pkt, Endian.Little);
               
                else 
                    warning('timeCallback:TooShortForHeader','Not enough bytes for valid header');
                end
                                
            end
        end
    end
    
    % save the bytebuffer to the timer userdata and workspace for the next
    % time
    set(src, 'UserData',UserData);
    assignin('base','ByteBuffer',UserData.ByteBuffer);
    
    catch ME
        fprintf('\n');
        disp(getReport(ME));
        
    end
 
end
