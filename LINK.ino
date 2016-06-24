
// include libraries
#include <XBee.h>
#include <Wire.h>
#include "CCSDS.h"
#include "CCSDS_xbee.h"

// define compile-time constants
#define PKT_MAX_LEN 200
#define NUM_TRANS_APIDS 5
#define TLMMask_LINKSendCtr   0x02000000  // 2^26

// alias the serial objects to make it explicit where the output is directed
#define debug_serial Serial
#define xbee_serial Serial3
#define radio_serial Serial2

// define data buffers
uint8_t Buff_9002XbeeBuf[PKT_MAX_LEN];
uint8_t Buff_Xbee2900[PKT_MAX_LEN];

// define xbee communication parameters
uint16_t XBee_MY_Addr = 0x0002;  // XBee address of this transmitter
uint16_t XBee_PAN_ID = 0x0B0B; // PAN ID of xbee (must match all xbees)

// List of AP_ID for forwarding data to ground
uint16_t Transmitted_AP_IDs[NUM_TRANS_APIDS] = {1, 2, 3, 4, 5};
uint8_t Ground_AP_ID = 0x03;
const uint8_t SyncByte[2] = {0x18, 0x01};
const uint8_t RespondSyncByte[2] = {0x18, 0x02};

// define other constants
uint8_t err_cnt = 0;
int APID = 0;
int PktLen = 0;
int BytesinBuffer = 0;
int BytesinBuffer_prev = 0;
int BytesRead900 = 0;
int XbeeBytesRead = 0;
uint32_t _SendCtr = 0;

uint32_t tlmctrl = 0xFFFFFFFF & TLMMask_LINKSendCtr;

// function prototypes
void radio2xbee();
void printPktInfo(CCSDS_PriHdr_t PriHeader, CCSDS_CmdSecHdr_t CmdHeader, CCSDS_TlmSecHdr_t TlmHeader);
void message_response();
void xbee2radio();

void setup() {
// begin serial ports, initalize xbee
  
  // debug
  debug_serial.begin(250000);          
  // xbee
  xbee_serial.begin(9600); 
  // radio
  radio_serial.begin(9600); 
    
  // initalize xbee
  int XbeeStatus = InitXBee(XBee_MY_Addr, XBee_PAN_ID, Serial3);
  if (!XbeeStatus) {
    debug_serial.println(F("Xbee initialized!"));
  }
  else {
    debug_serial.print(F("Xbee failed to initialize with Error code: "));
    debug_serial.println(XbeeStatus);
  }

  debug_serial.println("Link initalized!");
}


void printPktInfo(CCSDS_PriHdr_t PriHeader, CCSDS_CmdSecHdr_t CmdHeader, CCSDS_TlmSecHdr_t TlmHeader){
// print information about a CCSDS packet
    
    debug_serial.print("APID: ");
    debug_serial.print(CCSDS_RD_APID(PriHeader));
    debug_serial.print(", SecHdr: ");
    debug_serial.print(CCSDS_RD_SHDR(PriHeader));
    debug_serial.print(", Type: ");
    debug_serial.print(CCSDS_RD_TYPE(PriHeader));
    debug_serial.print(", Ver: ");
    debug_serial.print(CCSDS_RD_VERS(PriHeader));
    debug_serial.print(", SeqCnt: ");
    debug_serial.print(CCSDS_RD_SEQ(PriHeader));
    debug_serial.print(", SegFlag: ");
    debug_serial.print(CCSDS_RD_SEQFLG(PriHeader));
    debug_serial.print(", Len: ");
    debug_serial.println(CCSDS_RD_LEN(PriHeader));

    if(CCSDS_RD_TYPE(PriHeader)){
      debug_serial.print("FcnCode: ");
      debug_serial.print(CCSDS_RD_FC(CmdHeader));
      debug_serial.print(", CkSum: ");
      debug_serial.println(CCSDS_RD_CHECKSUM(CmdHeader));
    }
    else{
      debug_serial.print("Sec: ");
      debug_serial.print(CCSDS_RD_SEC_HDR_SEC(TlmHeader));
      debug_serial.print(", Subsec: ");
      debug_serial.println(CCSDS_RD_SEC_HDR_SUBSEC(TlmHeader));
    }
    
    
}

void message_response(){
// sends a response packet containing the sentcounter through 
// the 900 radio

  uint8_t _packet_data[PKT_MAX_LEN];
  uint8_t payload_size = 0;
  
  // declare the header structures
  CCSDS_PriHdr_t _PriHeader = *(CCSDS_PriHdr_t*) _packet_data;
  payload_size += sizeof(_PriHeader);

  CCSDS_TlmSecHdr_t _TlmSecHeader = *(CCSDS_TlmSecHdr_t*) (_packet_data + sizeof(_PriHeader));       
  payload_size += sizeof(_TlmSecHeader);

  // fill primary header fields
  CCSDS_WR_APID(_PriHeader,Ground_AP_ID);
  CCSDS_WR_SHDR(_PriHeader,1);
  CCSDS_WR_TYPE(_PriHeader,0);
  CCSDS_WR_VERS(_PriHeader,0);
  CCSDS_WR_SEQ(_PriHeader,_SendCtr);
  CCSDS_WR_SEQFLG(_PriHeader,0x03);

  // fill secondary header fields
  CCSDS_WR_SEC_HDR_SEC(_TlmSecHeader,millis()/1000L);
  CCSDS_WR_SEC_HDR_SUBSEC(_TlmSecHeader,millis() % 1000L);
  
  // copy the packet data
  payload_size = addIntToTlm(_SendCtr,_packet_data,payload_size);
 
  // fill the packet length field
  CCSDS_WR_LEN(_PriHeader,payload_size);
  
  // print debug
  debug_serial.print("Sending  ");
  debug_serial.print(payload_size);
  debug_serial.println(" bytes: ");

  // send message
  for(int ii=0; ii < payload_size; ii++){
    radio_serial.write( _packet_data[ii]);
    
    // print packet to debug
    debug_serial.print( _packet_data[ii],HEX);
    debug_serial.print( ", ");
  }
  debug_serial.println();

  _SendCtr++;
}

void xbee2radio(){
  // read message from xbee,
  // bytesRead is positive if there was data read
  XbeeBytesRead = readMsg(Buff_Xbee2900,1);
  
  //debug_serial.print("Xbee read status: ");
  //debug_serial.println(XbeeBytesRead);
  // If data recieved, proccess and send 
  if (XbeeBytesRead > 0) {
    debug_serial.println();

    CCSDS_TlmSecHdr_t TlmHeader;
    CCSDS_CmdSecHdr_t CmdHeader;
    CCSDS_PriHdr_t PriHeader;
    
    // Cast inital bytes of packet into header structure
    PriHeader = *(CCSDS_PriHdr_t*) (Buff_Xbee2900);
    CmdHeader = *(CCSDS_CmdSecHdr_t*) (Buff_Xbee2900+sizeof(CCSDS_PriHdr_t));
    TlmHeader = *(CCSDS_TlmSecHdr_t*) (Buff_Xbee2900+sizeof(CCSDS_PriHdr_t));
    
    // print a debug message with the packet info
    debug_serial.println("Xbee -> 900: ");
    printPktInfo(PriHeader, CmdHeader, TlmHeader);
      
    // Extract address 
    int AP_ID = CCSDS_RD_APID(PriHeader);

    // if message is addressed to Link, respond
    if(AP_ID == XBee_MY_Addr){

      // display debugging info
      debug_serial.println("debug_serial -> Respond: ");
      printPktInfo(PriHeader, CmdHeader, TlmHeader);
      
      message_response();
    }
    
    // Check against desired addresses and send if matches
    bool AP_ID_Match = false;
    for(int i = 0; i < NUM_TRANS_APIDS; i++) {
      if(AP_ID == i) {
        AP_ID_Match = true;
      }
    }
    if (AP_ID_Match == true){

      // print the bytes being sent to the debug
      debug_serial.print("Sending: ");
      for (int i = 0; i < XbeeBytesRead; i++){
       debug_serial.print(Buff_Xbee2900[i],HEX);
       debug_serial.print(", ");
       
       // NOTE: This must be write instead of print, otherwise it'll convert
       //   it to text characters
       radio_serial.write(Buff_Xbee2900[i]);
       }
       
    debug_serial.println();
    }
       
  } 
  else if(XbeeBytesRead > -4) {
    debug_serial.print("Failed to read pkt with error code ");
    debug_serial.println(XbeeBytesRead);
    if(err_cnt > 3){
      xbee_serial.flush();
      delay(3);
      err_cnt = 0;
      debug_serial.println("Flushing buffer");
    }
    err_cnt++;
  }
}

bool checkpacket(uint8_t _byte_buffer[]){
// return true if the byte array appears to be a valid packet, otherwise false
// checkpacket() does not check the length of _byte_buffer before casting it... only call if _byte_buffer is longer than 8 elements
// packets are identified by having a recognized APID, having a secondary header flag set to true, and a version flag set to 0

  uint8_t _APID;
  uint8_t _SHDR;
  uint8_t _VER;
  
  // assume that this is the beginning of a packet, extract the APID and SHDR flag
  _APID = CCSDS_RD_APID(*(CCSDS_PriHdr_t*) _byte_buffer);
  _SHDR = CCSDS_RD_SHDR(*(CCSDS_PriHdr_t*) _byte_buffer);
  _VER = CCSDS_RD_VERS(*(CCSDS_PriHdr_t*) _byte_buffer);

  // print the values to the serial
  debug_serial.print("APID :");
  debug_serial.print(_APID);
  debug_serial.print(" SHDR :");
  debug_serial.print(_SHDR);
  debug_serial.print(" VER :");
  debug_serial.println(_VER);
  
  // check if the APID matches 
  bool AP_ID_Match = false;
  for(int i = 0; i < NUM_TRANS_APIDS; i++) {
    if(_APID == Transmitted_AP_IDs[i]) {
      AP_ID_Match = true;
    }
  }

  // check if all conditions are met
  if(AP_ID_Match && _SHDR && !_VER) {
    debug_serial.println("PACKET!");
    return true;
  }
  else{
    return false;
  }
}

void radio2xbee(){
  /////// 900s to xbee
  // pseudocode:
  // append bytes read from radio into byte buffer
  // update counter indicating total length of buffer
  // loop through buffer looking for the beginning of packets
  // if there are enough bytes in the buffer to contain a full header, parse it to determine packet length
  // if there are enough bytes in the buffer to contain the full packet, send it out on the xbee
  // remove the sent bytes from the buffer by copying the remaining bytes back to the beginning
  // subtract the number of bytes sent from the counter so that it reflects the number of bytes remaining
  BytesinBuffer_prev = BytesinBuffer;
  
  // Read from 900s append to buffer     
  BytesRead900 = radio_serial.readBytes(Buff_9002XbeeBuf+BytesinBuffer, radio_serial.available());
  
  // updating buffer length counter
  BytesinBuffer += BytesRead900;

  // if bytes were read this cycle, print them to debug
  if(BytesRead900 > 0){
      debug_serial.print("Read :");
      debug_serial.println(BytesRead900);

      for(int i=0; i<BytesinBuffer; i++){ 
        debug_serial.print(Buff_9002XbeeBuf[i],HEX);
        debug_serial.print(",");
      }
  }
  
  // Looking for sync bytes 
  for(int i=0; i<BytesinBuffer-7; i++){
    
    // see if the packet looks like a valid packet
    if(checkpacket(Buff_9002XbeeBuf+i)){
      debug_serial.print("i = ");
      debug_serial.println(i);
      CCSDS_TlmSecHdr_t TlmHeader;
      CCSDS_CmdSecHdr_t CmdHeader;
      CCSDS_PriHdr_t PriHeader;

      // Cast inital bytes of packet into header structure
      PriHeader = *(CCSDS_PriHdr_t*) (Buff_9002XbeeBuf+i);
      CmdHeader = *(CCSDS_CmdSecHdr_t*) (Buff_9002XbeeBuf+i+sizeof(CCSDS_PriHdr_t));
      TlmHeader = *(CCSDS_TlmSecHdr_t*) (Buff_9002XbeeBuf+i+sizeof(CCSDS_PriHdr_t));

      // display debugging info
      debug_serial.println("900 -> Xbee: ");
      printPktInfo(PriHeader, CmdHeader, TlmHeader);
          
      // Get the total length of packet
      int PacketLength = CCSDS_RD_LEN(PriHeader);
      // Extract address 
      int APID = CCSDS_RD_APID(PriHeader);
      debug_serial.print("APID found = ");
      debug_serial.println(APID);
      // If you have a whole packet send it
      if(BytesinBuffer >= PacketLength+i){

        // if message is addressed to Link, respond
        if(APID == XBee_MY_Addr){

          // display debugging info
          debug_serial.println("radio -> Respond: ");
  
          message_response();
        }
        // otherwise forward it
        else{
          debug_serial.print("Sending to: ");
          debug_serial.print(APID);
          debug_serial.print(" ");
          debug_serial.print(PacketLength);
          debug_serial.println(" bytes");
  
          // send the packet over the xbee
          sendData(APID, Buff_9002XbeeBuf+i, PacketLength);
        }

          debug_serial.print("Removing ");
          debug_serial.print(PacketLength);
          debug_serial.println(" bytes from buffer.");
        
        // Shift unsent data in the buffer
        memcpy(Buff_9002XbeeBuf, Buff_9002XbeeBuf+i+PacketLength, BytesinBuffer-PacketLength-i);
        
        // update counter
        BytesinBuffer = BytesinBuffer-PacketLength-i;
        debug_serial.print(", BytesinBuf: ");
        debug_serial.println(BytesinBuffer);
      }
      break;
    }   
  } 
  // output the number of bytes in the buffer to the debug
  if(BytesinBuffer != BytesinBuffer_prev){
    debug_serial.print(", BytesinBuf: ");
    debug_serial.println(BytesinBuffer);
  }

}

void loop() {

  // repeat packets from xbee on 900 radio
  xbee2radio();

  // repeat packets from 900 on xbee
  radio2xbee();

  // wait a bit since the incoming data is low rate
  delay(10);

}
