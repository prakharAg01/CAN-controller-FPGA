#include <SPI.h>
#include <mcp2515.h>

MCP2515 mcp2515(10);  // MCP2515 CS pin connected to D10
struct can_frame canMsg = {};

// Each message must contain at most 8 ASCII characters.
const char messages[][9] = {
  "Hello!",
  "CAN TEST",
  "Data: 10",
  "Data: 20",
  "Data: 30",
  "LED ON",
  "LED OFF",
  "Goodbye!"
};

const uint8_t messageCount =
    sizeof(messages) / sizeof(messages[0]);

uint8_t messageIndex = 0;

const unsigned long sendInterval = 1000;  // milliseconds
unsigned long lastSendTime = 0;

void setup()
{
  Serial.begin(9600);
  SPI.begin();

  if (mcp2515.reset() != MCP2515::ERROR_OK) {
    Serial.println("MCP2515 reset failed");
    while (true) {}
  }

  // Use MCP_16MHZ here if your CAN module has a 16 MHz crystal.
  if (mcp2515.setBitrate(CAN_500KBPS, MCP_8MHZ)
      != MCP2515::ERROR_OK) {
    Serial.println("CAN bitrate setup failed");
    while (true) {}
  }

  if (mcp2515.setNormalMode() != MCP2515::ERROR_OK) {
    Serial.println("CAN normal mode failed");
    while (true) {}
  }

  canMsg.can_id = 0x036;

  // Make the first transmission happen immediately.
  lastSendTime = millis() - sendInterval;

  Serial.println("Continuous CAN transmitter ready");
}

void loop()
{
  unsigned long currentTime = millis();

  if (currentTime - lastSendTime >= sendInterval) {
    lastSendTime = currentTime;

    // Clear the previous payload.
    for (uint8_t i = 0; i < 8; i++) {
      canMsg.data[i] = 0;
    }

    // Copy the current message into the CAN payload.
    uint8_t length = 0;

    while (length < 8 && messages[messageIndex][length] != '\0') {
      canMsg.data[length] = messages[messageIndex][length];
      length++;
    }

    canMsg.can_dlc = length;

    MCP2515::ERROR result = mcp2515.sendMessage(&canMsg);

    if (result == MCP2515::ERROR_OK) {
      Serial.print("Queued: ");
      Serial.println(messages[messageIndex]);

      // Advance to the next message and repeat after the last.
      messageIndex = (messageIndex + 1) % messageCount;
    } else {
      Serial.print("Send error: ");
      Serial.println((int)result);

      // Keep the same message index to try again next interval.
    }
  }
}