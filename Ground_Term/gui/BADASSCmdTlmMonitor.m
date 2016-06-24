function BADASSCmdTlmMonitor(varargin)

    handles.mainFig = figure(...
    'Units','characters',...
    'Position',[135.8 42.7692307692308 193 32.3846153846154],...
    'Visible',get(0,'defaultfigureVisible'),...
    'Color',get(0,'defaultfigureColor'),...
    'IntegerHandle','off',...
    'MenuBar','none',...
    'Name','BADASSCmdTlmMonitor',...
    'NumberTitle','off',...
    'CloseRequestFcn',@(hObject,eventdata)mainFig_CloseRequestFcn(hObject,eventdata,guidata(hObject)),...
    'DeleteFcn',@(hObject,eventdata)mainFig_DeleteFcn(hObject,eventdata,guidata(hObject)),...
    'Tag','figure1',...
    'Resize','off',...
    'PaperPosition',get(0,'defaultfigurePaperPosition'),...
    'ScreenPixelsPerInchMode','manual',...
    'HandleVisibility','callback');
    % 'CreateFcn', {@(hObject,eventdata)BADASSCmdTlmMonitor_OpeningFcn(hObject,eventdata,guidata(hObject))},...

    handles.historyListbox = uicontrol(...
    'Parent',handles.mainFig,...
    'FontUnits',get(0,'defaultuicontrolFontUnits'),...
    'Units','characters',...
    'String',{  'Listbox' },...
    'Style','listbox',...
    'Value',1,...
    'ValueMode',get(0,'defaultuicontrolValueMode'),...
    'Position',[4.2 7.53846153846154 145.8 22.4615384615385],...
    'BackgroundColor',[1 1 1],...
    'Callback',@(hObject,eventdata)historyListBox_Callback(hObject,eventdata,guidata(hObject)),...
    'Children',[],...
    'Tag','historybox');
    % 'CreateFcn', {@local_CreateFcn, @(hObject,eventdata)BADASSCmdTlmMonitor('historybox_CreateFcn',hObject,eventdata,guidata(hObject)), appdata} ,...

%     handles.cmdentry = uicontrol(...
%     'Parent',handles.mainFig,...
%     'FontUnits',get(0,'defaultuicontrolFontUnits'),...
%     'Units','characters',...
%     'String','Tx serial commands',...
%     'Style','edit',...
%     'Position',[6.6 2.92307692307692 143.4 2.46153846153846],...
%     'BackgroundColor',[1 1 1],...
%     'Callback',@(hObject,eventdata)cmdentry_Callback(hObject,eventdata,guidata(hObject)),...
%     'Children',[],...
%     'Tag','cmdentry');
    % 'CreateFcn', {@local_CreateFcn, @(hObject,eventdata)BADASSCmdTlmMonitor('cmdentry_CreateFcn',hObject,eventdata,guidata(hObject)), appdata} ,...

    handles.portListbox = uicontrol(...
    'Parent',handles.mainFig,...
    'FontUnits',get(0,'defaultuicontrolFontUnits'),...
    'Units','characters',...
    'String',{  'Listbox' },...
    'Style','listbox',...
    'Value',1,...
    'ValueMode',get(0,'defaultuicontrolValueMode'),...
    'Position',[159.8 7.92307692307692 21.4 21.7692307692308],...
    'BackgroundColor',[1 1 1],...
    'Callback',@(hObject,eventdata)portListBox_Callback(hObject,eventdata,guidata(hObject)),...
    'Children',[],...
    'Tag','portlist');
    % 'CreateFcn', {@local_CreateFcn, @(hObject,eventdata)BADASSCmdTlmMonitor('portlist_CreateFcn',hObject,eventdata,guidata(hObject)), appdata} ,...

    handles.baudEdit = uicontrol(...
    'Parent',handles.mainFig,...
    'FontUnits',get(0,'defaultuicontrolFontUnits'),...
    'Units','characters',...
    'String','9600',...
    'Style','edit',...
    'Position',[168.6 4.84615384615385 14.6 2.38461538461539],...
    'BackgroundColor',[1 1 1],...
    'Callback',@(hObject,eventdata)baudEdit_Callback(hObject,eventdata,guidata(hObject)),...
    'Children',[],...
    'Tag','baudbox');
    % 'CreateFcn', {@local_CreateFcn, @(hObject,eventdata)BADASSCmdTlmMonitor('baudbox_CreateFcn',hObject,eventdata,guidata(hObject)), appdata} ,...

    % create text indicating the entry is for a baud rate
    handles.baudText = uicontrol(...
    'Parent',handles.mainFig,...
    'FontUnits',get(0,'defaultuicontrolFontUnits'),...
    'Units','characters',...
    'String',{  'Baud '; 'Rate' },...
    'Style','text',...
    'Position',[156.6 5.15384615384615 10.4 2.07692307692308],...
    'Children',[],...
    'Tag','text2' );
    % 'CreateFcn', {@local_CreateFcn, blanks(0), appdata}

    % create a button to connect to the serial
    handles.connectBtn = uicontrol(...
    'Parent',handles.mainFig,...
    'FontUnits',get(0,'defaultuicontrolFontUnits'),...
    'Units','characters',...
    'String','Connect',...
    'Style',get(0,'defaultuicontrolStyle'),...
    'Position',[160.4 1.53846153846154 22.6 2.23076923076923],...
    'Callback',@connectBtn_Callback,...
    'Children',[],...
    'Tag','connectbtn');
    % 'CreateFcn', {@local_CreateFcn, blanks(0), appdata} ,...
    % 'Callback',@(hObject,eventdata)connectbtn_Callback(hObject,eventdata,guidata(hObject)),...

%     handles.cmeentry_text = uicontrol(...
%     'Parent',handles.mainFig,...
%     'FontUnits',get(0,'defaultuicontrolFontUnits'),...
%     'Units','characters',...
%     'String','Type commands above. User ''Enter'' to send.',...
%     'Style','text',...
%     'Position',[52.8 1.53846153846154 52.6 1.07692307692308],...
%     'Children',[],...
%     'Tag','text3' );
    % 'CreateFcn', {@local_CreateFcn, blanks(0), appdata}

%     handles.cmdentrybtn = uicontrol(...
%     'Parent',handles.mainFig,...
%     'FontUnits',get(0,'defaultuicontrolFontUnits'),...
%     'Units','characters',...
%     'String','EnterCommand',...
%     'Style',get(0,'defaultuicontrolStyle'),...
%     'Position',[106.2 0.692307692307692 29.6 2.15384615384615],...
%     'Callback',@(hObject,eventdata)cmdentrybtn_Callback(hObject,eventdata,guidata(hObject)),...
%     'Children',[],...
%     'Tag','cmdentrybtn' );
    % 'CreateFcn', {@local_CreateFcn, blanks(0), appdata}


    % create a checkbox to disable scrolling
    handles.scrollCheckbox = uicontrol(...
    'Parent',handles.mainFig,...
    'FontUnits',get(0,'defaultuicontrolFontUnits'),...
    'Units','characters',...
    'String','AutoScroll',...
    'Style','checkbox',...
    'Position',[8 0.461538461538462 15 1.76923076923077],...
    'Callback',@(hObject,eventdata)scrollCheckbox_Callback(hObject,eventdata,guidata(hObject)),...
    'Children',[],...
    'Tag','scrollCheckBox');
    % 'CreateFcn', {@local_CreateFcn, blanks(0), appdata}

    % create a button to save a log
    handles.savelogBtn = uicontrol(...
    'Parent',handles.mainFig,...
    'FontUnits',get(0,'defaultuicontrolFontUnits'),...
    'Units','characters',...
    'String','SaveLog',...
    'Style',get(0,'defaultuicontrolStyle'),...
    'Position',[120 5 25 1.69230769230769],...
    'Callback',@(hObject,eventdata)savelogBtn_Callback(hObject,eventdata,guidata(hObject)),...
    'Children',[],...
    'Tag','autcmdbtn' );

    % create a button to bring up the BADASS command page
    handles.cmdpageBtn = uicontrol(...
    'Parent',handles.mainFig,...
    'FontUnits',get(0,'defaultuicontrolFontUnits'),...
    'Units','characters',...
    'String','CmdPage',...
    'Style',get(0,'defaultuicontrolStyle'),...
    'Position',[29.8 0.923076923076923 25 1.69230769230769],...
    'Callback',@(hObject,eventdata)cmdpageBtn_Callback(hObject,eventdata,guidata(hObject)),...
    'Children',[],...
    'Tag','autcmdbtn' );
    % 'CreateFcn', {@local_CreateFcn, blanks(0), appdata}

    % create timer
    handles.timer = timer('TimerFcn',@(obj, eventdata) timerCallback(hObject),'Period',0.01,'ExecutionMode','FixedRate');
    
    % create serial port object
    handles.serConn = 0;
    
    
    % populate the list of ports
    set(handles.portListbox, 'String', ...
        [{'COM1'} ; ...
         {'COM2'} ; ...
         {'COM3'} ; ...
         {'COM4'} ; ...
         {'COM5'} ; ...
         {'COM6'} ; ...
         {'COM7'} ; ...
         {'COM8'} ; ...
         {'COM9'} ; ...
         {'COM10'} ; ...
         {'COM11'} ; ...
         {'COM12'} ]);

    % initalize elements with initial values
    set(handles.historyListbox, 'String', cell(1));
    set(handles.scrollCheckbox,'Value',1);
    set(handles.baudEdit,'String','250000');
     
    % disable serial-dependent buttons
    set(handles.cmdpageBtn,'Enable','off');
    set(handles.savelogBtn,'Enable','off');

end

% --- Set application data first then calling the CreateFcn. 
% function local_CreateFcn(hObject, eventdata, createfcn, appdata)
% 
% if ~isempty(appdata)
%    names = fieldnames(appdata);
%    for i=1:length(names)
%        name = char(names(i));
%        setappdata(hObject, name, getfield(appdata,name));
%    end
% end
% 
% if ~isempty(createfcn)
%    if isa(createfcn,'function_handle')
%        createfcn(hObject, eventdata);
%    else
%        eval(createfcn);
%    end
% end
% end

% --- Executes on button press in connectbtn.
function connectBtn_Callback(varargin)
% hObject    handle to connectbtn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    handles = guihandles(varargin{1});

    if strcmp(get(handles.connectbtn,'String'),'Connect') % currently disconnected
        
        % get the user-specified port
        serPortn = get(handles.portlist, 'Value');
        serList = get(handles.portlist,'String');
        serPort = serList{serPortn};
        
        % define the serial port
        serConn = serial(serPort);
        
        % check that the user-entered baud rate makes sense
        valid_baudrates = [300, 600, 1200, 2400, 4800, 9600, 14400, 19200, 28800, 38400, 57600, 115200, 250000];
        baud_entry = get(handles.baudbox, 'String');
        if(all(isstrprop(baud_entry, 'digit')))
            baud_val = str2num(baud_entry);
            if(ismember(baud_val,valid_baudrates))
                warning('BADASSCmdTlmMonitor:connectBtnCallback:NonStandardBaud', 'The entered baud rate is not a standard baud rate and may not work, connecting...')
            end
            set(serConn,'BaudRate',baud_val);       
        else
            warning('BADASSCmdTlmMonitor:connectBtnCallback:NonNumericBaud', 'The entered baud rate contains non-numeric characters, enter a numeric value and connect again.')
            return
        end
            
        % open the serial port
        try
            fopen(serConn);
        catch
            fclose(serConn);
            fopen(serConn);
        end
        handles.serConn = serConn;
        
        % update gui status
        set(handles.portlist,'Enable','off');
        set(hObject,'String','Disconnect');
        set(handles.cmdentry,'Enable','on')
        set(handles.autcmdbtn,'Enable','on');
        set(handles.cmdentrybtn,'Enable','on');

        % update the history
        currList = get(handles.historybox, 'String');
        set(handles.historybox, 'String', ...
            [currList ; sprintf('%s : Connected to %s',datestr(now), handles.serConn.Port )]);
        if(get(handles.scrollCheckBox,'Value'))
            set(handles.historybox, 'Value', length(currList) + 1 );
        end
        
        % update handles
        guidata(hObject, handles);
        
        % create a timer
        start(handles.timer)
        
    else
        % remove timer
        if(isfield(handles,'timer'))
            stop(handles.timer);
            delete(handles.timer);
            handles = rmfield(handles, 'timer');
        end
        
        % echo message for disconnect
        currList = get(handles.historybox, 'String');
        set(handles.historybox, 'String', ...
            [currList ; sprintf('%s : Disconnected from %s ',datestr(now),handles.serConn.Port)]);
        if(get(handles.scrollCheckBox,'Value'))
            set(handles.historybox, 'Value', length(currList) + 1 );
        end
        
        % remove serConn handle
        if(isfield(handles,'serConn'))
            fclose(handles.serConn);
            handles = rmfield(handles, 'serConn');
        else
            fprintf('Serial already closed \n');
        end
        
        % change gui buttons
        set(hObject,'String','Connect');
        set(handles.portlist,'Enable','on');
        set(handles.cmdentry,'Enable','off');
        
    end
    
    guidata(hObject, handles);

end

function BADASSCmdTlmMonitor_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to test_gui (see VARARGIN)

    % Choose default command line output for test_gui
    handles.output = hObject;

    set(handles.portlist, 'String', ...
        [{'COM1'} ; ...
         {'COM2'} ; ...
         {'COM3'} ; ...
         {'COM4'} ; ...
         {'COM5'} ; ...
         {'COM6'} ; ...
         {'COM7'} ; ...
         {'COM8'} ; ...
         {'COM9'} ; ...
         {'COM10'} ; ...
         {'COM11'} ; ...
         {'COM12'} ]);


    set(handles.cmdentry,'Enable','off');
    set(handles.autcmdbtn,'Enable','off');
    set(handles.cmdentrybtn,'Enable','off');

    set(handles.baudbox,'String','250000');
    set(handles.historybox, 'String', cell(1));
    set(handles.scrollCheckBox,'Value',1)

    % Update handles structure
    guidata(hObject, handles);


    % UIWAIT makes test_gui wait for user response (see UIRESUME)
    % uiwait(handles.figure1);
end


% --- Outputs from this function are returned to the command line.
function varargout = test_gui_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
    varargout{1} = handles.output;
end

function timerCallback(hObject)
    % get handles
    handles = guidata(hObject);

    % if its open, read from the serial port
    if(strcmp(handles.serConn.Status,'open'))
        RxText = fscanf(handles.serConn);

        % update the history
        currList = get(handles.historybox, 'String');
        if length(RxText) < 1
            RxText = 'Timeout @ ';
            set(handles.historybox, 'String', ...
                [currList ; [RxText datestr(now)] ]);
        else
            set(handles.historybox, 'String', ...
                [currList ; ['R ' datestr(now,'HH:MM:SS.FFF') ': ' RxText ] ]);
            if(get(handles.scrollCheckBox,'Value'))
                set(handles.historybox, 'Value', length(currList) + 1 );
            end
        end
    end
    
    % ensure the gui updates
    drawnow; 
    
    % update the handles
    guidata(hObject, handles);
end


% --- Executes on selection change in historybox.
function historybox_Callback(hObject, eventdata, handles)
% hObject    handle to historybox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns historybox contents as cell array
%        contents{get(hObject,'Value')} returns selected item from historybox
end


% --- Executes during object creation, after setting all properties.
function historybox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to historybox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

    % Hint: listbox controls usually have a white background on Windows.
    %       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end



function cmdentry_Callback(hObject, eventdata, handles)
% hObject    handle to cmdentry (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of cmdentry as text
%        str2double(get(hObject,'String')) returns contents of cmdentry as a double
    TxText = get(hObject, 'String');
%     fprintf(handles.serConn, TxText);

    currList = get(handles.historybox, 'String');

    set(handles.historybox, 'String', ...
        [currList ; ['S ' datestr(now,'HH:MM:SS.FFF') ': ' TxText] ]);
    if(get(handles.scrollCheckBox,'Value'))
        set(handles.historybox, 'Value', length(currList) + 1 );
    end

    set(hObject, 'String', '');

end

% --- Executes on selection change in portlist.
function portListBox_Callback(hObject, eventdata, handles)
% hObject    handle to portlist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns portlist contents as cell array
%        contents{get(hObject,'Value')} returns selected item from portlist
end


function baudEdit_Callback(hObject, eventdata, handles)
% hObject    handle to baudbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of baudbox as text
%        str2double(get(hObject,'String')) returns contents of baudbox as a double
end


% --- Executes on button press in cmdentrybtn.
function cmdentrybtn_Callback(hObject, eventdata, handles)
% hObject    handle to cmdentrybtn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

    
    arr = getNumericArrGUI();
    
    if(arr ~= -1)
%         fprintf(handles.serConn, TxText);

        currList = get(handles.historybox, 'String');

        set(handles.historybox, 'String', ...
            [currList ; ['Sent @ ' datestr(now,'HH:MM:SS.FFF') ': ' char(arr)] ]);
        set(handles.historybox, 'Value', length(currList) + get(handles.scrollCheckBox,'Value') );

        set(hObject, 'String', '');
    end
end


% --- Executes on button press in scrollCheckBox.
function scrollCheckbox_Callback(hObject, eventdata, handles)
% hObject    handle to scrollCheckBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of scrollCheckBox
    

end


% --- Executes on button press in autcmdbtn.
function cmdpageBtn_Callback(hObject, eventdata, handles)
% hObject    handle to autcmdbtn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

    outputVariable = BADASSCmdPage();
    fprintf(handles.serConn, char(outputVariable));
end


% --- Executes during object deletion, before destroying properties.
function mainFig_DeleteFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    if(isfield(handles,'timer'))
        if(strcmp(get(handles.timer,'Running'),'on'))
            stop(handles.timer);
        end
        delete(handles.timer);
        handles = rmfield(handles, 'timer');
    end
        
end

% --- Executes when user attempts to close mainFig.
function mainFig_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
    if(isfield(handles,'serConn'))
        fclose(handles.serConn);
        handles = rmfield(handles, 'serConn');
    end

    delete(hObject);

end
