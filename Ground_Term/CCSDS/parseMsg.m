function msg = parseMsg(byte_arr, endianness)

    % get telemetry data from base workspace (or create it if it doesn't exist)
    try
        TLM = evalin('base','TLM');
    catch
        warning('parseMsg:TLMDBmissing','Telemetry database doesn''t appear to exist, creating it...')
        evalin('base','TLM = createTlmDatabase;');
        TLM = evalin('base','TLM');
    end

    byte_arr = uint8(byte_arr);
    
    byte_arr_len = length(byte_arr);
    
    pri_hdr = byte_arr(1:6);
    
    % check if packet is long enough to 
    if(byte_arr_len < 8)
       error('parseMsg:ShortPacket','The packet is %d bytes long, which is too short to be a valid packet',byte_arr_len);
    end

    % extract primary header
    [msg.APID, msg.SecHdr, msg.PktType, msg.CCSDSVer, msg.SeqCnt, msg.SegFlag, msg.PktLen] = ExtractPriHdr(pri_hdr, endianness);
    
    if(msg.CCSDSVer)
        warning('parseMsg:CCSDSVer','The CCSDS version is expected to be 0, but is ''%d''. This may indicate a malformed packet.',msg.CCSDSVer);
    end
    
    % extract the secondary header depending on if its a command or
    % telemetry message
    if(msg.PktType)
        
        cmd_sec_hdr = byte_arr(7:8);
        
        % calculate the packet checksum
        checksum = calcChecksum(pri_hdr);
        
        % extract the secondary header
        [msg.FcnCode, msg.Checksum, msg.Reserved] = ExtractCmdSecHdr(cmd_sec_hdr, endianness);
        
        % extract the packet's payload
        pktdata = byte_arr(13:end);
        
        % inform the user
        fprintf('Received a command, fcncode = %d, ', msg.FcnCode);
        if (checksum == msg.Checksum)
            fprintf('with valid checksum. \n');
        else
            fprintf('with invalid checksum. \n');
        end
        
        msg.Time = -1;
        
        return
    else
        
        tlm_sec_hdr = byte_arr(7:12);
        
        % check that packet is long enough to extract
        if(byte_arr_len < 12)
           error('parseMsg:ShortTlmHdr','The header of the telemetry packet is %d bytes long, which is too short to be a valid telemetry header.',byte_arr_len);
        end
        
        % extract the secondary header
        msg.Time = ExtractTlmSecHdr(tlm_sec_hdr, endianness);
        
        % extract the packet's payload
        pktdata = byte_arr(13:end);

    end
    
    Time = datenum(now());
    
    TLM.APID = addsample(TLM.APID, ...
            'Data', msg.APID, 'Time', Time);
    TLM.SecHdr = addsample(TLM.SecHdr, ...
            'Data', msg.SecHdr, 'Time', Time);
    TLM.CCSDSVer = addsample(TLM.CCSDSVer, ...
            'Data', msg.CCSDSVer, 'Time', Time);
    TLM.SeqCnt = addsample(TLM.SeqCnt, ...
            'Data', msg.SeqCnt, 'Time', Time);
    TLM.SegFlag = addsample(TLM.SegFlag, ...
            'Data', msg.SegFlag, 'Time', Time);
    TLM.PktLen = addsample(TLM.PktLen, ...
            'Data', msg.PktLen, 'Time', Time);    
        
    
    if(msg.PktType)
        TLM.FcnCode = addsample(TLM.FcnCode, ...
            'Data', msg.FcnCode, 'Time', Time);
        TLM.Checksum = addsample(TLM.Checksum, ...
            'Data', msg.Checksum, 'Time', Time);
        TLM.Reserved = addsample(TLM.Reserved, ...
            'Data', msg.Reserved, 'Time', Time);
    else
        TLM.Time = addsample(TLM.Time, ...
            'Data', Time, 'Time', Time);
        
    end
    
    fprintf('%d bytes of data \n',length(pktdata));
    
    %% Defines
    % must match arduino defines
	TLMMask_TlmCtrl =   	hex2dec('00000001'); % 2^0
	TLMMask_TargetNED =   	hex2dec('00000002'); % 2^1
	TLMMask_BNOCal =        hex2dec('00000004'); % 2^2
	TLMMask_EulerAng  =   	hex2dec('00000008'); % 2^3
	TLMMask_q_imu2body =   	hex2dec('00000010'); % 2^4
	TLMMask_q_ned2imu =   	hex2dec('00000020'); % 2^5
	TLMMask_q_ned2body =    hex2dec('00000040'); % 2^6
	TLMMask_v_targetbody =  hex2dec('00000080'); % 2^7
	TLMMask_AzElErr =   	hex2dec('00000100'); % 2^8
	TLMMask_ElCmd	=   	hex2dec('00000200'); % 2^9
	TLMMask_CycleTime =   	hex2dec('00000400'); % 2^10
	TLMMask_CmdRcvd =   	hex2dec('00000800'); % 2^11
	TLMMask_DesiredCycTime = hex2dec('00001000'); % 2^12
	TLMMask_Temp1 =         hex2dec('00002000'); % 2^14
	TLMMask_Temp2 =         hex2dec('00004000'); % 2^15
	TLMMask_TempBME =   	hex2dec('00008000'); % 2^16
	TLMMask_Pres =          hex2dec('00010000'); % 2^17
	TLMMask_PresAlt  =   	hex2dec('00020000'); % 2^18
	TLMMask_Humid =         hex2dec('00040000'); % 2^19
	TlmMask_Current=        hex2dec('00080000'); % 2^20
	TLMMask_Volt=           hex2dec('00100000'); % 2^21
    TLMMask_InitStat =   	hex2dec('00200000'); % 2^22
    TLMMask_MsgSent =       hex2dec('00400000'); % 2^23
    TLMMask_MsgRcvd =       hex2dec('00800000'); % 2^24
    TLMMask_Mode  =         hex2dec('01000000'); % 2^25
    TLMMask_LINKCtr  =      hex2dec('02000000'); % 2^26
	TLMMask_Time          = hex2dec('04000000'); % 2^27
    
    % initalize to beginning of packet
    data_idx = 1;

    % the first 4 bytes of the packet is expected to be a bitfield
    % indicating the telemetry it contains
    
    if(endianness == Endian.Little)
        tlmctrl = typecast(pktdata(data_idx+3:-1:data_idx),'uint32');
    else
        tlmctrl = typecast(pktdata(data_idx:data_idx+3),'uint32');
    end
    TLM.tlmctrl = addsample(TLM.tlmctrl, 'Data', tlmctrl, 'Time', Time);
    data_idx = data_idx + 4;

    fprintf('Tlmctrl: %08d, ',tlmctrl);
    
    % extract target_ned
    if(bitand(tlmctrl,TLMMask_TargetNED))
        [vec_tmp, data_idx] = extractvec(pktdata,data_idx,3, endianness);
        TLM.v_target_ned = addsample(TLM.v_target_ned, ...
            'Data', vec_tmp, 'Time', Time);
        
        fprintf('Target_NED: [%0.2f %0.2f %0.2f], ',vec_tmp);
    end
    
    % extrac cal values
    if(bitand(tlmctrl,TLMMask_BNOCal))
        [uint8_val(1), data_idx] = extractUint8(pktdata,data_idx,endianness);
        [uint8_val(2), data_idx] = extractUint8(pktdata,data_idx,endianness);
        [uint8_val(3), data_idx] = extractUint8(pktdata,data_idx,endianness);
        [uint8_val(4), data_idx] = extractUint8(pktdata,data_idx,endianness);

        TLM.bno_cal = addsample(TLM.bno_cal, ...
            'Data', uint8_val, 'Time', Time);
        
        fprintf('BNOCal: [%d %d %d %d], ',uint8_val);
    end
    
    % extract euler angles
    if(bitand(tlmctrl,TLMMask_EulerAng))
        [vec_tmp, data_idx] = extractvec(pktdata,data_idx,3, endianness);
        TLM.euler_ang = addsample(TLM.euler_ang, ...
            'Data', vec_tmp, 'Time', Time);
        
        fprintf('EulerAng: [%0.2f %0.2f %0.2f], ',vec_tmp);
    end
    
    % extract q_imu2body
    if(bitand(tlmctrl,TLMMask_q_imu2body))
        [vec_tmp, data_idx] = extractvec(pktdata,data_idx,4, endianness);
        TLM.q_imu2body = addsample(TLM.q_imu2body, ...
            'Data', vec_tmp, 'Time', Time);
        
        fprintf('Q_IMU2Body: [%0.2f %0.2f %0.2f %0.2f], ',vec_tmp);
    end
        
    % extract q_ned2imu
    if(bitand(tlmctrl,TLMMask_q_ned2imu))
        [vec_tmp, data_idx] = extractvec(pktdata,data_idx,4, endianness);
        TLM.q_ned2imu = addsample(TLM.q_ned2imu, ...
            'Data', vec_tmp, 'Time', Time);
        
        fprintf('Q_NED2IMU: [%0.2f %0.2f %0.2f %0.2f], ',vec_tmp);
    end
    
    % extract q_ned2body
    if(bitand(tlmctrl,TLMMask_q_ned2body))
        [vec_tmp, data_idx] = extractvec(pktdata, data_idx, 4, endianness);
        TLM.q_ned2body = addsample(TLM.q_ned2body, ...
            'Data', vec_tmp, 'Time', Time);
        
        fprintf('Q_NED2Body: [%0.2f %0.2f %0.2f %0.2f], ',vec_tmp);
    end
    
    % extract v_targetbody
    if(bitand(tlmctrl,TLMMask_v_targetbody))
        [vec_tmp, data_idx] = extractvec(pktdata, data_idx, 3, endianness);
        TLM.v_targetbody = addsample(TLM.v_targetbody, ...
            'Data', vec_tmp, 'Time', Time);
        
        fprintf('V_TargetBody: [%0.2f %0.2f %0.2f], ',vec_tmp);
    end
    
    % extract azel_err
    if(bitand(tlmctrl,TLMMask_AzElErr))
        [vec_tmp, data_idx] = extractvec(pktdata, data_idx, 2, endianness);
        TLM.azel_err = addsample(TLM.azel_err, ...
            'Data', vec_tmp, 'Time', Time);
        
        fprintf('AzElErr: [%0.2f %0.2f], ',vec_tmp*180/pi);

    end
    
    % extract el_cmd
    if(bitand(tlmctrl,TLMMask_ElCmd))
        
        [int16_tmp, data_idx] = extractInt16(pktdata,data_idx,endianness);
        
        TLM.el_cmd = addsample(TLM.el_cmd, ...
            'Data',int16_tmp, 'Time', Time);
        
        fprintf('ElCmd: %d, ',int16_tmp);
        
    end
    
    % extract cycle_time
    if(bitand(tlmctrl,TLMMask_CycleTime))
        [uint16_val, data_idx] = extractUint16(pktdata,data_idx,endianness);

        TLM.cycle_time = addsample(TLM.cycle_time, ...
            'Data', uint16_val, 'Time', Time);
        
        fprintf('CycTime: %d, ',uint16_val);
    end
    
    % extract cmd_rcvd
    if(bitand(tlmctrl,TLMMask_CmdRcvd))
        [uint8_val, data_idx] = extractUint8(pktdata,data_idx,endianness);
        
        TLM.cmd_rcvd = addsample(TLM.cmd_rcvd, ...
            'Data', uint8_val, 'Time', Time);
        
        fprintf('CmdRcvd: %d, ',uint8_val);
                
    end
    
    % extract desired_cyc_time
    if(bitand(tlmctrl,TLMMask_DesiredCycTime))
        [uint16_val, data_idx] = extractUint16(pktdata,data_idx,endianness);
        
        TLM.desired_cyc_time = addsample(TLM.desired_cyc_time, ...
            'Data', uint16_val, 'Time', Time);
        
        fprintf('DesiredCmdRcvd: %d, ',uint16_val);
    end
    
    % extract temp1
    if(bitand(tlmctrl,TLMMask_Temp1))
        [float_val, data_idx] = extractFloat(pktdata,data_idx,endianness);
        
        TLM.temp1 = addsample(TLM.temp1, ...
            'Data', float_val, 'Time', Time);
        
        fprintf('Temp1: %0.2f, ',float_val);

    end
    
    % extract temp2
    if(bitand(tlmctrl,TLMMask_Temp2))
        [float_val, data_idx] = extractFloat(pktdata,data_idx,endianness);
        
        TLM.temp2 = addsample(TLM.temp2, ...
            'Data', float_val, 'Time', Time);
        
        fprintf('Temp2: %0.2f, ',float_val);
    end

    % extract tempbme
    if(bitand(tlmctrl,TLMMask_TempBME))
        [float_val, data_idx] = extractFloat(pktdata,data_idx,endianness);
        TLM.tempbme = addsample(TLM.tempbme, ...
            'Data', float_val, 'Time', Time);
        
        fprintf('Tempbme: %0.2f, ',float_val);
    end
    
    % extract pres
    if(bitand(tlmctrl,TLMMask_Pres))
        [float_val, data_idx] = extractFloat(pktdata,data_idx,endianness);
        TLM.pres = addsample(TLM.pres, ...
            'Data', float_val, 'Time', Time);
        fprintf('Pressure: %0.2f, ',float_val);
    end
    
    % extract presalt
    if(bitand(tlmctrl,TLMMask_PresAlt))
        [float_val, data_idx] = extractFloat(pktdata,data_idx,endianness);
        TLM.alt = addsample(TLM.alt, ...
            'Data', float_val, 'Time', Time);
        fprintf('Alt: %0.2f, ',float_val);
    end

    % extract humidity
    if(bitand(tlmctrl,TLMMask_Humid))
        [float_val, data_idx] = extractFloat(pktdata,data_idx,endianness);

        TLM.humid = addsample(TLM.humid, ...
            'Data', float_val, 'Time', Time);
        fprintf('Humid: %0.2f, ',float_val);
    end
    
    % extract current
    if(bitand(tlmctrl,TlmMask_Current))
        [int16_val, data_idx] = extractInt16(pktdata,data_idx,endianness);
        
        TLM.current = addsample(TLM.current, ...
            'Data', int16_val, 'Time', Time);
%         'Data', uint16_val*0.03, 'Time', Time);
        fprintf('Current: %d, ',int16_val);

    end
    
    % extract volt
    if(bitand(tlmctrl,TLMMask_Volt))
        
        [int16_val, data_idx] = extractInt16(pktdata,data_idx,endianness);

        TLM.voltage = addsample(TLM.voltage, ...
            'Data', int16_val, 'Time', Time);
        %             'Data', int16_val*0.00298535/0.3267, 'Time', Time);
        
        fprintf('Volt: %d, ',int16_val);

    end

    % extract initstat
    if(bitand(tlmctrl,TLMMask_InitStat))
        
        [uint16_val, data_idx] = extractUint16(pktdata,data_idx,endianness);
        
        TLM.initstat = addsample(TLM.initstat, ...
            'Data', uint16_val, 'Time', Time);
        
        fprintf('InitStat: %d, ',uint16_val);
    end
    
    % extract msgsent
    if(bitand(tlmctrl,TLMMask_MsgSent))
        
        [uint32_val, data_idx] = extractUint32(pktdata,data_idx,endianness);
        
        TLM.msgsent = addsample(TLM.msgsent, ...
            'Data', uint32_val, 'Time', Time);
        
        fprintf('MsgSentCtr: %d, ',uint32_val);

    end
    
    % extract msgrcvd
    if(bitand(tlmctrl,TLMMask_MsgRcvd))
        
        [uint32_val, data_idx] = extractUint32(pktdata,data_idx,endianness);

        TLM.msgrcvd = addsample(TLM.msgrcvd, ...
            'Data', uint32_val, 'Time', Time);
        
        fprintf('MsgRcvdCtr: %d, ',uint32_val);

    end
    
    % extract mode
    if(bitand(tlmctrl,TLMMask_Mode))
        
        [uint16_val, data_idx] = extractUint16(pktdata,data_idx,endianness);
        
        TLM.mode = addsample(TLM.mode, ...
            'Data', uint16_val, 'Time', Time);
        fprintf('Mode: %d, ',uint16_val);

    end
    
    % extract mode
    if(bitand(tlmctrl,TLMMask_LINKCtr))
        
        [uint32_val, data_idx] = extractUint32(pktdata,data_idx,endianness);
        
        TLM.LINKCtr = addsample(TLM.LINKCtr, ...
            'Data', uint32_val, 'Time', Time);
        fprintf('LINKCtr: %d, ',uint32_val);

    end
    
    % extract time
    if(bitand(tlmctrl,TLMMask_Time))
        
        [uint32_val, data_idx] = extractUint32(pktdata,data_idx,endianness);
        
        TLM.FSWTime = addsample(TLM.FSWTime, ...
            'Data', uint32_val, 'Time', Time);
        fprintf('FSWTime: %d, ',uint32_val);

    end
    
    
    fprintf('\n');
    
    % put the data back into the base workspace
    assignin('base','TLM',TLM);

end