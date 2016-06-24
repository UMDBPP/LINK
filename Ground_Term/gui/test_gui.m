function varargout = BADASSCmdTlmMonitor(varargin)
% TEST_GUI MATLAB code for test_gui.fig
%      TEST_GUI, by itself, creates a new TEST_GUI or raises the existing
%      singleton*.
%
%      H = TEST_GUI returns the handle to a new TEST_GUI or the handle to
%      the existing singleton*.
%
%      TEST_GUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in TEST_GUI.M with the given input arguments.
%
%      TEST_GUI('Property','Value',...) creates a new TEST_GUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before test_gui_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to test_gui_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help test_gui

% Last Modified by GUIDE v2.5 23-Mar-2016 19:37:00

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @test_gui_OpeningFcn, ...
                   'gui_OutputFcn',  @test_gui_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
end

% End initialization code - DO NOT EDIT


% --- Executes just before test_gui is made visible.
function test_gui_OpeningFcn(hObject, eventdata, handles, varargin)
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

    % read from the serial port
    RxText = fscanf(handles.serConn);
    
    % update the history
    currList = get(handles.historybox, 'String');
    if length(RxText) < 1
        RxText = 'Timeout @ ';
        set(handles.historybox, 'String', ...
            [currList ; [RxText datestr(now)] ]);
    else
        set(handles.historybox, 'String', ...
            [currList ; [datestr(now,'R HH:MM:SS.FFF') ': ' RxText ] ]);
        if(get(handles.scrollCheckBox,'Value'))
            set(handles.historybox, 'Value', length(currList) + 1 );
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
        [currList ; ['Sent @ ' datestr(now,'HH:MM:SS.FFF') ': ' TxText] ]);
    if(get(handles.scrollCheckBox,'Value'))
        set(handles.historybox, 'Value', length(currList) + 1 );
    end

    set(hObject, 'String', '');

end


% --- Executes during object creation, after setting all properties.
function cmdentry_CreateFcn(hObject, eventdata, handles)
% hObject    handle to cmdentry (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

    % Hint: edit controls usually have a white background on Windows.
    %       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end


% --- Executes on selection change in portlist.
function portlist_Callback(hObject, eventdata, handles)
% hObject    handle to portlist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns portlist contents as cell array
%        contents{get(hObject,'Value')} returns selected item from portlist
end


% --- Executes during object creation, after setting all properties.
function portlist_CreateFcn(hObject, eventdata, handles)
% hObject    handle to portlist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

    % Hint: listbox controls usually have a white background on Windows.
    %       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end



function baudbox_Callback(hObject, eventdata, handles)
% hObject    handle to baudbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of baudbox as text
%        str2double(get(hObject,'String')) returns contents of baudbox as a double
end


% --- Executes during object creation, after setting all properties.
function baudbox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to baudbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

set(hObject,'String',9600)
end


% --- Executes on button press in connectbtn.
function connectbtn_Callback(hObject, eventdata, handles)
% hObject    handle to connectbtn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    if strcmp(get(hObject,'String'),'Connect') % currently disconnected
        
        % open the serial port
        serPortn = get(handles.portlist, 'Value');
        serList = get(handles.portlist,'String');
        serPort = serList{serPortn};
        serConn = serial(serPort);
        set(serConn,'BaudRate',str2num(get(handles.baudbox, 'String')));
        try
            fopen(serConn);
        catch
            fclose(serConn);
            fopen(serConn);
        end
        handles.serConn = serConn;
        set(handles.portlist,'Enable','off');

        % update gui status
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
        handles.timer=timer('TimerFcn',@(obj, eventdata) timerCallback(hObject),'Period',0.01,'ExecutionMode','FixedRate');
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
function scrollCheckBox_Callback(hObject, eventdata, handles)
% hObject    handle to scrollCheckBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of scrollCheckBox
    

end


% --- Executes on button press in autcmdbtn.
function autcmdbtn_Callback(hObject, eventdata, handles)
% hObject    handle to autcmdbtn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

    outputVariable = BADASSCmdPage();
    fprintf(handles.serConn, char(outputVariable));
end


% --- Executes during object deletion, before destroying properties.
function figure1_DeleteFcn(hObject, eventdata, handles)
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


% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
    if(isfield(handles,'serConn'))
        fclose(handles.serConn);
        handles = rmfield(handles, 'serConn');
    else
        fprintf('Serial already closed \n');
    end

    delete(hObject);

end
