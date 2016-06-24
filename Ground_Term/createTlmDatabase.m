function TLM = createTlmDatabase()
% createTlmDatabase
%
%   createTlmDatabase()
%       creates a structure suitable for saving telemetry data received
%       from BADASS and LINK
%
%   Steve Lentine
%   4/21/16
%


% header parameters
% primary
TLM.APID = timeseries('APID');
TLM.SecHdr = timeseries('Secondary Header Flag [1=Present,0=Absent]');
TLM.PktType = timeseries('Packet Type [1=Cmd,0=Tlm]');
TLM.CCSDSVer = timeseries('CCSDS Ver #');
TLM.SeqCnt = timeseries('Sequence Counter');
TLM.SegFlag = timeseries('Segmentation Flag');
TLM.PktLen = timeseries('Packet Length [bytes]');

% command secondary
TLM.FcnCode = timeseries('Function Code');
TLM.Checksum = timeseries('Checksum');
TLM.Reserved = timeseries('Reserved');

% tlm secondary
TLM.Time = timeseries('Tlm Time');

% telemetry points
TLM.tlmctrl = timeseries('TlmCtrl');
TLM.v_target_ned = timeseries('TargetNED');
TLM.bno_cal = timeseries('BNO Cal');
TLM.euler_ang = timeseries('Euler Ang');
TLM.q_imu2body = timeseries('Q IMU2Body');
TLM.q_ned2imu = timeseries('Q NED2IMU');
TLM.q_ned2body = timeseries('Q NED2Body');
TLM.v_targetbody = timeseries('TargetBody');
TLM.azel_err = timeseries('AzEl Err [rad]');
TLM.el_cmd = timeseries('El Cmd');
TLM.cycle_time = timeseries('Cycle Time [ms]');
TLM.cmd_rcvd = timeseries('Command Received');
TLM.desired_cyc_time = timeseries('Desired Cycle Time [ms]');
TLM.cmdecho = timeseries('Cmd Echo');
TLM.temp1 = timeseries('Temp1 [C]');
TLM.temp2 = timeseries('Temp2 [C]');
TLM.tempbme = timeseries('Temp BME [C]');
TLM.pres = timeseries('Pressure');
TLM.alt = timeseries('Altitude [m]');
TLM.humid = timeseries('Humidity [%]');
TLM.current = timeseries('Current [A]');
TLM.voltage = timeseries('Voltage [V]');
TLM.initstat = timeseries('InitStatus');
TLM.msgsent = timeseries('MsgSent');
TLM.msgrcvd = timeseries('MsgRcvd');
TLM.mode = timeseries('Mode');
TLM.LINKCtr = timeseries('LINKCtr');
TLM.FSWTime = timeseries('FSWTime');

end