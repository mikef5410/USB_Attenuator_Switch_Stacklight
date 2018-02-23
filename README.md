## USB_Attenuator_Switch_Stacklight

USB control of HP step attenuators, Coax Switches, and Stacklights.
Related project: [my USB Dual SPDT project](https://github.com/mikef5410/USB_SPDT)

![USB Microwave Attenuator](/doc/usb_atten.jpg)

This project is an STM32F411 based USB controller, originally for scavanged HP
microwave step attenuators, but I've also used it to control microwave coax
switches and a stacklight at my desk.

The hardware design files are in doc/

This device uses FreeRTOS, and implements two interfaces on the bus...

1. A CDC-ACM interface with a simple commandline monitor
2. A simple COMMAND-RESPONSE packet interface on bulk endpoints 0x1/0x81. It's
this interface that the perl code in perl/ and perl/test talks to. It's made to
be machine-machine.

The board has a USB 5V->12 or 24V step-up converter. The old HP attenuators I
have use 24V, my switches and stacklight use 12V. Change a resistor in the
DC-DC converter according to your intended use.

It's just a USB->GPIO device with some high voltage switching ability. FET
switches can be loaded for high-side or low-side switching, because you never
know what you're going to scavange. See the schematic.

The controller consults EEprom for USB identifying material, so one board and
software load can fit many uses.

After cloning, run the bootstrap script to get the required submodules.

So, here's an example of a stacklight:

![Stacklight](/doc/stacklight.jpg)

And, running a couple of Dow-Key SP8T's and Dow-Key SPDT's through a breakout
board:

![coaxSwitches](/doc/coaxSwitches.jpg)
