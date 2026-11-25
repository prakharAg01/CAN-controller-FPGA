open_project e:/MajorProject/can_top/can_top.xpr
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
puts "=== BITSTREAM GENERATION COMPLETED ==="
exit
