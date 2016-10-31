# LINK
The purpose of LINK is to act as an intermediate between the ground and payloads 
and route commands and telemetry to their repective desintations. LINK also logs all data
which passes through it locally to allow post-mission review of data at to mitigate the risk
of losing data during dropouts of the 900Mhz radio system which acts as the link to the ground.
Inter-payload communication is handled by xbee radios.

The 900MHz radios (henceforth: radio) is a transparent interface, data sent to one unit is
transmitted and output by the radio on the other end of the commincation link. This system
is capable of transmitting arbitrary data and imposes no limits on the structure of the data.

The xbees are being used in API mode, which means that interactions with the radios happen 
within the confines of an packet-based API. This interface allows superior control over data
handling than a transparent interface and is necessary for the peer-network model which allows
any payload to communicate with any other payload.

All data handled by link is expected to be in the form of CCSDS command or telemetry packets,
which allows the implementation of a standard interface and handling logic for the packets. 
Data received from the radios and xbees will be interpreted as CCSDS packets and responsed to 
accordingly (ie, commands will be processed and responded to). 

LINK's command interface was designed to allow for the ability for an external payload to 
exercise full control over how LINK would handle the data sent to it. The following commands
are related to the LINK interface:
*  NoOp - No operation, only increments counters as a test of the command interface
*  RESETCTR - Resets the LINK interface and status counters
   
The following commands allow explict routing of a message to its intended target:
*  HK_REQ - Requests that a housekeeping pkt containing status info be sent to the indicated address
*  FWDMSG - Requests that the contained data be forwarded to the indicated address
  
In addition to these commands, LINK uses a filter table to determine if a received packet 
should be forwarded to the ground. Although this breaks the paradigm that all actions should 
be commanded (to make tracing cause and effect in debugging easier), it is too cumbersome to 
require every external payload that wishes to relay data to the ground (which is LINK's primary purpose) 
to wrap their data in a FWDMSG command. The filter table is a list of APIDs (a field in a CCSDS
packet used to identify the type of packet) to determine if a message should be automatically forwarded to
the ground. The following commands are available to manage the filter table:
*  TLMFLTRBL - Requests that the current filter table be dumped to the ground
*  SETFLTRTBLIDX - Request that a specified index of the filter table be set to a specified value
 
LINK also has the ability to be reset remotely through the command:
*  REBOOT - Requests that LINK reboot itself via a watchdog timer
   
In addition to its data routing functionality, LINK also takes advantage of balloonduino's 
on-board sensors to monitor its status and the environment around it. All of this data is logged 
and the following commands can be used to request data from LINK:
*  REQ_ENV - Requests LINK send current temperature/pressure/humidity data
*  REQ_PWR - Requests LINK send current power/battery status data
*  REQ_IMU - Requests LINK send current accel/gryo/mag data
   
See the COSMOS repo (https://github.com/UMDBPP/COSMOS) for full format of the commands described above.