# Makefile for FEMTIKI
#
PATH1 = "C:/Users/Robert/OneDrive/documents/Cores2025/rf68000/software/"
PATH2 = "C:\Users\Robert\OneDrive\documents\Cores2025\rf68000\software\c_standard_lib-master\assert\"
PATH = $PATH;$(PATH1)"Femtiki/source/";$(PATH1)"Femtiki/source/kernel/";"F:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.29.30133\bin\Hostx64\x64"
INC1 = "C:/Users/Robert/OneDrive/documents/Cores2025/rf68000/software/c_standard_lib-master/_Femtiki/"
FEMTIKI_INC = "C:/Users/Robert/OneDrive/documents/Cores2025/rf68000/software/Femtiki/source/inc/"
INC = $(INC1)
#;$(FEMTIKI_INC)
INCLUDE = $(INC1)	
#;$(FEMTIKI_INC)
#CCX = cc64
#CFLAGS = -w -S -fno-exceptions
#CCX = cc64
#CXX = cc64 -w -S 
#AFLAGS = -Fvobj -Lbpl=5
AFLAGS = -Fvobj -m68010 -m68881
CFLAGS = -I$(INC)
CCX = vbccm68k
AAX = vasmrf68000_mot.exe
LLX = vlink

.SUFFIXES:	.x68

ASMS = \
	lib.x68 \
	mem_support.x68 \
	memmgnt3.asm \
	femtiki.asm

OUT = \
	lib.o \
	mem_support.o \
	memmgnt3.o \
	femtiki.o

all:	$(OUT)
	echo "made FEMTIKI"
  
LIB:
	del Femtiki2.c
	copy *.c Femtiki2.c
	$(CCX) $(CFLAGS) Femtiki2.c
	$(AAX) $(AFLAGS) kernel\Femtiki_vars.x68 -L Femtiki_vars.lst -o Femtiki_vars.o
	$(AAX) $(AFLAGS) kernel\Femtiki_asm.x68 -L kernel\Femtiki_asm.lst -o kernel\Femtiki_asm.o
	$(AAX) $(AFLAGS) mem_support.x68 -L mem_support.lst -o mem_support.o
	$(AAX) $(AFLAGS) _lmath.s -L _lmath.lst -o _lmath.o
#	$(AAX) $(AFLAGS) drivers\null.x68 -L drivers\null.lst -o drivers\null.o
#	$(AAX) $(AFLAGS) drivers\keybd.x68 -L drivers\keybd.lst -o drivers\keybd.o
#	$(AAX) $(AFLAGS) drivers\textvid.x68 -L drivers\textvid.lst -o drivers\textvid.o
#	$(AAX) $(AFLAGS) drivers\framebuf.x68 -L drivers\framebuf.lst -o drivers\framebuf.o
#	$(AAX) $(AFLAGS) drivers\gfxaccel.x68 -L drivers\gfxaccel.lst -o drivers\gfxaccel.o
#	$(AAX) $(AFLAGS) drivers\serial.x68 -L drivers\serial.lst -o drivers\serial.o
	del lib.o
	del femtiki_asm.o
#	copy drivers\*.o . /Y
#	copy ..\..\crt\source\lib.o lib.o
	$(AAX) $(AFLAGS) Femtiki2.asm -L Femtiki2.lst -o Femtiki2.o
	$(LLX) -T Femtiki.cmd -bsrec37 \
		errno.o ctype.o localeco.o \
		signal.o stdlib.o stdio.o string.o _lmath.o \
		kernel\Femtiki_vars.o \
		kernel\Femtiki_asm.o \
		kernel\Femtiki_kern.o \
		kernel\tcb.o \
		kernel\msg.o \
		kernel\semaphore.o \
		kernel\console.o \
		kernel\dbg_console.o \
		kernel\SetupDevices.o \
		..\..\examples\boot.o \
		..\..\crt\source\crt.o \
		Femtiki2.o -o Femtiki.s37

         
FEMTIKI:	$(OUT)
	echo "made FEMTIKI"

.c.o:
	$(CCX) $(CFLAGS) $<
	$(AAX) $(AFLAGS) $*.asm -L $*.lst -o $*.o

.x68.o:
	$(AAX) $(AFLAGS) $*.x68 -L $*.lst -o $*.o
	
clean:
	del *.o
	del *.lst
	del *.asm
	del *.lis
	del *.c.xml
	del *.fpp
	del *.hir
