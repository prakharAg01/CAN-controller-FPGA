#include <SPI.h>
#include <mcp2515.h>
#include <LiquidCrystal_I2C.h>

LiquidCrystal_I2C lcd(0x27, 16, 2);
MCP2515 mcp2515(10);  // MCP2515 CS connected to D10

struct can_frame canMsg;

void setup()
{
  Serial.begin(9600);
  SPI.begin();

  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Starting CAN...");

  mcp2515.reset();

  if (mcp2515.setBitrate(CAN_500KBPS, MCP_8MHZ)
      != MCP2515::ERROR_OK) {
    lcd.clear();
    lcd.print("CAN setup failed");
    Serial.println("CAN bitrate setup failed");
    while (true) {}
  }

  if (mcp2515.setNormalMode() != MCP2515::ERROR_OK) {
    lcd.clear();
    lcd.print("CAN mode failed");
    Serial.println("CAN normal mode failed");
    while (true) {}
  }

  lcd.clear();
  lcd.print("Waiting for CAN");
  Serial.println("Receiver ready");
}

void loop()
{
  if (mcp2515.readMessage(&canMsg) == MCP2515::ERROR_OK) {

    // Accept only the expected ID and a valid payload length.
    if (canMsg.can_id != 0x036 || canMsg.can_dlc > 8) {
      return;
    }

    lcd.setCursor(0, 0);
    lcd.print("CAN message:    ");

    // Erase the previous message without clearing the whole LCD.
    lcd.setCursor(0, 1);
    lcd.print("                ");
    lcd.setCursor(0, 1);

    Serial.print("Received: ");

    for (uint8_t i = 0; i < canMsg.can_dlc; i++) {
      lcd.write(canMsg.data[i]);
      Serial.write(canMsg.data[i]);
    }

    Serial.println();
  }
}