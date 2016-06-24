function [uint16_val, data_idx] = extractUint16(pktdata,data_idx,endianness)

    if(length(pktdata) > data_idx+1)

        if(endianness == Endian.Little)
            uint16_val = typecast(pktdata(data_idx+1:-1:data_idx),'uint16');
        else
            uint16_val = typecast(pktdata(data_idx:data_idx+1),'uint16');
        end
        
        data_idx = data_idx + 2;
                
    else
        warning('extractUint16:TooShort','\nArray doesn''t contain enough elements, returning -1')
        uint16_val = 0;
    end
end