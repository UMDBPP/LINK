/*
 * LINK code
 * 
 * The purpose of LINK is to act as an intermediate between the ground and payloads 
 * and route commands and telemetry to their repective desintations. LINK also logs all data
 * which passes through it locally to allow post-mission review of data at to mitigate the risk
 * of losing data during dropouts of the 900Mhz radio system which acts as the link to the ground.
 * Inter-payload communication is handled by xbee radios.
 * 
 * The 900MHz radios (henceforth: radio) is a transparent interface, data sent to one unit is
 * transmitted and output by the radio on the other end of the commincation link. This system
 * is capable of transmitting arbitrary data and imposes no limits on the structure of the data.
 * 
 * The xbees are being used in API mode, which means that interactions with the radios happen 
 * within the confines of an packet-based API. This interface allows superior control over data
 * handling than a transparent interface and is necessary for the peer-network model which allows
 * any payload to communicate with any other payload.
 * 
 * All data handled by link is expected to be in the form of CCSDS command or telemetry packets,
 * which allows the implementation of a standard interface and handling logic for the packets. 
 * Data received from the radios and xbees will be interpreted as CCSDS packets and responsed to 
 * accordingly (ie, commands will be processed and responded to). 
 * 
 * LINK's command interface was designed to allow for the ability for an external payload to 
 * exercise full control over how LINK would handle the data sent to it. The following commands
 * are related to the LINK interface:
 *   NoOp - No operation, only increments counters as a test of the command interface
 *   RESETCTR - Resets the LINK interface and status counters
 *   
 * The following commands allow explict routing of a message to its intended target:
 *   GND_HK_REQ - Requests that a housekeeping pkt containing status info be sent to the ground
 *   XB_HK_REW - Requests that a housekeeping pkt containing status info be sent to a specified xbee address
 *   GND_FWDMSG - Requests that the contained data be forwarded to the ground
 *   XB_FWDMSG - Requests that the contained data be forwarded to the specified xbee address
 *   
 * In addition to these commands, LINK uses a filter table to determine if a received packet 
 * should be forwarded to the ground. Although this breaks the paradigm that all actions should 
 * be commanded (to make tracing cause and effect in debugging easier), it is too cumbersome to 
 * require every external payload that wishes to relay data to the ground (which is LINK's primary purpose) 
 * to wrap their data in a GND_FWDMSG command. The filter table is a list of APIDs (an field in a CCSDS
 * packet used to identify the type of packet) to determine if a message should be automatically forwarded to
 * the ground. The following commands are available to manage the filter table:
 *   TLMFLTRBL - Requests that the current filter table be dumped to the ground
 *   SETFLTRTBLIDX - Request that a specified index of the filter table be set to a specified value
 * 
 */
   
//// Includes:
#include <Wire.h>
#include <SPI.h>
#include "RTClib.h"
#include <SD.h>
#include "CCSDS_Xbee/CCSDS.h"
#include "CCSDS_Xbee/ccsds_xbee.h"
#include "CCSDS_Xbee/ccsds_util.h"

//// Hardware objects
RTC_DS1307 rtc;  // real time clock (for logging with timestamps)

//// Compile time constants
#define PKT_MAX_LEN 200     // size of buffers to contain packets being relayed
#define FILT_TBL_LEN 10     // number of elements in the packet filter table

//// Enumerations
#define LOG_RCVD 1
#define LOG_SEND 0

//// Serial object aliases
// so that the user doesn't have to keep track of which is which
#define debug_serial Serial
#define radio_serial Serial2
#define xbee_serial Serial3

//// Data buffers
// for holding data being relayed
uint8_t Buff_900toXbee[PKT_MAX_LEN];
uint8_t Buff_Xbeeto900[PKT_MAX_LEN];
uint8_t Buff_Pos = 0;

//// Xbee setup parameters
uint16_t XBee_MY_Addr = 0x0002; // XBee address for this payload
uint16_t XBee_PAN_ID = 0x0B0B; // XBee PAN address (must be the same for all xbees)

//// Interface counters
// counters to track what data comes into/out of link
uint16_t CmdExeCtr = 0;
uint16_t CmdRejCtr = 0;
uint32_t RadioRcvdByteCtr = 0;
uint32_t XbeeRcvdByteCtr = 0;
uint32_t RadioSentByteCtr = 0;
uint32_t XbeeSentByteCtr = 0;

//// Filter Table
// table to filter what packets to automatically relay to ground
uint16_t filter_table[FILT_TBL_LEN] = {200, 210, 220, 300, 310, 320, 0, 0, 0, 0};

//// Files
// logging files
File xbeeLogFile;
File radioLogFile;
File initLogFile;

// Function prototypes
void command_response(uint8_t data[], uint8_t data_len);
uint16_t create_HK_pkt(uint8_t HK_Pkt_Buff[]);
uint16_t create_fltrtbl_pkt(uint8_t FLTR_TBL_Buff[]);
boolean checkApidFilterTable(uint16_t apid);
void radio_send_and_log(uint8_t data[], uint8_t data_len);
void xbee_send_and_log(uint8_t dest_addr, uint8_t data[], uint8_t data_len);
void logXbeePkt(File file, uint8_t data[], uint8_t len, uint8_t received_flg);
void print_time(File file);

// Other variables
uint16_t cycles_since_read = 0;

void setup() {
  /* setup()
   * 
   * Initalizes all the link hardware/software including:
   *   Serial
   *   Xbee
   *   RTC
   *   SD card
   *   Log files
   */
   
  //// Init serial ports:
  /*  aliases defined above are used to reduce confusion about which serial
   *    is connected to what interface
   *  xbee and radio serial are lower baud rates because the hardware 
   *    defaults to that baud rate. higher baud rates need to be tested
   *    before they're used with those devices
   */
  debug_serial.begin(250000);
  xbee_serial.begin(9600);
  radio_serial.begin(9600);

  //// Init Xbee
  /* InitXbee() will configure the attached xbee so that it can talk to
   *   xbees which also use this library. It also handles the initalization
   *   of the adafruit xbee library
   */
  int xbeeStatus = InitXBee(XBee_MY_Addr, XBee_PAN_ID, xbee_serial);
  if(!xbeeStatus) {
    debug_serial.println(F("XBee Initialized!"));
  } else {
    debug_serial.print(F("XBee Failed to Initialize with Error Code: "));
    debug_serial.println(xbeeStatus);
  }

  //// RTC  
  /* The RTC is used so that the log files contain timestamps. If the RTC
   *  is not running (because no battery is inserted) the RTC will be initalized
   *  to the time that this sketch was compiled at.
   */
  uint8_t rtc_running = 0;
  uint8_t rtc_start = 0;
  if (! (rtc_start = rtc.begin())) {
    Serial.println("RTC NOT detected.");
  }
  else{
    Serial.println("RTC detected!");
    if (! (rtc_running = rtc.isrunning())) {
      debug_serial.println("RTC is NOT running!");
      // following line sets the RTC to the date & time this sketch was compiled
      rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
      // To set the RTC with an explicit date & time:
      // rtc.adjust(DateTime(2014, 1, 21, 3, 0, 0));
    }
  }
  
  //// Init SD card
  /* The SD card is used to store all of the log files.
   */
  SPI.begin();
  pinMode(53,OUTPUT);
  if (!SD.begin(53)) {
    debug_serial.println("SD Card NOT detected.");
  }
  else{
    debug_serial.println("SD Card detected!");
  }
  
  //// Open log files
  /* Link will log to 3 files, one for I/O to the xbee, one for I/O to the radio,
   *  and one for recording its initialization status each time it starts up.
   *  NOTE: Filenames must be shorter than 8 characters
   */
  xbeeLogFile = SD.open("XBEE_LOG.txt", FILE_WRITE);
  delay(10);
  radioLogFile = SD.open("RDIO_LOG.txt", FILE_WRITE);
  delay(10);
  initLogFile = SD.open("INIT_LOG.txt", FILE_WRITE);
  delay(10);

  // write entry in init log file
  initLogFile.print("Startup Time: ");
  print_time(initLogFile);
  initLogFile.print(", RTC start: ");
  initLogFile.print(rtc_start);
  initLogFile.print(", RTC run: ");
  initLogFile.print(rtc_running);
  initLogFile.print(", xbee log: ");
  initLogFile.print(xbeeLogFile);
  initLogFile.print(", radio log: ");
  initLogFile.print(radioLogFile);
  initLogFile.print(", init log: ");
  initLogFile.print(initLogFile);
  initLogFile.print(", Xbee init status:  ");
  initLogFile.print(xbeeStatus);
  initLogFile.println();
  initLogFile.close();

  debug_serial.println(F("Link Initialized!"));
  
}

void loop() {
  /*  loop()
   *  
   *  Reads from xbee and processes any data
   *  Reads from radio and processes any data
   */

  // initalize a counter to record how many bytes were read this iteration
  int BytesRead = 0;

  //// Read message from xbee

  // xbee data arrives all at the same time, so its not necessary to remember
  // it between iterations, so we use a local buffer
  uint8_t ReadData[100];

  // read the data from the xbee with a 1ms timeout
  BytesRead = _readXbeeMsg(ReadData, 1);

  // if data was read, record it in the Xbee Rcvd counter
  if(BytesRead > 0){
    XbeeRcvdByteCtr += BytesRead;
  }

  // if data was read, process it as a CCSDS packet
  if(BytesRead > 0){

    // log the received data
    logPkt(xbeeLogFile, ReadData, BytesRead, LOG_RCVD);

    // check if the APID is included in the filter table, if so, forward it to ground
    if(checkApidFilterTable(getAPID(ReadData))){
      
      // forward and log the packet
      radio_send_and_log(ReadData, BytesRead);
      debug_serial.print("Recieved and forwarded packet in filter table with APID: ");
      debug_serial.print(getAPID(ReadData));
      
    }
    // if the data isn't forwarded, process it as a command
    else{
      
      command_response(ReadData, BytesRead);
    }
  
  }
  
  //// Read from 900s

  // Read any available data from radio
  /*  Data from the radio tends to appear in chuncks, several bytes at a time, which means
   *   that it can take several reads before an entire back of data is received. Therefore 
   *   we use a persistent buffer to store the data between reads and append the data from
   *   each read to that buffer.
   */
  BytesRead = radio_serial.readBytes(Buff_900toXbee + Buff_Pos, radio_serial.available());

  // add the number of bytes read to the previous length of the buffer to calculate the new 
  // length
  Buff_Pos += BytesRead;

  // add the number of bytes read to the radio rcvd counter
  RadioRcvdByteCtr += BytesRead;

  // increment a counter indicating the number of cycles since we received data
  cycles_since_read++;

  // if we read data this timestep we reset the counter indicating how long since we've 
  // received data
  if(BytesRead > 0){
    cycles_since_read = 0;
  }
  
  // process any packets
  if(BytesRead > 0 && Buff_Pos >= 8){

    debug_serial.print("Looking for packet of length ");
    debug_serial.print(getPacketLength(Buff_900toXbee));
    debug_serial.print(" and have ");
    debug_serial.println(Buff_Pos);
    
    // if we've read enough data to be a full packet, process it
    if(Buff_Pos >= getPacketLength(Buff_900toXbee)){

      // log the received data
      logPkt(radioLogFile, Buff_900toXbee, Buff_Pos, LOG_RCVD);
        
      command_response(Buff_900toXbee, Buff_Pos);
      Buff_Pos = 0;
    }
    
  }
  
  /*  Since a persistent buffer is employed to store the data which has been received, we
   *    meed to gaurd against it becoming full with invalid data (ie, if only half a packet
   *    is received, eventually we should just throw it away so that we can process the next
   *    one we get). To do this, if these is data in the buffer at its been at least 100 cycles
   *    (~1sec) since we last received data, we clear the buffer.
   */
  if(Buff_Pos > 0 && cycles_since_read > 100){

    // set the value of all elements of the buffer to zero
    memset( Buff_900toXbee, 0, PKT_MAX_LEN);

    // reset the counter to the beginning of the buffer
    Buff_Pos = 0;
    
    debug_serial.println("Clearing buffer");
  }

  // wait for 10ms until we attempt to read more data
  /* NOTE: this introduces a limit on data throughput by how many packets can be processed
   *   per unit of time. With a 10ms delay, we can process at most 200 packets/sec (100 from
   *   radio and 100 from xbee).
   *   
   *   Testing should be done before changing this number, but reducing it would allow for 
   *   higher throughput. With a value of 10ms no issues with receiving partial packets from
   *   the xbee have been observed and the partial packets from the radio have been handled 
   *   by the persistent buffer. Its not clear if the lack of issues with the xbee is because
   *   of the way the adafruit xbee library handles that interface, or if the abee just writes
   *   its data quick enough that its unlikely partial packets will be read.
   */
  delay(10);
}

void command_response(uint8_t data[], uint8_t data_len) {
  /*  command_response()
   * 
   *  given an array of data (presumably containing a CCSDS packet), check if the
   *  packet is a LINK command packet, and if so, process it
   */

  // get the APID (the field which identifies the type of packet)
  uint8_t _APID = getAPID(data);
    
  // check if the data is a command packet with the LINK command APID
  if(getPacketType(data) && _APID == 100){

    uint8_t FcnCode = getCmdFunctionCode(data);
    uint8_t destAddr = 0;
    uint16_t pktLength = 0;
    uint8_t HK_Pkt_Buff[36];
    uint8_t FLTR_TBL_Buff[32];
    uint16_t tbl_val = 0;
    uint8_t pkt_pos = 7;
    uint8_t tbl_idx = 0;

    // respond to the command depending on what type of command it is
    switch(FcnCode){

      // NoOp Cmd
      case 0:
        // No action other than to increment the interface counters
        
        debug_serial.println("Received NoOp Cmd");

        // increment the cmd executed counter
        CmdExeCtr++;
        break;
        
      // GroundRequestHK
      case 10:
        // Requests that an HK packet be sent to the ground
        debug_serial.println("Received Gnd_HkReq Cmd");
        
        // create a HK pkt
        pktLength = create_HK_pkt(HK_Pkt_Buff);

        // send packet via the radio and log it
        radio_send_and_log(HK_Pkt_Buff, sizeof(HK_Pkt_Buff));

        // increment the cmd executed counter
        CmdExeCtr++;
        break;
        
      // XbeeRequestHK
      case 20:
        // Requests that an HK packet be sent to the specified xbee address
        /*  Command format:
         *   CCSDS Command Header (8 bytes)
         *   Xbee address (1 byte)
         */
        
        debug_serial.print("Received XB_HkReq Cmd to addr ");
        
        // extract the desintation address from the command
        extractFromTlm(destAddr, data, 8);
        debug_serial.println(destAddr);
        
        // create a HK pkt
        pktLength = create_HK_pkt(HK_Pkt_Buff);

        // send the HK packet via xbee and log it
        xbee_send_and_log(destAddr, HK_Pkt_Buff, sizeof(HK_Pkt_Buff));
        
        // increment the cmd executed counter
        CmdExeCtr++;
        break;
                
      // XbeeFwdMessage
      case 25:
        // Requests that the data portion of this command be forwarded to the specified xbee address
        /*  Command format:
         *   CCSDS Command Header (8 bytes)
         *   Xbee address (1 byte)
         *   Data (rest of packet)
         */
         
        debug_serial.print("Received XbeeFwdMessage Cmd to addr ");

        // extract the desired xbee address from the packet
        pkt_pos = extractFromTlm(destAddr, data, 8);

        // extract the length of the command received (used for determining how long the data
        // to-be-forwarded is)
        pktLength = getPacketLength(data);
        debug_serial.println(destAddr);
        
        // send the data and log it
        // don't sent the CCSDS header we received (8 bytes) or the destination address (1 byte)
        xbee_send_and_log(destAddr, data + pkt_pos, pktLength-pkt_pos);

        // increment the cmd executed counter
        CmdExeCtr++;
        break;
        
      // GroundFwdMessage
      case 15:
        // Requests that the data portion of this command be forwarded to the ground
        /*  Command format:
         *   CCSDS Command Header (8 bytes)
         *   Data (rest of packet)
         */
         
        debug_serial.println("Received GroundFwdMessage Cmd");

        // extract the length of the command received (used for determining how long the data
        // to-be-forwarded is)
        pktLength = getPacketLength(data);

        // send and log the packet
        radio_send_and_log(data+8, data_len-8);

        // increment the cmd executed counter
        CmdExeCtr++;
        break;

      // ResetCtr
      case 30:
        // Requests that all of the interface data counters be reset to zero
        
        debug_serial.println("Received ResetCtr Cmd");

        // reset all counters to zero
        CmdExeCtr = 0;
        CmdRejCtr = 0;
        RadioRcvdByteCtr = 0;
        XbeeRcvdByteCtr = 0;
        RadioSentByteCtr = 0;
        XbeeSentByteCtr = 0;

        // increment the cmd executed counter
        CmdExeCtr++;
        break;

      // TlmFilterTable
      case 40:
        // Requests that the values in the filter table be sent to the ground

        debug_serial.println("Received TlmFilterTable Cmd");
         
        // create pkt with filter table
        pktLength = create_fltrtbl_pkt(FLTR_TBL_Buff);

        // send packet and log it
        radio_send_and_log(FLTR_TBL_Buff, sizeof(FLTR_TBL_Buff));

        // increment the cmd executed counter
        CmdExeCtr++;
        break;
        
      // SetFilterTableIdx
      case 45:
         // Requests that the specified index of the filter table be updated with the specified value

         debug_serial.print("Received SetFilterTableIdx Cmd");

         // extract index of element to be set
         pkt_pos = extractFromTlm(tbl_idx, data, 8);

         // extract value of the element
         extractFromTlm(tbl_val, data, pkt_pos);

         debug_serial.print(" for idx ");
         debug_serial.print(tbl_idx);
         debug_serial.print(" and val ");
         debug_serial.println(tbl_val);
         
         // update the filter table
         filter_table[tbl_idx] = tbl_val;

        // increment the cmd executed counter
        CmdExeCtr++;
        break;
                
      // unrecognized fcn code
      default:
        debug_serial.print("unrecognized fcn code ");
        debug_serial.println(FcnCode, HEX);
        
        // reject command
        CmdRejCtr++;
    }
    
  }
  else{
    debug_serial.print("Unrecognized apid 0x");
    debug_serial.println(_APID, HEX);
  }
}

uint16_t create_HK_pkt(uint8_t HK_Pkt_Buff[]){
/*  create_HK_pkt()
 * 
 *  Creates an HK packet containing the values of all the interface counters. 
 *  Packet data is filled into the memory passed in as the argument
 *  
 */

  // initalize counter to record length of packet
  uint16_t payloadSize = 0;
  
  // add length of primary header
  payloadSize += sizeof(CCSDS_PriHdr_t);

  // Populate primary header fields:
  setAPID(HK_Pkt_Buff, 110);
  setSecHdrFlg(HK_Pkt_Buff, 1);
  setPacketType(HK_Pkt_Buff, 0);
  setVer(HK_Pkt_Buff, 0);
  setSeqCtr(HK_Pkt_Buff, 0);
  setSeqFlg(HK_Pkt_Buff, 0);

  // add length of secondary header
  payloadSize += sizeof(CCSDS_TlmSecHdr_t);

  // Populate the secondary header fields:
  setTlmTimeSec(HK_Pkt_Buff, millis()/1000L);
  setTlmTimeSubSec(HK_Pkt_Buff, millis() % 1000L);

  // Add counter values to the pkt
  payloadSize = addIntToTlm(CmdExeCtr, HK_Pkt_Buff, payloadSize); // Add counter of sent packets to message
  payloadSize = addIntToTlm(CmdRejCtr, HK_Pkt_Buff, payloadSize); // Add counter of sent packets to message
  payloadSize = addIntToTlm(RadioRcvdByteCtr, HK_Pkt_Buff, payloadSize); // Add counter of sent packets to message
  payloadSize = addIntToTlm(XbeeRcvdByteCtr, HK_Pkt_Buff, payloadSize); // Add counter of sent packets to message
  payloadSize = addIntToTlm(RadioSentByteCtr, HK_Pkt_Buff, payloadSize); // Add counter of sent packets to message
  payloadSize = addIntToTlm(XbeeSentByteCtr, HK_Pkt_Buff, payloadSize); // Add counter of sent packets to message
  payloadSize = addIntToTlm(millis()/1000L, HK_Pkt_Buff, payloadSize); // Timer

  // fill the length field
  setPacketLength(HK_Pkt_Buff, payloadSize);

  return payloadSize;
}

uint16_t create_fltrtbl_pkt(uint8_t FLTR_TBL_Buff[]){
/*  create_fltrtbl_pkt()
 * 
 *  Creates an filter table packet containing the values of the filter table
 *  Packet data is filled into the memory passed in as the argument
 *  
 */
 
  // initalize counter to record length of packet
  uint16_t payloadSize = 0;

  // add length of primary header
  payloadSize += sizeof(CCSDS_PriHdr_t);

  // Populate primary header fields:
  setAPID(FLTR_TBL_Buff, 130);
  setSecHdrFlg(FLTR_TBL_Buff, 1);
  setPacketType(FLTR_TBL_Buff, 0);
  setVer(FLTR_TBL_Buff, 0);
  setSeqCtr(FLTR_TBL_Buff, 0);
  setSeqFlg(FLTR_TBL_Buff, 0);

  // add length of secondary header
  payloadSize += sizeof(CCSDS_TlmSecHdr_t);

  // Populate the secondary header fields:
  setTlmTimeSec(FLTR_TBL_Buff, millis()/1000L);
  setTlmTimeSubSec(FLTR_TBL_Buff, millis() % 1000L);

  // add elements of filter table to the packet
  for(int i = 0; i < FILT_TBL_LEN; i++){
    payloadSize = addIntToTlm(filter_table[i], FLTR_TBL_Buff, payloadSize); // Add the value of the table to message
  }
 
  // fill the length field
  setPacketLength(FLTR_TBL_Buff, payloadSize);

  return payloadSize;
}

boolean checkApidFilterTable(uint16_t apid){
/* checkApidFilterTable()
 *  
 *  checks if the given apid exists in the filter table
 *  
 */

  // loop through filter table and return true if value is found
  for(int i = 0; i < FILT_TBL_LEN; i++){
    if(apid == filter_table[i]){
      return true;
    }
  }

  // otherwise return false
  return false;
}

void radio_send_and_log(uint8_t data[], uint8_t data_len){
/*  radio_send_and_log()
 * 
 *  Sends the given data out over the radio and adds an entry to the radio log file.
 *  Also updates the radio sent counter.
 */

  // print the data to the radio serial
  debug_serial.print("Radio sending: ");
  for(int i = 0; i < data_len; i++) {
      debug_serial.print(data[i], HEX);
      debug_serial.print(", ");
    
      radio_serial.write(data[i]);
  }
  debug_serial.println();

  // log the sent data
  logPkt(radioLogFile, data, data_len, LOG_SEND);

  // update the radio send ctr
  RadioSentByteCtr += data_len;

}

void xbee_send_and_log(uint8_t dest_addr, uint8_t data[], uint8_t data_len){
/*  xbee_send_and_log()
 * 
 *  Sends the given data out over the xbee and adds an entry to the xbee log file.
 *  Also updates the radio sent counter.
 */
 
  // send the data via xbee
  _sendData(dest_addr, data, sizeof(data));

  debug_serial.print("Forwarding: ");
  for(int i = 0; i <= data_len; i++){
    debug_serial.print(data[i], HEX);
    debug_serial.print(", ");
  }
  debug_serial.println();

  // log the sent data
  logPkt(xbeeLogFile, data, sizeof(data), 0);

  // update the xbee send ctr
  XbeeSentByteCtr += data_len;
}

void print_time(File file){
/*  print_time()
 * 
 *  Prints the current time to the given log file
 */

  // get the current time from the RTC
  DateTime now = rtc.now();

  // print a datestamp to the file
  char buf[50];
  sprintf(buf, "%02d/%02d/%02d %02d:%02d:%02d", now.day(), now.month(), now.year(), now.hour(), now.minute(), now.second());
  file.print(buf);
}

void logPkt(File file, uint8_t data[], uint8_t len, uint8_t received_flg){
/*  logPkt()
 * 
 *  Prints an entry in the given log file containing the given data. Will prepend an
 *  'S' if the data was sent or an 'R' is the data was received based on the value
 *  of the received_flg.
 */

  // if the file is open
  if (file) {

    // prepend an indicator of if the data was received or sent
    // R indicates this was received data
    if(received_flg){
      file.print("R ");
    }
    else{
      file.print("S ");
    }
    
    // Print a timestamp
    print_time(file);

   char buf[50];

    // print the data in hex
    file.print(": ");
    for(int i = 0; i < len; i++){
        sprintf(buf, "%02x, ", data[i]);
        file.print(buf);
     }
     file.println();
     
     // ensure the data gets written to the file
     file.flush();
   }
}

