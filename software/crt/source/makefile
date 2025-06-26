# Makefile for CTYPE
#
PATH1 = "C:/Users/Robert/OneDrive/documents/Cores2025/rf68000/software/"
PATH2 = "C:\Users\Robert\OneDrive\documents\Cores2025\rf68000\software\c_standard_lib-master\assert\"
PATH = $PATH;$(PATH1)"examples\";"F:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.29.30133\bin\Hostx64\x64"
INC1 = "C:/Users/Robert/OneDrive/documents/Cores2025/rf68000/software/c_standard_lib-master/_Femtiki/"
FEMTIKI_INC = "C:/Users/Robert/OneDrive/documents/Cores2025/rf68000/software/Femtiki/source/kernel/"
INC = $(INC1)
INCLUDE = $(INC1)
#CCX = cc64
#CFLAGS = -w -S -fno-exceptions
#CCX = cc64
#CXX = cc64 -w -S 
#AFLAGS = -Fvobj -Lbpl=5
AFLAGS = -Fvobj -m68010 -m68881
CFLAGS = -I$(INC)
CCX = vbccm68k
AAX = vasmrf68000_mot.exe
LXX = vlink
LFLAGS = -bvobj-be

# -cpu=68010 -fpu=68881
 
ASMS =    inout.asm \
					putnum.asm \
					open.asm \
					lib.x68

OUT =     inout.o \
					putnum.o \
					open.o \
          lib.o
           
LIB:
	del crt.c
	copy *.c crt.c
	$(CCX) $(CFLAGS) crt.c
	$(AAX) $(AFLAGS) crt.asm -L crt.lst -o crt.o
	$(AAX) $(AFLAGS) lib.x68 -L lib.lst -o lib.o

ALL:	$(OUT)
	echo "made CTYPE"

CTYPE:	$(OUT)
	echo "made CTYPE"

.c.o:
	$(CCX) $(CFLAGS) $<
	$(AAX) $(AFLAGS) $*.asm -L $*.lst -o $*.o

.lib.o:
	$(LXX) $(LFLAGS) $< -o ctype.lib

clean:
	del *.o
	del *.lst
	del *.asm
	del *.lis
	del *.c.xml
	del *.fpp
	del *.hir
