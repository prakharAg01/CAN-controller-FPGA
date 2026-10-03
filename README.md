# Design and HDL Implementation of a CAN Protocol Controller with FPGA-Based Hardware Realization

## Overview

This project focuses on the design and hardware implementation of key modules of a Classical CAN 2.0A/B protocol controller using SystemVerilog and an FPGA.

The current FPGA implementation includes CAN bit stuffing and bit destuffing, verified through simulation and tested on a Digilent Nexys 4 DDR FPGA board.

## Implemented Modules

- CAN Bit Stuffer (TX side)
- CAN Bit Destuffer (RX side)
- CRC-15 logic
- FPGA test wrapper for automatic and manual bit-stream testing

## FPGA Hardware

- **Board:** Digilent Nexys 4 DDR
- **FPGA:** Xilinx Artix-7 XC7A100T-1CSG324
- **Clock:** 100 MHz
- **Development Tool:** AMD Xilinx Vivado 2023.2

## Simulation

The RTL modules were verified using Vivado XSim with self-checking SystemVerilog testbenches.

The bit-stuffing testbench checks:
- insertion of a complementary bit after five consecutive identical bits
- correct recovery of the original stream by the destuffer
- long runs of `0`s and `1`s
- randomized bit streams
- stuffing-error detection

## FPGA Testing

The FPGA test design supports two modes:

### Automatic Mode

A fixed 20-bit sequence is repeatedly passed through:

```text
Test Vector -> Bit Stuffer -> Bit Destuffer -> Comparator
```

LEDs are used to observe:
- transmitted bus bit
- stuffing activity
- pending stuff bit
- recovered bit
- pass/error status

### Manual Mode

Bits can be entered manually using the onboard switches and push button.

Example:

```text
00000 -> 000001
11111 -> 111110
```

After five consecutive equal bits, the FPGA indicates that a stuff bit is pending. On the next bit tick, the complementary bit is inserted automatically.

## Arduino Simulation

A separate CAN simulation was also carried out using Arduino.

## Tech Stack

- **HDL:** SystemVerilog
- **Simulation:** AMD Xilinx Vivado XSim
- **Synthesis / Implementation:** AMD Xilinx Vivado 2023.2
- **FPGA:** Digilent Nexys 4 DDR, Artix-7 XC7A100T

## Current Status

Completed:
- CAN bit stuffing RTL
- CAN bit destuffing RTL
- simulation verification
- synthesis and implementation on FPGA
- FPGA hardware testing in automatic and manual modes

Further work will integrate these verified modules into the complete CAN controller and physical CAN interface.
