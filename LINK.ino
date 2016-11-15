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
 *   HK_REQ - Requests that a housekeeping pkt containing status info be sent to the indicated address
 *   FWDMSG - Requests that the contained data be forwarded to the indicated address
 *   
 * In addition to these commands, LINK uses a filter table to determine if a received packet 
 * should be forwarded to the ground. Although this breaks the paradigm that all actions should 
 * be commanded (to make tracing cause and effect in debugging easier), it is too cumbersome to 
 * require every external payload that wishes to relay data to the ground (which is LINK's primary purpose) 
 * to wrap their data in a FWDMSG command. The filter table is a list of APIDs (a field in a CCSDS
 * packet used to identify the type of packet) to determine if a message should be automatically forwarded to
 * the ground. The following commands are available to manage the filter table:
 *   TLMFLTRBL - Requests that the current filter table be dumped to the ground
 *   SETFLTRTBLIDX - Request that a specified index of the filter table be set to a specified value
 * 
 * LINK also has the ability to be reset remotely through the command:
 *   REBOOT - Requests that LINK reboot itself via a watchdog timer
 *   
 * In addition to its data routing functionality, LINK also takes advantage of balloonduino's 
 * on-board sensors to monitor its status and the environment around it. All of this data is logged 
 * and the following commands can be used to request data from LINK:
 *   REQ_ENV - Requests LINK send current temperature/pressure/humidity data
 *   REQ_PWR - Requests LINK send current power/battery status data
 *   REQ_IMU - Requests LINK send current accel/gryo/mag data
 *   
 *   See the COSMOS repo (https://github.com/UMDBPP/COSMOS) for full format of the commands described above.
 * 
 */
   
//// Includes:
#include <avr/wdt.h>  // watchdog timer
#include <Wire.h>
#include <SPI.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_BNO055.h>
#include <utility/imumaths.h>
#include "Adafruit_MCP9808.h"
#include "RTClib.h"  // RTC and SoftRTC
#include <Adafruit_BME280.h>
#include <SD.h>
#include <Adafruit_ADS1015.h>
#include "CCSDS_Xbee/CCSDS.h"
#include "CCSDS_Xbee/ccsds_xbee.h"
#include "CCSDS_Xbee/ccsds_util.h"
#include <SSC.h>
#include <EEPROM.h>

//// Enumerations
// logging flag
#define LOG_RCVD 1
#define LOG_SEND 0

// LINK APIDS
#define LINK_CMD_APID 200
#define LINK_HK_APID 210
#define LINK_ENV_APID 211
#define LINK_PWR_APID 212
#define LINK_IMU_APID 213
#define LINK_INIT_APID 214
#define LINK_FLTR_TBL_APID 215
#define LINK_TIME_MSG_APID 216
#define LINK_FILEINFO_MSG_APID 217
#define LINK_FILEPART_MSG_APID 218
#define LINK_GND_MSG_APID 240 

// LINK FcnCodes
#define LINK_NOOP_CMD 0
#define LINK_HKREQ_CMD 10
#define LINK_REQENV_CMD 11
#define LINK_REQPWR_CMD 12
#define LINK_REQIMU_CMD 13
#define LINK_REQINIT_CMD 14
#define LINK_FLTRREQ_CMD 15
#define LINK_REQTIME_CMD 16
#define LINK_REQFILEINFO_CMD 17
#define LINK_REQFILEPART_CMD 18
#define LINK_SETFLTR_CMD 20
#define LINK_RESETCTR_CMD 30
#define LINK_FWDMSG_CMD 40 
#define LINK_SETTIME_CMD 50
#define LINK_REBOOT_CMD 99

//// Declare objects
Adafruit_BNO055 bno = Adafruit_BNO055(-1, 0x29);
Adafruit_MCP9808 tempsensor = Adafruit_MCP9808();
RTC_DS1307 rtc;  // real time clock (for logging with timestamps)
RTC_Millis SoftRTC;   // This is the millis()-based software RTC
Adafruit_BME280 bme;
Adafruit_ADS1015 ads(0x4A);
SSC ssc(0x28, 255);

//// Compile time constants
#define PKT_MAX_LEN 200     // size of buffers to contain packets being relayed
#define FILT_TBL_NUM_EL 15     // number of elements in the packet filter table
#define FLTR_TBL_START_ADDR 0

//// Serial object aliases
// so that the user doesn't have to keep track of which is which
#define debug_serial Serial
#define radio_serial Serial2
#define xbee_serial Serial3

//// Timing
// timing counters
uint16_t imu_read_ctr = 0;
uint16_t pwr_read_ctr = 0;
uint16_t env_read_ctr = 0;

// rate setting
// sensors will be read every X cycles
uint16_t imu_read_lim = 10;
uint16_t pwr_read_lim = 100;
uint16_t env_read_lim = 100;

//// Data buffers
// for holding data being relayed
uint8_t Buff_900toXbee[PKT_MAX_LEN];
uint8_t Buff_Xbeeto900[PKT_MAX_LEN];
uint8_t Buff_Pos = 0;

//// Xbee setup parameters
uint16_t XBee_MY_Addr = 0x0002; // XBee address for this payload 
// DO NOT CHANGE without making corresponding change in ground system definitions
uint16_t XBee_PAN_ID = 0x0B0B; // XBee PAN address (must be the same for all xbees)
// DO NOT CHANGE without changing for all xbees

//// Data Structures
// imu data
struct IMUData_s {
   uint8_t system_cal;
   uint8_t accel_cal;
   uint8_t gyro_cal;
   uint8_t mag_cal;
   float accel_x;
   float accel_y;
   float accel_z;
   float gyro_x;
   float gyro_y;
   float gyro_z;
   float mag_x;
   float mag_y;
   float mag_z;
}; 
// power data
struct PWRData_s {
  float batt_volt;
  float i_consump;
}; 
// environmental data
struct ENVData_s {
  float bme_pres;
  float bme_temp;
  float bme_humid;
  float ssc_pres;
  float ssc_temp;
  float bno_temp;
  float mcp_temp;
}; 
// environmental data
struct InitStat_s {
  uint8_t xbeeStatus;
  uint8_t rtc_running;
  uint8_t rtc_start;
  uint8_t BNO_init;
  uint8_t MCP_init;
  uint8_t BME_init;
  uint8_t SSC_init;
  uint8_t SD_detected;
}; 

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
uint16_t filter_table[FILT_TBL_NUM_EL] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

//// Other variables
uint16_t cycles_since_radio_read = 0;
uint32_t start_millis = 0;
InitStat_s InitStat;

//// Files
// interface logging files
File xbeeLogFile;
File radioLogFile;
File initLogFile;
// data logging files
File IMULogFile;
File ENVLogFile;
File PWRLogFile;

//// Function prototypes
void command_response(uint8_t data[], uint8_t data_len, struct IMUData_s IMUData, struct ENVData_s ENVData, struct PWRData_s PWRData);

// interface
void send_and_log(uint8_t dest_addr, uint8_t data[], uint8_t data_len);
void radio_send_and_log(uint8_t data[], uint8_t data_len);
void xbee_send_and_log(uint8_t dest_addr, uint8_t data[], uint8_t data_len);
void logXbeePkt(File file, uint8_t data[], uint8_t len, uint8_t received_flg);

// pkt creation
uint16_t create_HK_pkt(uint8_t HK_Pkt_Buff[]);
uint16_t create_fltrtbl_pkt(uint8_t FLTR_TBL_Buff[]);
uint16_t create_IMU_pkt(uint8_t HK_Pkt_Buff[], struct IMUData_s IMUData);
uint16_t create_PWR_pkt(uint8_t HK_Pkt_Buff[], struct PWRData_s PWRData);
uint16_t create_ENV_pkt(uint8_t HK_Pkt_Buff[], struct ENVData_s ENVData);
uint16_t create_TIME_pkt(uint8_t HK_Pkt_Buff[], DateTime t);
uint16_t create_FILEINFO_pkt(uint8_t Pkt_Buff[], File entry);
uint16_t create_FILEPART_pkt(uint8_t Pkt_Buff[], File entry, uint32_t start_pos, uint32_t end_pos);

// sensor reading
void read_imu(struct IMUData_s *IMUData);
void read_pwr(struct PWRData_s *PWRData);
void read_env(struct ENVData_s *ENVData);

// log data
void log_imu(struct IMUData_s IMUData, File IMULogFile);
void log_env(struct ENVData_s ENVData, File ENVLogFile);
void log_pwr(struct PWRData_s PWRData, File PWRLogFile);

// utility
void print_time(File file);
boolean checkApidFilterTable(uint16_t apid);

void setup() {
  /* setup()
   *  
   * Disables watchdog timer (in case its on)
   * Initalizes all the link hardware/software including:
   *   Serial
   *   Xbee
   *   RTC
   *   SoftRTC
   *   BNO
   *   MCP
   *   BME
   *   SSC
   *   ADS
   *   SD card
   *   Log files
   */

  // disable the watchdog timer immediately in case it was on because of a 
  // commanded reboot
  wdt_disable();

  //// Init serial ports:
  /*  aliases defined above are used to reduce confusion about which serial
   *    is connected to what interface
   *  xbee and radio serial are lower baud rates because the hardware 
   *    defaults to that baud rate. higher baud rates need to be tested
   *    before they're used with those devices
   */
  debug_serial.begin(250000);
  xbee_serial.begin(9600);
  radio_serial.begin(57600);

  debug_serial.println("Begin Link Init!");

  //// Init Xbee
  /* InitXbee() will configure the attached xbee so that it can talk to
   *   xbees which also use this library. It also handles the initalization
   *   of the adafruit xbee library
   */
  InitStat.xbeeStatus = InitXBee(XBee_MY_Addr, XBee_PAN_ID, xbee_serial);
  if(!InitStat.xbeeStatus) {
    debug_serial.println(F("XBee Initialized!"));
  } else {
    debug_serial.print(F("XBee Failed to Initialize with Error Code: "));
    debug_serial.println(InitStat.xbeeStatus);
  }

  //// RTC  
  /* The RTC is used so that the log files contain timestamps. If the RTC
   *  is not running (because no battery is inserted) the RTC will be initalized
   *  to the time that this sketch was compiled at.
   */
  InitStat.rtc_start = rtc.begin();
  if (!InitStat.rtc_start) {
    Serial.println("RTC NOT detected.");
  }
  else{
    Serial.println("RTC detected!");
    InitStat.rtc_running = rtc.isrunning();
    if (!InitStat.rtc_running) {
      debug_serial.println("RTC is NOT running!");
      // following line sets the RTC to the date & time this sketch was compiled
      rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
      // To set the RTC with an explicit date & time:
      // rtc.adjust(DateTime(2014, 1, 21, 3, 0, 0));
    }
  }

  //// SoftRTC (for subsecond precision)
  SoftRTC.begin(rtc.now());  // Initialize SoftRTC to the current time
  start_millis = millis();  // get the current millisecond count

  //// BNO
  InitStat.BNO_init = bno.begin();
  if(!InitStat.BNO_init){
    debug_serial.println("BNO055 NOT detected.");
  }
  else{
    debug_serial.println("BNO055 detected!");
  }
  delay(500);
  bno.setExtCrystalUse(true);

  //// MCP9808
  InitStat.MCP_init = tempsensor.begin(0x18);
  if (!InitStat.MCP_init) {
    debug_serial.println("MCP9808 NOT detected.");
  }
  else{
    debug_serial.println("MCP9808 detected!");
  }

  //// Init BME
  // Temp/pressure/humidity sensor
  InitStat.BME_init = bme.begin(0x76);
  if (!InitStat.BME_init) {
    debug_serial.println("BME280 NOT detected.");
  }
  else{
    debug_serial.println("BME280 detected!");
  }

  //// Init SSC
  //  set min / max reading and pressure, see datasheet for the values for your 
  //  sensor
  ssc.setMinRaw(0);
  ssc.setMaxRaw(16383);
  ssc.setMinPressure(0.0);
  ssc.setMaxPressure(30);
  //  start the sensor
  InitStat.SSC_init = ssc.start();
  if(!InitStat.SSC_init){
    debug_serial.println("SSC started ");
  }
  else{
    debug_serial.println("SSC failed!");
  }

  //// Init ADS
  // ADC, used for current consumption/battery voltage
  ads.begin();
  ads.setGain(GAIN_ONE);
  debug_serial.println("Initialized ADS1015");

  //// Init filter table
  // loads filter table values from non-volatile EEPROM storage
  // SetFltrTbl command will update both the program copy and the EEPROM
  // so that any changes are loaded on reboot
  debug_serial.print("Loading filter table: ");
  // loop through reading the values into a program variable
  for(int i = 0; i < FILT_TBL_NUM_EL; i++){
    EEPROM.get(FLTR_TBL_START_ADDR+i*2,filter_table[i]);
    debug_serial.print(filter_table[i]);
    debug_serial.print(", ");
  }
  debug_serial.println();
  
  //// Init SD card
  /* The SD card is used to store all of the log files.
   */
  SPI.begin();
  pinMode(53,OUTPUT);
  InitStat.SD_detected = SD.begin(53);
  if (!InitStat.SD_detected) {
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
  
  // for data files, write a header
  initLogFile = SD.open("INIT_LOG.txt", FILE_WRITE);
  initLogFile.println("DateTime,RTCStart,RTCRun,BNO,BME,MCP,SSC,Xbee");
  initLogFile.flush(); 
  delay(10);
  IMULogFile = SD.open("IMU_LOG.txt", FILE_WRITE);
  IMULogFile.println("DateTime,SystemCal[0-3],AccelCal[0-3],GyroCal[0-3],MagCal[0-3],AccelX[m/s^2],AccelY[m/s^2],AccelZ[m/s^2],GyroX[rad/s],GyroY[rad/s],GyroZ[rad/s],MagX[uT],MagY[uT],MagZ[uT]");
  IMULogFile.flush();  
  delay(10);
  PWRLogFile = SD.open("PWR_LOG.txt", FILE_WRITE);
  PWRLogFile.println("DateTime,BatteryVoltage[V],CurrentConsumption[A]");
  PWRLogFile.flush();
  delay(10);
  ENVLogFile = SD.open("ENV_LOG.txt", FILE_WRITE);
  ENVLogFile.println("DateTime,BMEPressure[hPa],BMETemp[degC],BMEHumidity[%],SSCPressure[PSI],SSCTemp[degC],BNOTemp[degC],MCPTemp[degC]");
  ENVLogFile.flush();
  delay(10);  
  
  // write entry in init log file
  print_time(initLogFile);
  initLogFile.print(", ");
  initLogFile.print(InitStat.rtc_start);
  initLogFile.print(", ");
  initLogFile.print(InitStat.rtc_running);
  initLogFile.print(", ");
  initLogFile.print(InitStat.BNO_init);
  initLogFile.print(", ");
  initLogFile.print(InitStat.BME_init);
  initLogFile.print(", ");
  initLogFile.print(InitStat.MCP_init);
  initLogFile.print(", ");
  initLogFile.print(InitStat.SSC_init);
  initLogFile.print(", ");
  initLogFile.print(InitStat.xbeeStatus);
  initLogFile.print(", ");
  initLogFile.print(InitStat.SD_detected);
  initLogFile.println();
  initLogFile.close();

  debug_serial.println(F("Link Initialized!"));
  
}

void loop() {
  /*  loop()
   *  
   *  Reads sensor data if cycle counters indicate to
   *  Reads from xbee and processes any data
   *  Reads from radio and processes any data
   */
  
  // declare structures to store data
  IMUData_s IMUData;
  PWRData_s PWRData;
  ENVData_s ENVData;

  // increment read counters
  imu_read_ctr++;
  pwr_read_ctr++;
  env_read_ctr++;

  // read sensors if time between last read
  if(imu_read_ctr > imu_read_lim){
    read_imu(&IMUData);
    log_imu(IMUData, IMULogFile);
    imu_read_ctr = 0;
  }
  if(pwr_read_ctr > pwr_read_lim){
    read_pwr(&PWRData);
    log_pwr(PWRData, PWRLogFile);
    pwr_read_ctr = 0;
  }
  if(env_read_ctr > env_read_lim){
    read_env(&ENVData);
    log_env(ENVData, ENVLogFile);
    env_read_ctr = 0;
  }  

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
      debug_serial.print("Recieved and forwarded packet of length ");
      debug_serial.print(BytesRead);
      debug_serial.print(" in filter table with APID: ");
      debug_serial.println(getAPID(ReadData));
      
    }
    // if the data isn't forwarded, process it as a command
    else{
      // respond to the data
      command_response(ReadData, BytesRead, IMUData, ENVData, PWRData);
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
  cycles_since_radio_read++;

  // if we read data this timestep we reset the counter indicating how long since we've 
  // received data
  if(BytesRead > 0){
    cycles_since_radio_read = 0;
    debug_serial.print("Got ");
    debug_serial.print(BytesRead);
    debug_serial.print(" bytes:");
    for (int i = 0; i < BytesRead; i++){
      debug_serial.print(Buff_900toXbee[Buff_Pos+i]);
      debug_serial.print(", ");
    }
    debug_serial.println();
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

      // respond to the data
      command_response(Buff_900toXbee, Buff_Pos, IMUData, ENVData, PWRData);

      // reset the buffer back to beginning since data has been processed
      Buff_Pos = 0;
    }
    
  }
  
  /*  Since a persistent buffer is employed to store the data which has been received, we
   *    meed to gaurd against it becoming full with invalid data (ie, if only half a packet
   *    is received, eventually we should just throw it away so that we can process the next
   *    one we get). To do this, if these is data in the buffer at its been at least 100 cycles
   *    (~1sec) since we last received data, we clear the buffer.
   */
  if(Buff_Pos > 0 && cycles_since_radio_read > 100){

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

void command_response(uint8_t data[], uint8_t data_len, struct IMUData_s IMUData, struct ENVData_s ENVData, struct PWRData_s PWRData) {
  /*  command_response()
   * 
   *  given an array of data (presumably containing a CCSDS packet), check if: 
   *    the packet is a command packet
   *    the APID is the LINK command packet APID
   *    the checksum in the header is correct
   *  if so, process it
   *  otherwise, reject it
   */

  // get the APID (the field which identifies the type of packet)
  uint16_t _APID = getAPID(data);
    
  // check if the data is a command packet with the LINK command APID
  if(getPacketType(data) && _APID == LINK_CMD_APID){

    // validate the packet checksum
    if(validateChecksum(data)){
    
      uint8_t FcnCode = getCmdFunctionCode(data);
      
      uint8_t FLTR_TBL_Buff[FILT_TBL_NUM_EL*2+12];
      uint8_t Pkt_Buff[100];
  
      // respond to the command depending on what type of command it is
      switch(FcnCode){
  
        // NoOp Cmd
        case LINK_NOOP_CMD:
        {
          // No action other than to increment the interface counters
          
          debug_serial.println("Received NoOp Cmd");
  
          // increment the cmd executed counter
          CmdExeCtr++;
          break;
        }
        // REQ_HK
        case LINK_HKREQ_CMD:
        {
          // Requests that an HK packet be sent to the ground
          debug_serial.print("Received HKReq Cmd to addr ");
          /*  Command format:
           *   CCSDS Command Header (8 bytes)
           *   Xbee address (1 byte) (or 0 if Gnd)
           */
          uint8_t destAddr = 0;
          uint16_t pktLength = 0;
          
          // extract the desintation address from the command
          extractFromTlm(destAddr, data, 8);
          debug_serial.println(destAddr);
          
          // create a HK pkt
          pktLength = create_HK_pkt(Pkt_Buff);

          // send the data
          send_and_log(destAddr, Pkt_Buff, pktLength);
  
          // increment the cmd executed counter
          CmdExeCtr++;
          break;
        } 
        // FwdMessage
        case LINK_FWDMSG_CMD:
        {
          // Requests that the data portion of this command be forwarded to the specified xbee address
          /*  Command format:
           *   CCSDS Command Header (8 bytes)
           *   Xbee address (1 byte) (or 0 if GND)
           *   Data (rest of packet)
           */
           
          debug_serial.print("Received FwdMessage Cmd of length ");

          uint8_t destAddr = 0;
          uint8_t pkt_pos = 7;
          uint16_t pktLength = 0;
                
          // extract the desired xbee address from the packet
          pkt_pos = extractFromTlm(destAddr, data, 8);
  
          // extract the length of the command received (used for determining how long the data
          // to-be-forwarded is)
          pktLength = getPacketLength(data);
          debug_serial.print(pktLength-pkt_pos);
          debug_serial.print(" to addr ");
          debug_serial.println(destAddr);

          // send the data
          send_and_log(destAddr, data + pkt_pos, pktLength-pkt_pos);
  
          // increment the cmd executed counter
          CmdExeCtr++;
          break;
        }
        // ResetCtr
        case LINK_RESETCTR_CMD:
        {
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
        }
        // TlmFilterTable
        case LINK_FLTRREQ_CMD:
        {
          // Requests that the values in the filter table be sent to the indicated address
          /*  Command format:
           *   CCSDS Command Header (8 bytes)
           *   Xbee address (1 byte) (or 0 if GND)
           */
           
          debug_serial.print("Received TlmFilterTable Cmd to addr: ");

          uint8_t destAddr = 0;
          uint8_t pkt_pos = 7;
          uint16_t pktLength = 0;
          
          // extract the desired xbee address from the packet
          pkt_pos = extractFromTlm(destAddr, data, 8);
          debug_serial.println(destAddr);
           
          // create pkt with filter table
          pktLength = create_fltrtbl_pkt(FLTR_TBL_Buff);

          // send the data
          send_and_log(destAddr, FLTR_TBL_Buff, sizeof(FLTR_TBL_Buff)); 
  
          // increment the cmd executed counter
          CmdExeCtr++;
          break;
        }
        // SetFilterTableIdx
        case LINK_SETFLTR_CMD:
        {
           // Requests that the specified index of the filter table be updated with the specified value

           uint16_t tbl_val = 0;
           uint8_t tbl_idx = 0;
           uint8_t pkt_pos = 7;
           
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

           debug_serial.println("Updating EEPROM storage");
           EEPROM.put(FLTR_TBL_START_ADDR+tbl_idx*2,tbl_val);  

          // increment the cmd executed counter
          CmdExeCtr++;
          break;
        }
        // ENV_Req
        case LINK_REQENV_CMD:
        {
          // Requests that the ENV status be reported to the specified address
          /*  Command format:
           *   CCSDS Command Header (8 bytes)
           *   Xbee address (1 byte) (or 0 if GND)
           */
          
          debug_serial.print("Received ENV_Req Cmd to addr: ");

          uint8_t destAddr = 0;
          uint8_t pkt_pos = 7;
          uint16_t pktLength = 0;
          
          // extract the desired xbee address from the packet
          pkt_pos = extractFromTlm(destAddr, data, 8);
          debug_serial.println(destAddr);
          
          // create a HK pkt
          pktLength = create_ENV_pkt(Pkt_Buff, ENVData);
          
          // send the data
          send_and_log(destAddr, Pkt_Buff, pktLength); 
          
          // increment the cmd executed counter
          CmdExeCtr++;
          break;
        }
        // PWR_Req
        case LINK_REQPWR_CMD:
        {
          // Requests that the PWR status be reported to the specified address
          /*  Command format:
           *   CCSDS Command Header (8 bytes)
           *   Xbee address (1 byte) (or 0 if GND)
           */
          
          debug_serial.print("Received PWR_Req Cmd to addr: ");

          uint8_t destAddr = 0;
          uint8_t pkt_pos = 7;
          uint16_t pktLength = 0;
          
          // extract the desired xbee address from the packet
          pkt_pos = extractFromTlm(destAddr, data, 8);
          debug_serial.println(destAddr);
          
          // create a HK pkt
          pktLength = create_PWR_pkt(Pkt_Buff, PWRData);
  
          // send the data
          send_and_log(destAddr, Pkt_Buff, pktLength);
          
          // increment the cmd executed counter
          CmdExeCtr++;
          break;
        }
        // IMU_Req
        case LINK_REQIMU_CMD:
        {
          // Requests that the IMU status be sent to the specified address
          /*  Command format:
           *   CCSDS Command Header (8 bytes)
           *   Xbee address (1 byte) (or 0 if GND)
           */
          
          debug_serial.print("Received IMU_Req Cmd to addr:");

          uint8_t destAddr = 0;
          uint8_t pkt_pos = 7;
          uint16_t pktLength = 0;
          
          // extract the desired xbee address from the packet
          pkt_pos = extractFromTlm(destAddr, data, 8);
          debug_serial.println(destAddr);
          
          // create a HK pkt
          pktLength = create_IMU_pkt(Pkt_Buff, IMUData);
  
          // send the data
          send_and_log(destAddr, Pkt_Buff, pktLength);
          
          // increment the cmd executed counter
          CmdExeCtr++;
          break;
        }
        // Init_Req
        case LINK_REQINIT_CMD:
        {
          // Requests that the IMU status be sent to the specified address
          /*  Command format:
           *   CCSDS Command Header (8 bytes)
           *   Xbee address (1 byte) (or 0 if GND)
           */
          
          debug_serial.print("Received Init_Req Cmd to addr:");

          uint8_t destAddr = 0;
          uint8_t pkt_pos = 7;
          uint16_t pktLength = 0;
          
          // extract the desired xbee address from the packet
          pkt_pos = extractFromTlm(destAddr, data, 8);
          debug_serial.println(destAddr);
          
          // create a Init pkt
          pktLength = create_INIT_pkt(Pkt_Buff, InitStat);
  
          // send the data
          send_and_log(destAddr, Pkt_Buff, pktLength);
          
          // increment the cmd executed counter
          CmdExeCtr++;
          break;
        }
        // SetTime
        case LINK_SETTIME_CMD:
        {
          // Sets the RTC time
          /*  Command format:
           *   CCSDS Command Header (8 bytes)
           *   Time (4 byte)
           */
          
          debug_serial.print("Received SetTime Cmd with time: ");

          uint8_t pkt_pos = 7;
          uint32_t settime = 0;
          
          // extract the time to set from the packet
          pkt_pos = extractFromTlm(settime, data, 8);
          debug_serial.println(settime);
          
          rtc.adjust(DateTime(settime));
          
          // increment the cmd executed counter
          CmdExeCtr++;
          break;
        }
        // GetTime
        case LINK_REQTIME_CMD:
        {
          // Requests that the IMU status be sent to the specified address
          /*  Command format:
           *   CCSDS Command Header (8 bytes)
           *   Xbee address (1 byte) (or 0 if GND)
           */
          
          debug_serial.print("Received Req_Time Cmd to addr:");

          uint8_t destAddr = 0;
          uint8_t pkt_pos = 7;
          uint16_t pktLength = 0;
          
          // extract the desired xbee address from the packet
          pkt_pos = extractFromTlm(destAddr, data, 8);
          debug_serial.println(destAddr);

          // create a Init pkt
          pktLength = create_TIME_pkt(Pkt_Buff, rtc.now());
  
          // send the data
          send_and_log(destAddr, Pkt_Buff, pktLength);
          // increment the cmd executed counter
          CmdExeCtr++;
          break;
        }
        // Req_Filename
        case LINK_REQFILEINFO_CMD:
        {
          // Requests that the filename status be sent to the specified address
          /*  Command format:
           *   CCSDS Command Header (8 bytes)
           *   Xbee address (1 byte) (or 0 if GND)
           *   Idx (1 byte)
           */
          
          debug_serial.print("Received Req_Filename Cmd to addr:");

          uint8_t destAddr = 0;
          uint8_t pkt_pos = 7;
          uint8_t file_idx = 0;
          uint16_t pktLength = 0;
          File rootdir = SD.open("/");
          File entry;
      
          // extract the desired xbee address from the packet
          pkt_pos = extractFromTlm(destAddr, data, 8);
          debug_serial.print(destAddr);
          debug_serial.print(" for file at idx: ");

          pkt_pos = extractFromTlm(file_idx, data, pkt_pos);
          debug_serial.println(file_idx);
          
          rootdir = SD.open("/");
          rootdir.seek(0);

          for(uint8_t i = 0; i < file_idx; i++){

            // open next file
            entry =  rootdir.openNextFile();
            
          }

          // if file idx exists
          if (entry && !entry.isDirectory()) {

            // create a FileInfo pkt
            pktLength = create_FILEINFO_pkt(Pkt_Buff, entry);

            // send the data
            send_and_log(destAddr, Pkt_Buff, pktLength);
          
            // increment the cmd executed counter
            CmdExeCtr++;
          }
          else{
            CmdRejCtr++;
          }

          // close the files
          entry.close();
          rootdir.close();
          
          break;
        }
        // Req_FilePart
        case LINK_REQFILEPART_CMD:
        {
          // Requests that the filename status be sent to the specified address
          /*  Command format:
           *   CCSDS Command Header (8 bytes)
           *   Xbee address (1 byte) (or 0 if GND)
           *   Idx (1 byte)
           *   Start Pos (4byte)
           *   End Pos (4byte)
           */
          
          debug_serial.print("Received Req_FilePart Cmd to addr ");          
          
          uint8_t destAddr = 0;
          uint8_t pkt_pos = 7;
          uint8_t file_idx = 0;
          uint32_t start_pos = 0;
          uint32_t end_pos = 0;
          uint16_t pktLength = 0;
          File rootdir = SD.open("/");
          File entry;
      
          // extract the desired xbee address from the packet
          pkt_pos = extractFromTlm(destAddr, data, 8);
          debug_serial.print(destAddr);
          debug_serial.print(" for file at idx: ");

          pkt_pos = extractFromTlm(file_idx, data, pkt_pos);
          debug_serial.println(file_idx);

          debug_serial.print(" from pos: ");
          pkt_pos = extractFromTlm(start_pos, data, pkt_pos);
          debug_serial.print(" to: ");
          pkt_pos = extractFromTlm(end_pos, data, pkt_pos);

          // if the user requested more bytes than a packet can hold
          // then reject the command
          if(end_pos - start_pos > PKT_MAX_LEN - 12){
            CmdRejCtr++;
            break;
          }
          
          rootdir = SD.open("/");
          rootdir.seek(0);

          for(uint8_t i = 0; i < file_idx; i++){

            // open next file
            entry =  rootdir.openNextFile();
            
          }

          // if file idx exists
          if (entry && !entry.isDirectory()) {

            // create a FileInfo pkt
            pktLength = create_FILEPART_pkt(Pkt_Buff, entry, start_pos, end_pos);

            // send the data
            send_and_log(destAddr, Pkt_Buff, pktLength);

            // increment the cmd executed counter
            CmdExeCtr++;
          }
          else{
            CmdRejCtr++;
          }

          // close the files
          entry.close();
          rootdir.close();
          break;
        }
        // Reboot
        case LINK_REBOOT_CMD:
        {
          // Requests that Link reboot
  
          debug_serial.println("Received Reboot Cmd");
  
          // set the reboot timer
          wdt_enable(WDTO_1S);
  
          // increment the cmd executed counter
          CmdExeCtr++;
          break;    
        }
        // unrecognized fcn code
        default:
        {
          debug_serial.print("unrecognized fcn code ");
          debug_serial.println(FcnCode, HEX);
          
          // reject command
          CmdRejCtr++;
        }
      } // end switch(FcnCode)
    } // end if(validateChecksum(data))
    else{
      debug_serial.println("Checksum doesn't match!");
      CmdRejCtr++;
    } // end else
  } // end if(getPacketType(data) && _APID == LINK_CMD_APID){
  else{
    debug_serial.print("Unrecognized apid 0x");
    debug_serial.println(_APID, HEX);
  }
} // end command_response()

uint16_t create_HK_pkt(uint8_t HK_Pkt_Buff[]){
/*  create_HK_pkt()
 * 
 *  Creates an HK packet containing the values of all the interface counters. 
 *  Packet data is filled into the memory passed in as the argument. This function
 *  assumes that the buffer is large enough to hold this packet.
 *  
 */

  // initalize counter to record length of packet
  uint16_t payloadSize = 0;
  
  // add length of primary header
  payloadSize += sizeof(CCSDS_PriHdr_t);

  // Populate primary header fields:
  setAPID(HK_Pkt_Buff, LINK_HK_APID);
  setSecHdrFlg(HK_Pkt_Buff, 1);
  setPacketType(HK_Pkt_Buff, 0);
  setVer(HK_Pkt_Buff, 0);
  setSeqCtr(HK_Pkt_Buff, 0);
  setSeqFlg(HK_Pkt_Buff, 0);

  // add length of secondary header
  payloadSize += sizeof(CCSDS_TlmSecHdr_t);

  // get the current time from the RTC
  DateTime now = rtc.now();
  
  // Populate the secondary header fields:
  setTlmTimeSec(HK_Pkt_Buff, now.unixtime());
  setTlmTimeSubSec(HK_Pkt_Buff, 0);

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
 *  Packet data is filled into the memory passed in as the argument. This function
 *  assumes that the buffer is large enough to hold this packet.
 *  
 */
 
  // initalize counter to record length of packet
  uint16_t payloadSize = 0;

  // add length of primary header
  payloadSize += sizeof(CCSDS_PriHdr_t);

  // Populate primary header fields:
  setAPID(FLTR_TBL_Buff, LINK_FLTR_TBL_APID);
  setSecHdrFlg(FLTR_TBL_Buff, 1);
  setPacketType(FLTR_TBL_Buff, 0);
  setVer(FLTR_TBL_Buff, 0);
  setSeqCtr(FLTR_TBL_Buff, 0);
  setSeqFlg(FLTR_TBL_Buff, 0);

  // add length of secondary header
  payloadSize += sizeof(CCSDS_TlmSecHdr_t);

  // get the current time from the RTC
  DateTime now = rtc.now();
  
  // Populate the secondary header fields:
  setTlmTimeSec(FLTR_TBL_Buff, now.unixtime());
  setTlmTimeSubSec(FLTR_TBL_Buff, 0);

  // add elements of filter table to the packet
  for(int i = 0; i < FILT_TBL_NUM_EL; i++){
    payloadSize = addIntToTlm(filter_table[i], FLTR_TBL_Buff, payloadSize); // Add the value of the table to message
  }
 
  // fill the length field
  setPacketLength(FLTR_TBL_Buff, payloadSize);

  return payloadSize;
}

boolean checkApidFilterTable(uint16_t apid){
/* checkApidFilterTable()
 *  
 *  checks if the given apid exists in the filter table. Returns
 *  true if it does, false otherwise.
 *  
 */

  // loop through filter table and return true if value is found
  for(int i = 0; i < FILT_TBL_NUM_EL; i++){
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
 *  Also updates the xbee sent counter.
 */
 
  // send the data via xbee
  _sendData(dest_addr, data, data_len);

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
  DateTime now = SoftRTC.now();
  uint32_t nowMS = millis();
  
  // print a datestamp to the file
  char buf[50];
  sprintf(buf, "%02d/%02d/%02d %02d:%02d:%02d.%03d", now.day(), now.month(), now.year(), now.hour(), now.minute(), now.second(),(nowMS - start_millis)%1000);  // print milliseconds);
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

void log_imu(struct IMUData_s IMUData, File IMULogFile){
/*  log_imu()
 * 
 *  Writes the IMU data to a log file with a timestamp.
 *  
 */
  
  // print the time to the file
  print_time(IMULogFile);

  // print the sensor values
  IMULogFile.print(", ");
  IMULogFile.print(IMUData.system_cal);
  IMULogFile.print(", ");
  IMULogFile.print(IMUData.accel_cal);
  IMULogFile.print(", ");
  IMULogFile.print(IMUData.gyro_cal);
  IMULogFile.print(", ");
  IMULogFile.print(IMUData.mag_cal);
  IMULogFile.print(", ");
  IMULogFile.print(IMUData.accel_x);
  IMULogFile.print(", ");
  IMULogFile.print(IMUData.accel_y);
  IMULogFile.print(", ");
  IMULogFile.print(IMUData.accel_z);
  IMULogFile.print(", ");
  IMULogFile.print(IMUData.gyro_x);
  IMULogFile.print(", ");
  IMULogFile.print(IMUData.gyro_y);
  IMULogFile.print(", ");
  IMULogFile.print(IMUData.gyro_z);
  IMULogFile.print(", ");
  IMULogFile.print(IMUData.mag_x);
  IMULogFile.print(", ");
  IMULogFile.print(IMUData.mag_y);
  IMULogFile.print(", ");
  IMULogFile.println(IMUData.mag_z);

  IMULogFile.flush();
}
void log_env(struct ENVData_s ENVData, File ENVLogFile){
/*  log_env()
 * 
 *  Writes the ENV data to a log file with a timestamp.
 *  
 */
 
  // print the time to the file
  print_time(ENVLogFile);

  // print the sensor values
  ENVLogFile.print(", ");
  ENVLogFile.print(ENVData.bme_pres);
  ENVLogFile.print(", ");
  ENVLogFile.print(ENVData.bme_temp);
  ENVLogFile.print(", ");
  ENVLogFile.print(ENVData.bme_humid);
  ENVLogFile.print(", ");
  ENVLogFile.print(ENVData.ssc_pres);
  ENVLogFile.print(", ");
  ENVLogFile.print(ENVData.ssc_temp);
  ENVLogFile.print(", ");
  ENVLogFile.print(ENVData.bno_temp);
  ENVLogFile.print(", ");
  ENVLogFile.println(ENVData.mcp_temp);

  ENVLogFile.flush();
}

void log_pwr(struct PWRData_s PWRData, File PWRLogFile){
/*  log_pwr()
 * 
 *  Writes the PWR data to a log file with a timestamp.
 *  
 */
 
  // print the time to the file
  print_time(PWRLogFile);
  
  // print the sensor values
  PWRLogFile.print(", ");
  PWRLogFile.print(PWRData.batt_volt,4);
  PWRLogFile.print(", ");
  PWRLogFile.println(PWRData.i_consump,4);

  PWRLogFile.flush();
}

void read_env(struct ENVData_s *ENVData){
/*  read_env()
 * 
 *  Reads all of the environmental sensors and stores data in 
 *  a structure.
 *  
 */
 
  //BME280
  ENVData->bme_pres = bme.readPressure() / 100.0F; // hPa
  ENVData->bme_temp = bme.readTemperature(); // degC
  ENVData->bme_humid = bme.readHumidity(); // %
/*
 * This is causing LINK to not respond to commands... not sure why
  //  SSC
  ssc.update();
  ENVData->ssc_pres = ssc.pressure(); // PSI
  ENVData->ssc_temp = ssc.temperature(); // degC
*/
  // BNO
  ENVData->bno_temp = bno.getTemp();
  
  //MCP9808
  ENVData->mcp_temp = tempsensor.readTempC(); // degC
}

void read_pwr(struct PWRData_s *PWRData){
/*  read_pwr()
 * 
 *  Reads all of the power sensors and stores data in 
 *  a structure.
 *  
 */
  PWRData->batt_volt = ((float)ads.readADC_SingleEnded(2)) * 0.002 * 3.0606; // V
  PWRData->i_consump = (((float)ads.readADC_SingleEnded(3)) * 0.002 - 2.5) * 10;
}

void read_imu(struct IMUData_s *IMUData){
/*  read_imu()
 * 
 *  Reads all of the IMU sensors and stores data in 
 *  a structure.
 *  
 */
  uint8_t system_cal, gyro_cal, accel_cal, mag_cal = 0;
  bno.getCalibration(&system_cal, &gyro_cal, &accel_cal, &mag_cal);

  // get measurements
  imu::Vector<3> mag = bno.getVector(Adafruit_BNO055::VECTOR_MAGNETOMETER); // (values in uT, micro Teslas)
  imu::Vector<3> gyro = bno.getVector(Adafruit_BNO055::VECTOR_GYROSCOPE); // (values in rps, radians per second)
  imu::Vector<3> accel = bno.getVector(Adafruit_BNO055::VECTOR_ACCELEROMETER); // (values in m/s^2)

  // assign them into global variables
  IMUData->system_cal = system_cal;
  IMUData->accel_cal = accel_cal;
  IMUData->gyro_cal = gyro_cal;
  IMUData->mag_cal = mag_cal;
  IMUData->accel_x = accel.x();
  IMUData->accel_y = accel.y();
  IMUData->accel_z = accel.z();
  IMUData->gyro_x = gyro.x();
  IMUData->gyro_y = gyro.y();
  IMUData->gyro_z = gyro.z();
  IMUData->mag_x = mag.x();
  IMUData->mag_y = mag.y();
  IMUData->mag_z = mag.z();

}

uint16_t create_ENV_pkt(uint8_t HK_Pkt_Buff[], struct ENVData_s ENVData){
/*  create_ENV_pkt()
 * 
 *  Creates an ENV packet containing the values of all environmental sensors. 
 *  Packet data is filled into the memory passed in as the argument. This function
 *  assumes that the buffer is large enough to hold this packet.
 *  
 */

  // get the current time from the RTC
  DateTime now = rtc.now();
  
  // initalize counter to record length of packet
  uint16_t payloadSize = 0;

  // add length of primary header
  payloadSize += sizeof(CCSDS_PriHdr_t);

  // Populate primary header fields:
  setAPID(HK_Pkt_Buff, LINK_ENV_APID);
  setSecHdrFlg(HK_Pkt_Buff, 1);
  setPacketType(HK_Pkt_Buff, 0);
  setVer(HK_Pkt_Buff, 0);
  setSeqCtr(HK_Pkt_Buff, 0);
  setSeqFlg(HK_Pkt_Buff, 0);

  // add length of secondary header
  payloadSize += sizeof(CCSDS_TlmSecHdr_t);

  // Populate the secondary header fields:
  setTlmTimeSec(HK_Pkt_Buff, now.unixtime());
  setTlmTimeSubSec(HK_Pkt_Buff, 0);

  // Add counter values to the pkt
  payloadSize = addFloatToTlm(ENVData.bme_pres, HK_Pkt_Buff, payloadSize); // Add bme pressure to message [Float]
  payloadSize = addFloatToTlm(ENVData.bme_temp, HK_Pkt_Buff, payloadSize); // Add bme temperature to message [Float]
  payloadSize = addFloatToTlm(ENVData.bme_humid, HK_Pkt_Buff, payloadSize); // Add bme humidity to message [Float]
  payloadSize = addFloatToTlm(ENVData.ssc_pres, HK_Pkt_Buff, payloadSize); // Add ssc pressure to message [Float]
  payloadSize = addFloatToTlm(ENVData.ssc_temp, HK_Pkt_Buff, payloadSize); // Add ssc temperature to messsage [Float]
  payloadSize = addFloatToTlm(ENVData.bno_temp, HK_Pkt_Buff, payloadSize); // Add bno temperature to message [Float]
  payloadSize = addFloatToTlm(ENVData.mcp_temp, HK_Pkt_Buff, payloadSize); // Add mcp temperature to message [Float]
  
  // fill the length field
  setPacketLength(HK_Pkt_Buff, payloadSize);

  return payloadSize;

}

uint16_t create_PWR_pkt(uint8_t HK_Pkt_Buff[], struct PWRData_s PWRData){
/*  create_PWR_pkt()
 * 
 *  Creates an PWR packet containing the values of all the power/battery sensors. 
 *  Packet data is filled into the memory passed in as the argument. This function
 *  assumes that the buffer is large enough to hold this packet.
 *  
 */
  // get the current time from the RTC
  DateTime now = rtc.now();
  
  // initalize counter to record length of packet
  uint16_t payloadSize = 0;

  // add length of primary header
  payloadSize += sizeof(CCSDS_PriHdr_t);

  // Populate primary header fields:
  setAPID(HK_Pkt_Buff, LINK_PWR_APID);
  setSecHdrFlg(HK_Pkt_Buff, 1);
  setPacketType(HK_Pkt_Buff, 0);
  setVer(HK_Pkt_Buff, 0);
  setSeqCtr(HK_Pkt_Buff, 0);
  setSeqFlg(HK_Pkt_Buff, 0);

  // add length of secondary header
  payloadSize += sizeof(CCSDS_TlmSecHdr_t);

  // Populate the secondary header fields:
  setTlmTimeSec(HK_Pkt_Buff, now.unixtime());
  setTlmTimeSubSec(HK_Pkt_Buff, 0);

  // Add counter values to the pkt
  payloadSize = addFloatToTlm(PWRData.batt_volt, HK_Pkt_Buff, payloadSize); // Add battery voltage to message [Float]
  payloadSize = addFloatToTlm(PWRData.i_consump, HK_Pkt_Buff, payloadSize); // Add current consumption to message [Float]

  // fill the length field
  setPacketLength(HK_Pkt_Buff, payloadSize);

  return payloadSize;

}

uint16_t create_IMU_pkt(uint8_t HK_Pkt_Buff[], struct IMUData_s IMUData){
/*  create_IMU_pkt()
 * 
 *  Creates an IMU packet containing the values of all the IMU sensors. 
 *  Packet data is filled into the memory passed in as the argument. This function
 *  assumes that the buffer is large enough to hold this packet.
 *  
 */
  // get the current time from the RTC
  DateTime now = rtc.now();
  
  // initalize counter to record length of packet
  uint16_t payloadSize = 0;

  // add length of primary header
  payloadSize += sizeof(CCSDS_PriHdr_t);

  // Populate primary header fields:
  setAPID(HK_Pkt_Buff, LINK_IMU_APID);
  setSecHdrFlg(HK_Pkt_Buff, 1);
  setPacketType(HK_Pkt_Buff, 0);
  setVer(HK_Pkt_Buff, 0);
  setSeqCtr(HK_Pkt_Buff, 0);
  setSeqFlg(HK_Pkt_Buff, 0);

  // add length of secondary header
  payloadSize += sizeof(CCSDS_TlmSecHdr_t);

  // Populate the secondary header fields:
  setTlmTimeSec(HK_Pkt_Buff, now.unixtime());
  setTlmTimeSubSec(HK_Pkt_Buff, 0);

  // Add counter values to the pkt
  payloadSize = addIntToTlm(IMUData.system_cal, HK_Pkt_Buff, payloadSize); // Add system cal status to message [uint8_t]
  payloadSize = addIntToTlm(IMUData.accel_cal, HK_Pkt_Buff, payloadSize); // Add accelerometer cal status to message [uint8_t]
  payloadSize = addIntToTlm(IMUData.gyro_cal, HK_Pkt_Buff, payloadSize); // Add gyro cal status to message [uint8_t]
  payloadSize = addIntToTlm(IMUData.mag_cal, HK_Pkt_Buff, payloadSize); // Add mnagnetomter cal status to message [uint8_t]
  payloadSize = addFloatToTlm(IMUData.accel_x, HK_Pkt_Buff, payloadSize); // Add battery accelerometer x to message [Float]
  payloadSize = addFloatToTlm(IMUData.accel_y, HK_Pkt_Buff, payloadSize); // Add battery accelerometer y to message [Float]
  payloadSize = addFloatToTlm(IMUData.accel_z, HK_Pkt_Buff, payloadSize); // Add battery accelerometer z to message [Float]
  payloadSize = addFloatToTlm(IMUData.gyro_x, HK_Pkt_Buff, payloadSize); // Add battery accelerometer x to message [Float]
  payloadSize = addFloatToTlm(IMUData.gyro_y, HK_Pkt_Buff, payloadSize); // Add battery accelerometer y to message [Float]
  payloadSize = addFloatToTlm(IMUData.gyro_z, HK_Pkt_Buff, payloadSize); // Add battery accelerometer z to message [Float]
  payloadSize = addFloatToTlm(IMUData.mag_x, HK_Pkt_Buff, payloadSize); // Add battery accelerometer x to message [Float]
  payloadSize = addFloatToTlm(IMUData.mag_y, HK_Pkt_Buff, payloadSize); // Add battery accelerometer y to message [Float]
  payloadSize = addFloatToTlm(IMUData.mag_z, HK_Pkt_Buff, payloadSize); // Add battery accelerometer z to message [Float]

  // fill the length field
  setPacketLength(HK_Pkt_Buff, payloadSize);
  
  return payloadSize;

}

uint16_t create_INIT_pkt(uint8_t HK_Pkt_Buff[], struct InitStat_s InitStat){
/*  create_IMU_pkt()
 * 
 *  Creates an IMU packet containing the values of all the IMU sensors. 
 *  Packet data is filled into the memory passed in as the argument. This function
 *  assumes that the buffer is large enough to hold this packet.
 *  
 */
  // get the current time from the RTC
  DateTime now = rtc.now();
  
  // initalize counter to record length of packet
  uint16_t payloadSize = 0;

  // add length of primary header
  payloadSize += sizeof(CCSDS_PriHdr_t);

  // Populate primary header fields:
  setAPID(HK_Pkt_Buff, LINK_INIT_APID);
  setSecHdrFlg(HK_Pkt_Buff, 1);
  setPacketType(HK_Pkt_Buff, 0);
  setVer(HK_Pkt_Buff, 0);
  setSeqCtr(HK_Pkt_Buff, 0);
  setSeqFlg(HK_Pkt_Buff, 0);

  // add length of secondary header
  payloadSize += sizeof(CCSDS_TlmSecHdr_t);

  // Populate the secondary header fields:
  setTlmTimeSec(HK_Pkt_Buff, now.unixtime());
  setTlmTimeSubSec(HK_Pkt_Buff, 0);

  // Add counter values to the pkt
  payloadSize = addIntToTlm(InitStat.xbeeStatus, HK_Pkt_Buff, payloadSize); // Add system cal status to message [uint8_t]
  payloadSize = addIntToTlm(InitStat.rtc_running, HK_Pkt_Buff, payloadSize); // Add accelerometer cal status to message [uint8_t]
  payloadSize = addIntToTlm(InitStat.rtc_start, HK_Pkt_Buff, payloadSize); // Add gyro cal status to message [uint8_t]
  payloadSize = addIntToTlm(InitStat.BNO_init, HK_Pkt_Buff, payloadSize); // Add mnagnetomter cal status to message [uint8_t]
  payloadSize = addIntToTlm(InitStat.MCP_init, HK_Pkt_Buff, payloadSize); // Add mnagnetomter cal status to message [uint8_t]
  payloadSize = addIntToTlm(InitStat.BME_init, HK_Pkt_Buff, payloadSize); // Add mnagnetomter cal status to message [uint8_t]
  payloadSize = addIntToTlm(InitStat.SSC_init, HK_Pkt_Buff, payloadSize); // Add mnagnetomter cal status to message [uint8_t]
  payloadSize = addIntToTlm(InitStat.SD_detected, HK_Pkt_Buff, payloadSize); // Add mnagnetomter cal status to message [uint8_t]

  // fill the length field
  setPacketLength(HK_Pkt_Buff, payloadSize);
  
  return payloadSize;

}


uint16_t create_TIME_pkt(uint8_t Pkt_Buff[], DateTime t){
/*  create_IMU_pkt()
 * 
 *  Creates an IMU packet containing the values of all the IMU sensors. 
 *  Packet data is filled into the memory passed in as the argument. This function
 *  assumes that the buffer is large enough to hold this packet.
 *  
 */
  // get the current time from the RTC
  DateTime now = rtc.now();
  
  // initalize counter to record length of packet
  uint16_t payloadSize = 0;

  // add length of primary header
  payloadSize += sizeof(CCSDS_PriHdr_t);

  // Populate primary header fields:
  setAPID(Pkt_Buff, LINK_TIME_MSG_APID);
  setSecHdrFlg(Pkt_Buff, 1);
  setPacketType(Pkt_Buff, 0);
  setVer(Pkt_Buff, 0);
  setSeqCtr(Pkt_Buff, 0);
  setSeqFlg(Pkt_Buff, 0);

  // add length of secondary header
  payloadSize += sizeof(CCSDS_TlmSecHdr_t);

  // Populate the secondary header fields:
  setTlmTimeSec(Pkt_Buff, now.unixtime());
  setTlmTimeSubSec(Pkt_Buff, 0);

  // Add counter values to the pkt
  payloadSize = addIntToTlm(t.unixtime(), Pkt_Buff, payloadSize); // Add system cal status to message [uint8_t]

  // fill the length field
  setPacketLength(Pkt_Buff, payloadSize);
  
  return payloadSize;

}

uint16_t create_FILEINFO_pkt(uint8_t Pkt_Buff[], File entry){
  /*  create_IMU_pkt()
 * 
 *  Creates an IMU packet containing the values of all the IMU sensors. 
 *  Packet data is filled into the memory passed in as the argument. This function
 *  assumes that the buffer is large enough to hold this packet.
 *  
 */
  // get the current time from the RTC
  DateTime now = rtc.now();
  
  // initalize counter to record length of packet
  uint16_t payloadSize = 0;

  // add length of primary header
  payloadSize += sizeof(CCSDS_PriHdr_t);

  // Populate primary header fields:
  setAPID(Pkt_Buff, LINK_FILEINFO_MSG_APID);
  setSecHdrFlg(Pkt_Buff, 1);
  setPacketType(Pkt_Buff, 0);
  setVer(Pkt_Buff, 0);
  setSeqCtr(Pkt_Buff, 0);
  setSeqFlg(Pkt_Buff, 0);

  // add length of secondary header
  payloadSize += sizeof(CCSDS_TlmSecHdr_t);

  // Populate the secondary header fields:
  setTlmTimeSec(Pkt_Buff, now.unixtime());
  setTlmTimeSubSec(Pkt_Buff, 0);

  // Add counter values to the pkt
  char filename[13]; // max filename is 8 characters + 1 period + 3 letter extention + 1 null term
  sprintf(filename,"%12s",entry.name());

  for(int i = 0; i < 13; i++){
    debug_serial.print(filename[i]);
  }

  payloadSize = addStrToTlm(filename, Pkt_Buff, payloadSize);
  payloadSize = addIntToTlm(entry.size(), Pkt_Buff, payloadSize);

  // fill the length field
  setPacketLength(Pkt_Buff, payloadSize);
  
  return payloadSize;
}


uint16_t create_FILEPART_pkt(uint8_t Pkt_Buff[], File entry, uint32_t start_pos, uint32_t end_pos){
  /*  create_IMU_pkt()
 * 
 *  Creates an IMU packet containing the values of all the IMU sensors. 
 *  Packet data is filled into the memory passed in as the argument. This function
 *  assumes that the buffer is large enough to hold this packet.
 *  
 */
  // get the current time from the RTC
  DateTime now = rtc.now();
  
  // initalize counter to record length of packet
  uint16_t payloadSize = 0;

  // add length of primary header
  payloadSize += sizeof(CCSDS_PriHdr_t);

  // Populate primary header fields:
  setAPID(Pkt_Buff, LINK_FILEPART_MSG_APID);
  setSecHdrFlg(Pkt_Buff, 1);
  setPacketType(Pkt_Buff, 0);
  setVer(Pkt_Buff, 0);
  setSeqCtr(Pkt_Buff, 0);
  setSeqFlg(Pkt_Buff, 0);

  // add length of secondary header
  payloadSize += sizeof(CCSDS_TlmSecHdr_t);

  // Populate the secondary header fields:
  setTlmTimeSec(Pkt_Buff, now.unixtime());
  setTlmTimeSubSec(Pkt_Buff, 0);

  // Add counter values to the pkt
  entry.seek(start_pos);

  // not sure why this doesn't work
  // error: invalid conversion from 'uint8_t {aka unsigned char}' to 'void*' [-fpermissive]
  //entry.read(Pkt_Buff[payloadSize], end_pos-start_pos);
  //payloadSize += end_pos-start_pos;

  for(int i = 0; i < end_pos-start_pos; i++){
    payloadSize = addIntToTlm(entry.read(), Pkt_Buff, payloadSize);
  }
  
  // fill the length field
  setPacketLength(Pkt_Buff, payloadSize);
  
  return payloadSize;

  
}


void send_and_log(uint8_t dest_addr, uint8_t data[], uint8_t data_len){
/*  send_and_log()
 * 
 *  If the destination address is 0, calls radio_send_and_log. Otherwise
 *  calls xbee_send_and_log
 *  
 */
  if(dest_addr == 0){
    // send packet via the radio and log it
    radio_send_and_log(data, data_len);
  }
  else{
    // send the HK packet via xbee and log it
    xbee_send_and_log(dest_addr, data, data_len);
  }
}

