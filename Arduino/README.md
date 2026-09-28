# Arduino CAN Bus Communication using MCP2515

To demonstrate CAN communication between two Arduino-compatible boards using MCP2515 CAN modules.

It contains two simple simulations:

## Simulation 1 — Basic CAN Message Transmission

[Watch the simple CAN demonstration](https://jklujaipur-my.sharepoint.com/:v:/g/personal/prathambansal_jklu_edu_in/IQCike3XNBnnToplAqMb4-pEAex8dkzbQV4d-UnmfVh7wJw?e=PJ1nON)

The first simulation is used to verify basic CAN communication between two nodes.

The transmitter sends short text messages such as:

```text
Hello!
CAN TEST
Data: 10
LED ON
LED OFF
```

The receiver listens for CAN frames with ID `0x036` and displays the received message on the Serial Monitor and a 16×2 I2C LCD.

Both MCP2515 modules are configured for:

| Parameter | Value |
|---|---|
| CAN Bitrate | 500 kbps |
| MCP2515 Clock | 8 MHz |
| CAN ID | `0x036` |
| MCP2515 CS Pin | D10 |
| Serial Baud Rate | 9600 |

---

## Simulation 2 — DHT11 Temperature and Humidity over CAN

[Watch the CAN + DHT11 Demonstration](https://jklujaipur-my.sharepoint.com/:v:/g/personal/prathambansal_jklu_edu_in/IQBjYMqr_Ot-SqB5dDFY5_8MAXcOkcdM6om6rojH7EmYRTg?e=ZLxitI)

The second simulation extends the CAN setup by connecting a DHT11 temperature and humidity sensor to the transmitter.

The transmitter reads:

- Temperature in °C
- Relative humidity in %

These values are placed inside the CAN data frame and sent to the receiver.

| CAN Byte | Data |
|---|---|
| `data[0]` | Humidity |
| `data[1]` | Temperature |
| `data[2]` to `data[7]` | Unused |

The receiver extracts the temperature and humidity values and displays them on the 16×2 I2C LCD.

Example:

```text
Humi: 61
Temp: 28
```

---

# Connections

## MCP2515 to Arduino Uno/Nano

| MCP2515 | Arduino Uno/Nano |
|---|---|
| VCC | Supply voltage required by module |
| GND | GND |
| CS | D10 |
| MOSI / SI | D11 |
| MISO / SO | D12 |
| SCK | D13 |

## CAN Bus Connection

| Transmitter MCP2515 | Receiver MCP2515 |
|---|---|
| CANH | CANH |
| CANL | CANL |
| GND | GND |

## DHT11 to Transmitter Arduino

| DHT11 | Arduino |
|---|---|
| VCC | 5V |
| DATA | D8 |
| GND | GND |

## I2C LCD to Receiver Arduino

| I2C LCD | Arduino Uno/Nano |
|---|---|
| VCC | 5V |
| GND | GND |
| SDA | A4 |
| SCL | A5 |

---

## Libraries Used

- `SPI`
- `mcp2515.h`
- `DHT`
- `LiquidCrystal_I2C`

The project demonstrates basic CAN message transmission and a simple practical application where sensor data from a DHT11 is transferred between two Arduino nodes over a CAN bus.

## Reference
Arduino CAN Bus Tutorial | Interfacing MCP2515 CAN Module with Arduino by How to Electronics
https://www.youtube.com/watch?v=QYX_XOjjGOM&t=132s
