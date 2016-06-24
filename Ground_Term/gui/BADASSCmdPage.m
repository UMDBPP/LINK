function outputVar = BADASSCmdPage() 

    BADASS_APID = 1;

    % Any variables declared here will be accessible to the callbacks
    % Initialize output
    outputVar = 1;
    % Initialize newVariable
    newVariable = [];

    % Initialize main figure
    hdl.mainfig = figure('CloseRequestFcn',@closefunction);
    set(hdl.mainfig,'Resize','off');
    
    hdl.closebtn = uicontrol(hdl.mainfig, 'Units', 'normalized', 'Position',[0.05 0.95 0.2 0.05], 'String', 'Close', 'Callback', @closefunction);

    % Done Button
    hdl.sendcyctimecmd = uicontrol(hdl.mainfig, 'Units', 'normalized', 'Position',[0.1 0.8 0.2 0.05], 'String', 'CycTime', 'Callback', @cyctime_cmdsend);
    hdl.cyctimeparam = uicontrol(hdl.mainfig, 'Style','edit', 'Units', 'normalized', 'Position',[0.3 0.8 0.2 0.07], 'String', 'CycleTime Val');
    hdl.cyctimetext = uicontrol(hdl.mainfig, 'Style','Text', 'Units', 'normalized', 'Position',[0.5 0.8 0.2 0.07], 'String', '[ms]');

    hdl.tlmctrlcmd = uicontrol(hdl.mainfig, 'Units', 'normalized', 'Position',[0.1 0.7 0.2 0.05], 'String', 'TlmCtrl', 'Callback', @tlmctrl_sendcmd);
    hdl.tlmctrlparam = uicontrol(hdl.mainfig, 'Style','edit', 'Units', 'normalized', 'Position',[0.3 0.7 0.2 0.07], 'String', 'TlmCtrl Val');
    
    hdl.targetnedcmd = uicontrol(hdl.mainfig, 'Units', 'normalized', 'Position',[0.1 0.6 0.2 0.05], 'String', 'TargetNED', 'Callback', @targetned_sendcmd);
    hdl.targetnedparam = uicontrol(hdl.mainfig, 'Style','edit', 'Units', 'normalized', 'Position',[0.3 0.6 0.3 0.07], 'String', 'TargetNED Val');
    hdl.targetnedtext = uicontrol(hdl.mainfig, 'Style','Text', 'Units', 'normalized', 'Position',[0.7 0.6 0.2 0.07], 'String', 'vector components');

    hdl.imu2bodycmd = uicontrol(hdl.mainfig, 'Units', 'normalized', 'Position',[0.1 0.5 0.2 0.05], 'String', 'IMU2Body', 'Callback', @imu2body_sendcmd);
    hdl.imu2bodyparam = uicontrol(hdl.mainfig, 'Style','edit', 'Units', 'normalized', 'Position',[0.3 0.5 0.4 0.07], 'String', 'IMU2Body Val');
    hdl.imu2bodytext = uicontrol(hdl.mainfig, 'Style','Text', 'Units', 'normalized', 'Position',[0.7 0.5 0.2 0.07], 'String', 'quaternion components');

    hdl.servoenablecmd = uicontrol(hdl.mainfig, 'Units', 'normalized', 'Position',[0.1 0.4 0.2 0.05], 'String', 'ServoEnable', 'Callback', @servoenable_sendcmd);
    hdl.servoenableparam = uicontrol(hdl.mainfig, 'Style','edit', 'Units', 'normalized', 'Position',[0.3 0.4 0.2 0.07], 'String', 'ServoEnable Val');
    
    hdl.rwenablecmd = uicontrol(hdl.mainfig, 'Units', 'normalized', 'Position',[0.1 0.3 0.2 0.05], 'String', 'RWEnable', 'Callback', @rwenable_sendcmd);
    hdl.rwenableparam = uicontrol(hdl.mainfig, 'Style','edit', 'Units', 'normalized', 'Position',[0.3 0.3 0.2 0.07], 'String', 'RWEnable Val');
    
    hdl.requesttlmcmd = uicontrol(hdl.mainfig, 'Units', 'normalized', 'Position',[0.1 0.2 0.2 0.05], 'String', 'RequestTlm', 'Callback', @requesttlm_sendcmd);
    hdl.requesttlmparam = uicontrol(hdl.mainfig, 'Style','edit', 'Units', 'normalized', 'Position',[0.3 0.2 0.2 0.07], 'String', 'RequestTlm Val');
    
    function requesttlm_sendcmd(hObject,eventdata)
        val = get(hdl.requesttlmparam,'String');
        
        % Close figure
        delete(hdl.mainfig); % close GUI
    end

    function rwenable_sendcmd(hObject,eventdata)
        val = get(hdl.rwenableparam,'String');
        
        % Close figure
        delete(hdl.mainfig); % close GUI
    end

    function servoenable_sendcmd(hObject,eventdata)
        val = get(hdl.servoenableparam,'String');
        if(isstrprop(val,'digit'))
            val_num = uint8(str2double(val));
            val_arr = typecast(val_num, 'uint8');
            outputVar = [ CreateCmdHdr(BADASS_APID, 1, 1, 0, 0, 0, 9, 5) val_arr];
        else
            warning('Value ''%s'' invalid.',val)
            outputVar = -1;
        end
        
        % Close figure
        delete(hdl.mainfig); % close GUI
    end

    function targetned_sendcmd(hObject,eventdata)
        entry = get(hdl.targetnedparam,'String');
        arr = str2num(entry); 
        if(isempty(arr))
            warning('BADASSCmdPage:TargetNED:NonNumericValues','String should be a comma separated list of digits');
            return
        end
        if(length(arr) ~= 3)
            warning('BADASSCmdPage:TargetNED:IncorrectNumParams','Expected 3 values, received %d',length(arr));
            return
        end
        fprintf('Passed validation! \n')
        
        val_arr = typecast(single(arr), 'uint8');
        outputVar = [CreateCmdHdr(BADASS_APID, 1, 1, 0, 0, 0, 20, 3) fliplr(val_arr)];       
        
        % Close figure
        delete(hdl.mainfig); % close GUI
    end

    function imu2body_sendcmd(hObject,eventdata)
        entry = get(hdl.imu2bodyparam,'String');
        arr = str2num(entry); 
        if(isempty(arr))
            warning('BADASSCmdPage:IMU2Body:NonNumericValues','String should be a comma separated list of digits');
            return
        end
        if(length(arr) ~= 4)
            warning('BADASSCmdPage:IMU2Body:IncorrectNumParams','Expected 4 values, received %d',length(arr));
            return
        end

        fprintf('Passed validation! \n')
        val_arr = typecast(single(arr), 'uint8');
        outputVar = [CreateCmdHdr(BADASS_APID, 1, 1, 0, 0, 0, 24, 4) fliplr(val_arr)]; 
        % Close figure
        delete(hdl.mainfig); % close GUI
    end

    function tlmctrl_sendcmd(hObject,eventdata)
        val = get(hdl.tlmctrlparam,'String');
        if(isstrprop(val,'digit'))
            val_num = uint32(str2double(val));
            val_arr = typecast(val_num, 'uint8');
            outputVar = [CreateCmdHdr(BADASS_APID, 1, 1, 0, 0, 0, 9, 1) fliplr(val_arr)];
        else
            warning('Value ''%s'' invalid.',val)
            return
        end
        
        % Close figure
        delete(hdl.mainfig); % close GUI
    end

    function cyctime_cmdsend(hObject,eventdata)
        val = get(hdl.cyctimeparam,'String');
        if(isstrprop(val,'digit'))
            val_num = uint32(str2double(val));
            val_arr = typecast(val_num, 'uint8');
            outputVar = [CreateCmdHdr(BADASS_APID, 1, 1, 0, 0, 0, 9, 2) fliplr(val_arr)];
        else
            warning('Value ''%s'' invalid.',val)
            return
        end
        
        % Close figure
        delete(hdl.mainfig); % close GUI
    end
        
    function closefunction(hObject,eventdata) 
        % This callback is executed if the user closes the gui
        % Assign Output
        
        outputVariable = -1;
        % Close figure
        delete(hdl.mainfig); % close GUI
    end

    % Pause until figure is closed ---------------------------------------%
    waitfor(hdl.mainfig);    
end