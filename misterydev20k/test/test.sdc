//Copyright (C)2014-2025 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.12 
//Created Time: 2025-12-04 12:16:37
create_clock -name osc -period 37 -waveform {0 18} [get_ports {clk}]
create_clock -name hdmi -period 8 -waveform {0 4} [get_nets {clk_pixel_x5}]
create_clock -name psram -period 10 -waveform {0 5} [get_nets {clk_psram psram_clk}] -add
