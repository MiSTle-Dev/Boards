set_device GW5A-LV25LQ144C1/I0 -name GW5A-25A

add_file top.sv
add_file clkdiv5.v
add_file pll_125m.v
add_file pll_125m_mod.v
add_file pll_init.v
add_file hdmi/audio_clock_regeneration_packet.sv
add_file hdmi/audio_sample_packet.sv
add_file hdmi/hdmi.sv
add_file hdmi/packet_picker.sv
add_file hdmi/source_product_description_info_frame.sv
add_file hdmi/audio_info_frame.sv
add_file hdmi/auxiliary_video_information_info_frame.sv
add_file hdmi/packet_assembler.sv
add_file hdmi/serializer.sv
add_file hdmi/tmds_channel.sv
add_file hdmi.cst

set_option -synthesis_tool gowinsynthesis
set_option -output_base_name hdmi
set_option -verilog_std sysv2017
set_option -top_module top
set_option -cst_warn_to_error 1
set_option -multi_boot 0
set_option -mspi_jump 0
set_option -bit_compress 0

run all
