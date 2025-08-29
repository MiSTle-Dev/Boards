# MiSTeryDev20k

This is a work-in-prigress abd will be the first prototype of a
complete custom board which will not be needing daughter boards
like the Tang Nano 20k and the Raspberry Pi Pico.

![Rendering](misterydev20k_board.jpg)

The main objective of this board is to run known-good cores and
firmware and test a few features that couldn't be implemented and
tested with the Tang Nano 20k. These include:

  - Use the RP2040 for JTAG programming of the FPGA
  - Access the SD card from the RP2040 as well
    - Boot the FPGA from SD card
  - Optionally use the RP2040's native USB via the USB Hub

Further minor changes over the existing boards are:

  - Two DB9 joysticks
  - MIDI on M5 Stack connector

[Schematic PDF](misterydev20k_sch.pdf)