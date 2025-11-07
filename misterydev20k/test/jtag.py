#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from pyftdi.jtag import JtagEngine
from pyftdi.bits import BitSequence

def detect_fpga(jtag):
    jtag.change_state('shift_dr')
    out = jtag.shift_and_update_register(BitSequence('1'*32))
    print(f'idcode: 0x{int(out):08x}')
    return int(out) == 0x81b

def enter_user_cmd(jtag):
    # enter user1 command (0x42) into JTAG ir
    jtag.change_state('shift_ir')
    jtag.shift_and_update_register(BitSequence(0x42, msb=True, length=8))

def send_user1_text(jtag, str):
    print("Sending:", str.strip("\n"))
    
    # append some zero bytes, so the FPGA gets a chance to react on the last character
    str += "\0"*10
    
    # prepare tranmission into data register
    jtag.change_state('shift_dr')
    bits = BitSequence(bytes_=str.encode("latin1"), msb=True)
    out = jtag.shift_and_update_register(bits)

    # check for non-zero bytes in the reply and print them
    print("Received:", ''.join([chr(char) if char else '' for char in out.tobytes(msby=True)]).strip("\n"))
    # jtag.go_idle()
        
if __name__ == '__main__':
    # gowin has JTAG on ft2232 port a
    jtag = JtagEngine(trst=True, frequency=1E6)
    jtag.configure('ftdi://ftdi:2232h/1')
    jtag.reset()
    jtag.go_idle()

    if not detect_fpga(jtag):
        print("No GW2AR-LV18 FPGA detected")
    else:
        enter_user_cmd(jtag)
        send_user1_text(jtag, "This text is being sent via JTAG\n")
