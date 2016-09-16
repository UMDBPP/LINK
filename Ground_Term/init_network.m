function net = init_network()

    net.scorchstatus.apid = 10;
    net.scorchstatus.procfcn = @scorch_process;
    
    net.cutdownstatus.apid = 11;
    net.cutdownstatus.procfcn = @mars_process;

    net.link.apid = uint8(apid.link);
    net.link.procfcn = @link_process;
    
    net.badass.apid = uint8(apid.badass);
    net.badass.procfcn = @badass_process;
end