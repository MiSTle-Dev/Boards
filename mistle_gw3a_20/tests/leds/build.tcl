set_device GW5A-LV25LQ144C1/I0 -name GW5A-25A

add_file leds.v
add_file ws2812.v
add_file leds.cst

set_option -synthesis_tool gowinsynthesis
set_option -output_base_name leds
set_option -verilog_std sysv2017
set_option -top_module top
set_option -cst_warn_to_error 1
set_option -multi_boot 0
set_option -mspi_jump 0
set_option -bit_compress 0

run all
