/* Rewrite of the 900Relay code to take advantage of new CCSDS_XBee Library. */

// Includes:
#include <XBee.h>
#include <Wire.h>
#include "CCSDS_Xbee/CCSDS.h"
#include "CCSDS_Xbee/ccsds_xbee.h"
#include "CCSDS_Xbee/ccsds_util.h"

// Compile time constants:
#define PKT_MAX_LEN 200
#define NUM_TRANS_APIDS 5
#define TLMMask_LINKSendCtr   0x02000000  // 2^26

// Serial object aliases:
#define debug_serial Serial
#define radio_serial Serial2
#define xbee_serial Serial3

// Data buffers:
uint8_t Buff_900toXbee[PKT_MAX_LEN];
uint8_t Buff_Xbeeto900[PKT_MAX_LEN];

// Xbee communication parameters:
uint16_t XBee_MY_Addr = 0x0002; // XBee address for this payload
uint16_t XBee_PAN_ID = 0x0B0B; // XBee PAN address (must be the same for all xbees)

// Comms stuff:
uint16_t Transmitted_AP_IDs[NUM_TRANS_APIDS] = {1, 2, 3, 4, 5}; // List of available AP_IDs
uint8_t Ground_AP_ID = 0x01; // AP ID for ground station
const uint8_t SyncByte[2] = {0x18, 0x01};
const uint8_t RespondSyncByte[2] = {0x18, 0x02};

// Other constants
uint8_t err_cnt = 0;
int APID = 0;
int PktLen = 0;
int BytesinBuffer = 0;
int XbeeBytesRead = 0;
uint32_t SendCtr = 0;

uint32_t tlmctrl = 0xFFFFFFFF & TLMMask_LINKSendCtr;

// Function prototypes
void radio2xbee();
void xbee2radio();
void messageResponse();
bool checkPacket(uint8_t byteBuffer[]);

void setup() {
	// Init serial ports:
	debug_serial.begin(9600);
	xbee_serial.begin(9600);
	radio_serial.begin(9600);

	// Init Xbee:
	int xbeeStatus = InitXBee(XBee_MY_Addr, XBee_PAN_ID, xbee_serial);
	if(!xbeeStatus) {
		debug_serial.println(F("XBee Initialized!"));
	} else {
		debug_serial.print(F("XBee Failed to Initialize with Error Code: "));
		debug_serial.println(xbeeStatus);
	}

	debug_serial.println(F("Data Parrot Initialized!"));
}

void loop() {
	xbee2radio();
	radio2xbee();
	delay(10);
}

void radio2xbee() {
	/////// 900s to xbee
  	// pseudocode:
  	// append bytes read from radio into byte buffer
  	// update counter indicating total length of buffer
  	// loop through buffer looking for the beginning of packets
  	// if there are enough bytes in the buffer to contain a full header, parse it to determine packet length
  	// if there are enough bytes in the buffer to contain the full packet, send it out on the xbee
  	// remove the sent bytes from the buffer by copying the remaining bytes back to the beginning
  	// subtract the number of bytes sent from the counter so that it reflects the number of bytes remaining

	int BytesinBuffer_prev = BytesinBuffer;
	int BytesRead = 0;

	// Read from 900s and append to buffer:
	BytesRead = radio_serial.readBytes(Buff_900toXbee + BytesinBuffer, radio_serial.available());

	// Update length counter:
	BytesinBuffer += BytesRead;

	// If bytes were read, print to debug:
	if(BytesRead > 0) {
		debug_serial.print("Read: ");
		debug_serial.print(BytesRead);
		debug_serial.println(" Bytes from 900...");

		for(int i = 0; i < BytesinBuffer; i++) {
			debug_serial.print(Buff_900toXbee[i],HEX);
			debug_serial.print(", ");
		}
		debug_serial.println();
	}

	// Search for packet sync bytes:
	for(int i = 0; i < (BytesinBuffer - 7); i++) {
		if(checkPacket(Buff_900toXbee + i)) { // If a packet is found in the data stream...
			debug_serial.print("Packet Found. i = "); // ...debug print where...
			debug_serial.println(i);

			debug_serial.println("900 -> XBee: "); // ...debug print the packet...
			CCSDS_PriHdr_t header = getPrimaryHeader(Buff_900toXbee + i);
			printPktInfo(header);

			// ...Get the length of the packet and it's destination address...
			int pktLength = getPacketLength(Buff_900toXbee + i);
			int destAPID = getAPID(Buff_900toXbee + i);

			debug_serial.print("APID Found: ");
			debug_serial.println(destAPID); // ...Debug print the APID...

			// ...and, if there's a full packet present in the buffer, send it.
			if(BytesinBuffer >= pktLength + i) {
				if(destAPID == XBee_MY_Addr) { // If meant for Link, respond.
					debug_serial.println("Radio -> Respond: ");
					messageResponse();
				} else { // If meant for other payload, forward it.
					debug_serial.print("Sending Message to: "); // Debug print the destination and size
					debug_serial.print(destAPID);
					debug_serial.print(" ");
					debug_serial.print(pktLength);
					debug_serial.println(" Bytes.");

					// Now forward the packet:
					_sendData(destAPID, Buff_900toXbee+i, pktLength);
				}

				// Now clear the buffer:
				debug_serial.print("Removing ");
				debug_serial.print(pktLength);
				debug_serial.println(" Bytes from Buffer.");

				// Shift out the bytes:
				memcpy(Buff_900toXbee, Buff_900toXbee + i + pktLength, BytesinBuffer - pktLength - i);

				// Update bytes in buffer counuter
				BytesinBuffer = BytesinBuffer - pktLength - i;
				debug_serial.print("Bytes in buffer: ");
				debug_serial.println(BytesinBuffer);
			}
			break;
		}
	}
}

void xbee2radio() {
	uint8_t ReadData[100];
	uint8_t FunctionCode;

	// Read message from xbee
	int BytesRead = _readXbeeMsg(ReadData, 1);

	if(BytesRead > 0) { // If a valid message tyoe
		debug_serial.println();

		debug_serial.println("Xbee -> 900: ");
		CCSDS_PriHdr_t header = getPrimaryHeader(ReadData);
		printPktInfo(header);

		debug_serial.print("Sending: ");
		for(int i = 0; i < BytesRead; i++) {
			debug_serial.print(ReadData[i], HEX);
			debug_serial.print(", ");

			radio_serial.write(ReadData[i]);
		}
		debug_serial.println();
	}
}

void messageResponse() {
	uint8_t responseData[PKT_MAX_LEN]; // Prepare data buffer
	uint8_t payloadSize = 0;

	CCSDS_PriHdr_t PrimaryHeader = *(CCSDS_PriHdr_t*)(responseData); // Create the primary header
	payloadSize += sizeof(PrimaryHeader);

	// Populate primary header fields:
	CCSDS_WR_APID(PrimaryHeader,Ground_AP_ID);
  	CCSDS_WR_SHDR(PrimaryHeader,1);
  	CCSDS_WR_TYPE(PrimaryHeader,0);
  	CCSDS_WR_VERS(PrimaryHeader,0);
  	CCSDS_WR_SEQ(PrimaryHeader,SendCtr);
  	CCSDS_WR_SEQFLG(PrimaryHeader,0x03);

	CCSDS_TlmSecHdr_t TlmHeader = *(CCSDS_TlmSecHdr_t*)(responseData + sizeof(PrimaryHeader)); // Create the secondary header
	payloadSize += sizeof(TlmHeader);

	// Populate the secondary header fields:
	CCSDS_WR_SEC_HDR_SEC(TlmHeader,millis()/1000L);
  	CCSDS_WR_SEC_HDR_SUBSEC(TlmHeader,millis() % 1000L);

	payloadSize = addIntToTlm(SendCtr, responseData, payloadSize); // Add counter of sent packets to message

	CCSDS_WR_LEN(PrimaryHeader, payloadSize); // Finally, write the payload size

	// Debug info:
	debug_serial.print("Sending ");
	debug_serial.print(payloadSize);
	debug_serial.println(" bytes: ");

	for(int i = 0; i < payloadSize; i++) {
		radio_serial.write(responseData[i]); // Use Serial.write() to get actualy bytes.

		// Print packet to debug:
		debug_serial.print(responseData[i],HEX);
		debug_serial.print(", ");
	}
	debug_serial.println();

	SendCtr++;
}

bool checkPacket(uint8_t byteBuffer[]) {
	CCSDS_PriHdr_t header = getPrimaryHeader(byteBuffer);

	uint8_t _APID = getAPID(byteBuffer);
	uint8_t _SHDR = CCSDS_RD_SHDR(header);
	uint8_t _VERS = CCSDS_RD_VERS(header);

	debug_serial.print("APID :");
  	debug_serial.print(_APID);
  	debug_serial.print(" SHDR :");
  	debug_serial.print(_SHDR);
  	debug_serial.print(" VER :");
  	debug_serial.println(_VERS);

  	bool AP_ID_Match = false;
  	for(int i = 0; i < NUM_TRANS_APIDS; i++) {
  		if(_APID == Transmitted_AP_IDs[i]) {
  			AP_ID_Match = true;
  			break;
  		}
  	}

  	if(AP_ID_Match && _SHDR && !_VERS) {
  		debug_serial.println("Valid Packet!");
  		return true;
  	}

  	return false;
}
