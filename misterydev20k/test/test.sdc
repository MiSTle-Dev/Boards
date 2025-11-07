//Copyright (C)2014-2025 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.12 
//Created Time: 2025-11-06 08:40:31
create_clock -name osc -period 37.037 -waveform {0 18.518} [get_ports {clk}]
create_clock -name hdmi -period 8 -waveform {0 4} [get_nets {clk_pixel_x5}]
