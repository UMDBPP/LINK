function arr = CreateTlmSecHdr()

    % initalize the output
    arr = uint8(zeros(6,1));
   
    % compile the command field
    time = posixtime(datetime('now'));
        
    sec = typecast(uint32(floor(time)),'uint8');
    subsec = typecast(uint16((time-floor(time))*65535),'uint8');

    % assign to array
    arr(1:4) = sec;
    arr(5:6) = subsec;
    
end