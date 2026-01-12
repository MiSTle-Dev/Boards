set_device GW5AT-LV60PG484AC1/I0 -device_version B

add_file src/gowin_pll/gowin_pll.v
add_file src/gowin_pll/gowin_pll_mod.v
add_file src/pll_init.v
add_file GW_JTAG.v
add_file font.v
add_file hdmi/audio_clock_regeneration_packet.sv
add_file hdmi/audio_info_frame.sv
add_file hdmi/audio_sample_packet.sv
add_file hdmi/auxiliary_video_information_info_frame.sv
add_file hdmi/hdmi.sv
add_file hdmi/packet_assembler.sv
add_file hdmi/packet_picker.sv
add_file hdmi/serializer.sv
add_file hdmi/source_product_description_info_frame.sv
add_file hdmi/tmds_channel.sv
add_file top.sv
add_file test.cst
add_file test.sdc

set_option -synthesis_tool gowinsynthesis
set_option -output_base_name test
set_option -verilog_std sysv2017
set_option -vhdl_std vhd2008
set_option -loading_rate 70.000
set_option -top_module top
set_option -bit_compress 1
set_option -use_mspi_as_gpio 1
set_option -use_sspi_as_gpio 1
set_option -use_done_as_gpio 1
set_option -use_cpu_as_gpio 1
set_option -use_ready_as_gpio 1
set_option -use_i2c_as_gpio 1
set_option -use_jtag_as_gpio 0
set_option -user_code 00000001

run all
