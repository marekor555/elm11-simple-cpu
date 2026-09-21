create_project -name "build" -dir . -pn "GW1NR-LV9QN88PC7/I6" -device_version "C" -force

set_option -verilog_std sysv2017
set_option -top_module top

add_file "../src/top.sv"
add_file "../src/pins.cst"

run all