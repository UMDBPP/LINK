function mars_process(pkt)

    [APID, SecHdr, PktType, CCSDSVer, SeqCnt, SegFlag, PktLen] = ExtractPriHdr(pkt, Endian.Little);

    if(PktType)
        % cmd packet
        [FcnCode, Checksum, Reserved] = ExtractCmdSecHdr(pkt, Endian.Little);
        fprintf('MARS - Received a command with FcnCode %d \n',FcnCode);
    else
        % telemetry packet
        Time = ExtractTlmSecHdr(pkt(7:12), Endian.Little);
        
        % process scorch status packet
        if(APID == 10)
            fprintf('Recieved MARS status packet \n');
            if(PktLen+7 > 12)
                if(pkt(13) == hex2dec('AA'))
                    fprintf('MARS - MARS is ARMED! \n');
                elseif(pkt(13) == hex2dec('DD'))
                    fprintf('MARS - MARS is disarmed! \n');
                elseif(pkt(13) == hex2dec('FF'))
                    fprintf('MARS - MARS FIRED! \n');
                elseif(pkt(13) == hex2dec('AC'))
                    fprintf('MARS - MARS initalized! \n');
                elseif(pkt(13) == hex2dec('AF'))
                    fprintf('MARS - MARS didn''t recongize the message \n');
                elseif(pkt(13) == hex2dec('BB'))
                    fprintf('MARS - MARS didn''t recongize the command FcnCode \n');
                else
                    fprintf('GANADORF status packet is shorter than expected \n');
                end
            end
        end
    end

end