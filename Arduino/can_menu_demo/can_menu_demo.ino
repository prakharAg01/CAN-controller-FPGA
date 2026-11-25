// =============================================================================
// File        : can_menu_demo.ino
// Description : Interactive CAN 2.0A Controller Menu with Arbitration Testing
//               for Arduino Uno + MCP2515 CAN Bus Module
// Features    : 
//   [1] Transmit Mode      : Sends standard CAN frame 0x244 to FPGA every 1.5s
//   [2] Receive Mode       : Listens for incoming frames from FPGA
//   [3] Arbitration Test 1 : Low Priority (0x244) -> FPGA (0x155) Wins Arbitration
//   [4] Arbitration Test 2 : High Priority (0x099) -> Arduino (0x099) Wins Arbitration
//   [c] Cancel / Stop      : Returns to main menu
// Baud Rate   : Serial Monitor @ 115200 baud | Physical CAN Bus @ 500 kbps
// =============================================================================

#include <SPI.h>
#include <mcp2515.h>

MCP2515 mcp2515(10); // CS pin on Digital Pin 10

struct can_frame txMsg;
struct can_frame rxMsg;

// Helper function to read raw MCP2515 registers via direct SPI
uint8_t readMcpReg(uint8_t reg) {
  digitalWrite(10, LOW);
  SPI.transfer(0x03); // SPI READ instruction
  SPI.transfer(reg);
  uint8_t val = SPI.transfer(0x00);
  digitalWrite(10, HIGH);
  return val;
}

// Helper function to write raw MCP2515 registers via direct SPI
void writeMcpReg(uint8_t reg, uint8_t val) {
  digitalWrite(10, LOW);
  SPI.transfer(0x02); // SPI WRITE instruction
  SPI.transfer(reg);
  SPI.transfer(val);
  digitalWrite(10, HIGH);
}

enum NodeMode {
  MODE_IDLE,
  MODE_TX,
  MODE_RX,
  MODE_ARB_LOSE, // Arduino sends 0x244 (FPGA 0x155 wins)
  MODE_ARB_WIN   // Arduino sends 0x099 (Arduino 0x099 wins)
};

NodeMode currentMode = MODE_IDLE;
unsigned long lastTxTime = 0;
const unsigned long txInterval = 1500; // 1.5s auto-send interval
uint32_t txCount = 0;
uint32_t rxCount = 0;

void printMenu() {
  Serial.println();
  Serial.println(F("============================================================="));
  Serial.println(F("         CAN 2.0A Interactive Node Control Menu             "));
  Serial.println(F("============================================================="));
  Serial.println(F("  [1] Transmit Mode      : Send frame 0x244 to FPGA every 1.5s"));
  Serial.println(F("  [2] Receive Mode       : Listen for incoming frames from FPGA"));
  Serial.println(F("  [3] Arbitration Test 1 : Low Priority (0x244) -> FPGA 0x155 Wins"));
  Serial.println(F("  [4] Arbitration Test 2 : High Priority (0x099) -> Arduino 0x099 Wins"));
  Serial.println(F("  [c] Cancel / Stop      : Halt active mode & return to menu"));
  Serial.println(F("============================================================="));
  Serial.print(F("Select an option [1, 2, 3, 4, c]: "));
}

void setup() {
  Serial.begin(115200);
  SPI.begin();

  // Reset MCP2515
  if (mcp2515.reset() != MCP2515::ERROR_OK) {
    Serial.println(F("\n[ERROR] MCP2515 Reset Failed! Check SPI wiring."));
    while (1);
  }

  // Configure 500 kbps with 8 MHz crystal
  if (mcp2515.setBitrate(CAN_500KBPS, MCP_8MHZ) != MCP2515::ERROR_OK) {
    Serial.println(F("\n[ERROR] Setting Bitrate 500 kbps Failed!"));
    while (1);
  }

  // Program bit timing matching FPGA (70-75% sample point, SJW=2TQ)
  mcp2515.setConfigMode();
  writeMcpReg(0x2A, 0x40); // CFG1: SJW=2TQ, BRP=0
  writeMcpReg(0x29, 0x8A); // CFG2: BTLMODE=1, PHSEG1=2TQ, PRSEG=3TQ
  writeMcpReg(0x28, 0x81); // CFG3: SOF=1, PHSEG2=2TQ

  if (mcp2515.setNormalMode() != MCP2515::ERROR_OK) {
    Serial.println(F("\n[ERROR] Setting Normal Mode Failed!"));
    while (1);
  }

  Serial.println(F("\n[OK] MCP2515 initialized at 500 kbps."));
  printMenu();
}

// -----------------------------------------------------------------------------
// Helper: Send a frame and inspect hardware registers for arbitration status
// -----------------------------------------------------------------------------
void sendArbitrationFrame(uint16_t canId, bool isHighPriority) {
  txCount++;
  txMsg.can_id  = canId;
  txMsg.can_dlc = 4;
  txMsg.data[0] = isHighPriority ? 0xAA : 0xDE;
  txMsg.data[1] = isHighPriority ? 0x55 : 0xAD;
  txMsg.data[2] = (txCount >> 8) & 0xFF;
  txMsg.data[3] = txCount & 0xFF;

  Serial.println();
  Serial.print(F("[ARB-TX #"));
  Serial.print(txCount);
  Serial.print(F("] Queuing ID: 0x"));
  Serial.print(canId, HEX);
  Serial.print(isHighPriority ? F(" (HIGH Priority)") : F(" (LOW Priority)"));
  Serial.print(F(" | DATA: "));
  for (int i = 0; i < 4; i++) {
    if (txMsg.data[i] < 0x10) Serial.print(F("0"));
    Serial.print(txMsg.data[i], HEX);
    Serial.print(F(" "));
  }
  Serial.println(F("..."));

  unsigned long startWait = millis();
  bool mloaObserved = false;

  // Queue frame in MCP2515
  MCP2515::ERROR res = mcp2515.sendMessage(&txMsg);
  if (res != MCP2515::ERROR_OK) {
    Serial.print(F("  [!] Queue failed: code "));
    Serial.println((int)res);
    return;
  }

  // Monitor hardware registers while transmission completes
  while (millis() - startWait < 500) {
    uint8_t ctrl0 = readMcpReg(0x30); // TXB0CTRL
    if (ctrl0 & 0x10) { // Bit 4: MLOA (Message Lost Arbitration)
      mloaObserved = true;
    }

    // Check if FPGA frame arrived
    if (mcp2515.readMessage(&rxMsg) == MCP2515::ERROR_OK) {
      rxCount++;
      Serial.print(F("  -> [RX on Bus] ID: 0x"));
      Serial.print(rxMsg.can_id, HEX);
      Serial.print(F(" | DLC: "));
      Serial.print(rxMsg.can_dlc);
      Serial.print(F(" | DATA: "));
      for (int i = 0; i < rxMsg.can_dlc; i++) {
        if (rxMsg.data[i] < 0x10) Serial.print(F("0"));
        Serial.print(rxMsg.data[i], HEX);
        Serial.print(F(" "));
      }
      Serial.println();

      if (rxMsg.can_id == 0x155) {
        if (!isHighPriority) {
          Serial.println(F("  ==============================================================="));
          Serial.println(F("  >>> [ARBITRATION RESULT: FPGA WON!] <<<"));
          Serial.println(F("  - FPGA ID 0x155 (001...) has higher priority than Arduino 0x244 (010...)"));
          Serial.println(F("  - Collision at Bit 9: FPGA drove Dominant (0), Arduino sampled it"));
          Serial.println(F("  - Arduino backed off non-destructively & received winning frame!"));
          Serial.println(F("  ==============================================================="));
        } else {
          Serial.println(F("  ==============================================================="));
          Serial.println(F("  >>> [FPGA RETRANSMISSION RECEIVED] <<<"));
          Serial.println(F("  - FPGA 0x155 lost arbitration to Arduino 0x099 and sent after!"));
          Serial.println(F("  ==============================================================="));
        }
      }
    }

    // Check if TXREQ has cleared (transmission completed)
    if (!(ctrl0 & 0x08)) {
      // If Arduino sent High Priority (0x099) and won arbitration,
      // wait up to 150ms for the losing FPGA node to automatically retransmit its frame (0x155)
      if (isHighPriority) {
        unsigned long reTxWait = millis();
        while (millis() - reTxWait < 150) {
          if (mcp2515.readMessage(&rxMsg) == MCP2515::ERROR_OK) {
            rxCount++;
            Serial.print(F("  -> [RX on Bus] ID: 0x"));
            Serial.print(rxMsg.can_id, HEX);
            Serial.print(F(" | DLC: "));
            Serial.print(rxMsg.can_dlc);
            Serial.print(F(" | DATA: "));
            for (int i = 0; i < rxMsg.can_dlc; i++) {
              if (rxMsg.data[i] < 0x10) Serial.print(F("0"));
              Serial.print(rxMsg.data[i], HEX);
              Serial.print(F(" "));
            }
            Serial.println();

            if (rxMsg.can_id == 0x155) {
              Serial.println(F("  ==============================================================="));
              Serial.println(F("  >>> [ARBITRATION RESULT: ARDUINO WON!] <<<"));
              Serial.println(F("  - Arduino ID 0x099 (0001...) has higher priority than FPGA 0x155 (0010...)"));
              Serial.println(F("  - Collision at Bit 8: Arduino drove Dominant (0), FPGA backed off!"));
              Serial.println(F("  - Arduino frame 0x099 delivered FIRST on physical bus!"));
              Serial.println(F("  - FPGA automatically retransmitted 0x155 right after (Received above)!"));
              Serial.println(F("  ==============================================================="));
            }
            break;
          }
        }
      }
      break;
    }
  }

  uint8_t tec = readMcpReg(0x1C);
  Serial.print(F("  -> [TX STATUS] TXREQ Cleared | TEC: "));
  Serial.print(tec);
  Serial.print(F(" | MLOA Flag: "));
  Serial.println(mloaObserved ? F("1 (Lost & Retransmitted)") : F("0 (No Loss)"));
}

void loop() {
  // ---------------------------------------------------------------------------
  // User Command Input
  // ---------------------------------------------------------------------------
  if (Serial.available() > 0) {
    char cmd = Serial.read();
    if (cmd == '\r' || cmd == '\n' || cmd == ' ') return;

    if (cmd == '1') {
      currentMode = MODE_TX;
      lastTxTime = 0;
      Serial.println(F("1"));
      Serial.println(F("\n>>> [MODE: TRANSMIT] Sending frame 0x244 every 1.5s (press 'c' to stop) <<<"));
    }
    else if (cmd == '2') {
      currentMode = MODE_RX;
      Serial.println(F("2"));
      Serial.println(F("\n>>> [MODE: RECEIVE] Listening for frames from FPGA (press 'c' to stop) <<<"));
    }
    else if (cmd == '3') {
      currentMode = MODE_ARB_LOSE;
      lastTxTime = 0;
      Serial.println(F("3"));
      Serial.println(F("\n=================================================================="));
      Serial.println(F(">>> [MODE: ARBITRATION TEST 1 - FPGA 0x155 WINS] <<<"));
      Serial.println(F("  Arduino sends Low Priority ID: 0x244"));
      Serial.println(F("  FPGA sends Higher Priority ID: 0x155"));
      Serial.println(F("  Press 's' to trigger single frame, or wait for auto-send (every 2s)."));
      Serial.println(F("  -> Press BTNU on FPGA (or type 't'/'b 5 100' on PC Dashboard) to collide!"));
      Serial.println(F("  Press 'c' to return to menu."));
      Serial.println(F("=================================================================="));
    }
    else if (cmd == '4') {
      currentMode = MODE_ARB_WIN;
      lastTxTime = 0;
      Serial.println(F("4"));
      Serial.println(F("\n=================================================================="));
      Serial.println(F(">>> [MODE: ARBITRATION TEST 2 - ARDUINO 0x099 WINS] <<<"));
      Serial.println(F("  Arduino sends Highest Priority ID: 0x099"));
      Serial.println(F("  FPGA sends Lower Priority ID:     0x155"));
      Serial.println(F("  Press 's' to trigger single frame, or wait for auto-send (every 2s)."));
      Serial.println(F("  -> Press BTNU on FPGA (or type 't'/'b 5 100' on PC Dashboard) to collide!"));
      Serial.println(F("  Press 'c' to return to menu."));
      Serial.println(F("=================================================================="));
    }
    else if (cmd == 's' || cmd == 'S') {
      if (currentMode == MODE_ARB_LOSE) {
        sendArbitrationFrame(0x244, false);
      } else if (currentMode == MODE_ARB_WIN) {
        sendArbitrationFrame(0x099, true);
      } else {
        Serial.println(F("\n[!] 's' trigger is for Arbitration Test modes (3 or 4)."));
      }
    }
    else if (cmd == 'c' || cmd == 'C') {
      currentMode = MODE_IDLE;
      Serial.println(F("c"));
      Serial.println(F("\n[STOPPED] Mode halted."));
      printMenu();
    }
    else {
      Serial.print(F("\n[!] Invalid input: '"));
      Serial.print(cmd);
      Serial.println(F("'. Enter 1, 2, 3, 4, or c."));
    }
  }

  // ---------------------------------------------------------------------------
  // Mode 1: Standard Periodic Transmission (0x244)
  // ---------------------------------------------------------------------------
  if (currentMode == MODE_TX) {
    unsigned long now = millis();
    if (now - lastTxTime >= txInterval) {
      lastTxTime = now;
      txCount++;

      txMsg.can_id  = 0x244;
      txMsg.can_dlc = 4;
      txMsg.data[0] = 0xDE;
      txMsg.data[1] = 0xAD;
      txMsg.data[2] = (txCount >> 8) & 0xFF;
      txMsg.data[3] = txCount & 0xFF;

      Serial.print(F("[TX #"));
      Serial.print(txCount);
      Serial.print(F(" -> FPGA] ID: 0x244 | DLC: 4 | DATA: DE AD "));
      if (txMsg.data[2] < 0x10) Serial.print(F("0"));
      Serial.print(txMsg.data[2], HEX);
      Serial.print(F(" "));
      if (txMsg.data[3] < 0x10) Serial.print(F("0"));
      Serial.print(txMsg.data[3], HEX);
      Serial.print(F(" ... "));

      MCP2515::ERROR result = mcp2515.sendMessage(&txMsg);
      uint8_t tec   = readMcpReg(0x1C);
      uint8_t ctrl0 = readMcpReg(0x30);
      uint8_t eflg  = readMcpReg(0x2D);

      if (result == MCP2515::ERROR_OK) {
        Serial.print(F("SUCCESS (Sent & Queued) | TEC: "));
        Serial.print(tec);
        Serial.print(F(" | TXB0CTRL: 0x"));
        Serial.print(ctrl0, HEX);
        Serial.print(F(" | EFLG: 0x"));
        Serial.println(eflg, HEX);
      } else {
        Serial.print(F("BUSY | TEC: "));
        Serial.println(tec);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Mode 2: Standard Reception
  // ---------------------------------------------------------------------------
  else if (currentMode == MODE_RX) {
    if (mcp2515.readMessage(&rxMsg) == MCP2515::ERROR_OK) {
      rxCount++;
      Serial.print(F("[RX #"));
      Serial.print(rxCount);
      Serial.print(F(" from FPGA] ID: 0x"));
      Serial.print(rxMsg.can_id, HEX);
      Serial.print(F(" | DLC: "));
      Serial.print(rxMsg.can_dlc);
      Serial.print(F(" | DATA: "));
      for (int i = 0; i < rxMsg.can_dlc; i++) {
        if (rxMsg.data[i] < 0x10) Serial.print(F("0"));
        Serial.print(rxMsg.data[i], HEX);
        Serial.print(F(" "));
      }
      Serial.println(F(" [ACK SENT]"));
    }
  }

  // ---------------------------------------------------------------------------
  // Mode 3: Arbitration Test (FPGA 0x155 Wins over Arduino 0x244)
  // ---------------------------------------------------------------------------
  else if (currentMode == MODE_ARB_LOSE) {
    // Continuously drain incoming frames so MCP2515 hardware RX buffers never overflow
    if (mcp2515.readMessage(&rxMsg) == MCP2515::ERROR_OK) {
      rxCount++;
      Serial.print(F("  -> [RX on Bus] ID: 0x"));
      Serial.print(rxMsg.can_id, HEX);
      Serial.print(F(" | DLC: "));
      Serial.print(rxMsg.can_dlc);
      Serial.print(F(" | DATA: "));
      for (int i = 0; i < rxMsg.can_dlc; i++) {
        if (rxMsg.data[i] < 0x10) Serial.print(F("0"));
        Serial.print(rxMsg.data[i], HEX);
        Serial.print(F(" "));
      }
      Serial.println(F(" [ACK SENT]"));
    }

    unsigned long now = millis();
    if (now - lastTxTime >= 150) { // Fast 150ms interval to guarantee bus collisions with FPGA
      lastTxTime = now;
      sendArbitrationFrame(0x244, false);
    }
  }

  // ---------------------------------------------------------------------------
  // Mode 4: Arbitration Test (Arduino 0x099 Wins over FPGA 0x155)
  // ---------------------------------------------------------------------------
  else if (currentMode == MODE_ARB_WIN) {
    // Continuously drain incoming frames so MCP2515 hardware RX buffers never overflow
    if (mcp2515.readMessage(&rxMsg) == MCP2515::ERROR_OK) {
      rxCount++;
      Serial.print(F("  -> [RX on Bus] ID: 0x"));
      Serial.print(rxMsg.can_id, HEX);
      Serial.print(F(" | DLC: "));
      Serial.print(rxMsg.can_dlc);
      Serial.print(F(" | DATA: "));
      for (int i = 0; i < rxMsg.can_dlc; i++) {
        if (rxMsg.data[i] < 0x10) Serial.print(F("0"));
        Serial.print(rxMsg.data[i], HEX);
        Serial.print(F(" "));
      }
      Serial.println(F(" [ACK SENT]"));

      if (rxMsg.can_id == 0x155) {
        Serial.println(F("  ==============================================================="));
        Serial.println(F("  >>> [ARBITRATION RESULT: ARDUINO WON!] <<<"));
        Serial.println(F("  - Arduino ID 0x099 delivered first, followed by FPGA 0x155!"));
        Serial.println(F("  ==============================================================="));
      }
    }

    unsigned long now = millis();
    if (now - lastTxTime >= 150) { // Fast 150ms interval to guarantee bus collisions with FPGA
      lastTxTime = now;
      sendArbitrationFrame(0x099, true);
    }
  }
}
