function PktType = ExtractPktType(arr)
  
    if(length(arr) < 6)
        error('ExtractHdr:PktLength','Byte array, length: %d, is too short to have a valid header',length(arr));
    end
    
    [~, ~, PktType, ~, ~, ~, ~] = ExtractPriHdr(arr(1:6));
        
end