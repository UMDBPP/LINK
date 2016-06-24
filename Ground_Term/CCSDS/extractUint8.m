function [uint8_val, data_idx] = extractUint8(pktdata,data_idx,endianness)

    if(length(pktdata) > data_idx)

        if(endianness == Endian.Little)
            uint8_val = typecast(pktdata(data_idx),'uint8');
        else
            uint8_val = typecast(pktdata(data_idx),'uint8');
        end
        
        data_idx = data_idx + 1;
                
    else
        warning('extractUint8:TooShort','Array doesn''t contain enough elements, returning -1')
        uint8_val = 0;
    end
end