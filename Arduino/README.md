# Arduino CAN Bus Transmitter and Receiver

A simple **CAN bus communication project using Arduino-compatible boards and MCP2515 CAN modules**.

The project contains two Arduino sketches:

- **Transmitter** – continuously sends a sequence of text messages over the CAN bus.
- **Receiver** – receives messages with the expected CAN identifier and displays them on both the **Serial Monitor** and a **16×2 I2C LCD**.

## Project Overview

This project demonstrates basic Controller Area Network (CAN) communication between two nodes using the **MCP2515 CAN controller**.

The transmitter cycles through several short ASCII messages and sends one message every second. The receiver listens for CAN frames with identifier `0x036`, extracts the payload, and displays the received text.

### Communication settings

| Parameter | Value |
|---|---|
| CAN bitrate | `500 kbps` |
| MCP2515 oscillator | `8 MHz` |
| CAN message ID | `0x036` |
| Maximum payload | `8 bytes` |
| Transmission interval | `1000 ms` |
| Serial baud rate | `9600` |
| MCP2515 CS pin | `D10` |
| LCD address | `0x27` |
| LCD size | `16 × 2` |

> The code is configured for an MCP2515 module with an **8 MHz oscillator**. If your module uses a 16 MHz crystal, change `MCP_8MHZ` to `MCP_16MHZ` in both sketches.

## Hardware Requirements

- 2 × Arduino-compatible boards
- 2 × MCP2515 CAN bus modules
- CAN bus wiring between the two modules
- 1 × 16×2 I2C LCD for the receiver
- Jumper wires
- USB cables for programming the boards

A correctly terminated CAN bus is also required. CAN networks normally use **120 Ω termination at both physical ends of the bus**.

## Software Requirements

Install the following Arduino libraries:

- `SPI` – included with the Arduino framework
- `arduino-mcp2515` / `mcp2515.h`
- `LiquidCrystal_I2C` – required by the receiver

## Project Structure

```text
.
├── transmitter(1).ino
├── receiver(1).ino
└── README.md
```

## Transmitter

The transmitter initializes the MCP2515 at `500 kbps` and operates it in normal CAN mode.

It continuously sends the following messages:

```text
Hello!
CAN TEST
Data: 10
Data: 20
Data: 30
LED ON
LED OFF
Goodbye!
```

Each CAN frame uses:

```cpp
canMsg.can_id = 0x036;
```

Since a standard CAN data frame can carry up to **8 payload bytes**, every message in the program is limited to eight ASCII characters.

A new message is sent approximately once every second:

```cpp
const unsigned long sendInterval = 1000;
```

After `"Goodbye!"` is transmitted, the sequence starts again from `"Hello!"`.

If transmission fails, the current message is retained and attempted again on the next interval.

## Receiver

The receiver initializes:

- MCP2515 CAN controller
- SPI communication
- 16×2 I2C LCD
- Serial communication

After startup, the LCD displays:

```text
Waiting for CAN
```

The receiver checks incoming CAN frames and only accepts frames with CAN ID:

```text
0x036
```

Frames with a different identifier are ignored.

When a valid frame arrives, its payload is displayed on:

1. The **16×2 LCD**
2. The **Arduino Serial Monitor**

Example:

```text
CAN message:
Data: 20
```

The Serial Monitor will show:

```text
Received: Data: 20
```

## Basic Connection Concept

Each Arduino communicates with its MCP2515 module through SPI.

The code explicitly uses:

```text
MCP2515 CS -> Arduino D10
```

The remaining SPI pins should be connected to the hardware SPI pins of the Arduino board being used.

The CAN sides of the two MCP2515 modules are connected together:

```text
Node 1                         Node 2
Arduino                        Arduino
   |                              |
   | SPI                          | SPI
   v                              v
MCP2515                        MCP2515
   |                              |
 CANH -------------------------- CANH
 CANL -------------------------- CANL
```

Ensure the two nodes share an appropriate common ground where required by the hardware setup.

## How to Run

1. Connect one Arduino to the first MCP2515 module.
2. Connect the second Arduino to the second MCP2515 module.
3. Connect `CANH` to `CANH`.
4. Connect `CANL` to `CANL`.
5. Connect the I2C LCD to the receiver board.
6. Verify that both MCP2515 modules use the oscillator frequency selected in the code.
7. Upload `transmitter(1).ino` to the transmitting board.
8. Upload `receiver(1).ino` to the receiving board.
9. Open both Serial Monitors at `9600` baud.
10. Observe the transmitter sending messages and the receiver displaying them.

## Expected Output

### Transmitter Serial Monitor

```text
Continuous CAN transmitter ready
Queued: Hello!
Queued: CAN TEST
Queued: Data: 10
Queued: Data: 20
...
```

### Receiver Serial Monitor

```text
Receiver ready
Received: Hello!
Received: CAN TEST
Received: Data: 10
Received: Data: 20
...
```

### Receiver LCD

The first line displays:

```text
CAN message:
```

The second line displays the received payload, for example:

```text
Data: 30
```

## Error Handling

Both sketches check whether the MCP2515 initializes correctly.

Possible startup errors include:

```text
MCP2515 reset failed
CAN bitrate setup failed
CAN normal mode failed
```

The receiver also reports initialization errors on its LCD.

If initialization fails, the program stops rather than attempting communication with an incorrectly configured CAN controller.

## What This Project Demonstrates

- Basic CAN bus communication
- MCP2515 configuration using SPI
- CAN message transmission and reception
- CAN identifiers
- CAN payload/DLC handling
- Periodic non-blocking transmission using `millis()`
- Filtering received messages in software
- Displaying CAN data on an I2C LCD
- Basic CAN communication error handling

## Possible Improvements

The project can be extended with:

- Sensor data transmission
- Multiple CAN message identifiers
- Hardware acceptance filters
- Structured binary CAN payloads
- Temperature and humidity monitoring
- LED or actuator control commands
- Message counters and timestamps
- CAN error-state monitoring
- Custom CAN controller implementation on an FPGA
