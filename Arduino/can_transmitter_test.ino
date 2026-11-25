#include <SPI.h>
#include <mcp2515.h>

MCP2515 mcp2515(10);  // CS pin on D10
struct can_frame canMsg;

void setup() {
  Serial.begin(115200);
  SPI.begin();

  Serial.println("=============================================");
  Serial.println("         Arduino CAN Transmitter             ");
  Serial.println("     Sending frames to FPGA at 500 kbps      ");
  Serial.println("=============================================");

  // Reset MCP2515
  if (mcp2515.reset() != MCP2515::ERROR_OK) {
    Serial.println("[ERROR] MCP2515 Reset Failed! Check SPI wiring.");
    while (1);
  }

  // Set 500 kbps @ 8 MHz crystal
  if (mcp2515.setBitrate(CAN_500KBPS, MCP_8MHZ) != MCP2515::ERROR_OK) {
    Serial.println("[ERROR] CAN Bitrate setup failed!");
    while (1);
  }

  // Put into Normal Mode to drive bus and wait for FPGA ACK
  if (mcp2515.setNormalMode() != MCP2515::ERROR_OK) {
    Serial.println("[ERROR] Setting Normal Mode failed!");
    while (1);
  }

  Serial.println("[OK] Ready! Sending frame 0x244 every 2 seconds...");
  Serial.println("---------------------------------------------");
}

void loop() {
  // Prepare test frame: ID = 0x244, DLC = 4, Payload: DE AD BE EF
  canMsg.can_id  = 0x244;
  canMsg.can_dlc = 4;
  canMsg.data[0] = 0xDE;
  canMsg.data[1] = 0xAD;
  canMsg.data[2] = 0xBE;
  canMsg.data[3] = 0xEF;

  Serial.print("[Arduino -> FPGA] Transmitting ID: 0x244 ... ");

  MCP2515::ERROR result = mcp2515.sendMessage(&canMsg);

  if (result == MCP2515::ERROR_OK) {
    Serial.println("SUCCESS! Frame sent to FPGA.");
  } else if (result == MCP2515::ERROR_ALLTXBUSY) {
    uint8_t eflg = mcp2515.getErrorFlags();
    Serial.print("BUSY: All TX buffers full waiting for bus ACK | EFLG: 0x");
    Serial.println(eflg, HEX);
  } else {
    Serial.print("Error code: ");
    Serial.println((int)result);
  }

  delay(2000); // Send every 2 seconds
}
