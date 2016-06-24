function stop_serial_monitor()
%
%
%

    % stop and delete the timer
    timers = timerfind;
    if(~isempty(timers))
        stop(timers);
        delete(timers);
    end
    evalin('base','clear timer_obj');
    
    % close the serial port
    if(~isempty(instrfind))
        fclose(instrfind);
    end
    evalin('base','clear serConn');
    
    % close the log file
    fclose('all');
    evalin('base','clear logfile');

end