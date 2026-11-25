open_project e:/MajorProject/can_top/can_top.xpr
add_files -norecurse e:/MajorProject/can_top/can_top.srcs/sources_1/new/uart_tx.sv
add_files -norecurse e:/MajorProject/can_top/can_top.srcs/sources_1/new/uart_rx.sv
add_files -norecurse e:/MajorProject/can_top/can_top.srcs/sources_1/new/can_uart_gateway.sv
update_compile_order -fileset sources_1
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
puts "=== DAY 38 BITSTREAM GENERATION COMPLETED ==="
exit
