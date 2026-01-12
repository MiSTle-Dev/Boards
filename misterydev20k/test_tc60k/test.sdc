//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.12 (64-bit) 
//Created Time: 2026-01-12 09:46:59
create_clock -name osc -period 20 -waveform {0 10} [get_ports {clk}]
create_clock -name hdmi -period 8 -waveform {0 4} [get_nets {clk_pixel_x5}]
