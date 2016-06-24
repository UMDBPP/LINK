function [float_val, data_idx] = extractFloat(pktdata,data_idx,endianness)

    if(length(pktdata) > data_idx+3)

        if(endianness == Endian.Little)
            float_val = typecast(pktdata(data_idx+3:-1:data_idx),'single');
        else
            float_val = typecast(pktdata(data_idx:data_idx+3),'single');
        end
        data_idx = data_idx + 4;
    else
        warning('extractFloat:TooShort','Array doesn''t contain enough elements, returning -1')
        float_val = -1;
    end
end