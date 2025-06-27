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


ASMS = \
	femtiki_vars.x68 \
	kernel\femtiki_asm.x68 \
	lib.x68 \
	putnum.asm \
	mem_support.x68 \
	memmgnt3.asm \
	kernel\tcb.asm \
	kernel\msg.asm \
	kernel\femtiki.asm \
	femtiki.asm

OUT = \
	femtiki_vars.o \
	kernel\femtiki_asm.o \
	lib.o \
	putnum.o \
	mem_support.o \
	memmgnt3.o \
	kernel\tcb.o \
	kernel\msg.o \
	kernel\femtiki.o \
	femtiki.o

all:	$(OUT)
	echo "made FEMTIKI"
  
LIB:
	del Femtiki.c
	copy *.c + kernel\*.c Femtiki.c
	$(CCX) $(CFLAGS) Femtiki.c
	$(AAX) $(AFLAGS) kernel\Femtiki_vars.x68 -L Femtiki_vars.lst -o Femtiki_vars.o
	$(AAX) $(AFLAGS) kernel\Femtiki_asm.x68 -L kernel\Femtiki_asm.lst -o kernel\Femtiki_asm.o
	$(AAX) $(AFLAGS) mem_support.x68 -L mem_support.lst -o mem_support.o
	$(AAX) $(AFLAGS) _lmath.s -L _lmath.lst -o _lmath.o
	del crt.o
	del lib.o
	del femtiki_asm.o
	copy ..\..\crt\source\lib.o lib.o
	copy ..\..\crt\source\crt.o crt.o
	copy kernel\femtiki_asm.o femtiki_asm.o
	$(AAX) $(AFLAGS) Femtiki.asm -L Femtiki.lst -o Femtiki.o
	$(LLX) -T Femtiki.cmd -bsrec37 Femtiki_vars.o errno.o ctype.o localeco.o \
		signal.o stdlib.o stdio.o string.o _lmath.o crt.o lib.o mem_support.o \
		femtiki_asm.o Femtiki.o -o Femtiki.s37

         
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
