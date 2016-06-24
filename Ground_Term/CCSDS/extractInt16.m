function [int16_val, data_idx] = extractInt16(pktdata,data_idx,endianness)

    if(length(pktdata) > data_idx+1)

        if(endianness == Endian.Little)
            int16_val = typecast(pktdata(data_idx+1:-1:data_idx),'int16');
        else
            int16_val = typecast(pktdata(data_idx:data_idx+1),'int16');
        end
        
        data_idx = data_idx + 2;
                
    else
        warning('extractInt16:TooShort','Array doesn''t contain enough elements, returning -1')
        int16_val = 0;
    end
end