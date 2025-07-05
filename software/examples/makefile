#
#PATH = $PATH;D:\cores2022\Thor\software\CC64\cc64\debug;"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.28.29333\bin\Hostx64\x64\bin\Hostx64\x64\"
#INC = D:\cores2022\Thor\software\source\;D:\cores2022\Thor\software\FMTK\source\kernel\;D:\cores2022\Thor\software\inc\
#INCLUDE = D:\cores2022\Thor\software\source\;D:\cores2022\Thor\software\FMTK\source\kernel\;D:\cores2022\Thor\software\inc\
#FPPINC  = D:\cores2022\Thor\software\source\;D:\cores2022\Thor\software\FMTK\source\kernel\;D:\cores2022\Thor\software\inc\
PATH1 = "C:/Users/Robert/OneDrive/documents/Cores2025/rf68000/software/"
PATH2 = "C:\Users\Robert\OneDrive\documents\Cores2025\rf68000\software\c_standard_lib-master\assert\"
PATH = $PATH;$(PATH1)"Femtiki/source/";$(PATH1)"Femtiki/source/kernel/";"F:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.29.30133\bin\Hostx64\x64"
INC1 = "C:/Users/Robert/OneDrive/documents/Cores2025/rf68000/software/c_standard_lib-master/_Femtiki/"
FEMTIKI_INC = "C:/Users/Robert/OneDrive/documents/Cores2025/rf68000/software/Femtiki/source/inc/"
INC = $(INC1)
#;$(FEMTIKI_INC)
INCLUDE = $(INC1)	
CXX = cc64
#CXX = opt
AFLAGS = -Fvobj -m68010 -m68881
CFLAGS2 = -c99 -ID:\cores2022\Thor\software\inc\ -O=31
#CFLAGS = -w -S -fno-exceptions
CFLAGS = -I$(INC) -fpu=68881

CCX = vbccm68k
LLX = vlink
AAX = vasmrf68000_mot

.SUFFIXES:	.x68

.x68.o:
	$(AAX) $(AFLAGS) $<

DRIVER_ASMS = \
	../Femtiki/source/drivers/null.x68 \
	../Femtiki/source/drivers/err.x68 \
	../Femtiki/source/drivers/keybd.x68 \
	../Femtiki/source/drivers/textvid.x68 \
	../Femtiki/source/drivers/framebuf.x68 \
	../Femtiki/source/drivers/gfxaccel.x68 \
	../Femtiki/source/drivers/audio.x68 \
	../Femtiki/source/drivers/serial.x68 \
	../Femtiki/source/drivers/random.x68 \
	../Femtiki/source/drivers/rtc.x68 \
	../Femtiki/source/drivers/pic.x68

DRIVERS = \
	../Femtiki/source/drivers/null.o \
	../Femtiki/source/drivers/err.o \
	../Femtiki/source/drivers/keybd.o \
	../Femtiki/source/drivers/textvid.o \
	../Femtiki/source/drivers/framebuf.o \
	../Femtiki/source/drivers/gfxaccel.o \
	../Femtiki/source/drivers/audio.o \
	../Femtiki/source/drivers/serial.o \
	../Femtiki/source/drivers/random.o \
	../Femtiki/source/drivers/rtc.o \
	../Femtiki/source/drivers/pic.o

#..\Femtiki\source\drivers\drivers.o: $(DRIVERS)
#	$(AAX) $(AFLAGS) -L ../Femtiki/source/drivers/pic.lst ../Femtiki/source/drivers/pic.x68 -o ../Femtiki/source/drivers/pic.o
#	$(AAX) $(AFLAGS) -L ../Femtiki/source/drivers/audio.lst ../Femtiki/source/drivers/audio.x68 -o ../Femtiki/source/drivers/audio.o
#	$(AAX) $(AFLAGS) -L ../Femtiki/source/drivers/err.lst ../Femtiki/source/drivers/err.x68 -o ../Femtiki/source/drivers/err.o
#	$(AAX) $(AFLAGS) -L ../Femtiki/source/drivers/serial.lst ../Femtiki/source/drivers/serial.x68 -o ../Femtiki/source/drivers/serial.o
#	$(AAX) $(AFLAGS) -L ../Femtiki/source/drivers/rtc.lst ../Femtiki/source/drivers/rtc.x68 -o ../Femtiki/source/drivers/rtc.o
#	$(LLX) -T ..\Femtiki\source\Femtiki.cmd \
#	../Femtiki/source/drivers/null.o \
#	../Femtiki/source/drivers/err.o \
#	../Femtiki/source/drivers/keybd.o \
#	../Femtiki/source/drivers/textvid.o \
#	../Femtiki/source/drivers/framebuf.o \
#	../Femtiki/source/drivers/gfxaccel.o \
#	../Femtiki/source/drivers/audio.o \
#	../Femtiki/source/drivers/serial.o \
#	../Femtiki/source/drivers/rtc.o \
# ../Femtiki/source/drivers/pic.o \
# -o drivers.o

OUT = \
	boot.o \
	DumpTasks.o \
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
	..\Femtiki\source\drivers\null.o \
	..\Femtiki\source\drivers\keybd.o \
	..\Femtiki\source\drivers\textvid.o \
	..\Femtiki\source\drivers\framebuf.o \
	..\Femtiki\source\drivers\gfxaccel.o \
	..\Femtiki\source\drivers\serial.o \
	..\Femtiki\source\drivers\random.o \
	..\Femtiki\source\drivers\pic.o \
	..\Femtiki\source\kernel\femtiki_asm.o \
	..\Femtiki\source\Femtiki2.o

$(OUT):	$(ASMS)
	$(AAX) $(AFLAGS) ..\Femtiki\source\drivers\null.x68 -L ..\Femtiki\source\drivers\null.lst -o ..\Femtiki\source\drivers\null.o
	$(AAX) $(AFLAGS) ..\Femtiki\source\drivers\keybd.x68 -L ..\Femtiki\source\drivers\keybd.lst -o ..\Femtiki\source\drivers\keybd.o
	$(AAX) $(AFLAGS) ..\Femtiki\source\drivers\textvid.x68 -L ..\Femtiki\source\drivers\textvid.lst -o ..\Femtiki\source\drivers\textvid.o
	$(AAX) $(AFLAGS) ..\Femtiki\source\drivers\framebuf.x68 -L ..\Femtiki\source\drivers\framebuf.lst -o ..\Femtiki\source\drivers\framebuf.o
	$(AAX) $(AFLAGS) ..\Femtiki\source\drivers\gfxaccel.x68 -L ..\Femtiki\source\drivers\gfxaccel.lst -o ..\Femtiki\source\drivers\gfxaccel.o
	$(AAX) $(AFLAGS) ..\Femtiki\source\drivers\serial.x68 -L ..\Femtiki\source\drivers\serial.lst -o ..\Femtiki\source\drivers\serial.o
	$(AAX) $(AFLAGS) ..\Femtiki\source\drivers\random.x68 -L ..\Femtiki\source\drivers\random.lst -o ..\Femtiki\source\drivers\random.o
	$(AAX) $(AFLAGS) ..\Femtiki\source\drivers\pic.x68 -L ..\Femtiki\source\drivers\pic.lst -o ..\Femtiki\source\drivers\pic.o
	$(AAX) $(AFLAGS) ..\Femtiki\source\mem_support.x68 -L ..\Femtiki\source\mem_support.lst -o ..\Femtiki\source\mem_support.o
	
	
BIOS:	$(OUT)
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

	$(CCX) $(CFLAGS) bootrom.c
	vbccm68k gfx.c -fpu=68881
	vbccm68k sieve.c
#	vbccm68k prtflt.c -fpu=68881
#	vasmrf68000_mot_win32.exe -Fvobj -L fibonacci.lst fibonacci.asm -o fibonacci.o
	vasmrf68000_mot.exe -Fvobj -L ..\crt\source\lib.lst ..\crt\source\lib.x68 -o ..\crt\source\lib.o -m68010 -m68881
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

	vbccm68k $(CFLAGS) DumpTasks.c
	vasmrf68000_mot.exe -Fvobj -L DumpTasks.lst DumpTasks.asm -o DumpTasks.o -m68010 -m68881
	$(LLX) -MFemtiki.map -T ..\Femtiki\source\Femtiki.cmd -bsrec37 $(OUT) -o Femtiki.s37
	$(LLX) -MFemtiki.map -T ..\Femtiki\source\Femtiki.cmd -brawbin1 $(OUT) -o Femtiki.bin

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
	
	$(AAX) $(AFLAGS) ..\Femtiki\source\drivers\null.x68 -L ..\Femtiki\source\drivers\null.lst -o ..\Femtiki\source\drivers\null.o
	$(AAX) $(AFLAGS) ..\Femtiki\source\drivers\keybd.x68 -L ..\Femtiki\source\drivers\keybd.lst -o ..\Femtiki\source\drivers\keybd.o
	$(AAX) $(AFLAGS) ..\Femtiki\source\drivers\textvid.x68 -L ..\Femtiki\source\drivers\textvid.lst -o ..\Femtiki\source\drivers\textvid.o
	$(AAX) $(AFLAGS) ..\Femtiki\source\drivers\framebuf.x68 -L ..\Femtiki\source\drivers\framebuf.lst -o ..\Femtiki\source\drivers\framebuf.o
	$(AAX) $(AFLAGS) ..\Femtiki\source\drivers\gfxaccel.x68 -L ..\Femtiki\source\drivers\gfxaccel.lst -o ..\Femtiki\source\drivers\gfxaccel.o
	$(AAX) $(AFLAGS) ..\Femtiki\source\drivers\serial.x68 -L ..\Femtiki\source\drivers\serial.lst -o ..\Femtiki\source\drivers\serial.o
	$(AAX) $(AFLAGS) ..\Femtiki\source\drivers\random.x68 -L ..\Femtiki\source\drivers\random.lst -o ..\Femtiki\source\drivers\random.o
	$(AAX) $(AFLAGS) ..\Femtiki\source\drivers\pic.x68 -L ..\Femtiki\source\drivers\pic.lst -o ..\Femtiki\source\drivers\pic.o
	
#	vlink -T ..\Femtiki\source\Femtiki.cmd -brawbin1 boot.o ..\Femtiki\source\Femtiki.o -o boot.bin
	vlink -T ..\Femtiki\source\Femtiki.cmd -bsrec37 bootrom.o \
	..\c_standard_lib-master\errno\errno.o \
	..\c_standard_lib-master\ctype\ctype.o \
	..\c_standard_lib-master\locale\localeco.o \
	..\c_standard_lib-master\signal\signal.o \
	..\c_standard_lib-master\stdio\stdio.o \
	..\c_standard_lib-master\stdlib\stdlib.o \
	..\c_standard_lib-master\string\string.o \
	..\c_standard_lib-master\time\timelib.o \
	..\c_standard_lib-master\float\xfloat.o \
	..\Femtiki\source\xvalues.o \
	..\Femtiki\source\xdtento.o \
	..\Femtiki\source\xdunscal.o \
	..\Femtiki\source\xldunsca.o \
	..\Femtiki\source\xdscale.o \
	..\Femtiki\source\xdnorm.o \
	..\Femtiki\source\_lmath.o \
	..\Femtiki\source\drivers\null.o \
	..\Femtiki\source\drivers\keybd.o \
	..\Femtiki\source\drivers\textvid.o \
	..\Femtiki\source\drivers\framebuf.o \
	..\Femtiki\source\drivers\gfxaccel.o \
	..\Femtiki\source\drivers\serial.o \
	..\Femtiki\source\drivers\random.o \
	..\Femtiki\source\drivers\pic.o \
	..\Femtiki\source\kernel\dbg_console.o \
	..\Femtiki\source\kernel\semaphore.o \
	..\Femtiki\source\kernel\tcb.o \
	..\Femtiki\source\kernel\msg.o \
	..\Femtiki\source\kernel\Femtiki_vars.o \
	..\Femtiki\source\kernel\SetupDevices.o \
	..\Femtiki\source\kernel\femtiki_asm.o \
	..\Femtiki\source\kernel\Femtiki_kern.o \
	..\crt\source\crt.o \
	..\crt\source\lib.o \
	..\Femtiki\source\Femtiki2.o \
	DumpTasks.o \
	boot.o \
	gfx.o -o bootrom.s37

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

