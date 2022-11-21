# rf68000

## Overview
This is a mc68000 similar core. It is not the smallest core, some aspects of the core are not well thought out, but it runs.
It is *not* micro-coded and instead uses a large state machine. Many classes of instructions have their own states.
ALU operations are distributed and there are three separate result lanes for byte, word and long-word operations.
The core may be configured for little-endian operation. The default is for big-endian.
There is some 68010 compatibility. The movec instruction and vector base register are present. Instructions that operate on the status register are restricted to supervisor mode.
movec was desired to allow access to additional control registers. tick-tick count, coreno-the multi-core core number

## Status
The core fails to complete the test suite dervied from https://github.com/cdifan/cputest. which itself is derived from MicroCoreLabs https://github.com/MicroCoreLabs/Projects/MCL68/MC68000_Test_Code It gets about 3/4 of the way through. So there are some bugs yet. Most common instructions are working. The following instructions are not working correctly: ABCD, SBCD, NBCD, and DIVS.
The core works well enough to run a small monitor program that allows dumping and editing memory.
It is used in a multi-core network-on-chip.

## History
Work started on the core in 2008. It was set aside for a long time, and work resumed in November 2022.

## Supported Bus Interface
The core is *WISHBONE* B.3 master compatible.
Supported cycles: master read/write, master read/modify/write
Address and data bus are both 32-bits wide.

## Size / Performance
approx. 13,000 LUTs, approx 80 MHz max (in -1 part).
No idea how the cycle times compare to a stock 68000, but suspect it may be a little faster due to minimum bus cycle time of two clocks and a 32-bit data bus.

## Software
The core may use 68000 software. There is a modified 68k vasm assembler. Additional control registers were added for movec.
There are some software examples in the examples folder.

## License
BSD-3

## Other 68k Cores
http://www.opencores.org/project,ao68000
http://www.opencores.org/project,tg68
http://www.experiment-s.de/en
http://www.opencores.org/project,k68
http://www.opencores.org/project,ae68
