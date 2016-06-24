function [APID, SecHdr, PktType, CCSDSVer, SeqCnt, SegFlag, PktLen] = ExtractPriHdr(arr, endianness)

%    uint8   StreamId[2];  /* packet identifier word (stream ID) */
%  /*  bits  shift   ------------ description ---------------- */
%       /* 0x07FF    0  : application ID                            */
%       /* 0x0800   11  : secondary header: 0 = absent, 1 = present */
%       /* 0x1000   12  : packet type:      0 = TLM, 1 = CMD        */
%       /* 0xE000   13  : CCSDS version, always set to 0            */
% 
%    uint8   Sequence[2];  /* packet sequence word */
%       /*  bits  shift   ------------ description ---------------- */
%       /* 0x3FFF    0  : sequence count                            */
%       /* 0xC000   14  : segmentation flags:  3 = complete packet  */
% 
%    uint8  Length[2];     /* packet length word */
%       /*  bits  shift   ------------ description ---------------- */
%       /* 0xFFFF    0  : (total packet length) - 7                 */
% 
   
    % streamID field
    if(endianness == Endian.Little)
        streamid_tmp = typecast(arr(2:-1:1),'uint16');
    else
        streamid_tmp = typecast(arr(1:2),'uint16');
    end
    
    APID = bitshift(bitand(streamid_tmp,hex2dec('07FF')),0);
    SecHdr = bitshift(bitand(streamid_tmp,hex2dec('0800')),-11);
    PktType = bitshift(bitand(streamid_tmp,hex2dec('1000')),-12);
    CCSDSVer = bitshift(bitand(streamid_tmp,hex2dec('E000')),-13);

    % sequence field
    if(endianness == Endian.Little)
        sequence_tmp = swapbytes(typecast(arr(4:-1:3),'uint16'));
    else
        sequence_tmp = typecast(arr(3:4),'uint16');
    end
    SeqCnt = bitshift(bitand(sequence_tmp,hex2dec('3FFF')),0);
    SegFlag = bitshift(bitand(sequence_tmp,hex2dec('C000')),-14);
    
    % length field
    if(endianness == Endian.Little)
        PktLen = typecast(arr(6:-1:5),'uint16');
    else
        PktLen = typecast(arr(5:6),'uint16');
    end

end