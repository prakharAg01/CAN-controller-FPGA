## Clock
set_property PACKAGE_PIN E3 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.000 -waveform {0 5} [get_ports clk]

## Input switch
set_property PACKAGE_PIN J15 [get_ports data_sw]
set_property IOSTANDARD LVCMOS33 [get_ports data_sw]

## Buttons
set_property PACKAGE_PIN N17 [get_ports rst_btn_raw]
set_property IOSTANDARD LVCMOS33 [get_ports rst_btn_raw]

set_property PACKAGE_PIN M18 [get_ports step_btn_raw]
set_property IOSTANDARD LVCMOS33 [get_ports step_btn_raw]

## CRC LEDs
set_property PACKAGE_PIN H17 [get_ports {led_crc[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_crc[0]}]

set_property PACKAGE_PIN K15 [get_ports {led_crc[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_crc[1]}]

set_property PACKAGE_PIN J13 [get_ports {led_crc[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_crc[2]}]

set_property PACKAGE_PIN N14 [get_ports {led_crc[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_crc[3]}]

set_property PACKAGE_PIN R18 [get_ports {led_crc[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_crc[4]}]

set_property PACKAGE_PIN V17 [get_ports {led_crc[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_crc[5]}]

set_property PACKAGE_PIN U17 [get_ports {led_crc[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_crc[6]}]

set_property PACKAGE_PIN U16 [get_ports {led_crc[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_crc[7]}]

set_property PACKAGE_PIN V16 [get_ports {led_crc[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_crc[8]}]

set_property PACKAGE_PIN T15 [get_ports {led_crc[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_crc[9]}]

set_property PACKAGE_PIN U14 [get_ports {led_crc[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_crc[10]}]

set_property PACKAGE_PIN T16 [get_ports {led_crc[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_crc[11]}]

set_property PACKAGE_PIN V15 [get_ports {led_crc[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_crc[12]}]

set_property PACKAGE_PIN V14 [get_ports {led_crc[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_crc[13]}]

set_property PACKAGE_PIN V12 [get_ports {led_crc[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_crc[14]}]

## Activity LED = LED15
set_property PACKAGE_PIN V11 [get_ports led_activity]
set_property IOSTANDARD LVCMOS33 [get_ports led_activity]