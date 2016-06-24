function get900signal()

    % get streams from base workspace
    if(~evalin('base','exist(''serConn'',''var'')'))
        error('sendCmd:serConnDoesntExist','serConn doesn''t exist is base workspace, are you sure the serial connection is open?');
    end
    if(~evalin('base','exist(''logfile'',''var'')'))
        error('sendCmd:logfileDoesntExist','logfile doesn''t exist is base workspace, are you sure the serial connection is open?');
    end
    
    serConn = evalin('base','serConn');
    logfile = evalin('base','logfile');
    
    fprintf('Entering AT mode \n');
    fprintf(serConn,'+++')
    pause(1);
    fprintf('%s',fgetl(serConn))
    fprintf(serConn,'AT&T=RSSI');
    fprintf('900 report signal sent \n');
   
    pause(2);
    fprintf('%s',fscanf(serConn))
    fprintf('Disabling signal report \n');
    fprintf(serConn,'AT&T');
    pause(0.5);
    fprintf(serConn,'ATZ');
end


% AT&T=RSSI Enables RSSI debugging report
% AT&T=TDM