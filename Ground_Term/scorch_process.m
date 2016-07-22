function scorch_process(pkt)

    [APID, SecHdr, PktType, CCSDSVer, SeqCnt, SegFlag, PktLen] = ExtractPriHdr(pkt, Endian.Little);

    if(PktType)
        % cmd packet
        [FcnCode, Checksum, Reserved] = ExtractCmdSecHdr(pkt, Endian.Little);
        fprintf('SCORCH - Received a command with FcnCode %d \n',FcnCode);
    else
        % telemetry packet
        Time = ExtractTlmSecHdr(pkt(7:12), Endian.Little);
        if(PktLen+7 > 12)
            dec2hex(pkt(13))
            if(pkt(13) == hex2dec('AA'))
                fprintf('SCORCH - SCORCH is ARMED! \n');
            elseif(pkt(13) == hex2dec('DD'))
                fprintf('SCORCH - SCORCH is disarmed! \n');
            elseif(pkt(13) == hex2dec('FF'))
                fprintf('SCORCH - SCORCH FIRED! \n');
            elseif(pkt(13) == hex2dec('AC'))
                fprintf('SCORCH - SCORCH initalized! \n');
            elseif(pkt(13) == hex2dec('AF'))
                fprintf('SCORCH - SCORCH didn''t recongize the message \n');
            elseif(pkt(13) == hex2dec('BB'))
                fprintf('SCORCH - SCORCH didn''t recongize the command FcnCode \n');
            end
        end
    end

end