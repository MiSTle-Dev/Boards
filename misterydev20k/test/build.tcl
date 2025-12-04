set_device GW2AR-LV18QN88C8/I7 -name GW2AR-18C

add_file GW_JTAG.v
add_file pll_125m.v
add_file pll_psram.v
add_file clkdiv5.v
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
add_file ws2812.v
add_file test.cst
add_file test.sdc

set_option -synthesis_tool gowinsynthesis
set_option -output_base_name test
set_option -verilog_std sysv2017
set_option -loading_rate 25.000
set_option -top_module top
set_option -bit_compress 1

run all
