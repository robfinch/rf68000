# rf68000

## Overview
This is a mc68000 similar core. It is not the smallest core, some aspects of the core are not well thought out, but it runs.
It is *not* micro-coded and instead uses a large state machine. Many classes of instructions have their own states.
ALU operations are distributed and there are three separate result lanes for byte, word and long-word operations.
The core may be configured for little-endian operation. The default is for big-endian.
There is some 68010 compatibility. The movec instruction and vector base register are present. Instructions that operate on the status register are restricted to supervisor mode. This is to support virtual machine.
movec was desired to allow access to additional control registers. tick-tick count, coreno-the multi-core core number

## Status
The core fails to complete the test suite dervied from https://github.com/cdifan/cputest. which itself is derived from MicroCoreLabs https://github.com/MicroCoreLabs/Projects/MCL68/MC68000_Test_Code. Known to be a good test of operation of a 68000. It gets about 3/4 of the way through. So there are some bugs yet. Almost all instructions are working. The following instructions are not working correctly: ABCD, SBCD, NBCD, and DIVS. The procedure to handle BCD numbers is to convert to binary, perform the operation, then convert back to BCD. Suspect illegal combinations of BCD digits are working differently.
The core works well enough to run a small monitor program that allows dumping and editing memory.
It is used in a multi-core network-on-chip.

## History
Work started on the core in 2008. It was set aside for a long time, and work resumed in November 2022.

## Supported Bus Interface
The core is *WISHBONE* B.3 master compatible.
Supported cycles: master read/write, master read/modify/write
Address and data bus are both 32-bits wide.

## Size / Performance
Build under Vivado:
approx. 13,000 LUTs (21,000 LC's) without FP, approx <80 MHz max (in -1 part).
No idea how the cycle times compare to a stock 68000, but suspect it may be a little faster due to minimum bus cycle time of two clocks and a 32-bit data bus.
Built under Quartus:
approx. 33,000 LE's without FP, approx <69 MHz fmax.

## Software
The core may use 68000 software. There is a modified 68k vasm assembler. Additional control registers were added for movec.
There are some software examples in the examples folder.

## Instruction Set
The core includes BCD to binary and binary to BCD conversion functions in addition to the standard 68k instructions.

### Floating-Point
The core supports 96-bit triple precision decimal floating-point. The core repurposes the packed BCD floating-point instructions to implement triple precision densely-packed-decimal floating point. This may be
disabled by commenting out the 'SUPPORT_DECFLT' definition to reduce the core
size.
The following floating-point instructions are at least partially supported:
FADD, FSUB, FMUL, FDIV, FNEG, FSCALE, FCMP, FTST, FBcc, FMOVE
Decimal floating-point primitives are found in the ft816float project at
opencores.org.

## System-on-Chip
There is a demo system-on-chip including multiple rf68000 cores connected in a loop.
Pressing Alt-Tab on the keyboard switches between cores.
There is a small monitor program allowing the cores to be tested. TinyBasic is included.
Pressing '?' on the keyboard displays help.

## License
BSD-3

## Other 68k Cores
http://www.opencores.org/project,ao68000
http://www.opencores.org/project,tg68
http://www.experiment-s.de/en
http://www.opencores.org/project,k68
http://www.opencores.org/project,ae68

## Building the Core
To build the core including the decimal floating-point requires modules from the Float repository under the dfpu folder.

Apparently Quartus does not like for statements inside of generate statements that do not habe a begin...end and a statement name.
