function [arr, char_arr, str_arr] = CreatePriHdr(APID, SecHdr, PktType, CCSDSVer, SeqCnt, SegFlag, PktLen)

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

    if(APID > 2047)
        warning('CreatePriHdr:APIDOutOfRange','APID is out of range and may be truncated');
    end
    if(SegFlag > 3)
        warning('CreatePriHdr:SegFlgOutOfRange','Segmentation flag is out of range and may be truncated');
    end
    if(PktType > 1)
        warning('CreatePriHdr:PktTypeOutOfRange','Packet Type flag is out of range and may be truncated');
    end

    arr = uint8(zeros(6,1));
   
    % streamID field
    streamid_tmp = uint16(0);
    
    streamid_tmp = bitor(swapbytes(bitand(uint16(APID),hex2dec('07FF'))),streamid_tmp);
    streamid_tmp = bitor(bitand(bitshift(uint16(SecHdr),3),hex2dec('0008')),streamid_tmp);
    streamid_tmp = bitor(bitand(bitshift(uint16(PktType),4),hex2dec('0010')),streamid_tmp);
    streamid_tmp = bitor(bitand(bitshift(uint16(CCSDSVer),5),hex2dec('00E0')),streamid_tmp);

    streamid = typecast(streamid_tmp,'uint8');

    % sequence field
    sequence_tmp = uint16(0);
    sequence_tmp = bitor(swapbytes(bitand(uint16(SeqCnt),hex2dec('3FFF'))),sequence_tmp);    
    sequence_tmp = bitor(bitand(bitshift(uint16(SegFlag),6),hex2dec('C0')),sequence_tmp);

    sequence = typecast(sequence_tmp,'uint8');
    
    % length field
    length_tmp = swapbytes(uint16(PktLen-7));
    
    length = typecast(length_tmp,'uint8');

    % assign to array
    arr(1) = streamid(1);
    arr(2) = streamid(2);
    arr(3) = sequence(1);
    arr(4) = sequence(2);
    arr(5) = length(1);
    arr(6) = length(2);
    
    arr = arr.';
    
    % convert to characters
    char_arr = char(arr.');
    
    % convert to string of number
    str_arr = strrep(regexprep(num2str(arr),' +',' '),' ',',');


end