function rebootremote900()

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
    fprintf(serConn,'RATZ')
    fprintf('900 remote reboot signal sent \n');
end