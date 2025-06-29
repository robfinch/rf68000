#
PATH = $PATH;D:\cores2022\Thor\software\CC64\cc64\debug;"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.28.29333\bin\Hostx64\x64\bin\Hostx64\x64\"
INC = D:\cores2022\Thor\software\source\;D:\cores2022\Thor\software\FMTK\source\kernel\;D:\cores2022\Thor\software\inc\
INCLUDE = D:\cores2022\Thor\software\source\;D:\cores2022\Thor\software\FMTK\source\kernel\;D:\cores2022\Thor\software\inc\
FPPINC  = D:\cores2022\Thor\software\source\;D:\cores2022\Thor\software\FMTK\source\kernel\;D:\cores2022\Thor\software\inc\
CXX = cc64
#CXX = opt
CFLAGS2 = -c99 -ID:\cores2022\Thor\software\inc\ -O=31
CFLAGS = -w -S -fno-exceptions

LLX = vlink

#

BIOS:
	del boot_rom.bin
	del boot_rom.lst
	del rom1.mem
	del rom2.mem
	del rom3.mem
	del rom4.mem
	del rom5.mem
	del rom6.mem
	del rom7.mem
#	cc64 $(CFLAGS) SieveOfE.c
#	cc64 $(CFLAGS) os_stub.c

	vbccm68k bootrom.c -fpu=68881
	vbccm68k gfx.c -fpu=68881
	vbccm68k sieve.c
#	vbccm68k prtflt.c -fpu=68881
#	vasmrf68000_mot_win32.exe -Fvobj -L fibonacci.lst fibonacci.asm -o fibonacci.o
	vasmrf68000_mot.exe -Fvobj -L lib.lst lib.x68 -o lib.o -m68010 -m68881
	vasmrf68000_mot.exe -Fvobj -L gfx.lst gfx.asm -o gfx.o -m68010 -m68881
	vasmrf68000_mot.exe -Fvobj -L bootrom.lst bootrom.asm -o bootrom.o -m68010 -m68881
	vasmrf68000_mot.exe -Fvobj -L LEDTest.lst LEDTest.asm -o LEDTest.o
	vasmrf68000_mot.exe -Fvobj -L cputest.lst cputest.asm -o cputest.o
	vasmrf68000_mot.exe -Fvobj -L boot.lst boot.x68 -o boot.o -m68010 -m68881
	vasmrf68000_mot.exe -Fvobj -L TestFp.lst TestFp.x68 -o TestFp.o -m68010 -m68881
#	vasmrfPhoenix_std_win32.exe -Fvobj -L add.lst add.asm -o add.o
#	vlink -T rom_bios.cmd -brawbin1 fibonacci.o -o fibonacci.bin
#	vlink -T rom_bios.cmd -brawbin1 LEDTest.o -o LEDTest.bin
#	vlink -T rom_bios.cmd -brawbin1 cputest.o -o cputest.bin

	$(LLX) -T ..\Femtiki\source\Femtiki.cmd -bsrec37 \
		boot.o \
		..\Femtiki\source\kernel\Femtiki_vars.o \
		..\Femtiki\source\kernel\Femtiki_kern.o \
		..\Femtiki\source\kernel\msg.o \
		..\Femtiki\source\kernel\tcb.o \
		..\Femtiki\source\kernel\dbg_console.o \
		..\Femtiki\source\kernel\semaphore.o \
		..\Femtiki\source\kernel\SetupDevices.o \
		..\Femtiki\source\errno.o \
		..\Femtiki\source\ctype.o \
		..\Femtiki\source\localeco.o \
		..\Femtiki\source\signal.o \
		..\Femtiki\source\stdlib.o \
		..\Femtiki\source\stdio.o \
		..\Femtiki\source\string.o \
		..\Femtiki\source\timelib.o \
		..\Femtiki\source\xfloat.o \
		..\Femtiki\source\xvalues.o \
		..\Femtiki\source\xdtento.o \
		..\Femtiki\source\xdunscal.o \
		..\Femtiki\source\xldunsca.o \
		..\Femtiki\source\xdscale.o \
		..\Femtiki\source\xdnorm.o \
		..\Femtiki\source\_lmath.o \
		..\crt\source\crt.o \
		..\crt\source\lib.o \
		..\Femtiki\source\mem_support.o \
		..\Femtiki\source\kernel\femtiki_asm.o \
		..\Femtiki\source\Femtiki2.o -o Femtiki.s37

	$(LLX) -T ..\Femtiki\source\Femtiki.cmd -brawbin1 \
		boot.o \
		..\Femtiki\source\kernel\Femtiki_vars.o \
		..\Femtiki\source\kernel\Femtiki_kern.o \
		..\Femtiki\source\kernel\msg.o \
		..\Femtiki\source\kernel\tcb.o \
		..\Femtiki\source\kernel\dbg_console.o \
		..\Femtiki\source\kernel\semaphore.o \
		..\Femtiki\source\kernel\SetupDevices.o \
		..\Femtiki\source\errno.o \
		..\Femtiki\source\ctype.o \
		..\Femtiki\source\localeco.o \
		..\Femtiki\source\signal.o \
		..\Femtiki\source\stdlib.o \
		..\Femtiki\source\stdio.o \
		..\Femtiki\source\string.o \
		..\Femtiki\source\timelib.o \
		..\Femtiki\source\xfloat.o \
		..\Femtiki\source\xvalues.o \
		..\Femtiki\source\xdtento.o \
		..\Femtiki\source\xdunscal.o \
		..\Femtiki\source\xldunsca.o \
		..\Femtiki\source\xdnorm.o \
		..\Femtiki\source\xdscale.o \
		..\Femtiki\source\_lmath.o \
		..\crt\source\crt.o \
		..\crt\source\lib.o \
		..\Femtiki\source\mem_support.o \
		..\Femtiki\source\kernel\femtiki_asm.o \
		..\Femtiki\source\Femtiki2.o -o Femtiki.bin

		bin2ver Femtiki.bin 32 m
		copy rom.mem rom1.mem
		copy rom.mem rom2.mem
		copy rom.mem rom3.mem
		copy rom.mem rom4.mem
		copy rom.mem rom5.mem
		copy rom.mem rom6.mem
		copy rom.mem rom7.mem
		copy rom.mem rom68k.mem

#	vlink -T ..\Femtiki\source\Femtiki.cmd -bsrec37 boot.o -o boot.s37
#	vlink -T bios.cmd -bsrec37 TestFp.o lib.o -o TestFp.s37
	
	
#	vlink -T ..\Femtiki\source\Femtiki.cmd -brawbin1 boot.o ..\Femtiki\source\Femtiki.o -o boot.bin
	vlink -T bios.cmd -bsrec37 bootrom.o lib.o gfx.o -o bootrom.s37
#	vlink -T rom_bios.cmd -brawbin1 add.o -o add.bin
#	bin2ver fibonacci.bin 128
#	bin2ver LEDTest.bin 32 m
#	bin2ver boot.bin 32 m
#	copy rom.mem rom1.mem
#	copy rom.mem rom2.mem
#	copy rom.mem rom3.mem
#	copy rom.mem rom4.mem
#	copy rom.mem rom5.mem
#	copy rom.mem rom6.mem
#	copy rom.mem rom7.mem
#	bin2ver cputest.bin 32 m
#	bin2ver add.bin 128

