## ============================================================
## Nexys 4 DDR - CAN bit stuffing demo
## FPGA: xc7a100tcsg324-1
## ============================================================

## 100 MHz system clock
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports {clk}]
create_clock -add -name sys_clk_pin -period 10.000 -waveform {0 5} [get_ports {clk}]

## Switches
## SW0 -> mode_sw
set_property -dict { PACKAGE_PIN J15 IOSTANDARD LVCMOS33 } [get_ports {mode_sw}]

## SW1 -> data_sw
set_property -dict { PACKAGE_PIN L16 IOSTANDARD LVCMOS33 } [get_ports {data_sw}]

## Buttons
## BTN center -> reset
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports {rst_btn_raw}]

## BTN up -> manual step
set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports {step_btn_raw}]

## LEDs
## LED0 -> heartbeat
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports {led_heartbeat}]

## LED1 -> bit_out
set_property -dict { PACKAGE_PIN K15 IOSTANDARD LVCMOS33 } [get_ports {led_bit_out}]

## LED2 -> stuffing
set_property -dict { PACKAGE_PIN J13 IOSTANDARD LVCMOS33 } [get_ports {led_stuffing}]

## LED3 -> stuff_pending
set_property -dict { PACKAGE_PIN N14 IOSTANDARD LVCMOS33 } [get_ports {led_stuff_pending}]

## LED4 -> recovered bit
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports {led_recovered}]

## LED5 -> PASS
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports {led_pass}]

## LED6 -> ERROR
set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports {led_error}]