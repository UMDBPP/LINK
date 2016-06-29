# 900Relay
Code for the Link payload which relays messages between xbee and 900MHz radio


Using the ground station:

The ground station is written in Matlab, which is acting as a serial monitor and performs the following functions:
* Logs ALL data received by the radio to a file (rawlog.txt)
* Logs all packets sent to and received by the radio to a file (log.txt)
* Forms CCSDS packets using a number of helper functions to make human interaction easier
* Parses received packets and stores the telemetry in a database
* Plots the telemetry stored in the database

The ground station was written in and tested with Matlab 2016a. All functions have help text defined. Type 
    ```
	help <function name>
	```
	or 
	```
	doc <function name>
    ```
into the matlab command line to view it.

To use the ground station:
1. Plug the RFD900 into your computer using an FTDI cable
2. Determine which COM port the radio is connected to (can be done via Device Manager on Windows)
3. Use the function 'start_serial_monitor' to start the ground station
    - Provide the COM port the radio is connected to as the argument
    - See the function help for using baud rates other than 9600
4. Matlab will now periodically poll the serial port for new data, log it, and try to interpret it as a packet

To send a command:
1. Make sure the serial monitor has been started, as instructed above
2. Use the 'sendCmd' function to send a command
	- See the function help for calling syntax
	
To close the ground station:
1. Use the function 'stop_serial_monitor' to close the ground station
	- See the function help for calling syntax