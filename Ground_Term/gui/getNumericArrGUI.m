function outputVariable = getNumericArrGUI() 

    % Any variables declared here will be accessible to the callbacks
    % Initialize output
    outputVariable = [];
    inputVariable = 0;
    % Initialize newVariable
    newVariable = [];

    % Initialize main figure
    hdl.mainfig = figure('CloseRequestFcn',@closefunction);

    % add entry
    hdl.addTextEntry = uicontrol(hdl.mainfig, 'Style','edit', 'Units', 'normalized', 'Position',[(1-0.6)/2 0.8 0.6 0.1], 'String', 'CommandEntry');

    % Done Button
    hdl.validatePushButton = uicontrol(hdl.mainfig, 'Units', 'normalized', 'Position',[(1-0.3)/2 0.7 0.3 0.1], 'String', 'Validate', 'Callback', @validate);
    hdl.sendPushButton = uicontrol(hdl.mainfig, 'Units', 'normalized', 'Position',[(1-0.3)/2 0.6 0.3 0.1], 'String', 'Send', 'Callback', @send);
    hdl.closePushButton = uicontrol(hdl.mainfig, 'Units', 'normalized', 'Position',[(1-0.3)/2 0.5 0.3 0.1], 'String', 'Close', 'Callback', @closefunction);

    set(hdl.sendPushButton,'Enable','off');
    
    function validate(hObject,eventdata)
        entry = get(hdl.addTextEntry,'String');
        all_digit = isstrprop(strsplit(entry,','),'digit');
        if(~all([all_digit{:}]))
            warning('String should be a comma separated list of digits');
        end
        arr = uint8(str2double(strsplit(entry,',')));
        if(any(arr > 255))
            warning('Values should be in the range 0-255');
        end
        fprintf('Passed validation! \n')
        set(hdl.sendPushButton,'Enable','on');
        
    end
        
    function closefunction(hObject,eventdata) 
        % This callback is executed if the user closes the gui
        % Assign Output
        
        outputVariable = -1;
        % Close figure
        delete(hdl.mainfig); % close GUI
    end

    function send(hObject,eventdata)  
        % Assign Output
        outputVariable = uint8(str2double(strsplit(get(hdl.addTextEntry,'String'),',')));
        % Close figure
        delete(hdl.mainfig); % close GUI
    end

    % Pause until figure is closed ---------------------------------------%
    waitfor(hdl.mainfig);    
end