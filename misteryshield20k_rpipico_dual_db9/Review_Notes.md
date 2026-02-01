# Review Notes #

**flaws/mistakes:**

* the arrow symbols for LEDs and TVS are missing
* C10, C11 not grounded well, move the next trace farther away
* move R31 somewhere else

**suggestions for improvement:**

* add a label to the POWER PORT
* add lables to the MIDI port pins on the backside
* change clearance from 0,5 to 0,25mm (minimum is 0,1mm at JLCPCB for 1 oz 2 layer PCBs) for better ground planes
* change debug header to 2x3 pins (RX TX GND) for reduced complexity
* remove OR circuit
* change LED0 = Power (green), LED1 = FDD (yellow), LED2 = HDD (red)
* check resistors for uniform LED brightness 

🔴 Rot 560 Ω
🟠 Orange 510 Ω
🟡 Gelb 470 Ω
🟢 Grün 430 Ω

* check LED / pin assignment
* align Tang & Pi sockets


**fixed/checked already:**

* ortientation of TVS corrected
* the pins of MIDI connector are wired correctly
* 2nd DB9 wired correctly
