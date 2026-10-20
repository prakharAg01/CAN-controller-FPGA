# Design and HDL Implementation of a CAN Protocol Controller with FPGA-Based Hardware Realization

## Overview

This project focuses on the design and FPGA implementation of independent modules required for a Classical CAN 2.0A/B protocol controller.

Each CAN function is developed and verified as a separate RTL module first. After individual verification, the modules can be integrated into the complete CAN controller.

## Hardware and Tools

- **HDL:** SystemVerilog
- **Simulation:** AMD Xilinx Vivado XSim
- **Synthesis / Implementation:** AMD Xilinx Vivado 2023.2
- **FPGA Board:** Digilent Nexys 4 DDR
- **FPGA Device:** Xilinx Artix-7 XC7A100T-1CSG324

---

# Module Status

| Module | Simulation | FPGA Implementation | Status |
|---|---|---|---|
| Bit Stuffer | Completed | Completed | Verified |
| Bit Destuffer | Completed | Completed | Verified |
| CRC-15 | Completed | Completed | Verified |
| Bit Timing Logic (BTL) | Testbenches included | In development | Implemented |
| TX Serializer | Testbench included | Demo video | Implemented |
| RX Deserializer | Testbench included | Demo video | Implemented |

The CAN BTL RTL, Vivado project, and testbenches are organized under [`can_btl/`](./can_btl/).

---

# 1. CAN Bit Stuffer

## Purpose

The bit stuffer inserts one complementary bit after five consecutive bits of the same polarity while CAN bit stuffing is enabled.

## Files

```text
can_bit_stuffer.sv
```

## Simulation

Verified using a self-checking SystemVerilog testbench.

Tests include:

- five consecutive `0`s
- five consecutive `1`s
- long runs of identical bits
- randomized run-heavy bit streams
- trailing stuff-bit cases

## FPGA Verification
[Watch the implementation of Stuffer on the FPGA](https://jklujaipur-my.sharepoint.com/:v:/g/personal/prakharagrawal_jklu_edu_in/IQA1kvPVU3V8ToO6Xl6lxWgNAVOErDggriFbZTn9bCVfqDM?nav=eyJyZWZlcnJhbEluZm8iOnsicmVmZXJyYWxBcHAiOiJPbmVEcml2ZUZvckJ1c2luZXNzIiwicmVmZXJyYWxBcHBQbGF0Zm9ybSI6IldlYiIsInJlZmVycmFsTW9kZSI6InZpZXciLCJyZWZlcnJhbFZpZXciOiJNeUZpbGVzTGlua0NvcHkifX0&e=WM0cXw).

Implemented on the Digilent Nexys 4 DDR.

Manual examples:

```text
00000 -> 000001
11111 -> 111110
```

The FPGA LEDs were used to observe:

- current bus bit
- stuffing activity
- pending stuff bit

## Status

**Completed and verified on FPGA.**

---

# 2. CAN Bit Destuffer

## Purpose

The bit destuffer removes inserted CAN stuff bits from the received bit stream and detects invalid stuffing conditions.

## Files

```text
can_bit_destuffer.sv
```

## Simulation

Verified together with the bit stuffer using a loopback self-checking testbench.

The recovered data stream is compared against the original input stream.

The testbench also verifies `stuff_error` behavior.

## FPGA Verification
[Watch the implementation of the crc on the FPGA](https://jklujaipur-my.sharepoint.com/:v:/g/personal/prakharagrawal_jklu_edu_in/IQAUSu0wjZdlSrW3hum8-HPCAUnui2mtVKKSlad7LdSX0uU?nav=eyJyZWZlcnJhbEluZm8iOnsicmVmZXJyYWxBcHAiOiJPbmVEcml2ZUZvckJ1c2luZXNzIiwicmVmZXJyYWxBcHBQbGF0Zm9ybSI6IldlYiIsInJlZmVycmFsTW9kZSI6InZpZXciLCJyZWZlcnJhbFZpZXciOiJNeUZpbGVzTGlua0NvcHkifX0&e=WKHip6).

The stuffer output was connected internally to the destuffer input.

The FPGA test verified that inserted stuff bits were removed and the original data bits were recovered.

## Status

**Completed and verified on FPGA.**

---

# 3. CAN CRC-15

## Purpose

The CRC module implements the Classical CAN CRC-15 calculation using the polynomial:

```text
x^15 + x^14 + x^10 + x^8 + x^7 + x^4 + x^3 + 1
```

Polynomial value without the `x^15` term:

```text
0x4599
```

## Files

```text
can_crc.sv
```

## Simulation

Verified using a self-checking SystemVerilog testbench.

Example test vectors:

```text
20 zero bits        -> CRC 0x0000
1                   -> CRC 0x4599
10                  -> CRC 0x4EAB
101010101010        -> CRC 0x77BB
CAN header-like test -> CRC 0x272F
```

The testbench also verifies that the CRC value remains unchanged when `calc_en = 0`.

## FPGA Verification

Implemented on the Digilent Nexys 4 DDR.

Board-level operation:

```text
SW0   -> input bit
BTNC  -> CRC reset
BTNU  -> process one bit
LED0-14 -> CRC value
LED15 -> activity indication
```

Example hardware checks:

```text
Input 1            -> CRC 0x4599
Input 10           -> CRC 0x4EAB
Input 101010101010 -> CRC 0x77BB
```

## Status

**Completed and verified on FPGA.**

---

# 4. CAN Bit Timing Logic (BTL)

## Purpose

The BTL generates time-quanta ticks, bit ticks, and sample points from the
configured bit-rate prescaler and CAN bit segments. It samples the receive bus,
supports hard synchronization at start of frame, and resynchronizes during a
frame using the synchronization jump width (SJW).

## Files

```text
can_btl/can_btl.srcs/sources_1/new/can_btl.sv
can_btl/can_btl.srcs/sim_1/new/tb_can_btl.sv
can_btl/can_btl.srcs/sim_1/new/tb_can_btl_baud.sv
can_btl/can_btl.srcs/sim_1/new/tb_can_btl_sync.sv
```

The BTL testbenches cover bit timing, baud configuration, hard sync, and
resynchronization behavior.

---

# 5. CAN Serializer and Deserializer

## Purpose

The TX serializer loads frame fields and shifts them out most-significant bit
first. The RX deserializer collects incoming de-stuffed bits into fields of a
configured length. These modules provide the transmit and receive shift
registers for assembling and parsing CAN frame data.

## Files

```text
can_btl/can_btl.srcs/sources_1/new/can_tx_shift.sv
can_btl/can_btl.srcs/sources_1/new/can_rx_shift.sv
can_btl/can_btl.srcs/sim_1/new/tb_can_tx_shift.sv
can_btl/can_btl.srcs/sim_1/new/tb_can_rx_shift.sv
can_btl/can_btl.srcs/sim_1/new/tb_can_shift_chain.sv
```

The TX serializer supports field loading, ready/valid handshaking, and
bubble-free reloads. The RX deserializer signals when each configured-length
field has been collected. Testbenches cover the individual shift registers and
their chain.

## FPGA Demonstration

[Watch the FPGA implementation of the serializer and deserializer](https://jklujaipur-my.sharepoint.com/:v:/g/personal/prakharagrawal_jklu_edu_in/IQDMzTgm2xkWRayTjft29vRSARhJACfPEV_SgnvLsn9wPJg?nav=eyJyZWZlcnJhbEluZm8iOnsicmVmZXJyYWxBcHAiOiJPbmVEcml2ZUZvckJ1c2luZXNzIiwicmVmZXJyYWxBcHBQbGF0Zm9ybSI6IldlYiIsInJlZmVycmFsTW9kZSI6InZpZXciLCJyZWZlcnJhbFZpZXciOiJNeUZpbGVzTGlua0NvcHkifX0&e=uY0ZRQ).

---

# Arduino Simulation

A separate CAN simulation was also performed using Arduino hardware.

Additional CAN controller modules will be documented here as they are developed.
