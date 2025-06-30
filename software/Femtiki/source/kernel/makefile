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

.SUFFIXES: .x68

SOURCES = \
	femtiki_kern.c \
	tcb.c \
	msg.c \
	request.c \
	semaphore.c \
	dbg_console.c \
	console.c \
	SetupDevices.c

ASMS = \
	femtiki_vars.x68 \
	femtiki_asm.x68

OUT = \
	femtiki_vars.o \
	femtiki_asm.o \
	Femtiki_kern.o \
	tcb.o \
	msg.o \
	request.o \
	semaphore.o \
	dbg_console.o \
	console.o \
	SetupDevices.o

Femtiki1.o: $(OUT)
	$(CCX) $(CFLAGS) femtiki_kern.c
	$(CCX) $(CFLAGS) tcb.c
	$(CCX) $(CFLAGS) msg.c
	$(CCX) $(CFLAGS) request.c
	$(CCX) $(CFLAGS) semaphore.c
	$(CCX) $(CFLAGS) dbg_console.c
	$(CCX) $(CFLAGS) console.c
	$(CCX) $(CFLAGS) SetupDevices.c
	$(AAX) $(AFLAGS) femtiki_kern.asm -L femtiki_kern.lst -o femtiki_kern.o
	$(AAX) $(AFLAGS) tcb.asm -L tcb.lst -o tcb.o
	$(AAX) $(AFLAGS) msg.asm -L msg.lst -o msg.o
	$(AAX) $(AFLAGS) semaphore.asm -L semaphore.lst -o semaphore.o
	$(AAX) $(AFLAGS) dbg_console.asm -L dbg_console.lst -o dbg_console.o
	$(AAX) $(AFLAGS) console.asm -L console.lst -o console.o
	$(AAX) $(AFLAGS) SetupDevices.asm -L SetupDevices.lst -o SetupDevices.o
	$(AAX) $(AFLAGS) femtiki_vars.x68 -L femtiki_vars.lst -o femtiki_vars.o
	$(AAX) $(AFLAGS) femtiki_asm.x68 -L femtiki_asm.lst -o femtiki_asm.o
#	$(LLX) -bvobj-be femtiki_kern.o tcb.o msg.o request.o semaphore.o dbg_console.o console.o SetupDevices.o \
#		femtiki_vars.o femtiki_asm.o -o Femtiki1.o	
	
all:	$(OUT)
	echo "made FEMTIKI"
  
FEMTIKI:	$(OUT)
	echo "made FEMTIKI KERNEL"

.x68.o:
	$(AAX) $(AFLAGS) $< -L $*.lst -o $*.o

.c.asm:
	$(CCX) $(CFLAGS) $<
	
.c.o:
	$(CCX) $(CFLAGS) $<
	$(AAX) $(AFLAGS) $*.asm -L $*.lst -o $*.o

.asm.o:
	$(AAX) $(AFLAGS) $< -L $*.lst -o $*.o

clean:
	del *.o
	del *.lst
	del *.asm
	del *.lis
	del *.c.xml
	del *.fpp
	del *.hir
