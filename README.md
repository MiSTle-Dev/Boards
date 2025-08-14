The MiSTle projects can be used with off-the-shelf components and
some breadboard setup.

To simplify this the MiSTeryNano project provides additional custom designed hardware boards.

## Shields
Shields are carrier boards that carry one or more off-the-shelf development boards, connect them and provide them with additional peripherals like USB Hubs, MIDI ports, Joystick ports etc.

  - The [MiSTeryShield20k](misteryshield20k) is a base board for
  the Tang Nano 20k and the M0S Dock with a DB9 joystick connector and
  MIDI ports
  - [MiSTeryShield20k RPiPico](misteryshield20k_rpipico) is a board similar to the
  [MiSTeryShield20k](misteryshield20k) but using a Raspberry Pi Pico instead of the M0S Dock and with a USB hub already built-in
  - The [MiSTeryShield20k lite](misteryshield20k_lite) is also a base
  board for the Tang Nano 20k. It includes the RP2040 and a USB-A
  port and is a minimal all-in-one solution for the Tang Nano 20k.

## MCU PMOD's

Many FPGA boards privide so-called PMOD ports. These can be used to add the FPGA Companion MCU to those boards. The
MCU PMOD's provide a PMOD connector to common MCU developments boards and makes them compatible with typical FPGA PMOD ports.

FPGA baords providing PMOD ports are include the Tang Primer 20K, Primer 25K, Mega 60k/138K NEO, Mega138kPro and Console 60k/138k

  - The [PMOD M0S](m0s_pmod) provides a PMOD port for the M0S Dock (BL616 µC)
  - The [PMOD PiPico](pipico_pmod) provides a PMOD port for Raspberry Pi Pico and (W)ifi
  - The [PMOD PiZero](pizero_pmod) provides a PMOD port for Raspberry Pi Pico compatible RP2040-ZERO board

## Other boards
  
  - The [T20 PMOD](t20_pmod) is an add-on for the Efinix T20BGA256 development board adding a PMOD for HDMI usage, the SD card slot and a Raspberry Pi PICO incl. USB-A header to it making it a complete MiSTeryNano setup.
  - The [Atari ST Keyboard](atarist_keyboard) design is a tiny 50% Atari ST style keyboard which is meant to become the basis for a Mini Atari ST
  - [MisteryShield20k DS2 Adapter](misteryshield20k_ds2_adapter) is an add-on for the [MiSTeryShield20k](misteryshield20k) allowing to connect Playstation Dualshock 2 Game controllers to it

## Complete stand-alone solutions

  - The [MiSTeryDev20k](misterydev20k) is meant to become a
  first test of a complete all-in-one board for the GW2AR-LV18 FPGA
  (the same one as on the Tang Nano 20k).

## Related projects

Further hardware is available in related projects:

  - [MisteryNano Case](https://github.com/prcoder-1/MiSTeryNano-Case) is a 3d printable case design for the bare Tang Nano 20k (no shields) with room and mounting instructions for expansion connectors and an optional M0S Dock
  
