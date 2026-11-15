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
| Bit Timing Logic (BTL) | Completed | Completed | Verified |
| TX Serializer | Completed | Completed | Verified |
| RX Deserializer | Completed | Completed | Verified |
| Acceptance Filter | Completed | In progress | Verified |
| Bit Stream Processor (BSP) | Completed | In progress | Verified |
| Error Management Logic (EML) | Completed | In progress | Verified |
| TX Buffer & Inferred BRAM RX FIFO | Completed | In progress | Verified |
| Host Register Interface | Completed | In progress | Verified |
| Top-Level Controller (`can_controller_top`) | Completed | In progress | Verified |
| Dual-Node System & Bus Arbitration | Completed | In progress | Verified |


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
[Watch the implementation of Stuffer and DeStuffer on the FPGA](https://jklujaipur-my.sharepoint.com/:v:/g/personal/prakharagrawal_jklu_edu_in/IQA1kvPVU3V8ToO6Xl6lxWgNAVOErDggriFbZTn9bCVfqDM?nav=eyJyZWZlcnJhbEluZm8iOnsicmVmZXJyYWxBcHAiOiJPbmVEcml2ZUZvckJ1c2luZXNzIiwicmVmZXJyYWxBcHBQbGF0Zm9ybSI6IldlYiIsInJlZmVycmFsTW9kZSI6InZpZXciLCJyZWZlcnJhbFZpZXciOiJNeUZpbGVzTGlua0NvcHkifX0&e=WM0cXw).

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
[Watch the implementation of the CRC on the FPGA](https://jklujaipur-my.sharepoint.com/:v:/g/personal/prakharagrawal_jklu_edu_in/IQAUSu0wjZdlSrW3hum8-HPCAUnui2mtVKKSlad7LdSX0uU?nav=eyJyZWZlcnJhbEluZm8iOnsicmVmZXJyYWxBcHAiOiJPbmVEcml2ZUZvckJ1c2luZXNzIiwicmVmZXJyYWxBcHBQbGF0Zm9ybSI6IldlYiIsInJlZmVycmFsTW9kZSI6InZpZXciLCJyZWZlcnJhbFZpZXciOiJNeUZpbGVzTGlua0NvcHkifX0&e=WKHip6).

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

# 6. CAN Acceptance Filter

## Purpose

The acceptance filter performs hardware message filtering on incoming standard 11-bit CAN identifiers. It compares the received identifier against a configurable acceptance code register (`filter_id`) and an acceptance mask register (`filter_mask`). Bits set to `1` in the mask require an exact match, while bits set to `0` are treated as "don't care", allowing selective reception of specific message IDs, groups of IDs, or wildcard reception.

## Files

```text
can_acceptance_filter/can_acceptance_filter.srcs/sources_1/new/can_acceptance_filter.sv
can_acceptance_filter/can_acceptance_filter.srcs/sim_1/new/tb_can_acceptance_filter.sv
```

## Simulation

Verified using a self-checking SystemVerilog testbench.

Tests include:

- Exact identifier matching (`mask = 0x7FF`)
- Partial-mask range and group filtering
- Wildcard acceptance (`mask = 0x000`, all frames accepted)
- Rejection of non-matching identifiers
- Boundary cases (all zeros `0x000`, all ones `0x7FF`)

## Status

**Completed and verified in simulation.**

---

# 7. CAN Bit Stream Processor (BSP)

## Purpose

The Bit Stream Processor is the core protocol finite state machine orchestrating Classical CAN 2.0A frame transmission and reception. It sequences frames through all standard CAN fields: Start of Frame (SOF), Arbitration (11-bit ID + RTR), Control (IDE, r0, DLC), Data (0–8 bytes), CRC Field (15-bit CRC sequence + delimiter), Acknowledge (ACK slot + delimiter), End of Frame (EOF, 7 recessive bits), Interframe Space (IFS intermission), and Error Frames (active and passive flags).

The BSP coordinates bit stuffing on the TX path, bit destuffing on the RX path, running CRC generation and verification, dominant ACK generation for valid incoming frames, and non-destructive bitwise arbitration.

## Files

```text
can_bsp/can_bsp.srcs/sources_1/imports/new/can_bsp.sv
can_bsp/can_bsp.srcs/sim_1/new/tb_can_bsp.sv
```

## Simulation

Verified across dedicated single-node and multi-node testbenches.

Tests include:

- Frame serialization with automatic bit-stuffing insertion across SOF through CRC sequence
- Frame deserialization with bit destuffing and protocol bit validation
- Hardware ACK generation in the ACK slot when received frame CRC matches
- Bitwise arbitration loss detection: transmitter demotes to receiver upon driving recessive but sampling dominant
- Interframe space (IFS) intermission timing and hard-synchronization on incoming SOF edges
- Active error flag driving (6 dominant bits) and passive error flag driving (6 recessive bits)

## Status

**Completed and verified in simulation.**

---

# 8. CAN Error Management Logic (EML)

## Purpose

The Error Management Logic implements standard CAN 2.0 error confinement rules. It maintains the Transmit Error Counter (TEC) and Receive Error Counter (REC), governing transitions between three protocol error states:

- **ERROR_ACTIVE** (`TEC <= 127` and `REC <= 127`): Node participates normally on the bus and drives active error flags (6 dominant bits) upon detecting an error.
- **ERROR_PASSIVE** (`TEC > 127` or `REC > 127`, `TEC <= 255`): Node drives passive error flags (6 recessive bits) and observes suspend transmission time after frames.
- **BUS_OFF** (`TEC > 255`): Node disconnects from driving the bus, disabling all transmission until a recovery condition (128 occurrences of 11 consecutive recessive bits) or host command is detected.

The module detects and classifies five standard CAN error types: Bit Error, Stuff Error, CRC Error, ACK Error, and Form Error.

## Files

```text
can_eml/can_eml.srcs/sources_1/new/can_eml.sv
can_eml/can_eml.srcs/sim_1/new/tb_can_eml.sv
```

## Simulation

Verified using a dedicated SystemVerilog testbench.

Tests include:

- TEC increment (+8 per TX error) and decrement (-1 per successful transmission)
- REC increment (+1 per RX error) and decrement (-1 per successful reception)
- State transitions between Active, Passive, and Bus-Off
- Bus-off recovery tracking (128 sequences of 11 recessive bits) and host abort/clear
- Error warning threshold detection (`TEC >= 96` or `REC >= 96`)

## Status

**Completed and verified in simulation.**

---

# 9. CAN Buffer Subsystem (TX Buffer & Inferred BRAM RX FIFO)

## Purpose

The buffer subsystem provides message staging and decouples host processor bus transactions from CAN bit timing:

- **Transmit Buffer (`can_tx_buffer.sv`)**: Single-message holding buffer with ready/busy handshaking. Holds the frame identifier, RTR, DLC, and payload data during transmission and arbitration, retaining the frame for automatic retransmission if arbitration is lost.
- **True Dual-Port Block RAM (`can_bram_dual_port.sv`)**: Parameterized dual-port memory inferred as FPGA Block RAM (BRAM), providing independent simultaneous read and write port access.
- **Receive FIFO (`can_rx_fifo.sv`)**: 16-frame circular FIFO constructed over inferred Block RAM. Stores complete 80-bit frame packets (ID, RTR, DLC, and up to 64 data bits). Features hardware read/write pointers, occupancy count (`rx_count`), overrun detection (`rx_overrun`), almost-full warning, and acceptance filter gating.

## Files

```text
can_buffer/can_buffer.srcs/sources_1/new/can_tx_buffer.sv
can_buffer/can_buffer.srcs/sources_1/new/can_rx_fifo.sv
can_buffer/can_buffer.srcs/sources_1/new/can_bram_dual_port.sv
can_buffer/can_buffer.srcs/sim_1/new/tb_can_tx_buffer.sv
can_buffer/can_buffer.srcs/sim_1/new/tb_can_rx_fifo.sv
can_buffer/can_buffer.srcs/sim_1/new/tb_can_buffer_integration.sv
```

## Simulation

Verified using unit testbenches and an integrated buffer subsystem testbench.

Tests include:

- Single-slot TX holding, back-to-back writes, and transmission abort
- Circular FIFO pointer wrapping, occupancy tracking, and Block RAM read-during-write isolation
- Acceptance filter gating (non-matching frames are rejected before Block RAM commit)
- FIFO full flag assertion and overrun protection against memory corruption

## Status

**Completed and verified in simulation.**

---

# 10. CAN Host Register Interface

## Purpose

The register interface provides a standard 32-bit memory-mapped processor/host bus interface supporting word-aligned single-cycle read and write operations with transfer acknowledge (`reg_ack`) and unified interrupt generation (`irq_out`).

Memory-mapped registers implemented:

- `MODECR` (0x00): Reset mode, loopback mode, listen-only mode, abort transmission, bus-off recovery request
- `CMR` (0x04): Self-clearing command strobes for TX request, RX FIFO pop, and clear FIFO
- `SR` (0x08): Real-time status flags (TX ready/busy, RX empty/full/overrun, error states)
- `IR_IE` (0x0C): Interrupt status (Write-1-to-Clear) and interrupt enable masks
- `BTR` (0x10): Bit timing configuration (BRP, TSEG1, TSEG2, SJW)
- `AFID` (0x14) & `AFMSK` (0x18): Acceptance filter code and mask registers
- `ECR` (0x1C): Read-only error counters (`TEC[15:8]`, `REC[7:0]`)
- `TX_HEADER` (0x20), `TX_DATA_L` (0x24), `TX_DATA_H` (0x28): Outgoing frame staging
- `RX_HEADER` (0x2C), `RX_DATA_L` (0x30), `RX_DATA_H` (0x34): Current RX FIFO head frame
- `FIFO_CNT` (0x38): Queued frame count in the RX FIFO

## Files

```text
can_regs/can_regs.srcs/sources_1/new/can_regs.sv
can_regs/can_regs.srcs/sim_1/new/tb_can_regs.sv
```

## Simulation

Verified using a dedicated register testbench.

Tests include:

- Word-aligned read and write access across all registers
- Power-up reset default values and read-only register protection
- Self-clearing command strobes (`CMR`)
- Interrupt generation and Write-1-to-Clear (W1C) clearing mechanism

## Status

**Completed and verified in simulation.**

---

# 11. Top-Level CAN Controller Integration

## Purpose

The top-level module (`can_controller_top.sv`) integrates all protocol submodules into a unified Classical CAN 2.0A IP core. It connects the Host Register Interface, TX Buffer, Block RAM RX FIFO, Acceptance Filter, RX Frame Assembler & CRC Checker (`can_rx_assembler.sv`), Bit Stream Processor FSM, Error Management Logic, Bit Timing Logic, and Bit Stuffer/Destuffer.

The core provides an internal loopback mode for hardware-independent verification and transceiver physical pad connections (`can_tx`, `can_rx`) for physical CAN transceivers (e.g., TJA1050/MCP2551).

## Files

```text
can_top/can_top.srcs/sources_1/new/can_controller_top.sv
can_top/can_top.srcs/sources_1/new/can_rx_assembler.sv
can_top/can_top.srcs/sim_1/new/tb_can_controller_top.sv
```

## Simulation

Verified using a top-level loopback testbench.

Tests include:

- Power-up reset sequence and default register configuration
- End-to-end loopback frame transmission: host write $\rightarrow$ serialization $\rightarrow$ bit stuffing $\rightarrow$ BTL sampling $\rightarrow$ destuffing $\rightarrow$ frame assembly $\rightarrow$ FIFO push $\rightarrow$ interrupt assertion
- Acceptance filtering rejection and acceptance in loopback
- Host interrupt handling and FIFO pop verification

## Status

**Completed and verified in simulation.**

---

# 12. Dual-Node System Verification & Bus Arbitration

## Purpose

A multi-node system testbench instantiating two independent `can_controller_top` nodes connected to an open-collector wired-AND physical CAN bus:

$$\text{can\_bus} = \text{can\_tx\_a} \ \& \ \text{can\_tx\_b}$$

This configuration verifies real multi-node physical layer behaviors: non-destructive bitwise arbitration with dominant bit zero priority, receiver dominant ACK generation, automatic retransmission of losing frames after Interframe Space (IFS), multi-node acceptance filtering discrimination, and back-to-back burst frame transfers into Block RAM FIFO.

## Files

```text
can_top/can_top.srcs/sim_1/new/tb_can_controller_two_node.sv
can_top/can_top.srcs/sim_1/new/tb_can_top.sv
```

## Simulation

Verified using a dual-node system testbench covering six test scenarios (64/64 assertion checks passing):

- **T1: Power-up Reset & Configuration**: Both nodes initialize default registers and configure bit timing; bus rests in recessive state.
- **T2: Unidirectional Transfer (Node A $\rightarrow$ Node B)**: Node A transmits frame `0x155` (DLC=4); Node B generates hardware dominant ACK bit; frame is queued into Node B FIFO and popped.
- **T3: Reverse Unidirectional Transfer (Node B $\rightarrow$ Node A)**: Node B transmits frame `0x3AA` with full 8-byte payload; Node A generates ACK and receives into FIFO.
- **T4: Simultaneous Transmission with Arbitration (Node A Wins)**: Node A (`ID 0x120`) and Node B (`ID 0x124`) transmit simultaneously. At bit `ID[2]`, Node B detects recessive-vs-dominant mismatch, asserts `arb_lost`, drops `tx_en`, and becomes an active receiver. Node A completes transmission cleanly. After IFS intermission, Node B automatically retransmits `ID 0x124` and Node A receives it into FIFO. Error counters remain `0x00`.
- **T5: Reverse Arbitration (Node B Wins)**: Node B (`ID 0x250`) and Node A (`ID 0x270`) transmit simultaneously. Node A detects arbitration loss at bit `ID[5]`, demotes to receiver, and automatically retransmits after Node B completes.
- **T6: Multi-Node Acceptance Filtering & Burst Transfers**: Node B rejects non-matching frame `0x401` while providing bus ACK; Node B accepts matching frame `0x400`. Node B transmits three back-to-back burst frames (`0x101`, `0x102`, `0x103`), filling Node A's FIFO to count 3, followed by sequential FIFO pop and validation.

## Status

**Completed and verified in simulation.**

---

# Arduino Simulation

A separate CAN simulation was also performed using Arduino hardware.

Additional CAN controller modules will be documented here as they are developed.
