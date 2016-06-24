function [uint32_val, data_idx] = extractUint32(pktdata,data_idx,endianness)

    if(length(pktdata) > data_idx+3)

        if(endianness == Endian.Little)
            uint32_val = typecast(pktdata(data_idx+3:-1:data_idx),'uint32');
        else
            uint32_val = typecast(pktdata(data_idx:data_idx+3),'uint32');
        end
        
        data_idx = data_idx + 4;
                
    else
        warning('extractUint32:TooShort','Array doesn''t contain enough elements, returning -1')
        uint32_val = 0;
    end
end