# GW3A-LV20 MiSTle developent board

This board is meant to be a development board to run the upcoming
[GW3A-LV20 FPGA](https://www.gowinsemi.com/en/product/detail/84/) with
the MiSTle retro computing cores. The NanoMig has already [been
prepared](https://github.com/MiSTle-Dev/NanoMig/tree/main/src/mistle/gw3a_20)
to ensure that the cores can be synthesized and especially to verify
the pin mapping.

![Rendering](mistle_gw3a_20_render.jpeg)

## Current state

  - Initial schematic and board derived from the [MiSTeryDev20k board](https://github.com/MiSTle-Dev/Boards/tree/main/misterydev20k)
  - [NanoMig](https://github.com/MiSTle-Dev/NanoMig) core [synthesized for GW3A-LV20](https://github.com/MiSTle-Dev/NanoMig/tree/main/src/mistle/gw3a_20) :heavy_check_mark:
    - LUT usage around 80%
  - Schematic updates
    - GW2AR-LV18 FPGA replaced by GW3A-LV20 :heavy_check_mark:
    - Updated pin mapping :heavy_check_mark:
    - Added external 64MBit (16M*16) SDRAM as the GW3A-LV20 has no internal SDRAM :heavy_check_mark: 
    - External peripherals mapped :heavy_check_mark:
    - Update FPGA Power Supply :heavy_check_mark:
    - Add smoothing capacitors and similar :heavy_check_mark:
    - Initial routing :heavy_check_mark:
    - Verify schematic :wrench:
    - Verify pcb
    - Update JLCPCB part numbers
    - Order

## Preliminary schematic

The schematic is a work in progress and can be viewed [here](https://github.com/MiSTle-Dev/Boards/blob/main/mistle_gw3a_20/mistle_gw3a_20_sch.pdf).