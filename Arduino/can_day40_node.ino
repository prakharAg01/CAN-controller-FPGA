// =============================================================================
// File        : can_day40_node.ino
// Project     : Day 40: Full 3-Way Hardware Integration & Bidirectional Echo Node
// Architecture: PC (Python Dashboard) <-> FPGA (Artix-7) <-> Arduino Uno (MCP2515)
// Physical Bus: Differential CAN (500 kbps @ 8MHz MCP2515 crystal, 120 ohm terminated)
// =============================================================================

#include <SPI.h>
#include <mcp2515.h>

MCP2515 mcp2515(10); // CS pin on D10

struct can_frame txMsg;
struct can_frame rxMsg;

unsigned long lastSendTime = 0;
const unsigned long sendInterval = 2000; // Periodic transmission every 2s
uint32_t txCounter = 0;
uint32_t rxCounter = 0;

void setup() {
  Serial.begin(115200);
  SPI.begin();

  Serial.println("=============================================================");
  Serial.println("  Day 40: CAN 2.0A Controller - Full Bidirectional Node     ");
  Serial.println("  Arduino Uno + MCP2515 <===> Artix-7 FPGA (Nexys 4 DDR)    ");
  Serial.println("  Physical Bus: 500 kbps, 11-bit Classical CAN Frames        ");
  Serial.println("=============================================================");

  // Reset MCP2515
  if (mcp2515.reset() != MCP2515::ERROR_OK) {
    Serial.println("[ERROR] MCP2515 Reset Failed! Check SPI wiring (CS=10, MOSI=11, MISO=12, SCK=13).");
    while (1);
  }

  // Configure 500 kbps with 8 MHz crystal oscillator
  if (mcp2515.setBitrate(CAN_500KBPS, MCP_8MHZ) != MCP2515::ERROR_OK) {
    Serial.println("[ERROR] CAN Bitrate configuration failed!");
    while (1);
  }

  // Set Normal Active Mode (enables physical bus TX, RX, and dominant ACK generation)
  if (mcp2515.setNormalMode() != MCP2515::ERROR_OK) {
    Serial.println("[ERROR] Entering Normal Mode failed!");
    while (1);
  }

  Serial.println("[OK] MCP2515 initialized successfully at 500 kbps!");
  Serial.println("[OK] Ready for bidirectional full-duplex communication.");
  Serial.println("-------------------------------------------------------------");
}

void loop() {
  // ---------------------------------------------------------------------------
  // 1. Check for Incoming Frames from FPGA
  // ---------------------------------------------------------------------------
  if (mcp2515.readMessage(&rxMsg) == MCP2515::ERROR_OK) {
    rxCounter++;
    Serial.print("[RX #");
    Serial.print(rxCounter);
    Serial.print(" from FPGA] ID: 0x");
    Serial.print(rxMsg.can_id, HEX);
    Serial.print(" | DLC: ");
    Serial.print(rxMsg.can_dlc);
    Serial.print(" | DATA: ");
    for (int i = 0; i < rxMsg.can_dlc; i++) {
      if (rxMsg.data[i] < 0x10) Serial.print("0");
      Serial.print(rxMsg.data[i], HEX);
      Serial.print(" ");
    }
    Serial.println(" [ACK SENT]");

    // Optional Auto-Echo Response back to FPGA:
    // Echo received frame with ID = rx_id + 0x100
    struct can_frame echoMsg;
    echoMsg.can_id  = rxMsg.can_id + 0x100;
    echoMsg.can_dlc = rxMsg.can_dlc;
    for (int i = 0; i < rxMsg.can_dlc; i++) {
      echoMsg.data[i] = rxMsg.data[i] ^ 0xFF; // Invert payload as echo
    }
    mcp2515.sendMessage(&echoMsg);
  }

  // ---------------------------------------------------------------------------
  // 2. Periodic Autonomous Transmission to FPGA (Heartbeat Frame)
  // ---------------------------------------------------------------------------
  unsigned long now = millis();
  if (now - lastSendTime >= sendInterval) {
    lastSendTime = now;
    txCounter++;

    txMsg.can_id  = 0x244;
    txMsg.can_dlc = 4;
    txMsg.data[0] = 0xDE;
    txMsg.data[1] = 0xAD;
    txMsg.data[2] = (txCounter >> 8) & 0xFF;
    txMsg.data[3] = txCounter & 0xFF;

    Serial.print("[TX #");
    Serial.print(txCounter);
    Serial.print(" -> FPGA] ID: 0x244 | DATA: DE AD ");
    if (txMsg.data[2] < 0x10) Serial.print("0");
    Serial.print(txMsg.data[2], HEX);
    Serial.print(" ");
    if (txMsg.data[3] < 0x10) Serial.print("0");
    Serial.print(txMsg.data[3], HEX);
    Serial.print(" ... ");

    MCP2515::ERROR result = mcp2515.sendMessage(&txMsg);
    if (result == MCP2515::ERROR_OK) {
      Serial.println("SUCCESS! Frame sent and queued.");
    } else if (result == MCP2515::ERROR_ALLTXBUSY) {
      uint8_t eflg = mcp2515.getErrorFlags();
      Serial.print("BUSY: All TX buffers full waiting for bus ACK | EFLG: 0x");
      Serial.println(eflg, HEX);
    } else {
      Serial.print("ERROR: ");
      Serial.println((int)result);
    }
  }
}
