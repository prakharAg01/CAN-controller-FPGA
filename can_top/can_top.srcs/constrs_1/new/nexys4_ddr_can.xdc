## =============================================================================
## File        : nexys4_ddr_can.xdc
## Description : Timing and Physical Constraints for CAN 2.0A Controller on
##               Digilent Nexys 4 DDR (Artix-7 XC7A100T-1CSG324C).
##
## =============================================================================

## -----------------------------------------------------------------------------
## 1. Primary Clock (100 MHz Oscillator on Pin E3)
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN E3  IOSTANDARD LVCMOS33 } [get_ports { clk }]
create_clock -add -name sys_clk_pin -period 10.000 -waveform {0 5.000} [get_ports { clk }]

## -----------------------------------------------------------------------------
## 2. Reset Push Button (CPU_RESET, Red Button next to power switch - Active Low)
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN C12 IOSTANDARD LVCMOS33 } [get_ports { rst_n }]

## -----------------------------------------------------------------------------
## 3. Physical CAN Transceiver Header (Pmod Header JA)
##    JA Pin 1 (C17): CAN_TXD (FPGA Output -> Transceiver TXD)
##    JA Pin 2 (D18): CAN_RXD (Transceiver RXD -> FPGA Input, Recessive Idle High)
##    JA Pin 3 (E18): CAN_S   (Transceiver Silent/Standby: 0=Normal, 1=Silent)
##    JA Pin 5: GND, Pin 6: 3V3
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN C17 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports { can_tx }]
set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 PULLUP true }       [get_ports { can_rx }]
set_property -dict { PACKAGE_PIN E18 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 4 } [get_ports { can_s }]

## -----------------------------------------------------------------------------
## 4. Status LEDs (16 On-board LEDs)
##    LED[3:0]   : BSP FSM Numeric State (0=IDLE, 1=SOF, 2=ARB, 3=CTRL, ...)
##    LED[5:4]   : Node Error State (00=Active, 01=Passive, 10=Bus-Off)
##    LED[6]     : IRQ Flag (Active High)
##    LED[7]     : Heartbeat (1 Hz Blink indicating 100MHz clock is active)
##    LED[11:8]  : RX FIFO Count (0..16 messages queued in Block RAM FIFO)
##    LED[15:12] : Transmit Error Counter (TEC[3:0])
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports { led[0] }]
set_property -dict { PACKAGE_PIN K15 IOSTANDARD LVCMOS33 } [get_ports { led[1] }]
set_property -dict { PACKAGE_PIN J13 IOSTANDARD LVCMOS33 } [get_ports { led[2] }]
set_property -dict { PACKAGE_PIN N14 IOSTANDARD LVCMOS33 } [get_ports { led[3] }]
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports { led[4] }]
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports { led[5] }]
set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports { led[6] }]
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports { led[7] }]
set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports { led[8] }]
set_property -dict { PACKAGE_PIN T15 IOSTANDARD LVCMOS33 } [get_ports { led[9] }]
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports { led[10] }]
set_property -dict { PACKAGE_PIN T16 IOSTANDARD LVCMOS33 } [get_ports { led[11] }]
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports { led[12] }]
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports { led[13] }]
set_property -dict { PACKAGE_PIN V12 IOSTANDARD LVCMOS33 } [get_ports { led[14] }]
set_property -dict { PACKAGE_PIN V11 IOSTANDARD LVCMOS33 } [get_ports { led[15] }]

## -----------------------------------------------------------------------------
## 5. Control Switches & Push Buttons
##    SW[0]    (J15): Internal Loopback Mode (1 = Enabled, 0 = Normal Bus)
##    SW[1]    (L16): Reserved / Filter Enable
##    BTNU     (M18): Send Test Frame Button (Triggers single frame transmission)
##    BTNC     (N17): Alternate Reset Button (Active High)
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN J15 IOSTANDARD LVCMOS33 } [get_ports { sw[0] }]
set_property -dict { PACKAGE_PIN L16 IOSTANDARD LVCMOS33 } [get_ports { sw[1] }]
set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports { btn_send }]
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports { btnc }]

## -----------------------------------------------------------------------------
## 6. USB-UART Interface (FT2232HQ Bridge)
##    UART_RXD_OUT (Pin D4) : FPGA TX -> PC RX
##    UART_TXD_IN  (Pin C4) : PC TX -> FPGA RX
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN D4 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports { uart_txd }]
set_property -dict { PACKAGE_PIN C4 IOSTANDARD LVCMOS33 }                   [get_ports { uart_rxd }]

## -----------------------------------------------------------------------------
## 7. Device Configuration Properties (Prevents Vivado DRC Warnings)
## -----------------------------------------------------------------------------
set_property CFGBVS VCCO          [current_design]
set_property CONFIG_VOLTAGE 3.3   [current_design]
