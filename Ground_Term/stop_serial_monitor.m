function stop_serial_monitor()
%   shutdown the ground station
%
%   STOP_SERIAL_MONITOR()
%       closes the serial monitor and the any open log files
%
%   Changelog:
%   2016-06-29  SPL     Added a changelog
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
    
    % close the log files
    fclose('all');
    evalin('base','clear logfile rawlogfile');

end