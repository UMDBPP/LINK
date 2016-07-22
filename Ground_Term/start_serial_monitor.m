function start_serial_monitor(varargin)
% starts the telemetry monitor
%
%   START_SERIAL_MONITOR(serPortn)
%       starts the telemetry monitor on the specified serial port at 9600
%       baud
%   START_SERIAL_MONITOR(serPortn, baud)
%       starts the telemetry monitor of the specified serial port at the
%       specified baud rate
%   START_SERIAL_MONITOR(serPortn, baud, verbose)
%       same as above, but lower verbose numbers will suppress output to
%       the command line
%
%   Sets up a timer callback to periodically poll the serial port for new
%   input. Will attempt to identify the beginning of the packet and parse
%   the byte-stream for a CCSDS header and packet format. Will read the
%   telemetry into a database to allow processing.
%
%   example:
%   START_SERIAL_MONITOR(5)
%   START_SERIAL_MONITOR(5, 9600)
%
%   Changelog:
%   SPL     2016-06-29  Added logging of raw bytes received to prevent data
%                       loss if packets are not parsed correctly. Removed
%                       default serial port (will vary between computers).
%                       Changed to using inputParser to handle input
%                       validation. Added verbosity argument.
%  

    % setup the input validation
    p = inputParser;
    addRequired(p,'serPortn',@(x) validateSerPort(x));
    addOptional(p,'baud',9600,@(x) validateBaudRate(x));
    addOptional(p,'verbose',1,@isnumeric);
    parse(p,varargin{:});
    
    % add necessary folders to path
    setupPath()

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
    serPort = serList{p.Results.serPortn};
    if(p.Results.verbose>0)
        fprintf('Connecting to serial %s \n',serPort);
    end
    
    % create the serial object
    serConn = serial(serPort);

    % check that the user-entered baud rate makes sense
    if(p.Results.verbose>0)
        fprintf('Using baud rate %d \n',p.Results.baud);
    end
    set(serConn,'BaudRate',uint32(p.Results.baud));       


    % try opening the serial port, if it doesn't work, try closing and
    % reopening
    try
        fopen(serConn);
    catch
        fclose(serConn);
        fopen(serConn);
    end
    
    % if the logs directory doesn't exist, create it
    if(~exist(fullfile(fileparts(mfilename('fullpath')),'logs'),'dir'))
        warning('start_serial_monitor:LogsDirMissing','Ground_Term/logs does not exist, creating it');
        mkdir(fullfile(fileparts(mfilename('fullpath')),'logs'));
        addpath(fullfile(fileparts(mfilename('fullpath')),'logs'));
    end
    
    % open a log file
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
    assignin('base','net',init_network());
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

    verbose = 2;

    net = evalin('base','net');
    
    % catch any errors so that the ground stations continues receiving
    try
        
    % get the userdata structure from the timer callback
	UserData = get(src, 'UserData');
    
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
        for k = 1:length(data)
            fprintf(rawlogfile,'%02s,',dec2hex(data(k)));
        end
        fprintf(rawlogfile,'\n');
        
        % print what was received to the command line
        if(verbose > 1)
            fprintf('R %s: ', datestr(now,'yyyy-mm-dd HH:MM:SS.FFF'));
            for k = 1:length(data)
                fprintf('%02s,',dec2hex(data(k)));
            end
%             fprintf('%02s,',dec2hex(UserData.ByteBuffer));
            fprintf('\n');
        end
                    
        % append the new data to what we've read previously
        UserData.ByteBuffer = [UserData.ByteBuffer data];
        
        % iterate through buffer looking for packets
        for i = 1:length(UserData.ByteBuffer)-8
            if(checkpacket(UserData.ByteBuffer(i:end)))
            
                % the location of the packet in the buffer
                pkt_offset = i;
                
                % extract the packet header
                if(i+8 < length(UserData.ByteBuffer))
                
                    % extract the packet length from the primary header
                    [~, ~, ~, ~, ~, ~, PktLen] = ExtractPriHdr(UserData.ByteBuffer(pkt_offset:pkt_offset+8), Endian.Little);

                    total_pktlen = PktLen+7-1;
                    
                    % if the whole packet has been read into the buffer
                    if(pkt_offset+total_pktlen < length(UserData.ByteBuffer))
 
                        % log it
                        fprintf(logfile,'R %s: ', datestr(now,'yyyy-mm-dd HH:MM:SS.FFF'));
                        fprintf(logfile,'%02s,',dec2hex(UserData.ByteBuffer(pkt_offset:pkt_offset+total_pktlen)));
                        fprintf(logfile,'\n');
                        
                        % extract the packet for processing
                        pkt = UserData.ByteBuffer(pkt_offset:pkt_offset+total_pktlen);
                        
                        % display the packet
%                         if(verbose > 0)
%                             displayPkt(pkt);
%                         end
                        
                        % get names of payloads
%                         payloads = fieldnames(net);
%                         APID = ExtractPriHdr(pkt, Endian.Little);

                        % loop through payloads
%                         for j = 1:length(payloads)
                            % if this packet is recognized
%                             if(APID == net.(payloads{j}).apid)
                                % call the appropriate processing function
%                                 net.scorch.procfcn(pkt)
%                             end
%                         end
                        
%                         if j == length(payloads)
%                             fprintf('Unrecognized packet with APID %d\n',APID);
%                         end
                        
                        % remove the pkt bytes from the buffer
                        UserData.ByteBuffer = UserData.ByteBuffer(pkt_offset+total_pktlen:end); 
                    end
                end
                
                % a packet was found and was either processed or was not
                % fully received
                break
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
