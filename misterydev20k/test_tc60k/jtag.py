#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from pyftdi.jtag import JtagEngine
from pyftdi.bits import BitSequence
import time

def detect_fpga(jtag):
    jtag.change_state('shift_dr')
    out = jtag.shift_and_update_register(BitSequence('1'*32))
    print(f'idcode: 0x{int(out):08x}')
    return int(out) == 0x81b

def set_cmd(jtag, cmd):
    jtag.change_state('shift_ir')
    jtag.shift_and_update_register(BitSequence(cmd, length=8))

def setup_cmd(jtag, cmd, addr = None, extra = None):
    jtag.change_state('shift_dr')
    jtag.shift_register(BitSequence(cmd, length=8))
    if addr != None: jtag.shift_register(BitSequence(addr[0], length=addr[1]))
    if extra != None: jtag.shift_register(BitSequence(None, length=extra))
        
def data_tx(jtag, data, len=None):
    if isinstance(data, bytearray):
        jtag.shift_and_update_register(BitSequence(bytes_=data))
    else:
        jtag.shift_and_update_register(BitSequence(data, length=len))

def data_rx(jtag, len=8):
    rx = jtag.shift_and_update_register(BitSequence(None, length=len))
    return rx.tobytes(msby=True)

def text(jtag, str):
    print("Sending:", str.strip("\n"))
    
    # append some zero bytes, so the FPGA gets a chance to react on the last character
    str += "\0"*10
    
    # prepare tranmission into data register
    jtag.change_state('shift_dr')
    bits = BitSequence(bytes_=str.encode("latin1"), msb=False)
    out = jtag.shift_and_update_register(bits)
    
    # check for non-zero bytes in the reply and print them
    print("Received:", ''.join([chr(char) if char else '' for char in out.tobytes(msby=True)]).strip("\n"))
    
def hexdump(data: bytes, extra_offset=0):
    def to_printable_ascii(byte):
        return chr(byte) if 32 <= byte <= 126 else "."

    offset = 0
    while offset < len(data):
        chunk = data[offset : offset + 16]
        hex_values = " ".join(f"{byte:02x}" for byte in chunk)
        ascii_values = "".join(to_printable_ascii(byte) for byte in chunk)
        print(f"{offset+extra_offset:08x}  {hex_values:<48}  |{ascii_values}|")
        offset += 16
    
if __name__ == '__main__':
    # gowin has JTAG on ft2232 port a
    jtag = JtagEngine(trst=True, frequency=1E6)
    jtag.configure('ftdi://ftdi:2232h/1')
    jtag.reset()
    jtag.go_idle()

    if not detect_fpga(jtag):
        print("No GW2AR-LV18 FPGA detected")
    else:
        # --- gao#1/0x42 is used for text IO ---
        set_cmd(jtag, 0x42)
        text(jtag, "This text is being sent via JTAG\n")

        # --- gao#2/0x43 is used for debug IO ---
        set_cmd(jtag, 0x43)

        # drive leds on/off/on/off/on/off, rgb white
        setup_cmd(jtag, 1)
        data_tx(jtag, 0xd5404040, 32)

        print("==== PSRAM tests ====")
        
        # read 32 bit SPI PSRAM status
        setup_cmd(jtag, 2)
        status = data_rx(jtag, 32)
        if not (status[0] & 0x80): print("PSRAM is not ready")
        else:
            print("PSRAM is ready")
            if not (status[0] & 0x40): print("PSRAM not ok")
            if status[0] & 0x20: print("PSRAM busy")
            if status[0] & 0x1f: print("PSRAM status invalid")
            print("PSRAM vendor:", hex(status[1]), "(should be 0x0d)")
            print("PSRAM JTAG transfer length:", status[2], "bytes")

            # write 32 bytes / 256 bits test data
            LEN=32
            data = bytearray([0x12,0x34,0x56,0x78,0x9a,0xbc,0xde,0xf0,0x12,0x34,0x56,0x78,0x9a,0xbc,0xde,0xf0,
                              0x00,0x11,0x22,0x33,0x44,0x55,0x66,0x77,0x88,0x99,0xaa,0xbb,0xcc,0xdd,0xee,0xff ])
            # data = 0xffeeddccbbaa99887766554433221100fe
            mask = (1 << (8*status[2]))-1

            for i in range(len(data)//status[2]):
                setup_cmd(jtag, 4, (status[2]*i,24))
                data_tx(jtag, data[i*status[2]:(i+1)*status[2]])

            # read one row once
            for i in range(len(data)//status[2]):
                setup_cmd(jtag, 3, (status[2]*i,24), 8)
                hexdump(data_rx(jtag, 8*status[2]), status[2]*i)

            print()
                
            # read 512 bytes of SPI PSRAM data
            for i in range(512//status[2]):
                # Send command, address and 8 extra data bits.
                # We need to send 8 extra bits in a seperate transfer to give PSRAM some
                # time to react. The problem is that the first reply bit is already prepared
                # with the last bit of the previous transfer. The PSRAM does not have enough
                # time to react when this is being sent with the address bits. This was true
                # with serial SPI at 25Mhz and may have changed with QPI at 100Mhz.
                setup_cmd(jtag, 3, (status[2]*i,24), 8)
                hexdump(data_rx(jtag, 8*status[2]), status[2]*i)

            # TODO: Extensive ram test
