function net = init_network()

    net.scorch.apid = apid.scorch;
    net.scorch.procfcn = @scorch_process;

    net.link.apid = uint8(apid.link);
    net.link.procfcn = @link_process;
    
    net.badass.apid = uint8(apid.badass);
    net.badass.procfcn = @badass_process;
end