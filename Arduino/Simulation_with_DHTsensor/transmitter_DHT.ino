#include <SPI.h>
#include <mcp2515.h>
#include <DHT.h>

#define DHTPIN 8
#define DHTTYPE DHT11

struct can_frame canMsg;

MCP2515 mcp2515(10);
DHT dht(DHTPIN, DHTTYPE);

void setup()
{
  Serial.begin(9600);

  SPI.begin();
  dht.begin();

  mcp2515.reset();
  mcp2515.setBitrate(CAN_500KBPS, MCP_8MHZ);
  mcp2515.setNormalMode();

  Serial.println("CAN Transmitter Started");
}

void loop()
{
  int h = dht.readHumidity();
  int t = dht.readTemperature();

  // Print DHT values on Serial Monitor
  Serial.print("Temperature: ");
  Serial.print(t);
  Serial.print(" °C");

  Serial.print(" | Humidity: ");
  Serial.print(h);
  Serial.println(" %");

  canMsg.can_id  = 0x036;
  canMsg.can_dlc = 8;

  canMsg.data[0] = h;
  canMsg.data[1] = t;
  canMsg.data[2] = 0x00;
  canMsg.data[3] = 0x00;
  canMsg.data[4] = 0x00;
  canMsg.data[5] = 0x00;
  canMsg.data[6] = 0x00;
  canMsg.data[7] = 0x00;

  mcp2515.sendMessage(&canMsg);

  Serial.println("CAN message sent");
  Serial.println("----------------------");

  delay(1000);
}