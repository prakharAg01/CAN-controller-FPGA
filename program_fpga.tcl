open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target
current_hw_device [get_hw_devices xc7a100t_0]
refresh_hw_device -update_hw_probes false [lindex [get_hw_devices xc7a100t_0] 0]
set_property PROBES.FILE {} [get_hw_devices xc7a100t_0]
set_property FULL_PROBES.FILE {} [get_hw_devices xc7a100t_0]
set_property PROGRAM.FILE {e:/MajorProject/can_top/can_top.runs/impl_1/nexys4_can_top.bit} [get_hw_devices xc7a100t_0]
program_hw_devices [get_hw_devices xc7a100t_0]
refresh_hw_device [lindex [get_hw_devices xc7a100t_0] 0]
puts "=== FPGA PROGRAMMED SUCCESSFULLY ==="
close_hw_target
disconnect_hw_server
close_hw_manager
exit
