function serConn = tlmmonitor(serPortn, baud)

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

    

   
   
%     % setup callback function to process data
%     set(serConn,'BytesAvailableFcnMode','byte');
%     set(serConn,'BytesAvailableFcnCount',64);
%     set(serConn,'BytesAvailableFcn',@testcallback); 

    % open the serial port
    try
        fopen(serConn);
    catch
        fclose(serConn);
        fopen(serConn);
    end
    
    % assign the serial connection to the base workspace so the user can
    % interact with it
    assignin('base','serConn',serConn);
    fprintf('\n');

end



function testcallback(serConn,varargin)

    persistent UserData
    
    if(~exist('UserData','var'))
        UserData = 1;
    else
        UserData = UserData + 1;
    end
        
%     if(~isfield(varargin{1}.Data,'mydata'))
%         varargin{1}.Data.UserData = 1;
%     else
%          varargin{1}.Data.UserData = varargin{1}.Data.UserData+1;
%     end
%     varargin{1}.Data
%     varargin{1}.Data.UserData
%     persistent bytes_rcvd

    % read all the data available      
    RxText = fread(serConn,serConn.BytesAvailable);

%     % convert it from char to integer
%     data = uint8(RxText);
%     
%     fprintf('read %d bytes\n',length(data));
%     
%     % look for the xbee sync bytes
%     if(data(1)== hex2dec('7E'))
%         
%         % strip off the xbee header
%         data = data(9:end).';
%         
%         % if its from the xbee, its little endian
%         endianness = Endian.Little;
%     else
%         endianness = Endian.Little;
%         data = data.';
%     end
% 
%     % if it looks like a BADASS message
%     if(all(data(1:2)== [hex2dec('08') hex2dec('2')] ))
% 
%         % parse the message
%         msg = parseMsg(data,endianness);
% 
%         % output it to the command line
%         fprintf('R %s: ', datestr(now,'HH:MM:SS.FFF'));
%         for i=1:length(data)
%             fprintf('%s',dec2hex(data(i)));
%             if(i~=length(data))
%                 fprintf(',');
%             end
% 
%         end
%         fprintf('\n');
%     % otherwise we must be out of sync
%     else
%         % print it to the command line
%         fprintf('Out of synch, waiting, got: \n');
%         for i=1:length(RxText)
%             fprintf('%s',dec2hex(uint8(RxText(i))));
%             if(i~=length(RxText))
%                 fprintf(',');
%             end
% 
%         end
%         fprintf('\n');
% 
%         % flush the input to try to resync us
%         flushinput(serConn);
%         pause(0.01);
% 
%     end

end
