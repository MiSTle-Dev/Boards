# MiSTeryDev20k

This is a work-in-progress and it will be the first prototype of a
complete custom board which will not be needing daughter boards
like the Tang Nano 20k or the Raspberry Pi Pico.

![Rendering](misterydev20k_board.jpg)

The main objective of this board is to run known-good cores and
firmware and test a few features that couldn't be implemented and
tested with the Tang Nano 20k. These include:

  - Use the RP2040 for JTAG programming of the FPGA
  - Additional access to the SD card directly from the RP2040
    - Boot the FPGA from SD card
  - Optionally use the RP2040's native USB via the USB Hub

Further minor changes over the existing boards are:

  - Two DB9 joysticks
  - MIDI on M5 Stack connector

[Schematic PDF](misterydev20k_sch.pdf)
[Layout PDF](misterydev20k_board.pdf)	

## Current state

  - Schematic :white_check_mark:
  - Initial PCB layout :white_check_mark:
  - LCSC part mapping :x:
  - BOM verification :x:
  - Final PCB layout :x:
  - FPGA stock :x:
  - Manufacture :x:
  - Test :x:
