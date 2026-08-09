# MiSTle Icepi Carrier

This is a carrier/base board for the [Icepi-Zero](https://github.com/cheyao/icepi-zero).
It adds the FPGA Companion with its USB ports and two classic Dsub9 joystick ports.

The IcePi mounts face down onto the carrier which will then provide the IcePi with an
[RP2350 as FPGA Companion](https://github.com/MiSTle-Dev/FPGA-Companion), two DB9
joystick/mouse ports and a few LEDs.

![With icepi](icepi_carrier.jpg)

> [!WARNING]
> The IcePi Zero needs to be mounted face down. Otherwise the IcePi and/or the carrier
> board may be damaged!

This carrier board is supported by the [Lattice/IcePi port of NanoMig](https://github.com/MiSTle-Dev/NanoMig/tree/main/src/lattice/icepi-zero). 

> [!IMPORTANT]
> The 3.3V voltage regulation of the IcePi is being used for the carrier as well. This means
> that the RP2350 on the carrier will not work without the IcePi installed.

The RP2350 on the IcePi Carrier runs the [PICO2 variant of the FPGA Companion firmware](https://github.com/MiSTle-Dev/FPGA-Companion/tree/main/src/rp2040) which is configured like so:

```
$ cd FPGA-Companion/src/rp2040
$ mkdir build
$ cd build
$ cmake -DBOARD=PICO2 ..
...
$ make
```

The resulting ```fpga_companion.uf2``` can be copied via USB to the Carrier.

![Without icepi](icepi_carrier_empty.jpg)

See the [schematics](icepi_carrier_sch.pdf) and the [board layout](icepi_carrier_pcb.pdf).

![Without icepi](icepi_carrier_pcb.jpg)

## Production

![Render with icepi](icepi_carrier_render.jpg)

![Render without icepi](icepi_carrier_empty_render.jpg)

This board can be manfactured through [JLCPCBs assembly service](http://jlcpcb.com) using the [production data](production). The production data does not include the pin header/socket required to mount the IcePi as this needs to match what's mounted on the IcePi itself.

## History

  - V1.0: Initial version
  - V1.0a: Replaced ws2812b with slightly bigger one with better availability at JLC
  