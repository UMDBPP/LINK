function processLogFile(filename)

    if(~exist(filename,'file'))
       error('processLogFile:FileDoesntExist','File ''%s'' cant be found',filename); 
    end

    filelines = textread(filename, '%s', 'delimiter', '\n');

    for i = 1:length(filelines)
        i
        line = filelines{i};
        if(strcmp(line(1),'R'))
            pkt = uint8(hex2dec(strsplit(line(17:end),',')));
            msg = parseMsg(pkt, Endian.Little);
            
        end
    end
    
end