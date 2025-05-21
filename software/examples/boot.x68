; ============================================================================
;        __
;   \\__/ o\    (C) 2022-2025  Robert Finch, Waterloo
;    \  __ /    All rights reserved.
;     \/_//     robfinch<remove>@opencores.org
;       ||
;  
;
; BSD 3-Clause License
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions are met:
;
; 1. Redistributions of source code must retain the above copyright notice, this
;    list of conditions and the following disclaimer.
;
; 2. Redistributions in binary form must reproduce the above copyright notice,
;    this list of conditions and the following disclaimer in the documentation
;    and/or other materials provided with the distribution.
;
; 3. Neither the name of the copyright holder nor the names of its
;    contributors may be used to endorse or promote products derived from
;    this software without specific prior written permission.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
; DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
; FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
; SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
; CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
; OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
; OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;                                                                          
; ============================================================================
;-------------------------------------------------------------------------------
;
; system memory map
;
;
; 00000000 +----------------+      <+
;          | startup sp,pc  | 8 B   |
; 00000008 +----------------+       |
;					 |    vectors     | pair shared+
; 00000400 +----------------+       |
;					 |   bios mem     |       |
; 00001000 +----------------+       |
;					 |   bios code    |       |
; 00020000 +----------------+      <+
;					 |    unused      |
; 00040000 +----------------+
;					 |   local ram    |
; 00048000 +----------------+
;					 |    unused      |
; 00100000 +----------------+
;					 |   global ram   |
; 00101000 +----------------+
;					 | serial rcvbuf  |
; 00102000 +----------------+
;          | serial xmitbuf |
; 00103000 +----------------+
;					 |    unused      |
; 40000000 +----------------+
;          |                |
;          |                |
;          |                |
;          :  dram memory   : 1GB MB
;          |                |
;          |                |
;          |                |
; 80000000 +----------------+
;          |                |
;          |                |
;          |                |
;          :  dram memory   : 1GB MB
;          |     mirror     |
;          |                |
;          |                |
; C0000000 +----------------+
;          |                |
;          :     unused     :
;          |                |
; FD000000 +----------------+
;          |                |
;          :    I/O area    : 1.0 M
;          |                |
; FFE00000 +----------------+
;          |                |
;          :     unused     :
;          |                |
; FFFFFFFF +----------------+
;
;-------------------------------------------------------------------------------
;
HAS_MMU equ 0
NCORES equ 4
TEXTCOL equ 64
TEXTROW	equ	32

CTRLC	EQU		$03
CTRLH	EQU		$08
CTRLS	EQU		$13
CTRLX	EQU		$18
CTRLZ	EQU		$1A
LF		EQU		$0A
CR		EQU		$0D
XON		EQU		$11
XOFF	EQU		$13
EOT		EQU		$04
BLANK EQU		$20

SC_F12  EQU    $07
SC_C    EQU    $21
SC_T    EQU    $2C
SC_Z    EQU    $1A
SC_KEYUP	EQU		$F0
SC_EXTEND   EQU		$E0
SC_CTRL		EQU		$14
SC_RSHIFT	EQU		$59
SC_NUMLOCK	EQU		$77
SC_SCROLLLOCK	EQU	$7E
SC_CAPSLOCK		EQU	$58
SC_ALT		EQU		$11
SC_LSHIFT	EQU		$12
SC_DEL		EQU		$71		; extend
SC_LCTRL	EQU		$58
SC_TAB      EQU		$0D

	include "..\Femtiki\device.x68"
	include "..\Femtiki\FemtikiTop.x68"

DDATA EQU $FFFFFFF0     ; DS.L    3
HISPC EQU $FFFFFFFC     ; DS.L    1
SCREEN_FORMAT = 1

	if HAS_MMU
TEXTREG		EQU	$1E3FF00	; virtual addresses
txtscreen	EQU	$1E00000
semamem		EQU	$1E50000
ACIA			EQU	$1E60000
ACIA_RX		EQU	0
ACIA_TX		EQU	0
ACIA_STAT	EQU	4
ACIA_CMD	EQU	8
ACIA_CTRL	EQU	12
I2C2 			equ $01E69000
I2C_PREL 	equ 0
I2C_PREH 	equ 1
I2C_CTRL 	equ 2
I2C_RXR 	equ 3
I2C_TXR 	equ 3
I2C_CMD 	equ 4
I2C_STAT 	equ 4
PLIC			EQU	$1E90000
MMU				EQU $FDC00000	; physical address
leds			EQU	$1EFFF00	; virtual addresses
keybd			EQU	$1EFFE00
KEYBD			EQU	$1EFFE00
RAND			EQU	$1EFFD00
RAND_NUM	EQU	$1EFFD00
RAND_STRM	EQU	$1EFFD04
RAND_MZ		EQU $1EFFD08
RAND_MW		EQU	$1EFFD0C
RST_REG		EQU	$1EFFC00
IO_BITMAP	EQU $1F00000
	else
TEXTREG		EQU	$FD080000
txtscreen	EQU	$FD000000
semamem		EQU	$FD050000
ACIA			EQU	$FD060000
ACIA_RX		EQU	0
ACIA_TX		EQU	0
ACIA_STAT	EQU	4
ACIA_CMD	EQU	8
ACIA_CTRL	EQU	12
I2C2 			equ $FD069000
I2C_PREL 	equ 0
I2C_PREH 	equ 1
I2C_CTRL 	equ 2
I2C_RXR 	equ 3
I2C_TXR 	equ 3
I2C_CMD 	equ 4
I2C_STAT 	equ 4
PLIC			EQU	$FD090000
MMU				EQU $FDC00000	; physical address
leds			EQU	$FD0FFF00	; virtual addresses
keybd			EQU	$FD0FFE00
KEYBD			EQU	$FD0FFE00
RAND			EQU	$FD0FFD00
RAND_NUM	EQU	$FD0FFD00
RAND_STRM	EQU	$FD0FFD04
RAND_MZ		EQU $FD0FFD08
RAND_MW		EQU	$FD0FFD0C
RST_REG		EQU	$FD0FFC00
IO_BITMAP	EQU $FD100000
FRAMEBUF	EQU	$FD200000
	endif

SERIAL_SEMA	EQU	2
KEYBD_SEMA	EQU	3
RAND_SEMA		EQU	4
SCREEN_SEMA	EQU	5
MEMORY_SEMA EQU 6
TCB_SEMA 		EQU	7
FMTK_SEMA		EQU	8

macIRQ_proc	macro arg1
	dc.l IRQ_proc\1
endm

macIRQ_proc_label	macro arg1
IRQ_proc\1:
endm

	data
	; 0
	dc.l		$00040FFC
	dc.l		start
	dc.l		bus_err
	dc.l		addr_err
	dc.l		illegal_trap		* ILLEGAL instruction
	dc.l		0
	dc.l		chk_exception		; CHK
	dc.l		EXCEPTION_7			* TRAPV
	dc.l		0
	dc.l		0
	
	; 10
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		0
	
	; 20
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		SpuriousIRQ
	dc.l		0
	dc.l		0
	dc.l		irq3_rout
	dc.l		0
	dc.l		0
	
	; 30
	dc.l		TickIRQ						; IRQ 30 - timer / keyboard
	dc.l		nmi_rout
	dc.l		io_trap						; TRAP zero
	dc.l		0
	dc.l		0
	dc.l		trap3							; breakpoint
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		0

	; 40
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		TRAP15
	dc.l		0
	dc.l		0

	; 50	
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		io_irq

	; 60
	dc.l		KeybdIRQ
	dc.l		SerialIRQ
	dc.l		0
	dc.l		brdisp_trap
	
	; 64

IRQ_trampolines:
;	rept 192
;	macIRQ_proc REPTN
;	endr

	org			$400

irq_list_tbl:
	rept 192
	dc.l 0
	dc.l 0
	endr

	org			$A00

;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------

; BIOS variables which must be local (not shared) to each core

CursorRow	equ		$40000
CursorCol	equ		$40001
TextPos		equ		$40002
TextCurpos	equ	$40002
TextScr			equ	$40004
S19StartAddress	equ	$40008
KeybdEcho		equ	$4000C
KeybdWaitFlag	equ	$4000D
CmdBuf			equ $40040
CmdBufEnd		equ	$40080
fgColor			equ	$40084
bkColor			equ	$40088
TextRows		equ	$4008C
TextCols		equ	$4008D
_fpTextIncr	equ $40094
_canary			equ $40098
tickcnt			equ $4009C
IRQFlag			equ $400A0
InputDevice	equ $400A4
OutputDevice	equ $400A8
Regsave			equ	$40100
numBreakpoints	equ		8
BreakpointFlag	equ		$40200
NumSetBreakpoints	equ	$40202	; to $40203
Breakpoints			equ		$40220	; to $40240
BreakpointWords	equ		$40280	; to $402A0
fpBuf       equ $402C0
;RunningTCB  equ $40300
_exp equ $40500
_digit equ $40504
_width equ $40508
_E equ $4050C
_digits_before_decpt equ $40510
_precision equ $40514
_fpBuf equ $40520	; to $40560
_fpWork equ $40600
_dasmbuf	equ	$40800
OFFSET equ $40880
pen_color equ $40890
gr_x equ $40894
gr_y equ $40898
gr_width equ $4089C
gr_height equ $408A0
gr_bitmap_screen equ $408A4
gr_raster_op equ $408A8
gr_double_buffer equ $408AC
gr_bitmap_buffer equ $408B0
sys_switches equ $408B8
EightPixels equ $40100000	; to $40200020

null_dcb equ $0040A00		; 0
keybd_dcb equ $0040A40	; 1
con_dcb equ $0040A80		; 2
err_dcb equ $0040AC0		; 3
serial_dcb equ $0040B40	; 5

TimerStack	equ	$40BFC

; Keyboard buffer is in shared memory
IOFocus			EQU	$00100000
memend			equ $00100004
KeybdLEDs		equ	$0010000E
_KeyState1	equ	$0010000F
_KeyState2	equ	$00100010
_KeybdHead	equ	$00100011
_KeybdTail	equ	$00100012
_KeybdCnt		equ	$00100013
KeybdID			equ	$00100018
_Keybd_tick	equ $0001001C
_KeybdBuf		equ	$00100020
_KeybdOBuf	equ	$00100080
S19Checksum	equ	$00100150
SerTailRcv	equ	$00100160
SerHeadRcv	equ	$00100162
SerRcvXon		equ	$00100164
SerRcvXoff	equ	$00100165
SerTailXmit	equ	$00100166
SerHeadXmit	equ	$00100168
SerXmitXoff	equ	$0010016A
SerRcvBuf		equ	$00101000
SerXmitBuf	equ	$00102000
RTCBuf			equ $00100200	; to $0010023F

	code
	align		2
start:
;	fadd (a0)+,fp2
	move.w #$2700,sr					; enable level 6 and higher interrupts
	moveq #0,d0								; set address space zero
	movec d0,asid
	; Setup circuit select signals
	move.l #MMU,d0
	movec d0,mmus
	if HAS_MMU
		move.l #$01F00000,d0			; set virtual address for iop bitmap
		movec d0,iops
		move.l #$01E00000,d0			; set virtual address for io block
		movec d0,ios
	else
		move.l #$FD100000,d0			; set virtual address for iop bitmap
		movec d0,iops
		move.l #$FD000000,d0			; set virtual address for io block
		movec d0,ios
	endif
;	move.l $4000000C,d0
	movec coreno,d0							; set initial value of thread register
	swap d0											; coreno in high eight bits
	lsl.l #8,d0
	movec d0,tr
	; Prepare local variable storage
	move.w #1023,d0						; 1024 longs to clear
	lea	$40000,a0							; non shared local memory address
.0111:
	clr.l	(a0)+								; clear the memory area
	dbra d0,.0111
	bsr setup_null
	bsr setup_keybd
	bsr setup_console
	bsr setup_serial
	move.b #2,OutputDevice		; select text screen output
	if (SCREEN_FORMAT==1)
		move.l #$0000ff,fgColor		; set foreground / background color (white)
		move.l #$000002,bkColor		; medium blue
	else
		move.l #$1fffff,fgColor		; set foreground / background color (white)
		move.l #$00003f,bkColor		; medium blue
	endif
	movec.l	coreno,d0					; get core number (2 to 9)
	subi.b #2,d0							; adjust (0 to 7)
	if (SCREEN_FORMAT==1)
		mulu #8192,d0						; compute screen location
	else
		mulu #16384,d0						; compute screen location
	endif
	if HAS_MMU
		addi.l #$01E00000,d0
	else
		addi.l #$FD000000,d0
	endif
	move.l d0,TextScr
	move.b #64,TextCols				; set rows and columns
	move.b #32,TextRows
	movec.l	coreno,d0					; get core number
	cmpi.b #2,d0
	bne	start_other
	bsr init_framebuf
	clr.l sys_switches
	move.w #$1f00,pen_color		; blue pen
	clr.l gr_x
	clr.l gr_y
	move.b #1,gr_raster_op		; op = copy
	move.w #1920,gr_width
	move.w #1080,gr_height
	move.l #$40000000,gr_bitmap_screen
	move.l #$40400000,gr_bitmap_buffer
	move.l #$00000040,FRAMEBUF+16	; base addr 1
	move.l #$00004040,FRAMEBUF+24	; base addr 2
	move.b d0,IOFocus					; Set the IO focus in global memory
	if HAS_MMU
		bsr InitMMU							; Can't access anything till this is done'
	endif
	bsr	InitIOPBitmap					; not going to get far without this
	bsr	InitSemaphores
	bsr	InitRand
	bsr RandGetNum
	andi.l #$FFFFFF00,d1
	move.l d1,_canary
	movec d1,canary
	bsr	Delay3s						; give devices time to reset
	bsr	clear_screen

	bsr	_KeybdInit
;	bsr	InitIRQ
	bsr	SerialInit
;	bsr init_i2c
;	bsr rtc_read

	; Write startup message to screen

	lea	msg_start,a1
	bsr	DisplayString
;	bsr	FemtikiInit
	movec	coreno,d0
	swap d0
	moveq	#1,d1
	bsr	UnlockSemaphore	; allow another cpu access
	moveq	#0,d1
	bsr	UnlockSemaphore	; allow other cpus to proceed
	move.w #$A4A4,leds			; diagnostics
	bsr	init_plic				; initialize platform level interrupt controller
	bra	StartMon
	bsr	cpu_test
;	lea	brdisp_trap,a0	; set brdisp trap vector
;	move.l	a0,64*4

loop2:
	move.l	#-1,d0
loop1:
	move.l	d0,d1
	lsr.l		#8,d1
	lsr.l		#8,d1
	move.b	d1,leds
	dbra		d0,loop1
	bra			loop2

start_other:
	bsr			Delay3s2						; need time for system setup (io_bitmap etc.)
	bsr			Delay3s2						; need time for system setup (io_bitmap etc.)
	bsr			Delay3s2						; need time for system setup (io_bitmap etc.)
	bsr			clear_screen
	movec		coreno,d1
	bsr			DisplayByte
	lea			msg_core_start,a1
	bsr			DisplayString
;	bsr			FemtikiInitIRQ
do_nothing:	
	bra			StartMon
	bra			do_nothing

;------------------------------------------------------------------------------
; Initialize the MMU to allow thread #0 access to IO
;------------------------------------------------------------------------------
	if HAS_MMU
	align 2
mmu_adrtbl:	; virtual address[24:16], physical address[31:16] bytes reversed!
	dc.l	$0010,$10000300	; global scratch pad
	dc.l	$01E0,$00FD0300	
	dc.l	$01E1,$01FD0300
	dc.l	$01E2,$02FD0300
	dc.l  $01E3,$03FD0300
	dc.l	$01E5,$05FD0300
	dc.l	$01E6,$06FD0300
	dc.l	$01E9,$09FD0300
	dc.l	$01EF,$0FFD0300
	dc.l	$01F0,$10FD0300
	dc.l  $01FF,$FFFF0300	; all ones output for IRQ ack needed

	even
InitMMU:
	lea MMU+8,a0				; first 128kB is local RAM
	move.l #$32000,d2		; map all pages to DRAM
	move.l #510,d0			; then override for IO later
.0002
	move.l d2,d1
	bsr rbo
	move.l d1,(a0)+
	addi.w #1,d2				; increment DRAM page number
	dbra d0,.0002
	lea MMU,a0					; now program IO access
	lea mmu_adrtbl,a1
	moveq #10,d0
.0001
	move.l (a1)+,d2
	lsl.l #2,d2
	move.l (a1)+,(a0,d2.w)
	dbra d0,.0001
	rts	
	endif

;------------------------------------------------------------------------------
; Setup the NULL device
;------------------------------------------------------------------------------

null_init:
setup_null:
	moveq #31,d0
	lea.l null_dcb,a0
.0001:
	clr.l (a0)+
	dbra d0,.0001
	move.l #$20424344,null_dcb+DCB_MAGIC				; 'DCB'
	move.l #$4C4C554E,null_dcb+DCB_NAME					; 'NULL'
	move.l #null_cmdproc,null_dcb+DCB_CMDPROC
null_ret:
	rts

null_cmdproc:
	rts

;------------------------------------------------------------------------------
; Setup the console device
; stdout = text screen controller
;------------------------------------------------------------------------------

console_init:
setup_console:
	moveq #31,d0
	lea.l con_dcb,a0
.0001:
	clr.l (a0)+
	dbra d0,.0001
	move.l #$20424344,con_dcb+DCB_MAGIC				; 'DCB'
	move.l #$204E4F43,con_dcb+DCB_NAME				; 'CON'
	move.l #console_cmdproc,con_dcb+DCB_CMDPROC
	movec.l	coreno,d0					; get core number (2 to 9)
	subi.b #2,d0							; adjust (0 to 7)
	mulu #16384,d0						; compute screen location
	if HAS_MMU
		addi.l #$01E00000,d0
	else
		addi.l #$FD000000,d0
	endif
	move.l d0,con_dcb+DCB_INBUFPTR
	move.l d0,con_dcb+DCB_OUTBUFPTR
	move.l #16384,con_dcb+DCB_INBUFSIZE
	move.l #16384,con_dcb+DCB_OUTBUFSIZE
	move.b #TEXTCOL,con_dcb+DCB_OUTCOLS	; set rows and columns
	move.b #TEXTROW,con_dcb+DCB_OUTROWS
	move.b #TEXTCOL,con_dcb+DCB_INCOLS		; set rows and columns
	move.b #TEXTROW,con_dcb+DCB_INROWS
	rts

	align 2
CON_CMDTBL:
	dc.l console_init
	dc.l console_stat
	dc.l console_putchar
	dc.l console_putbuf
	dc.l console_getchar
	dc.l console_getbuf
	dc.l console_set_inpos
	dc.l console_set_outpos

console_cmdproc:
	cmpi.b #8,d6
	bhs.s .0001
	tst.b d6
	bmi.s .0001
	movem.l d6/a0,-(a7)
	asl.b #2,d6
	ext.w d6
	lea CON_CMDTBL,a0
	move.l (a0,d6.w),a0
	jsr (a0)
	movem.l (a7)+,d6/a0
	rts
.0001:
	moveq #E_Func,d0
	rts

console_stat:
	moveq #E_Ok,d0
	rts

console_putchar:
	bsr DisplayChar
	moveq #E_Ok,d0
	rts

console_getchar:
	bsr FromScreen
	moveq #E_Ok,d0
	rts

console_putbuf:
console_getbuf:
console_set_inpos:
console_set_outpos:
	moveq #E_NotSupported,d0
	rts

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

init_framebuf:
	rts
	move.b #1,FRAMEBUF+0		; turn on frame buffer
	move.b #1,FRAMEBUF+1		; color depth 16 BPP
	move.b #$11,FRAMEBUF+2	; hres 1:1 vres 1:1
	rts

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

GlobalReadLong:
		move.l (a0),d1
		rts
		bra nd1
GlobalWriteLong:
		move.l d1,(a0)
		rts
net_delay:
		bra nd1
nd1	bra nd2
nd2 bra nd3
nd3 bra nd4
nd4	nop
		rts
	

;------------------------------------------------------------------------------
; The IO bitmap needs to be initialized to allow access to IO.
;------------------------------------------------------------------------------

InitIOPBitmap:
	moveq #0,d3				; d3 = asid value
	move.w #63,d0			; 64 bitmaps to setup
	movec iops,a0			; a0 = IOP bitmap address
	movea.l a0,a1			; a1 = table address
.0004
	tst.b d3
	seq d1						; set entire bitmap for asid 0, otherwise clear entire bitmap
	ext.w	d1					; make into a long value
	ext.l d1
	move.w #127,d4
.0001
	move.l d1,(a1)+		; set or clear entire table
	dbra d4,.0001
	moveq #-1,d1
	move.l d1,160(a0)	; all io address spaces have access to semaphores
	move.l d1,164(a0)
	move.l d1,168(a0)
	move.l d1,172(a0)
	move.l d1,508(a0)	; all io address spaces access random # generator
	swap d0
	move.w #31,d0			; 32 long words for the screen area per bitmap
.0003
	move.l d1,(a0)+		; all cores have access to a screen
	dbra d0,.0003
	swap d0
	addi.b #1,d3			; do next address space
	movea.l a1,a0			; a0 points to area for next address space
	dbra d0,.0004
	rts	
	
;------------------------------------------------------------------------------
; RandInit
; 	Initialize random number generator.
;
; Modifies:
;		none
; Parameters:
;		none
;	Returns:
;		none
;------------------------------------------------------------------------------

InitRand:
RandInit:
	movem.l	d0/d1,-(a7)
	moveq #37,d0								; lock semaphore
	moveq	#RAND_SEMA,d1
	trap #15
	movec coreno,d0							; d0 = core number
	lsl.l	#6,d0									; allow 64 streams per core
	move.l d0,RAND_STRM					; select the stream
	move.l #$12345678,RAND_MZ		; initialize to some value
	move.l #$98765432,RAND_MW
	move.l #777777777,RAND_NUM	; generate first number
	moveq #38,d0								; unlock semaphore
	moveq	#RAND_SEMA,d1
	trap #15
	movem.l	(a7)+,d0/d1
	rts

;------------------------------------------------------------------------------
; Returns
;		d1 = random integer
;------------------------------------------------------------------------------

RandGetNum:
	movem.l	d0/d2,-(a7)
	moveq #RAND_SEMA,d1
	bsr T15LockSemaphore
	movec	coreno,d0
	lsl.l	#6,d0
	move.l d0,RAND_STRM					; select the stream
	move.l RAND_NUM,d2					; d2 = random number
	clr.l	RAND_NUM							; generate next number
	bsr T15UnlockSemaphore
	move.l d2,d1
	movem.l	(a7)+,d0/d2
	rts

;------------------------------------------------------------------------------
; Modifies:
;		none
; Returns
;		fp0 = random float between 0 and 1.
;------------------------------------------------------------------------------

_GetRand:
	move.l d1,-(sp)
	fmove.x fp1,-(sp)
	bsr RandGetNum
	lsr.l #1,d1									; make number between 0 and 2^31
	fmove.l d1,fp0
	fmove.l #$7FFFFFFF,fp1			; divide by 2^31
	fdiv fp1,fp0
	fmove.x (sp)+,fp1
	move.l (sp)+,d1
	rts

;------------------------------------------------------------------------------
; RandWait
;    Wait some random number of clock cycles before returning.
;------------------------------------------------------------------------------

RandWait:
	movem.l	d0/d1,-(a7)
	bsr			RandGetNum
	andi.w	#15,d1
.0001:
	nop
	dbra		d1,.0001
	movem.l	(a7)+,d0/d1
	rts

;------------------------------------------------------------------------------
; Initialize semaphores
; - all semaphores are set to unlocked except the first one, which is locked
; for core #2.
;
; Parameters:
;		<none>
; Modifies:
;		<none>
; Returns:
;		<none>
;------------------------------------------------------------------------------

InitSemaphores:
	movem.l	d1/a0,-(a7)
	lea			semamem,a0
	move.l	#$20000,$2000(a0)	; lock the first semaphore for core #2, thread #0
	move.w	#254,d1
.0001:
	lea			4(a0),a0
	clr.l		$2000(a0)					; write zeros to unlock
	dbra		d1,.0001
	movem.l	(a7)+,d1/a0
	rts

; -----------------------------------------------------------------------------
; Parameters:
;		d1 semaphore number
;
; Side Effects:
;		increments semaphore, saturates at 255
;
; Returns:	
; 	z flag set if semaphore was zero
; -----------------------------------------------------------------------------

;IncrementSemaphore:
;	movem.l	d1/a0,-(a7)			; save registers
;	lea			semamem,a0			; point to semaphore memory
;	ext.w		d1							; make d1 word value
;	asl.w		#4,d1						; align to memory
;	tst.b		1(a0,d1.w)			; read (test) value for zero
;	movem.l	(a7)+,a0/d1			; restore regs
;	rts
	
; -----------------------------------------------------------------------------
; Parameters:
;		d1 semaphore number
;
; Side Effects:
;		decrements semaphore, saturates at zero
;
; Returns:	
; 	z flag set if semaphore was zero
; -----------------------------------------------------------------------------

;DecrementSemaphore:
;	movem.l	d1/a0,-(a7)			; save registers
;	lea			semamem,a0			; point to semaphore memory
;	andi.w	#255,d1					; make d1 word value
;	asl.w		#4,d1						; align to memory
;	tst.b		1(a0,d1.w)			; read (test) value for zero
;	movem.l	(a7)+,a0/d1			; restore regs
;	rts

; -----------------------------------------------------------------------------
; Lock a semaphore
;
; Parameters:
;		d0 = key
;		d1 = semaphore number
; -----------------------------------------------------------------------------

LockSemaphore:
	rts
	movem.l	d1/a0,-(a7)			; save registers
	lea			semamem,a0			; point to semaphore memory lock area
	andi.w	#255,d1					; make d1 word value
	lsl.w		#2,d1						; align to memory
.0001
	move.l	d0,(a0,d1.w)		; try and write the semaphore
	cmp.l		(a0,d1.w),d0		; did it lock?
	bne.s		.0001						; no, try again
	movem.l	(a7)+,a0/d1			; restore regs
	rts
	
; -----------------------------------------------------------------------------
; Unlocks a semaphore even if not the owner.
;
; Parameters:
;		d1 semaphore number
; -----------------------------------------------------------------------------

ForceUnlockSemaphore:
	movem.l	d1/a0,-(a7)				; save registers
	lea			semamem+$3000,a0	; point to semaphore memory read/write area
	andi.w	#255,d1						; make d1 word value
	lsl.w		#2,d1							; align to memory
	clr.l		(a0,d1.w)					; write zero to unlock
	movem.l	(a7)+,a0/d1				; restore regs
	rts

; -----------------------------------------------------------------------------
; Unlocks a semaphore. Must be the owner to have effect.
; Three cases:
;	1) the owner, the semaphore will be reset to zero
;	2) not the owner, the write will be ignored
; 3) already unlocked, the write will be ignored
;
; Parameters:
;		d0 = key
;		d1 = semaphore number
; -----------------------------------------------------------------------------

UnlockSemaphore:
	bra ForceUnlockSemaphore
	movem.l	d1/a0,-(a7)				; save registers
	lea			semamem+$1000,a0	; point to semaphore memory unlock area
	andi.w	#255,d1						; make d1 word value
	lsl.w		#2,d1							; align to memory
	move.l	d0,(a0,d1.w)			; write matching value to unlock
	movem.l	(a7)+,a0/d1				; restore regs
	rts

; -----------------------------------------------------------------------------
; Parameters:
;		d1 = semaphore to lock / unlock
; -----------------------------------------------------------------------------

T15LockSemaphore:	
	movec tr,d0
	bra LockSemaphore

T15UnlockSemaphore:
	movec tr,d0
	bra UnlockSemaphore

T15GetFloat:
	move.l a1,a0
	move.l d1,d0
	bsr _GetFloat
	move.l a0,a1
	move.l d0,d1
	rts

T15Abort:
	bsr DisplayByte
	lea msgStackCanary,a1
	bsr DisplayStringCRLF
	bra Monitor

chk_exception:
	move.l 2(sp),d1
	bsr DisplayTetra
	lea msgChk,a1
	bsr DisplayStringCRLF
	bra Monitor

; -----------------------------------------------------------------------------
; Delay for a few seconds to allow some I/O reset operations to take place.
; -----------------------------------------------------------------------------

Delay3s:
	move.l	#3000000,d0		; this should take a few seconds to loop
	lea			leds,a0				; a0 = address of LED output register
	bra			dly3s1				; branch to the loop
dly3s2:	
	swap		d0						; loop is larger than 16-bits
dly3s1:
	move.l	d0,d1					; the counter cycles fast, so use upper bits for display
	rol.l		#8,d1					; could use swap here, but lets test rol
	rol.l		#8,d1
	move.b	d1,(a0)				; set the LEDs
	dbra		d0,dly3s1			; decrement and branch back
	swap		d0
	dbra		d0,dly3s2
	rts

Delay3s2:
	movec		coreno,d0			; vary delay by core to stagger startup
	lsl.l		#8,d0
	addi.l	#3000000,d0		; this should take a few seconds to loop
	bra			.0001					; branch to the loop
.0002	
	swap		d0						; loop is larger than 16-bits
.0001
	dbra		d0,.0001			; decrement and branch back
	swap		d0
	dbra		d0,.0002
	rts

	include "cputest.x68"
	include "TinyBasicFlt.x68"

; -----------------------------------------------------------------------------
; -----------------------------------------------------------------------------

set_text_mode:
	moveq #TEXTCOL,d0
	move.b d0,TEXTREG					; number of columns
	moveq #TEXTROW,d0
	move.b d0,TEXTREG+1				; number of rows
	moveq #0,d0
	move.b d0,TEXTREG+3				; text mode
	moveq #17,d0
	move.b d0,TEXTREG+8				; max row scan
	moveq #11,d0
	move.b d0,TEXTREG+10			; max pix
	rts
	
set_graphics_mode:
	moveq #TEXTCOL*2,d0
	move.b d0,TEXTREG					; number of columns
	moveq #TEXTROW*2,d0
	move.b d0,TEXTREG+1				; number of rows
	moveq #1,d0
	move.b d0,TEXTREG+3				; graphics mode
	moveq #7,d0
	move.b d0,TEXTREG+8				; max row scan
	moveq #7,d0
	move.b d0,TEXTREG+10			; max pix
	rts

; -----------------------------------------------------------------------------
; Gets the screen color in d0 and d1.
; -----------------------------------------------------------------------------

get_screen_color:
	if (SCREEN_FORMAT==1)
		move.l fgColor,d0				; get foreground color in bits 0 to 7
		asl.l #8,d0							; foreground color in bits 8 to 15
		or.l bkColor,d0					;
		swap d0									; foreground color in bits 24 to 31, bk in 16 to 23
	else
		move.l	fgColor,d0			; get foreground color
		asl.l		#5,d0						; shift into position
		ori.l		#$40000000,d0		; set priority
		move.l	bkColor,d1
		lsr.l		#8,d1
		lsr.l		#8,d1
		andi.l	#31,d1					; mask off extra bits
		or.l		d1,d0						; set background color bits in upper long word
		move.l	bkColor,d1			; get background color
		asl.l		#8,d1						; shift into position for display ram
		asl.l		#8,d1
	endif
	rts

; -----------------------------------------------------------------------------
; -----------------------------------------------------------------------------

get_screen_address:
	move.l	TextScr,a0
	rts
	
; -----------------------------------------------------------------------------
; -----------------------------------------------------------------------------

clear_screen:
	movem.l	d0/d1/d2/a0,-(a7)
	movec		coreno,d0
	swap		d0	
;	moveq		#SCREEN_SEMA,d1
;	bsr			LockSemaphore
	bsr	get_screen_address			; a0 = pointer to screen area
	move.b	TextRows,d0					; d0 = rows
	move.b	TextCols,d2					; d2 = cols
	ext.w		d0									; convert to word
	ext.w		d2									; convert to word
	mulu d0,d2									; d2 = number of character cells to clear
	bsr	get_screen_color				; get the color bits
	if (SCREEN_FORMAT==1)
		ori.w #32,d0
		rol.w #8,d0
		swap d0
		rol.w #8,d0
loop3:
		move.l d0,(a0)+						; copy to cell
	else
		ori.w	#32,d1							; load space character
		rol.w	#8,d1								; swap endian, text controller expects little endian
		swap d1
		rol.w	#8,d1
		rol.w	#8,d0								; swap endian
		swap d0
		rol.w	#8,d0
loop3:
		move.l d1,(a0)+						; copy char plus bkcolor to cell
		move.l d0,(a0)+						; copy fgcolor to cell
	endif
	dbra d2,loop3
	movec coreno,d0
	swap d0	
;	moveq #SCREEN_SEMA,d1
;	bsr UnlockSemaphore
	movem.l (a7)+,d0/d1/d2/a0
	rts

CRLF:
	movem.l d0/d1,-(a7)
	move.b #13,d1
	moveq #6,d0						; output character function
	trap #15
	move.b #10,d1
	moveq #6,d0						; output character function
	trap #15
	movem.l (a7)+,d0/d1
	rts

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

UpdateTextPos:
	move.b	CursorRow,d0		; compute screen location
	andi.w	#$7f,d0
	move.b	TextCols,d2
	ext.w		d2
	mulu.w	d2,d0
	move.l	d0,d3
	move.b	CursorCol,d2
	andi.w	#$ff,d2
	add.w		d2,d0
	move.w	d0,TextPos			; save cursor pos
	rts

;------------------------------------------------------------------------------
; Calculate screen memory location from CursorRow,CursorCol.
; Destroys d0,d2,a0
;------------------------------------------------------------------------------

CalcScreenLoc:
	bsr	UpdateTextPos
	ext.l	d0									;	 make it into a long
	if (SCREEN_FORMAT==1)
		asl.l #2,d0							; 4 bytes per char
	else
		asl.l	#3,d0							; 8 bytes per char
	endif
	bsr	get_screen_address
	add.l	d0,a0								; a0 = screen location
	rts

;------------------------------------------------------------------------------
; Display a character on the screen
; d1.b = char to display
;------------------------------------------------------------------------------

DisplayChar:
	movem.l	d1/d2/d3,-(a7)
	movec		coreno,d2
	cmpi.b	#2,d2
;	bne.s		.0001
;	bsr			SerialPutChar
.0001:
	andi.l	#$ff,d1				; zero out upper bytes of d1
	cmpi.b	#13,d1				; carriage return ?
	bne			dccr
	clr.b		CursorCol			; just set cursor column to zero on a CR
dcx14:
	bsr			SyncCursor		; set position in text controller
dcx7:
	movem.l	(a7)+,d1/d2/d3
	rts
dccr:
	cmpi.b	#$91,d1			; cursor right ?
	bne.s   dcx6
	move.b	TextCols,d2
	sub.b		#1,d2
	sub.b		CursorCol,d2
	beq.s		dcx7
	addi.b	#1,CursorCol
	bra.s		dcx14
dcx6:
	cmpi.b	#$90,d1			; cursor up ?
	bne.s		dcx8
	cmpi.b	#0,CursorRow
	beq.s		dcx7
	subi.b	#1,CursorRow
	bra.s		dcx14
dcx8:
	cmpi.b	#$93,d1			; cursor left?
	bne.s		dcx9
	cmpi.b	#0,CursorCol
	beq.s		dcx7
	subi.b	#1,CursorCol
	bra.s		dcx14
dcx9:
	cmpi.b	#$92,d1			; cursor down ?
	bne.s		dcx10
	move.b	TextRows,d2
	sub.b		#1,d2
	cmp.b		CursorRow,d2
	beq.s		dcx7
	addi.b	#1,CursorRow
	bra.s		dcx14
dcx10:
	cmpi.b	#$94,d1			; cursor home ?
	bne.s		dcx11
	cmpi.b	#0,CursorCol
	beq.s		dcx12
	clr.b		CursorCol
	bra			dcx14
dcx12:
	clr.b		CursorRow
	bra			dcx14
dcx11:
	movem.l	d0/d1/d2/a0,-(a7)
	cmpi.b	#$99,d1			; delete ?
	beq.s		doDelete
	cmpi.b	#CTRLH,d1			; backspace ?
	beq.s   doBackspace
	cmpi.b	#CTRLX,d1			; delete line ?
	beq			doCtrlX
	cmpi.b	#10,d1		; linefeed ?
	beq.s		dclf

	; regular char
	bsr			CalcScreenLoc	; a0 = screen location
	move.l	d1,d2					; d2 = char
	bsr			get_screen_color	; d0,d1 = color
	if (SCREEN_FORMAT==1)
		or.l d1,d0
		rol.w	#8,d0					; swap bytes
		swap d0							; swap halfs
		rol.w	#8,d0					; swap remaining bytes
		move.l d0,(a0)+
	else
		or.l		d2,d1					; d1 = char + color
		rol.w		#8,d1					; text controller expects little endian data
		swap		d1
		rol.w		#8,d1
		move.l d1,(a0)+
		rol.w		#8,d0					; swap bytes
		swap		d0						; swap halfs
		rol.w		#8,d0					; swap remaining bytes
		move.l d0,(a0)+
	endif
	bsr	IncCursorPos
	bsr	SyncCursor
	bra	dcx4
dclf:
	bsr			IncCursorRow
dcx16:
	bsr			SyncCursor
dcx4:
	movem.l	(a7)+,d0/d1/d2/a0		; get back a0
	movem.l	(a7)+,d1/d2/d3
	rts

	;---------------------------
	; CTRL-H: backspace
	;---------------------------
doBackspace:
	cmpi.b	#0,CursorCol		; if already at start of line
	beq.s   dcx4						; nothing to do
	subi.b	#1,CursorCol		; decrement column

	;---------------------------
	; Delete key
	;---------------------------
doDelete:
	movem.l	d0/d1/a0,-(a7)	; save off screen location
	bsr	CalcScreenLoc				; a0 = screen location
	move.b CursorCol,d0
.0001:
	if (SCREEN_FORMAT==1)
		move.l 4(a0),(a0)				; pull remaining characters on line over 1
		adda.l #4,a0
	else
		move.l 8(a0),(a0)				; pull remaining characters on line over 1
		move.l 12(a0),4(a0)
		adda.l #8,a0
	endif
	addi.b #1,d0
	cmp.b	TextCols,d0
	blo.s	.0001
	bsr	get_screen_color
	if (SCREEN_FORMAT==1)
		move.w #' ',d0
		rol.w	#8,d0
		swap d0
		rol.w	#8,d0
		move.l d0,-4(a0)
	else
		move.w #' ',d1					; terminate line with a space
		rol.w	#8,d1
		swap d1
		rol.w	#8,d1
		move.l d1,-8(a0)
	endif
	movem.l	(a7)+,d0/d1/a0
	bra.s		dcx16				; finished

	;---------------------------
	; CTRL-X: erase line
	;---------------------------
doCtrlX:
	clr.b	CursorCol			; Reset cursor to start of line
	move.b TextCols,d0	; and display TextCols number of spaces
	ext.w	d0
	ext.l	d0
	move.b #' ',d1			; d1 = space char
.0001:
	; DisplayChar is called recursively here
	; It's safe to do because we know it won't recurse again due to the
	; fact we know the character being displayed is a space char
	bsr	OutputChar			
	subq #1,d0
	bne.s	.0001
	clr.b	CursorCol			; now really go back to start of line
	bra	dcx16						; we're done

;------------------------------------------------------------------------------
; Increment the cursor position, scroll the screen if needed.
;------------------------------------------------------------------------------

IncCursorPos:
	addi.w	#1,TextCurpos
	addi.b	#1,CursorCol
	move.b	TextCols,d0
	cmp.b		CursorCol,d0
	bhs.s		icc1
	clr.b		CursorCol
IncCursorRow:
	addi.b	#1,CursorRow
	move.b	TextRows,d0
	cmp.b		CursorRow,d0
	bhi.s		icc1
	move.b	TextRows,d0
	move.b	d0,CursorRow		; in case CursorRow is way over
	subi.b	#1,CursorRow
	ext.w		d0
	asl.w		#1,d0
	sub.w		d0,TextCurpos
	bsr			ScrollUp
icc1:
	rts

;------------------------------------------------------------------------------
; Scroll screen up.
;------------------------------------------------------------------------------

ScrollUp:
	movem.l	d0/d1/a0/a5,-(a7)		; save off some regs
	movec	coreno,d0
	swap d0	
	moveq	#SCREEN_SEMA,d1
	bsr	LockSemaphore
	bsr	get_screen_address
	move.l a0,a5								; a5 = pointer to text screen
.0003:								
	move.b TextCols,d0					; d0 = columns
	move.b TextRows,d1					; d1 = rows
	ext.w d0										;	make cols into a word value
	ext.w	d1										; make rows into a word value
	if (SCREEN_FORMAT==1)
		asl.w	#2,d0								; make into cell index
	else
		asl.w	#3,d0								; make into cell index
	endif
	lea	0(a5,d0.w),a0						; a0 = pointer to second row of text screen
	if (SCREEN_FORMAT==1)
		lsr.w	#2,d0								; get back d0
	else
		lsr.w	#3,d0								; get back d0
	endif
	subq #1,d1									; number of rows-1
	mulu d1,d0									; d0 = count of characters to move
	if (SCREEN_FORMAT==1)
	else
		add.l d0,d0									; d0*2 2 longs per char
	endif
.0001:
	move.l (a0)+,(a5)+
	dbra d0,.0001
	movec coreno,d0
	swap d0	
	moveq #SCREEN_SEMA,d1
	bsr UnlockSemaphore
	movem.l (a7)+,d0/d1/a0/a5
	; Fall through into blanking out last line

;------------------------------------------------------------------------------
; Blank out the last line on the screen.
;------------------------------------------------------------------------------

BlankLastLine:
	movem.l	d0/d1/d2/a0,-(a7)
	movec	coreno,d0
	swap d0	
	moveq	#SCREEN_SEMA,d1
	bsr	LockSemaphore
	bsr	get_screen_address
	move.b TextRows,d0					; d0 = rows
	move.b TextCols,d1					; d1 = columns
	ext.w	d0
	ext.w	d1
	subq #1,d0									; last row = #rows-1
	mulu d1,d0									; d0 = index of last line
	if (SCREEN_FORMAT==1)
		lsl.w	#2,d0								; *4 bytes per char
	else
		lsl.w	#3,d0								; *8 bytes per char
	endif
	lea	(a0,d0.w),a0						; point a0 to last row
	move.b TextCols,d2					; number of text cells to clear
	ext.w	d2
	subi.w #1,d2								; count must be one less than desired
	bsr	get_screen_color				; d0,d1 = screen color
	if (SCREEN_FORMAT==1)
		move.b #32,d0
	else
		move.b #32,d1								; set the character for display in low 16 bits
		bsr	rbo											; reverse the byte order
	endif
	rol.w	#8,d0
	swap d0
	rol.w	#8,d0
.0001:
	if (SCREEN_FORMAT==1)
		move.l d0,(a0)+
	else
		move.l d0,(a0)+
		move.l d1,(a0)+
	endif
	dbra d2,.0001
	movec	coreno,d0
	swap d0	
	moveq #SCREEN_SEMA,d1
	bsr UnlockSemaphore
	movem.l	(a7)+,d0/d1/d2/a0
	rts

;------------------------------------------------------------------------------
; Display a string on standard output.
;------------------------------------------------------------------------------

DisplayString:
	movem.l	d0/d1/a1,-(a7)
dspj1:
	clr.l d1							; clear upper bits of d1
	move.b (a1)+,d1				; move string char into d1
	beq.s dsret						; is it end of string ?
	moveq #6,d0						; output character function
	trap #15
	bra.s	dspj1						; go back for next character
dsret:
	movem.l	(a7)+,d0/d1/a1
	rts

;------------------------------------------------------------------------------
; Display a string on the screen followed by carriage return / linefeed.
;------------------------------------------------------------------------------

DisplayStringCRLF:
	bsr		DisplayString
	bra		CRLF

;------------------------------------------------------------------------------
; Display a string on the screen limited to 255 chars max.
;------------------------------------------------------------------------------

DisplayStringLimited:
	movem.l	d0/d1/d2/a1,-(a7)
	move.w	d1,d2					; d2 = max count
	andi.w	#$00FF,d2			; limit to 255 chars
	bra.s		.0003					; enter loop at bottom
.0001:
	clr.l d1							; clear upper bits of d1
	move.b (a1)+,d1				; move string char into d1
	beq.s .0002						; is it end of string ?
	moveq #6,d0						; output character function
	trap #15
.0003:
	dbra		d2,.0001			; go back for next character
.0002:
	movem.l	(a7)+,d0/d1/d2/a1
	rts

DisplayStringLimitedCRLF:
	bsr		DisplayStringLimited
	bra		CRLF
	
;------------------------------------------------------------------------------
; Set cursor position to top left of screen.
;
; Parameters:
;		<none>
; Returns:
;		<none>
; Registers Affected:
;		<none>
;------------------------------------------------------------------------------

HomeCursor:
	clr.b		CursorRow
	clr.b		CursorCol
	clr.w		TextPos
	; fall through

;------------------------------------------------------------------------------
; SyncCursor:
;
; Sync the hardware cursor's position to the text cursor position but only for
; the core with the IO focus.
;
; Parameters:
;		<none>
; Returns:
;		<none>
; Registers Affected:
;		<none>
;------------------------------------------------------------------------------

SyncCursor:
	movem.l	d0/d1/d2/a0,-(a7)
	bsr	UpdateTextPos
	clr.l d1
	move.w d0,d1
	movec	coreno,d2
	cmp.b	IOFocus,d2
	bne.s .0001
	subi.w #2,d2				; factor in location of screen in controller
	move.w #TEXTROW,d0
	mulu #TEXTCOL,d0
	mulu d0,d2					; 2048/4000 cells per screen
	add.l	d2,d1
	rol.w	#8,d1					; swap byte order
	swap d1
	rol.w #8,d1
	lea TEXTREG+$24,a0
	move.l d1,(a0)
.0001:	
	movem.l	(a7)+,a0/d0/d1/d2
	rts

;==============================================================================
; TRAP #15 handler
;
; Parameters:
;		d0.w = function number to perform
;==============================================================================

TRAP15:
	movem.l	d0/a0,-(a7)
	lea T15DispatchTable,a0
	asl.l #2,d0
	move.l (a0,d0.w),a0
	jsr (a0)
	movem.l (a7)+,d0/a0
	rte

		align	2
T15DispatchTable:
	dc.l	DisplayStringLimitedCRLF
	dc.l	DisplayStringLimited
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	GetKey
	dc.l	OutputChar
	dc.l	CheckForKey
	dc.l	GetTick
	dc.l	StubRout
	; 10
	dc.l	StubRout
	dc.l	Cursor1
	dc.l	SetKeyboardEcho
	dc.l	DisplayStringCRLF
	dc.l	DisplayString
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	CheckForKey
	; 20
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	; 30
	dc.l	StubRout
	dc.l	StubRout
	dc.l	SimHardware	;rotate_iofocus
	dc.l	SerialPeekCharDirect
	dc.l	SerialPutChar
	dc.l	SerialPeekChar
	dc.l	SerialGetChar
	dc.l	T15LockSemaphore
	dc.l	T15UnlockSemaphore
	dc.l	prtflt
	; 40
	dc.l  _GetRand
	dc.l	T15GetFloat
	dc.l	T15Abort
	dc.l	T15FloatToString
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	; 50
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	; 60
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	; 70
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	; 80
	dc.l	SetPenColor
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	DrawToXY
	dc.l	MoveToXY
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	; 90
	dc.l	StubRout
	dc.l	StubRout
	dc.l	SetDrawMode
	dc.l	StubRout
	dc.l	GRBufferToScreen
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout

;------------------------------------------------------------------------------

SimHardware:
	cmpi.w #3,d1
	bne.s .0001
	move.l #sys_switches,d1
	rts
.0001:
	rts

;------------------------------------------------------------------------------
;
GetTick:
	move.l tickcnt,d1
	rts

;------------------------------------------------------------------------------
;
SetDrawMode:
	cmpi.w #10,d1
	bne.s .0001
	move.b #5,gr_raster_op			; 'OR' operation
	rts
.0001:
	cmpi.w #17,d1
	bne.s .0002
	move.w #1,gr_double_buffer
	rts
.0002:
	rts
	
SetPenColor:
	move.l d1,pen_color
	rts

;------------------------------------------------------------------------------
; Page flip between two buffers.
;------------------------------------------------------------------------------

GRBufferToScreen:
	movem.l a0/a1,-(a7)
	eor.b #1,FRAMEBUF+3					; page flip
	move.l gr_bitmap_buffer,a1
	move.l gr_bitmap_screen,a0
	move.l a0,gr_bitmap_buffer
	move.l a1,gr_bitmap_screen
	movem.l (a7)+,a0/a1
	rts

; The following copies the buffer, why? Not needed if page flipping.
;	movem.l d0/a0/a1,-(a7)
;	move.l gr_bitmap_buffer,a1
;	move.l gr_bitmap_screen,a0
;	move.w gr_width,d0
;	mulu gr_height,d0
;	lsr.l #4,d0							; moving 16 pixels per iteration
;	move.l #0,$BFFFFFF8			; set burst length zero
;	bra.s .loop
;.loop2:
;	swap d0
;.loop:
;	move.l a1,$BFFFFFF0			; set source address
;	tst.l $BFFFFFFC					; do a read op, no value needed
;	move.l a0,$BFFFFFF4			; set destination address
;	move.l d0,$BFFFFFFC			; do a write operation (any value)
;	dbra d0,.loop
;	swap d0									; might go over 32/64 kB
;	dbra d0,.loop2
;	movem.l (a7)+,d0/a0/a1
;	rts

; Write the first eight pixels with the pen color.
; Load the pixel buffer with the eight pixels.

clear_bitmap_screen4:
	movem.l d0/d1/a0,-(a7)
	move.l gr_bitmap_buffer,a0
	move.w pen_color,d0
	swap d0
	move.w pen_color,d0
	move.w #8,d1
.loop3:
	move.l d0,(a0)+
	dbra d1,.loop3
	move.l gr_bitmap_buffer,a0
	move.l a0,$BFFFFFF0			; load data hold with eight pixels
	move.l #16,$BFFFFFF8		; set burst length sixteen
	tst.l $BFFFFFFC					; load up the values (read)
	move.w gr_width,d0
	mulu gr_height,d0
	lsr.l #8,d0							; moving 16x16 pixels per iteration
	bra.s .loop
.loop2:
	swap d0
.loop:
	move.l a0,$BFFFFFF4			; set destination address
	move.l d0,$BFFFFFFC			; write any value
	add.l #32,a0						; advance pointer
	dbra d0,.loop
	swap d0
	dbra d0,.loop2
	movem.l (a7)+,d0/d1/a0
	rts

; The following code using bursts of 1k pixels did not work (hardware).
;
;clear_bitmap_screen2:
;	move.l gr_bitmap_screen,a0
;clear_bitmap_screen3:
;	movem.l d0/d2/a0,-(a7)
;	move.l #$3F3F3F3F,$BFFFFFF4	; 32x64 byte burst
;	move.w pen_color,d0
;	swap d0
;	move.w pen_color,d0
;	move.w gr_width,d2		; calc. number of pixels on screen
;	mulu gr_height,d2
;	add.l #1023,d2				; rounding up
;	lsr.l #8,d2						; divide by 1024 pixel update
;	lsr.l #2,d2
;.0001:
;	move.l a0,$BFFFFFF8		; write update address
;	add.l #2048,a0				; update pointer
;	move.l d0,$BFFFFFFC		; trigger burst write of 2048 bytes
;	dbra d2,.0001
;	movem.l (a7)+,d0/d2/a0
;	rts

; More conventional but slow way of clearing the screen.
;
;clear_bitmap_screen:
;	move.l gr_bitmap_screen,a0
;clear_bitmap_screen1:
;	movem.l d0/d2/a0,-(a7)
;	move.w pen_color,d0
;	swap d0
;	move.w pen_color,d0
;	move.w gr_width,d2		; calc. number of pixels on screen
;	mulu gr_height,d2			; 800x600 = 480000
;	bra.s .0001
;.0002:
;	swap d2
;.0001:
;	move.l d0,(a0)+
;	dbra d2,.0001
;	swap d2
;	dbra d2,.0002
;	movem.l (a7)+,d0/d2/a0
;	rts

TestBitmap:
	bsr clear_bitmap_screen4
	moveq #94,d0							; page flip (display blank screen)
	trap #15
	move.w #$007c,pen_color		; red pen
	clr.l gr_x
;	clr.l gr_y
	move.l #1,gr_y
	move.l gr_width,d3
	subq.l #1,d3
	move.l #1,d4
	bsr DrawHorizTo
	clr.l gr_x
	clr.l gr_y
	move.l #0,d3
	move.l gr_height,d4
	subq.l #1,d4
	bsr DrawVertTo
	move.w #$E001,pen_color		; green pen
	move.l #2,gr_x
	clr.l gr_y
	move.l #2,d3
	move.l gr_height,d4
	subq.l #1,d4
	bsr DrawVertTo
	clr.l gr_x
	clr.l gr_y
	move.l gr_width,d3
	subq.l #1,d3
	move.l d3,gr_x
	move.l gr_height,d4
	subq.l #1,d4
	bsr DrawToXY
	moveq #94,d0							; page flip again
	trap #15
	bra Monitor

Diagonal1:
	clr.l gr_x
	clr.l gr_y
	move.l gr_width,d3
	subq.l #1,d3
	move.l gr_height,d4
	subq.l #1,d4
	bsr DrawToXY
	rts

Diagonal2:
	move.l gr_width,d3
	subq.l #1,d3
	move.l d3,gr_x
	clr.l gr_y
	move.l gr_height,d3
	subq.l #1,d3
	moveq #0,d4
	move.w #$E001,pen_color
	bsr DrawToXY
	rts

Vertical1:
	clr.l gr_x
	clr.l gr_y
	move.l #0,d3
	move.l gr_height,d4
	subq.l #1,d4
	bsr DrawVertTo
	rts

Vertical2:
	move.w #$E001,pen_color		; green pen
	move.l #2,gr_x
	clr.l gr_y
	move.l #2,d3
	move.l gr_height,d4
	subq.l #1,d4
	bsr DrawVertTo
	rts

;------------------------------------------------------------------------------
; Plot on bitmap screen using current pen color.
;
;	Parameters:
;		d1 = x co-ordinate
;		d2 = y co-ordinate
;------------------------------------------------------------------------------
	
;parameter OPBLACK = 4'd0;
;parameter OPCOPY = 4'd1;
;parameter OPINV = 4'd2;
;parameter OPAND = 4'd4;
;parameter OPOR = 4'd5;
;parameter OPXOR = 4'd6;
;parameter OPANDN = 4'd7;
;parameter OPNAND = 4'd8;
;parameter OPNOR = 4'd9;
;parameter OPXNOR = 4'd10;
;parameter OPORN = 4'd11;
;parameter OPWHITE = 4'd15;

;---------------------------------------------------------------------
; The following uses point plot hardware built into the frame buffer.
;---------------------------------------------------------------------

plot:
	move.l a0,-(a7)
	move.l #FRAMEBUF,a0
.0001:
	tst.b 40(a0)									; wait for any previous command to finish
	bne.s .0001										; Then set:
	move.w d1,32(a0)							; pixel x co-ord
	move.w d2,34(a0)							; pixel y co-ord
	move.w pen_color,44(a0)				; pixel color
	move.b gr_raster_op,41(a0)		; set raster operation
	move.b #2,40(a0)							; point plot command
	move.l (a7)+,a0
	rts

;-------------------------------------------
; In case of lacking hardware plot
;-------------------------------------------
	align 2
plottbl:
	dc.l plot_black
	dc.l plot_copy
	dc.l plot_copy
	dc.l plot_and
	dc.l plot_or
	dc.l plot_xor
	dc.l plot_copy
	dc.l plot_copy
	dc.l plot_copy
	dc.l plot_copy
	dc.l plot_copy
	dc.l plot_copy
	dc.l plot_copy
	dc.l plot_copy
	dc.l plot_white

plot_sw:
	movem.l d1/d2/d3/d4/a0/a1,-(a7)
	mulu gr_width,d2							; multiply y by screen width
;	move.l d1,d3
;	andi.l #30,d3
;	moveq #30,d4
;	sub.l d4,d3
;	andi.l #$FFFFFFE0,d1
;	or.l d3,d1
	ext.l d1											; clear high-order word of x
	add.l d1,d2										; add in x co-ord
	add.l d2,d2										; *2 for 16 BPP
	move.l gr_bitmap_buffer,a0		; where the draw occurs
	move.w gr_raster_op,d3
	lsl.w #2,d3
	move.l plottbl(pc,d3.w),a1
	jmp (a1)
plot_or:
	move.w (a0,d2.l),d4	
	or.w pen_color,d4
	move.w d4,(a0,d2.l)
	movem.l (a7)+,d1/d2/d3/d4/a0/a1
	rts
plot_xor:
	move.w (a0,d2.l),d4
	move.w pen_color,d3	
	eor.w d3,d4
	move.w d4,(a0,d2.l)
	movem.l (a7)+,d1/d2/d3/d4/a0/a1
	rts
plot_and:
	move.w (a0,d2.l),d4	
	and.w pen_color,d4
	move.w d4,(a0,d2.l)
	movem.l (a7)+,d1/d2/d3/d4/a0/a1
	rts
plot_copy:
	move.w pen_color,(a0,d2.l)
	movem.l (a7)+,d1/d2/d3/d4/a0/a1
	rts
plot_black:
	clr.w (a0,d2.l)
	movem.l (a7)+,d1/d2/d3/d4/a0/a1
	rts
plot_white:
	move.w #$FF7F,(a0,d2.l)
	movem.l (a7)+,d1/d2/d3/d4/a0/a1
	rts

;------------------------------------------------------------------------------
; Set graphics cursor position.
;------------------------------------------------------------------------------

MoveToXY:
	move.l d3,gr_x
	move.l d4,gr_y
	rts

;------------------------------------------------------------------------------
; Draw a line from the current graphics position to x1,y1.
;
; Register Usage:
;		d1 = x0
;		d2 = y0
;		d3 = x1
;		d4 = y1
;		d5 = dx
;		d6 = dy
;		d7 = sx
;		d0 = sy
;		a0 = err
;		a1 = 2*err
;------------------------------------------------------------------------------

DrawToXY:
	movem.l d0/d1/d2/d5/d6/d7/a0/a1,-(a7)
	move.l gr_x,d1
	move.l gr_y,d2
	move.l d3,d5
	move.l d4,d6
	sub.l d1,d5			; d5 = x1-x0
	bne.s .notVert
	movem.l (a7)+,d0/d1/d2/d5/d6/d7/a0/a1
	bra DrawVertTo
.notVert:
	bpl.s .0001
	neg.l d5				
.0001:						; d5 = dx = abs(x1-x0)
	sub.l d2,d6			; d6 = y1-y0
	bne.s .notHoriz
	movem.l (a7)+,d0/d1/d2/d5/d6/d7/a0/a1
	bra DrawHorizTo
.notHoriz:
	bmi.s .0002
	neg.l d6
.0002:						; d6 = dy = -abs(y1-y0)
	move.l #1,d7		; d7 = sx (x0 < x1 ? 1 : -1)
	cmp.l d1,d3
	bhi.s .0004
	neg.l d7
.0004:
	move.l #1,d0		; d0 = sy (y0 < y1) ? 1 : -1)
	cmp.l d2,d4
	bhi.s .0006
	neg.l d0
.0006:
	move.l d5,a0		; a0 = error = dx + dy
	adda.l d6,a0
.loop:
	bsr CheckForCtrlC
	bsr plot				; plot(x0,y0)
	move.l a0,a1
	adda.l a1,a1		; a1 = error *2
	cmp.l a1,d6			; e2 >= dy?
	bgt.s .0008
	cmp.l d1,d3			; x0==x1?
	beq.s .brkloop
	adda.l d6,a0		; err = err + dy
	add.l d7,d1			; x0 = x0 + sx
.0008:
	cmp.l a1,d5			; err2 <= dx?
	blt.s .0009
	cmp.l d2,d4			; y0==y1?
	beq.s .brkloop
	adda.l d5,a0		; err = err + dx
	add.l d0,d2			; y0 = y0 + sy
.0009:
	bra.s .loop
.brkloop:
	move.l d3,gr_x
	move.l d4,gr_y
	movem.l (a7)+,d0/d1/d2/d5/d6/d7/a0/a1
	rts

; Parameters:
;		d3 = x1
;		d4 = y1

DrawHorizTo:
	movem.l d1/d2/d5,-(a7)
	move.l gr_x,d1
	move.l gr_y,d2
	move.l #1,d5			; assume increment
	cmp.l d1,d3
	bhi.s .0001
	neg.l d5					; switch to decrement
.0001:
	bsr plot
	cmp.l d1,d3
	beq.s .0002
	add.l d5,d1
	bra.s .0001
.0002:
	move.l d1,gr_x
	movem.l (a7)+,d1/d2/d5
	rts
	
	
; Parameters:
;		d3 = x1
;		d4 = y1

DrawVertTo:
	movem.l d1/d2/d5,-(a7)
	move.l gr_x,d1
	move.l gr_y,d2
	move.l #1,d5			; assume increment
	cmp.l d2,d4
	bhi.s .0001
	neg.l d5					; switch to decrement
.0001:
	bsr plot
	cmp.l d2,d4
	beq.s .0002
	add.l d5,d2
	bra.s .0001
.0002:
	move.l d2,gr_y
	movem.l (a7)+,d1/d2/d5
	rts
	
	
;plotLine(x0, y0, x1, y1)
;    dx = abs(x1 - x0)
;    sx = x0 < x1 ? 1 : -1
;    dy = -abs(y1 - y0)
;    sy = y0 < y1 ? 1 : -1
;    error = dx + dy
;    
;    while true
;        plot(x0, y0)
;        e2 = 2 * error
;        if e2 >= dy
;            if x0 == x1 break
;            error = error + dy
;            x0 = x0 + sx
;        end if
;        if e2 <= dx
;            if y0 == y1 break
;            error = error + dx
;            y0 = y0 + sy
;        end if
;    end while
    
;------------------------------------------------------------------------------
; Cursor positioning / Clear screen
; - out of range settings are ignored
;
; Parameters:
;		d1.w cursor position, bits 0 to 7 are row, bits 8 to 15 are column.
;	Returns:
;		none
;------------------------------------------------------------------------------

Cursor1:
	move.l d1,-(a7)
	cmpi.w #$FF00,d1
	bne.s .0002
	bsr	clear_screen
	move.l (a7)+,d1
	bra	HomeCursor
.0002:
	cmp.b TextRows,d1		; if cursor pos out of range, ignore setting
	bhs.s	.0003
	move.b d1,CursorRow
.0003:
	ror.w	#8,d1
	cmp.b	TextCols,d1
	bhs.s	.0001
	move.b d1,CursorCol
.0001:
	bsr SyncCursor			; update hardware cursor
	move.l (a7)+,d1
	rts

;------------------------------------------------------------------------------
; Stub routine for unimplemented functionality.
;------------------------------------------------------------------------------

StubRout:
	rts

;------------------------------------------------------------------------------
; Select a specific IO focus.
;------------------------------------------------------------------------------

select_iofocus:
	cmpi.b	#2,d1
	blo.s		.0001
	cmpi.b	#NCORES+1,d1
	bhi.s		.0001
	move.l	d1,d0
	bra.s		select_focus1
.0001:
	rts

;------------------------------------------------------------------------------
; Rotate the IO focus, done when ALT-Tab is pressed.
;
; Modifies:
;		d0, IOFocus BIOS variable
;		updates the text screen pointer
;------------------------------------------------------------------------------

rotate_iofocus:
	move.b IOFocus,d0					; d0 = focus, we can trash d0
	add.b	#1,d0								; increment the focus
	cmp.b	#NCORES+1,d0				; limit to 2 to 9
	bls.s	.0001
	move.b #2,d0
.0001:
select_focus1:
	move.b	d0,IOFocus				; set IO focus
	; reset keyboard processor to focus core
;	move.l #$3C060500,d0			; core=??,level sensitive,enabled,irq6,inta
;	or.b IOFocus,d0
;	move.l d0,PLIC+$80+4*30		; set register
	; Adjust text screen pointer
	subi.b #2,d0							; screen is 0 to 7, focus is 2 to 9
	ext.w	d0									; make into word value
	mulu #2048,d0							; * 2048	cells per screen
	rol.w	#8,d0								; swap byte order
	swap d0										; get bits 16-31
	rol.w	#8,d0								; swap byte order
	move.l d0,TEXTREG+$28			; update screen address in text controller
	bra	SyncCursor						; set cursor position

;==============================================================================
; PLIC - platform level interrupt controller
;
; Register layout:
;   bits 0 to 7  = cause code to issue (vector number)
;   bits 8 to 11 = irq level to issue
;   bit 16 = irq enable
;   bit 17 = edge sensitivity
;   bit 18 = 0=vpa, 1=inta
;		bit 24 to 29 target core
;
; Note byte order must be reversed for PLIC.
;==============================================================================

init_plic:
	lea	PLIC,a0							; a0 points to PLIC
	lea	$80+4*29(a0),a1			; point to timer registers (29)
	move.l #$0006033F,(a1)	; initialize, core=63,edge sensitive,enabled,irq6,vpa
	lea	4(a1),a1						; point to keyboard registers (30)
	move.l #$3C060502,(a1)	; core=2,level sensitive,enabled,irq6,inta
	lea	4(a1),a1						; point to nmi button register (31)
	move.l #$00070302,(a1)	; initialize, core=2,edge sensitive,enabled,irq7,vpa
	lea	$80+4*16(a0),a1			; a1 points to ACIA register
	move.l #$3D030502,(a1)	; core=2,level sensitive,enabled,irq3,inta	
	lea	$80+4*4(a0),a1			; a1 points to io_bitmap irq
	move.l #$3B060702,(a1)	; core=2,edge sensitive,enabled,irq6,inta	
	rts

;==============================================================================
; Keyboard stuff
;
; KeyState2_
; 876543210
; ||||||||+ = shift
; |||||||+- = alt
; ||||||+-- = control
; |||||+--- = numlock
; ||||+---- = capslock
; |||+----- = scrolllock
; ||+------ =
; |+------- = 
; +-------- = extended
;
;==============================================================================

;------------------------------------------------------------------------------
; Setup the Keyboard device
;------------------------------------------------------------------------------
setup_keybd:
keybd_init:
	moveq #31,d0
	lea.l keybd_dcb,a0
.0001:
	clr.l (a0)+
	dbra d0,.0001
	move.l #$20424344,keybd_dcb+DCB_MAGIC				; 'DCB'
	move.l #$2044424B,keybd_dcb+DCB_NAME				; 'KBD'
	move.l #keybd_cmdproc,con_dcb+DCB_CMDPROC
	move.l #_KeybdBuf,keybd_dcb+DCB_INBUFPTR
	move.l #_KeybdOBuf,keybd_dcb+DCB_OUTBUFPTR
	move.l #32,keybd_dcb+DCB_INBUFSIZE
	move.l #32,keybd_dcb+DCB_OUTBUFSIZE
	clr.b keybd_dcb+DCB_OUTCOLS	; set rows and columns
	clr.b keybd_dcb+DCB_OUTROWS
	clr.b keybd_dcb+DCB_INCOLS		; set rows and columns
	clr.b keybd_dcb+DCB_INROWS
;	bsr KeybdInit
	rts

	align 2
KBD_CMDTBL:
	dc.l keybd_init
	dc.l keybd_stat
	dc.l keybd_putchar
	dc.l keybd_putbuf
	dc.l keybd_getchar
	dc.l keybd_getbuf
	dc.l keybd_set_inpos
	dc.l keybd_set_outpos

keybd_cmdproc:
	cmpi.b #8,d6
	bhs.s .0001
	tst.b d6
	bmi.s .0001
	movem.l d6/a0,-(a7)
	asl.b #2,d6
	ext.w d6
	lea KBD_CMDTBL,a0
	move.l (a0,d6.w),a0
	jsr (a0)
	movem.l (a7)+,d6/a0
	rts
.0001:
	moveq #E_Func,d0
	rts

keybd_stat:
	bsr _KeybdGetStatus
	moveq #E_Ok,d0
	rts

keybd_putchar:
	bsr KeybdSendByte
	moveq #E_Ok,d0
	rts

keybd_getchar:
	bsr GetKey
	moveq #E_Ok,d0
	rts

keybd_putbuf:
keybd_getbuf:
keybd_set_inpos:
keybd_set_outpos:
	moveq #E_NotSupported,d0
	rts

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Get ID - get the keyboards identifier code.
;
; Parameters: none
; Returns: d = $AB83, $00 on fail
; Modifies: d, KeybdID updated
; Stack Space: 2 words
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

KeybdGetID:
	move.w	#$F2,d1
	bsr			KeybdSendByte
	bsr			KeybdWaitTx
	bsr			KeybdRecvByte
	btst		#7,d1
	bne			kgnotKbd
	cmpi.b	#$AB,d1
	bne			kgnotKbd
	bsr			KeybdRecvByte
	btst		#7,d1
	bne			kgnotKbd
	cmpi.b	#$83,d1
	bne			kgnotKbd
	move.l	#$AB83,d1
kgid1:
	move.w	d1,KeybdID
	rts
kgnotKbd:
	moveq		#0,d1
	bra			kgid1

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Set the LEDs on the keyboard.
;
; Parameters:
;		d1.b = LED state
;	Modifies:
;		none
; Returns:
;		none
; Stack Space:
;		1 long word
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

KeybdSetLED:
	move.l	d1,-(a7)
	move.b	#$ED,d1
	bsr			KeybdSendByte
	bsr			KeybdWaitTx
	bsr			KeybdRecvByte
	tst.b		d1
	bmi			.0001
	cmpi.b	#$FA,d1
	move.l	(a7),d1
	bsr			KeybdSendByte
	bsr			KeybdWaitTx
	bsr			KeybdRecvByte
.0001:
	move.l	(a7)+,d1
	rts

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Initialize the keyboard.
;
; Parameters:
;		none
;	Modifies:
;		none
; Returns:
;		none
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

_KeybdInit:
KeybdInit:
;	movem.l	d0/d1/d3/a1,-(a7)
	clr.b	_KeyState1		; records key up/down state
	clr.b	_KeyState2		; records shift,ctrl,alt state
	rts

	bsr			Wait300ms
	bsr			_KeybdGetStatus	; wait for response from keyboard
	tst.b		d1
	bpl			.0001					; is input buffer full ? no, branch
	bsr	_KeybdGetScancode
	bsr _KeybdClearIRQ
	cmpi.b	#$AA,d1				; keyboard Okay
	beq			kbdi0005
.0001:
	moveq		#10,d3
kbdi0002:
	bsr			Wait10ms
	clr.b		KEYBD+1				; clear receive register (write $00 to status reg)
	bsr net_delay
	moveq		#-1,d1				; send reset code to keyboard
	move.b	d1,KEYBD+1		; write $FF to status reg to clear TX state
	bsr net_delay
	bsr			KeybdSendByte	; now write ($FF) to transmit register for reset
	bsr			KeybdWaitTx		; wait until no longer busy
	tst.l		d1
	bmi			kbdiXmitBusy
	bsr			KeybdRecvByte	; look for an ACK ($FA)
	cmpi.b	#$FA,d1
	bne			.0001
	bsr			KeybdRecvByte	; look for BAT completion code ($AA)
.0001:
	cmpi.b	#$FC,d1				; reset error ?
	beq			kbdiTryAgain
	cmpi.b	#$AA,d1				; reset complete okay ?
	bne			kbdiTryAgain

	; After a reset, scan code set #2 should be active
.config:
	move.w	#$F0,d1			; send scan code select
	move.b	d1,leds
	bsr net_delay
	bsr			KeybdSendByte
	bsr			KeybdWaitTx
	tst.l		d1
	bmi			kbdiXmitBusy
	bsr			KeybdRecvByte	; wait for response from keyboard
	tst.w		d1
	bmi			kbdiTryAgain
	cmpi.b	#$FA,d1				; ACK
	beq			kbdi0004
kbdiTryAgain:
	dbra		d3,kbdi0002
.keybdErr:
	lea			msgBadKeybd,a1
	bsr			DisplayStringCRLF
	bra			ledxit
kbdi0004:
	moveq		#2,d1			; select scan code set #2
	bsr			KeybdSendByte
	bsr			KeybdWaitTx
	tst.l		d1
	bmi			kbdiXmitBusy
	bsr			KeybdRecvByte	; wait for response from keyboard
	tst.w		d1
	bmi			kbdiTryAgain
	cmpi.b	#$FA,d1
	bne			kbdiTryAgain
kbdi0005:
	bsr			KeybdGetID
ledxit:
	moveq		#$07,d1
	bsr			KeybdSetLED
	bsr			Wait300ms
	moveq		#$00,d1
	bsr			KeybdSetLED
	movem.l	(a7)+,d0/d1/d3/a1
	rts
kbdiXmitBusy:
	lea			msgXmitBusy,a1
	bsr			DisplayStringCRLF
	movem.l	(a7)+,d0/d1/d3/a1
	rts
	
msgBadKeybd:
	dc.b		"Keyboard error",0
msgXmitBusy:
	dc.b		"Keyboard transmitter stuck",0

	even
_KeybdGetStatus:
	movec coreno,d1
	cmpi.b #2,d1
	bne .0001
	moveq	#0,d1
	move.b KEYBD+1,d1
	rts
.0001:
	moveq #0,d1
	move.b KEYBD+3,d1
	rts

; Get the scancode from the keyboard port

_KeybdGetScancode:
	movec coreno,d1
	cmpi.b #2,d1
	bne .0001
	moveq		#0,d1
	move.b	KEYBD,d1				; get the scan code
	rts
.0001:
	moveq #0,d1
	move.b KEYBD+2,d1
	rts

_KeybdClearIRQ:
	move.l d1,-(a7)
	movec coreno,d1
	cmpi.b #2,d1
	bne .0001
	move.b	#0,KEYBD+1			; clear receive register
.0001:
	move.l (a7)+,d1
	rts

; Recieve a byte from the keyboard, used after a command is sent to the
; keyboard in order to wait for a response.
;
KeybdRecvByte:
	move.l	d3,-(a7)
	move.w	#100,d3		; wait up to 1s
.0003:
	bsr			_KeybdGetStatus	; wait for response from keyboard
	tst.b		d1
	bmi			.0004			; is input buffer full ? yes, branch
	bsr			Wait10ms	; wait a bit
	dbra		d3,.0003	; go back and try again
	move.l	(a7)+,d3
	moveq		#-1,d1		; return -1
	rts
.0004:
	bsr	_KeybdGetScancode
	bsr _KeybdClearIRQ
	move.l	(a7)+,d3
	rts


; Wait until the keyboard transmit is complete
; Returns -1 if timedout, 0 if transmit completed
;
KeybdWaitTx:
	movem.l	d2/d3,-(a7)
	moveq		#100,d3		; wait a max of 1s
.0001:
	bsr	_KeybdGetStatus
	btst #6,d1				; check for transmit complete bit
	bne	.0002					; branch if bit set
	bsr	Wait10ms			; delay a little bit
	dbra d3,.0001			; go back and try again
	movem.l	(a7)+,d2/d3
	moveq	#-1,d1			; return -1
	rts
.0002:
	movem.l	(a7)+,d2/d3
	moveq	#0,d1		; return 0
	rts

;------------------------------------------------------------------------------
; d1.b 0=echo off, non-zero = echo on
;------------------------------------------------------------------------------

SetKeyboardEcho:
	move.b	d1,KeybdEcho
	rts

;------------------------------------------------------------------------------
; Get key pending status into d1.b
;
; Returns:
;		d1.b = 1 if a key is available, otherwise zero.
;------------------------------------------------------------------------------

CheckForKey:
	moveq.l	#0,d1					; clear high order bits
;	move.b	KEYBD+1,d1		; get keyboard port status
;	smi.b		d1						; set true/false
;	andi.b	#1,d1					; return true (1) if key available, 0 otherwise
	tst.b	_KeybdCnt
	sne.b	d1
	rts

;------------------------------------------------------------------------------
; GetKey
; 	Get a character from the keyboard. 
;
; Modifies:
;		d1
; Returns:
;		d1 = -1 if no key available or not in focus, otherwise key
;------------------------------------------------------------------------------

GetKey:
	move.l	d0,-(a7)					; push d0
	move.b	IOFocus,d1				; Check if the core has the IO focus
	movec.l	coreno,d0
	cmp.b	d0,d1
	bne.s	.0004								; go return no key available, if not in focus
	bsr	KeybdGetCharNoWait		; get a character
	tst.l	d1									; was a key available?
	bmi.s	.0004
	tst.b	KeybdEcho						; is keyboard echo on ?
	beq.s	.0003								; no echo, just return the key
	cmpi.b #CR,d1							; convert CR keystroke into CRLF
	bne.s	.0005
	bsr	CRLF
	bra.s	.0003
.0005:
	bsr	OutputChar
.0003:
	move.l (a7)+,d0						; pop d0
	rts												; return key
; Return -1 indicating no char was available
.0004:
	move.l (a7)+,d0						; pop d0
	moveq	#-1,d1							; return no key available
	rts

;------------------------------------------------------------------------------
; Check for the cntrl-C keyboard sequence. Abort running routine and drop
; back into the monitor.
;------------------------------------------------------------------------------

CheckForCtrlC:
	move.l d1,-(a7)
	bsr	KeybdGetCharNoWait
	cmpi.b #CTRLC,d1
	beq	Monitor
	move.l (a7)+,d1
	rts

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

KeybdGetCharNoWait:
	clr.b	KeybdWaitFlag
	bra	KeybdGetChar

KeybdGetCharWait:
	move.b #-1,KeybdWaitFlag

KeybdGetChar:
	movem.l	d0/d2/d3/a0,-(a7)
.0003:
	movec	coreno,d0
	swap d0
	moveq	#KEYBD_SEMA,d1
	bsr	LockSemaphore
	move.b	_KeybdCnt,d2		; get count of buffered scan codes
	beq.s		.0015						;
	move.b	_KeybdHead,d2		; d2 = buffer head
	ext.w		d2
	lea			_KeybdBuf,a0		; a0 = pointer to keyboard buffer
	clr.l		d1
	move.b	(a0,d2.w),d1		; d1 = scan code from buffer
	addi.b	#1,d2						; increment keyboard head index
	andi.b	#31,d2					; and wrap around at buffer size
	move.b	d2,_KeybdHead
	subi.b	#1,_KeybdCnt		; decrement count of scan codes in buffer
	exg			d1,d2						; save scancode value in d2
	movec		coreno,d0
	swap		d0
	moveq		#KEYBD_SEMA,d1
	bsr			UnlockSemaphore
	exg			d2,d1						; restore scancode value
	bra			.0001						; go process scan code
.0014:
	bsr		_KeybdGetStatus		; check keyboard status for key available
	bmi		.0006							; yes, go process
.0015:
	movec		coreno,d0
	swap		d0
	moveq		#KEYBD_SEMA,d1
	bsr			UnlockSemaphore
	tst.b		KeybdWaitFlag			; are we willing to wait for a key ?
	bmi			.0003							; yes, branch back
	movem.l	(a7)+,d0/d2/d3/a0
	moveq		#-1,d1						; flag no char available
	rts
.0006:
	bsr	_KeybdGetScancode
	bsr _KeybdClearIRQ
.0001:
	move.w	#1,leds
	cmp.b	#SC_KEYUP,d1
	beq		.doKeyup
	cmp.b	#SC_EXTEND,d1
	beq		.doExtend
	cmp.b	#SC_CTRL,d1
	beq		.doCtrl
	cmp.b	#SC_LSHIFT,d1
	beq		.doShift
	cmp.b	#SC_RSHIFT,d1
	beq		.doShift
	cmp.b	#SC_NUMLOCK,d1
	beq		.doNumLock
	cmp.b	#SC_CAPSLOCK,d1
	beq		.doCapsLock
	cmp.b	#SC_SCROLLLOCK,d1
	beq		.doScrollLock
	cmp.b   #SC_ALT,d1
	beq     .doAlt
	move.b	_KeyState1,d2			; check key up/down
	move.b	#0,_KeyState1			; clear keyup status
	tst.b	d2
	bne	    .0003					; ignore key up
	cmp.b   #SC_TAB,d1
	beq     .doTab
.0013:
	move.b	_KeyState2,d2
	bpl		.0010					; is it extended code ?
	and.b	#$7F,d2					; clear extended bit
	move.b	d2,_KeyState2
	move.b	#0,_KeyState1			; clear keyup
	lea		_keybdExtendedCodes,a0
	move.b	(a0,d1.w),d1
	bra		.0008
.0010:
	btst	#2,d2					; is it CTRL code ?
	beq		.0009
	and.w	#$7F,d1
	lea		_keybdControlCodes,a0
	move.b	(a0,d1.w),d1
	bra		.0008
.0009:
	btst	#0,d2					; is it shift down ?
	beq  	.0007
	lea		_shiftedScanCodes,a0
	move.b	(a0,d1.w),d1
	bra		.0008
.0007:
	lea		_unshiftedScanCodes,a0
	move.b	(a0,d1.w),d1
	move.w	#$0202,leds
.0008:
	move.w	#$0303,leds
	movem.l	(a7)+,d0/d2/d3/a0
	rts
.doKeyup:
	move.b	#-1,_KeyState1
	bra		.0003
.doExtend:
	or.b	#$80,_KeyState2
	bra		.0003
.doCtrl:
	move.b	_KeyState1,d1
	clr.b	_KeyState1
	tst.b	d1
	bpl.s	.0004
	bclr	#2,_KeyState2
	bra		.0003
.0004:
	bset	#2,_KeyState2
	bra		.0003
.doAlt:
	move.b	_KeyState1,d1
	clr.b	_KeyState1
	tst.b	d1
	bpl		.0011
	bclr	#1,_KeyState2
	bra		.0003
.0011:
	bset	#1,_KeyState2
	bra		.0003
.doTab:
	move.l	d1,-(a7)
  move.b  _KeyState2,d1
  btst	#1,d1                 ; is ALT down ?
  beq     .0012
;    	inc     _iof_switch
  move.l	(a7)+,d1
  bra     .0003
.0012:
  move.l	(a7)+,d1
  bra     .0013
.doShift:
	move.b	_KeyState1,d1
	clr.b	_KeyState1
	tst.b	d1
	bpl.s	.0005
	bclr	#0,_KeyState2
	bra		.0003
.0005:
	bset	#0,_KeyState2
	bra		.0003
.doNumLock:
	bchg	#4,_KeyState2
	bsr		KeybdSetLEDStatus
	bra		.0003
.doCapsLock:
	bchg	#5,_KeyState2
	bsr		KeybdSetLEDStatus
	bra		.0003
.doScrollLock:
	bchg	#6,_KeyState2
	bsr		KeybdSetLEDStatus
	bra		.0003

KeybdSetLEDStatus:
	movem.l	d2/d3,-(a7)
	clr.b		KeybdLEDs
	btst		#4,_KeyState2
	beq.s		.0002
	move.b	#2,KeybdLEDs
.0002:
	btst		#5,_KeyState2
	beq.s		.0003
	bset		#2,KeybdLEDs
.0003:
	btst		#6,_KeyState2
	beq.s		.0004
	bset		#0,KeybdLEDs
.0004:
	move.b	KeybdLEDs,d1
	bsr			KeybdSetLED
	movem.l	(a7)+,d2/d3
	rts

KeybdSendByte:
	move.b d1,KEYBD
	rts
	
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Wait for 10 ms
;
; Parameters: none
; Returns: none
; Modifies: none
; Stack Space: 2 long words
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Wait10ms:
	movem.l	d0/d1,-(a7)
	movec	tick,d0
	addi.l #400000,d0			; 400,000 cycles at 40MHz
.0001:
	movec	tick,d1
	cmp.l	d1,d0
	bhi	.0001
	movem.l	(a7)+,d0/d1
	rts

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Wait for 300 ms
;
; Parameters: none
; Returns: none
; Modifies: none
; Stack Space: 2 long words
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Wait300ms:
	movem.l	d0/d1,-(a7)
	movec		tick,d0
	addi.l	#12000000,d0			; 12,000,000 cycles at 40MHz
.0001:
	movec		tick,d1
	cmp.l		d1,d0
	bhi			.0001
	movem.l	(a7)+,d0/d1
	rts

;--------------------------------------------------------------------------
; Keyboard IRQ routine.
; - only core 2 processes keyboard interrupts.
; - the keyboard buffer is in shared global scratchpad space.
;
; Returns:
; 	d1 = -1 if keyboard routine handled interrupt, otherwise positive.
;--------------------------------------------------------------------------

KeybdIRQ:
	move.w #$2600,sr					; disable lower interrupts
	movem.l	d0/d1/a0,-(a7)
	eori.l #-1,$FD000000
	moveq	#0,d1								; check if keyboard IRQ
	move.b KEYBD+1,d1					; get status reg
	tst.b	d1
	bpl	.0001									; branch if not keyboard
	movec	coreno,d0
	swap d0
	moveq	#KEYBD_SEMA,d1
	bsr LockSemaphore
	move.b KEYBD,d1						; get scan code
	clr.b KEYBD+1							; clear status register (clears IRQ AND scancode)
	btst #1,_KeyState2				; Is Alt down?
	beq.s	.0003
	cmpi.b #SC_TAB,d1					; is Alt-Tab?
	bne.s	.0003
	movec tick,d0
	sub.l _Keybd_tick,d0
	cmp.l #10,d0							; has it been 10 or more ticks?
;	blo.s .0002
	movec tick,d0							; update tick of last ALT-Tab
	move.l d0,_Keybd_tick
	bsr	rotate_iofocus
	clr.b	_KeybdHead					; clear keyboard buffer
	clr.b	_KeybdTail
	clr.b	_KeybdCnt
	bra	.0002									; do not store Alt-Tab
.0003:
	; Insert keyboard scan code into raw keyboard buffer
	cmpi.b #32,_KeybdCnt			; see if keyboard buffer full
	bhs.s	.0002
	move.b _KeybdTail,d0			; keyboard buffer not full, add to tail
	ext.w	d0
	lea	_KeybdBuf,a0					; a0 = pointer to buffer
	move.b d1,(a0,d0.w)				; put scancode in buffer
	addi.b #1,d0							; increment tail index
	andi.b #31,d0							; wrap at buffer limit
	move.b d0,_KeybdTail			; update tail index
	addi.b #1,_KeybdCnt				; increment buffer count
.0002:
	movec	coreno,d0
	swap d0
	moveq	#KEYBD_SEMA,d1
	bsr	UnlockSemaphore
.0001:
	movem.l	(a7)+,d0/d1/a0		; return
	rte

;--------------------------------------------------------------------------
; PS2 scan codes to ascii conversion tables.
;--------------------------------------------------------------------------
;
_unshiftedScanCodes:
	dc.b	$2e,$a9,$2e,$a5,$a3,$a1,$a2,$ac
	dc.b	$2e,$aa,$a8,$a6,$a4,$09,$60,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$71,$31,$2e
	dc.b	$2e,$2e,$7a,$73,$61,$77,$32,$2e
	dc.b	$2e,$63,$78,$64,$65,$34,$33,$2e
	dc.b	$2e,$20,$76,$66,$74,$72,$35,$2e
	dc.b	$2e,$6e,$62,$68,$67,$79,$36,$2e
	dc.b	$2e,$2e,$6d,$6a,$75,$37,$38,$2e
	dc.b	$2e,$2c,$6b,$69,$6f,$30,$39,$2e
	dc.b	$2e,$2e,$2f,$6c,$3b,$70,$2d,$2e
	dc.b	$2e,$2e,$27,$2e,$5b,$3d,$2e,$2e
	dc.b	$ad,$2e,$0d,$5d,$2e,$5c,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$08,$2e
	dc.b	$2e,$95,$2e,$93,$94,$2e,$2e,$2e
	dc.b	$98,$7f,$92,$2e,$91,$90,$1b,$af
	dc.b	$ab,$2e,$97,$2e,$2e,$96,$ae,$2e

	dc.b	$2e,$2e,$2e,$a7,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$fa,$2e,$2e,$2e,$2e,$2e

_shiftedScanCodes:
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$09,$7e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$51,$21,$2e
	dc.b	$2e,$2e,$5a,$53,$41,$57,$40,$2e
	dc.b	$2e,$43,$58,$44,$45,$24,$23,$2e
	dc.b	$2e,$20,$56,$46,$54,$52,$25,$2e
	dc.b	$2e,$4e,$42,$48,$47,$59,$5e,$2e
	dc.b	$2e,$2e,$4d,$4a,$55,$26,$2a,$2e
	dc.b	$2e,$3c,$4b,$49,$4f,$29,$28,$2e
	dc.b	$2e,$3e,$3f,$4c,$3a,$50,$5f,$2e
	dc.b	$2e,$2e,$22,$2e,$7b,$2b,$2e,$2e
	dc.b	$2e,$2e,$0d,$7d,$2e,$7c,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$08,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$7f,$2e,$2e,$2e,$2e,$1b,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e

	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e

; control
_keybdControlCodes:
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$09,$7e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$11,$21,$2e
	dc.b	$2e,$2e,$1a,$13,$01,$17,$40,$2e
	dc.b	$2e,$03,$18,$04,$05,$24,$23,$2e
	dc.b	$2e,$20,$16,$06,$14,$12,$25,$2e
	dc.b	$2e,$0e,$02,$08,$07,$19,$5e,$2e
	dc.b	$2e,$2e,$0d,$0a,$15,$26,$2a,$2e
	dc.b	$2e,$3c,$0b,$09,$0f,$29,$28,$2e
	dc.b	$2e,$3e,$3f,$0c,$3a,$10,$5f,$2e
	dc.b	$2e,$2e,$22,$2e,$7b,$2b,$2e,$2e
	dc.b	$2e,$2e,$0d,$7d,$2e,$7c,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$08,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$7f,$2e,$2e,$2e,$2e,$1b,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e

_keybdExtendedCodes:
	dc.b	$2e,$2e,$2e,$2e,$a3,$a1,$a2,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$95,$2e,$93,$94,$2e,$2e,$2e
	dc.b	$98,$99,$92,$2e,$91,$90,$2e,$2e
	dc.b	$2e,$2e,$97,$2e,$2e,$96,$2e,$2e

;==============================================================================
;==============================================================================
; Monitor
;==============================================================================
;==============================================================================

cmdString:
	dc.b	'?'+$80						; ? display help
	dc.b	'A','S'+$80				; AS = asteroids
	dc.b	'L'+$80						; L load S19 file
	dc.b	'F','B'+$80				; FB fill with byte
	dc.b	'F','W'+$80				; FW fill with wyde
	dc.b	'F','L'+$80				; FL fill with long wyde
	dc.b	'FMT','K'+$80			; FMTK run Femtiki OS
	dc.b	'B','A'+$80				; BA start Tiny Basic
	dc.b	'B','R'+$80				; BR breakpoint
	dc.b	'D','I'+$80				; DI disassemble
	dc.b	'D','R'+$80				; DR dump registers
	dc.b	'D'+$80						; D dump memory
	dc.b	'J'+$80						; J jump to code
	dc.b	'E'+$80						; : edit memory
	dc.b	"CL",'S'+$80			; CLS clear screen
	dc.b	"COR",'E'+$80			; CORE <n> switch to core
	dc.b	"TF",'P'+$80			; TFP test fp
	dc.b  "TG",'F'+$80			; TGF test get float
	dc.b  "TRA",'M'+$80			; TRAM test RAM
	dc.b	'T','R'+$80				; TR test serial receive
	dc.b	'T'+$80						; T test CPU
	dc.b	'S'+$80						; S send serial
	dc.b	"RESE",'T'+$80		; RESET <n>
	dc.b	"CLOC",'K'+$80		; CLOCK <n>
	dc.b	'R'+$80						; R receive serial
	dc.b	'V'+$80

	align	2
cmdTable:
	dc.l	cmdHelp
	dc.l	cmdAsteroids
	dc.l	cmdLoadS19
	dc.l	cmdFillB
	dc.l	cmdFillW
	dc.l	cmdFillL
	dc.l	cmdFMTK
	dc.l	cmdTinyBasic
	dc.l	cmdBreakpoint
	dc.l	cmdDisassemble
	dc.l	cmdDumpRegs
	dc.l	cmdDumpMemory
	dc.l	cmdJump
	dc.l	cmdEditMemory
	dc.l	cmdClearScreen
	dc.l	cmdCore
	dc.l  cmdTestFP
	dc.l	cmdTestGF
	dc.l  cmdTestRAM
	dc.l	cmdTestSerialReceive
	dc.l	cmdTestCPU
	dc.l	cmdSendSerial
	dc.l	cmdReset
	dc.l	cmdClock
	dc.l	cmdReceiveSerial	
	dc.l	cmdVideoMode
	dc.l	cmdMonitor

; Get a word from screen memory and swap byte order

FromScreen:
	move.l (a0),d1
	bsr	rbo
	if (SCREEN_FORMAT==1)
		lea	4(a0),a0	; increment screen pointer
	else
		lea	8(a0),a0	; increment screen pointer
	endif
	rts

StartMon:
	clr.w	NumSetBreakpoints
	bsr	ClearBreakpointList
cmdMonitor:
Monitor:
	; Reset the stack pointer on each entry into the monitor
	move.l #$40FFC,sp		; reset core's stack
	pea Monitor					; Cause any RTS to go here
	move.w #$2200,sr		; enable level 2 and higher interrupts
	movec	coreno,d0
	swap d0
	moveq	#1,d1
	bsr	UnlockSemaphore
	clr.b KeybdEcho			; turn off keyboard echo
PromptLn:
	bsr	CRLF
	move.b #'$',d1
	bsr OutputChar

; Get characters until a CR is keyed
;
Prompt3:
	bsr	GetKey
	cmpi.b #-1,d1
	beq.s	Prompt3
	cmpi.b #CR,d1
	beq.s	Prompt1
	bsr	OutputChar
	bra.s	Prompt3

; Process the screen line that the CR was keyed on

Prompt1:
	clr.b	CursorCol				; go back to the start of the line
	bsr	CalcScreenLoc			; a0 = screen memory location
.0001:
	bsr	FromScreen				; grab character off screen
	cmpi.b #'$',d1				; skip over '$' prompt character
	beq.s	.0001
	
; Dispatch based on command string

cmdDispatch:
	lea	cmdString,a2
	clr.l	d4							; command counter
	if (SCREEN_FORMAT==1)
		lea	-4(a0),a0				; backup a character
	else
		lea	-8(a0),a0				; backup a character
	endif
	move.l	a0,a3					; a3 = start of command on screen
.checkNextCmd:
	bsr	FromScreen				; d1 = char from input screen
	move.b (a2)+,d5
	eor.b	d5,d1						; does it match with command string?
	beq.s	.checkNextCmd		; If it does, keep matching for longest match
	cmpi.b #$80,d1				; didn't match, was it the end of the command?
	beq.s	.foundCmd
	tst.b	-1(a2)					; was end of table hit?
	beq.s	.endOfTable
	addi.w #4,d4					; increment command counter
	move.l a3,a0					; reset input pointer
	tst.b	-1(a2)					; were we at the end of the command?
	bmi.s	.checkNextCmd		; if were at end continue, otherwise scan for end of cmd
.scanToEndOfCmd
	tst.b	(a2)+						; scan to end of command
	beq.s	.endOfTable
	bpl.s	.scanToEndOfCmd
	bmi.s	.checkNextCmd
.endOfTable
	lea	msgUnknownCmd,a1
	bsr	DisplayStringCRLF
	bra	Monitor
.foundCmd:
	lea	cmdTable,a1				; a1 = pointer to command address table
	move.l (a1,d4.w),a1		; fetch command routine address from table
	jmp	(a1)							; go execute command

cmdVideoMode:
	bsr ignBlanks
	bsr GetHexNumber
	cmpi.b #0,d1
	bne.s .0001
	bsr set_text_mode
	bsr clear_screen
	bra Monitor
.0001:
	bsr set_graphics_mode
	bsr get_screen_address
	move.l #0,RAND+4		; select stream 0
	move.w #7499,d2
.0002:
	move.l RAND,d1
	move.l #0,RAND			; cause new number generation
	move.l d1,(a0)+			; random display
	dbra d2,.0002
	bra Monitor

cmdBreakpoint:
	bsr	ignBlanks
	bsr	FromScreen
	cmpi.b	#'+',d1
	beq	ArmBreakpoint
	cmpi.b	#'-',d1
	beq	DisarmBreakpoint
	cmpi.b	#'L',d1
	beq	ListBreakpoints
	bra	Monitor

cmdAsteroids:
	pea Monitor
	jmp asteroids_start

cmdTinyBasic:
	bra	CSTART

cmdTestCPU:
	bsr	cpu_test
	lea	msg_test_done,a1
	bsr	DisplayStringCRLF
	bra	Monitor

cmdClearScreen:
	bsr	ClearScreen
	bsr	HomeCursor
	bra	Monitor

cmdCore:
	bsr			ignBlanks
	bsr			FromScreen
	cmpi.b	#'2',d1					; check range
	blo			Monitor
	cmpi.b	#'0'+NCORES+1,d1
	bhi			Monitor
	subi.b	#'0',d1					; convert ascii to binary
	bsr			select_iofocus
	bra			Monitor

cmdFMTK:
	bsr FemtikiInit
	bra Monitor

cmdTestFP:
	moveq #41,d0						; function #41, get float
	moveq #8,d1							; d1 = input stride
	move.l a0,a1						; a1 = pointer to input buffer
	trap #15
	move.l a1,a0
	fmove.x fp0,fp4
	bsr ignBlanks
	bsr FromScreen
	move.b d1,d7
	moveq #41,d0						; function #41, get float
	move.l #8,d1						; d1 = input stride
	move.l a0,a1						; a1 = pointer to input buffer
	trap #15
	move.l a1,a0
	fmove.x fp0,fp2
	bsr CRLF
;	moveq #39,d0
;	moveq #40,d1
;	moveq #30,d2
;	moveq #'e',d3
;	trap #15
;	bsr CRLF
	fmove.x fp4,fpBuf
	fmove.x fp2,fpBuf+16
	cmpi.b #'+',d7
	bne .0001
	fadd fp2,fp4
	bra .0002
.0001
	cmpi.b #'-',d7
	bne .0003
	fsub fp2,fp4
	bra .0002
.0003
	cmpi.b #'*',d7
	bne .0004
	fmul fp2,fp4
	bra .0002
.0004
	cmpi.b #'/',d7
	bne .0005
	fdiv fp2,fp4
	bra .0002
.0002
	fmove.x fp4,fpBuf+32
	fmove.x fp4,fp0
	lea _fpBuf,a1						; a0 = pointer to buffer to use
	moveq #39,d0						; function #39 print float
	moveq #40,d1						; width
	moveq #30,d2						; precision
	moveq #'e',d3
	trap #15
.0005
	bsr CRLF
	bra Monitor

cmdTestGF:
	bsr CRLF
	moveq #41,d0						; function #41, get float
	move.l #8,d1						; d1 = input stride
	move.l a0,a1						; a1 = pointer to input buffer
	trap #15
	fmove.x fp0,fpBuf+32
	lea _fpBuf,a1						; a0 = pointer to buffer to use
	moveq #39,d0
	moveq #40,d1
	moveq #30,d2
	moveq #'e',d3
	trap #15
	move.l a1,a0
	bsr CRLF
	bra Monitor
		
;-------------------------------------------------------------------------------
; CLOCK <n>
;    Set the clock register to n which will turn off or on clocks to the CPUs.
;-------------------------------------------------------------------------------

cmdClock:
	bsr			ignBlanks
	bsr			GetHexNumber
	tst.b		d0							; was there a number?
	beq			Monitor
	ori.w		#4,d0						; primary core's clock cannot be turned off
	rol.w		#8,d1						; switch byte order
	move.w	d1,RST_REG+2
	bra			Monitor

;-------------------------------------------------------------------------------
; RESET <n>
;    Reset the specified core. Resetting the core automatically turns on the 
; core's clock.
;-------------------------------------------------------------------------------

cmdReset:
	bsr			ignBlanks
	bsr			FromScreen
	cmpi.b	#'2',d1					; check range
	blo			Monitor
	cmpi.b	#'9',d1
	bhi			Monitor
	subi.b	#'0',d1					; convert ascii to binary
	lsl.w		#1,d1						; make into index
	lea			tblPow2,a1
	move.w	(a1,d1.w),d1
	rol.w		#8,d1						; reverse byte order
	move.w	d1,RST_REG
	bra			Monitor

tblPow2:
	dc.w		1
	dc.w		2
	dc.w		4
	dc.w		8
	dc.w		16
	dc.w		32
	dc.w		64
	dc.w		128
	dc.w		256
	dc.w		512
	dc.w		1024
	dc.w		2048
	dc.w		4096
	dc.w		8192
	dc.w		16384
	dc.w		32768
	even
	
cmdHelp:
DisplayHelp:
	lea			HelpMsg,a1
	bsr			DisplayString
	bra			Monitor

HelpMsg:
	dc.b	"? = Display help",LF,CR
	dc.b  "CORE n = switch to core n, n = 2 to 9",LF,CR
	dc.b  "RESET n = reset core n",LF,CR
	dc.b	"CLS = clear screen",LF,CR
	dc.b	"EB = Edit memory bytes, EW, EL",LF,CR
	dc.b	"FB = Fill memory bytes, FW, FL",LF,CR
	dc.b	"FMTK = run Femtiki OS",LF,CR
	dc.b	"L = Load S19 file",LF,CR
	dc.b	"D = Dump memory, DR = dump registers",LF,CR
	dc.b	"DI = Disassemble",LF,CR
	dc.b	"BA = start tiny basic",LF,CR
	dc.b  "BR = set breakpoint",LF,CR
	dc.b	"J = Jump to code",LF,CR
	dc.b  "S = send to serial port",LF,CR
	dc.b	"T = cpu test program",LF,CR
	dc.b	"TRAM = test RAM",LF,CR,0

msgUnknownCmd:
	dc.b	"command unknown",0

msgHello:
	dc.b	LF,CR,"Hello World!",LF,CR,0
	even

;------------------------------------------------------------------------------
; This routine borrowed from Gordo's Tiny Basic interpreter.
; Used to fetch a command line. (Not currently used).
;
; d0.b	- command prompt
;------------------------------------------------------------------------------

GetCmdLine:
		bsr		OutputChar		; display prompt
		move.b	#' ',d0
		bsr		OutputChar
		lea		CmdBuf,a0
.0001:
		bsr		GetKey
		cmp.b	#CTRLH,d0
		beq.s	.0003
		cmp.b	#CTRLX,d0
		beq.s	.0004
		cmp.b	#CR,d0
		beq.s	.0002
		cmp.b	#' ',d0
		bcs.s	.0001
.0002:
		move.b	d0,(a0)
		lea			8(a0),a0
		bsr		OutputChar
		cmp.b	#CR,d0
		beq		.0007
		cmp.l	#CmdBufEnd-1,a0
		bcs.s	.0001
.0003:
		move.b	#CTRLH,d0
		bsr		OutputChar
		move.b	#' ',d0
		bsr		OutputChar
		cmp.l	#CmdBuf,a0
		bls.s	.0001
		move.b	#CTRLH,d0
		bsr		OutputChar
		subq.l	#1,a0
		bra.s	.0001
.0004:
		move.l	a0,d1
		sub.l	#CmdBuf,d1
		beq.s	.0006
		subq	#1,d1
.0005:
		move.b	#CTRLH,d0
		bsr		OutputChar
		move.b	#' ',d0
		bsr		OutputChar
		move.b	#CTRLH,d0
		bsr		OutputChar
		dbra	d1,.0005
.0006:
		lea		CmdBuf,a0
		bra		.0001
.0007:
		move.b	#LF,d0
		bsr		OutputChar
		rts

;------------------------------------------------------------------------------
; S <address> <length>
; Send data buffer to serial port
; S 40000 40
;------------------------------------------------------------------------------

cmdSendSerial:
	bsr			ignBlanks
	bsr			GetHexNumber
	beq			Monitor
	move.l	d1,d6					; d6 points to buffer
	bsr			ignBlanks
	bsr			GetHexNumber
	bne.s		.0003
	moveq		#16,d1
.0003:
	move.l	d6,a1					; a1 points to buffer
	move.l	d1,d2					; d2 = count of bytes to send
	bra.s		.0002					; enter loop at bottom
.0001:
	move.b	(a1)+,d1
	move.w	#34,d0				; serial putchar
	trap		#15
.0002:
	dbra		d2,.0001
	bra			Monitor
		
;------------------------------------------------------------------------------
; R <address> <length>
; Send data buffer to serial port
; R 10000 40
;------------------------------------------------------------------------------

cmdReceiveSerial:
	bsr			ignBlanks
	bsr			GetHexNumber
	beq			Monitor
	move.l	d1,d6					; d6 points to buffer
	bsr			ignBlanks
	bsr			GetHexNumber
	bne.s		.0003
	moveq		#16,d1
.0003:
	move.l	d6,a1					; a1 points to buffer
	move.l	d1,d2					; d2 = count of bytes to send
	bra.s		.0002					; enter loop at bottom
.0001:
	move.w	#36,d0				; serial peek char
	trap		#15
	tst.l		d1
	bmi.s		.0001
	move.b	d1,(a1)+
.0002:
	dbra		d2,.0001
	bra			Monitor
		
;------------------------------------------------------------------------------
; Fill memory
;
; FB = fill bytes		FB 00000010 100 FF	; fill starting at 10 for 256 bytes
; FB = fill bytes		FB 00000010 100 R		; fill with random bytes
; FW = fill words
; FL = fill longs
; F = fill bytes
;------------------------------------------------------------------------------

cmdFillB:
	bsr			ignBlanks
	bsr			GetHexNumber
	move.l	d1,a1					; a1 = start
	bsr			ignBlanks
	bsr			GetHexNumber
	move.l	d1,d3					; d3 = count
	beq			Monitor
	bsr			ignBlanks
	bsr PeekScreenChar
	cmpi.b #'R',d1
	bne.s .0002
	bsr FromScreen
	move.b #'R',d5
	bra.s .fmem
.0002:
	bsr	GetHexNumber		; fill value
	move.b d1,d4
.fmem:
	move.w a1,d2
	tst.w d2
	bne.s .0001
	bsr	CheckForCtrlC
.0001:	
	cmpi.b #'R',d5
	bne.s .0003
	bsr RandGetNum
.0003:
	move.b d4,(a1)+
	sub.l	#1,d3
	bne.s	.fmem
	bra	Monitor
	
cmdFillW:
	bsr			ignBlanks
	bsr			GetHexNumber
	move.l	d1,a1					; a1 = start
	bsr			ignBlanks
	bsr			GetHexNumber
	move.l	d1,d3					; d3 = count
	beq			Monitor
	bsr			ignBlanks
	bsr PeekScreenChar
	cmpi.b #'R',d1
	bne.s .0002
	bsr FromScreen
	move.b #'R',d5
	bra.s .fmem
.0002:
	bsr	GetHexNumber			; fill value
	move.w d1,d4
.fmem:
	move.w a1,d2
	tst.w d2
	bne.s .0001
	bsr	CheckForCtrlC
.0001:	
	cmpi.b #'R',d5
	bne.s .0003
	bsr RandGetNum
.0003:
	move.w d4,(a1)+
	sub.l	#1,d3
	bne.s	.fmem
	bra	Monitor
	
cmdFillL:
	bsr			ignBlanks
	bsr			GetHexNumber
	move.l	d1,a1					; a1 = start
	bsr			ignBlanks
	bsr			GetHexNumber
	move.l	d1,d3					; d3 = count
	beq			Monitor
	bsr			ignBlanks
	bsr PeekScreenChar
	cmpi.b #'R',d1
	bne.s .0002
	bsr FromScreen
	move.b #'R',d5
	bra.s .fmem
.0002:
	bsr			GetHexNumber	; fill value
	move.l d1,d4
.fmem:
	move.w a1,d2
	tst.w d2
	bne.s .0001
	bsr	CheckForCtrlC
.0001:	
	cmpi.b #'R',d5
	bne.s .0003
	bsr RandGetNum
.0003:
	move.l d4,(a1)+
	sub.l	#1,d3
	bne.s	.fmem
	bra	Monitor
	
;------------------------------------------------------------------------------
; Modifies:
;	a0	- text pointer
;------------------------------------------------------------------------------

ignBlanks:
	move.l d1,-(a7)
.0001:
	bsr	FromScreen
	cmpi.b #' ',d1
	beq.s .0001
	if (SCREEN_FORMAT==1)
		lea	-4(a0),a0
	else
		lea	-8(a0),a0
	endif
	move.l (a7)+,d1
	rts


;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

PeekScreenChar:
	move.l (a0),d1
	bra rbo

;------------------------------------------------------------------------------
; Get the size character
; If the size is not recognized, assume a byte size
;
; Modifies:
;		a0	- text pointer
;		d1
; Returns:
;		d4 = size character 'B','W' or 'L'
;------------------------------------------------------------------------------

GetSzChar:
	bsr	ignBlanks
	moveq #'B',d4		; assume byte
	move.l (a0),d1
	bsr	rbo
	cmpi.b #'B',d1
	beq.s .0002
	cmpi.b #'W',d1
	beq.s .0002
	cmpi.b #'L',d1
	beq.s .0002
	rts
.0002:
	bsr FromScreen
	move.b d1,d4
	rts

;------------------------------------------------------------------------------
; Edit memory byte.
;    Bytes are built into long words in case the memory is only longword
; accessible.
;------------------------------------------------------------------------------

EditMemHelper:
	bsr ignBlanks
	bsr GetHexNumber
	cmpi.b #'L',d4
	bne.s .0001
	move.l d1,d2
	rts
.0001:
	cmpi.b #'W',d4
	bne.s .0002
	swap d2
	move.w d1,d2
	rts
.0002:
	lsl.l #8,d2
	move.b d1,d2
	rts
	
cmdEditMemory:
	bsr GetSzChar
	bsr ignBlanks
	bsr	GetHexNumber
	move.l d1,a1
edtmem1:
	cmpi.b #'L',d4
	bne.s .0004
	clr.l	d2
	bsr EditMemHelper
	move.l d2,(a1)+
	clr.l	d2
	bsr EditMemHelper
	move.l d2,(a1)+
	bra Monitor
.0004:
	cmpi.b #'W',d4
	bne.s .0005
	clr.l	d2
	bsr EditMemHelper
	bsr EditMemHelper
	move.l d2,(a1)+
	clr.l	d2
	bsr EditMemHelper
	bsr EditMemHelper
	move.l d2,(a1)+
	bra Monitor
.0005:
	clr.l	d2
	bsr EditMemHelper
	bsr EditMemHelper
	bsr EditMemHelper
	bsr EditMemHelper
	move.l d2,(a1)+
	clr.l	d2
	bsr EditMemHelper
	bsr EditMemHelper
	bsr EditMemHelper
	bsr EditMemHelper
	move.l d2,(a1)+
	bra Monitor

;------------------------------------------------------------------------------
; Execute code at the specified address.
;------------------------------------------------------------------------------

cmdJump:
ExecuteCode:
	bsr	ignBlanks
	bsr	GetHexNumber
	move.l d1,a0
	jsr	(a0)
	bra Monitor

;------------------------------------------------------------------------------
; Disassemble code
; DI 1000
;------------------------------------------------------------------------------
;        CALLING SEQUENCE:
;   D0,D1,D2 = CODE TO BE DISASSEMBLED
;   A4 = VALUE OF PROGRAM COUNTER FOR THE CODE
;   A5 = POINTER TO STORE DATA (BUFSIZE = 80 ASSUMED)
;        JSR       DCODE68K
;
;        RETURN:
;   A4 = VALUE OF PROGRAM COUNTER FOR NEXT INSTRUCTION
;   A5 = POINTER TO LINE AS DISASSEMBLED
;   A6 = POINTER TO END OF LINE


cmdDisassemble:
	bsr ignBlanks
	bsr GetHexNumber
	beq Monitor
	move.w #20,d3			; number of lines to disassemble
.0002:
	move.l d3,-(a7)
	move.l d1,a0
	move.l d1,a4			; a4 = PC of code
	move.w (a0)+,d0		; d0 to d2 = bytes of instruction to decode
	swap d0
	move.w (a0)+,d0
	move.w (a0)+,d1		; d0 to d2 = bytes of instruction to decode
	swap d1
	move.w (a0)+,d1
	move.w (a0)+,d2		; d0 to d2 = bytes of instruction to decode
	swap d2
	move.w (a0)+,d2
	lea _dasmbuf,a5		; a5 = pointer to disassembly buffer
	bsr DCODE68K	
	move.w #62,d4
.0001:
	move.b (a5)+,d1
	bsr OutputChar
	dbra d4,.0001
	bsr CRLF
	move.l a4,d1
	move.l (a7)+,d3
	dbra d3,.0002
	bra Monitor
	
;------------------------------------------------------------------------------
; Do a memory dump of the requested location.
; DB 0800 0850
;------------------------------------------------------------------------------

cmdDumpMemory:
	bsr GetSzChar
	bsr ignBlanks
	bsr	GetHexNumber
	beq	Monitor					; was there a number ? no, other garbage, just ignore
	move.l d1,d3				; save off start of range
	bsr	ignBlanks
	bsr	GetHexNumber
	bne.s	DumpMem1
	move.l d3,d1
	addi.l #64,d1				;	no end specified, just dump 64 bytes
DumpMem1:
	move.l d3,a0
	move.l d1,a1
	bsr	CRLF
.0001:
	cmpa.l a0,a1
	bls	Monitor
	bsr	DisplayMem
	bra.s	.0001

;------------------------------------------------------------------------------
; Display memory dump in a format suitable for edit.
;
;	EB 12345678 00 11 22 33 44 55 66 77  "........"
;
; Modifies:
;		d1,d2,a0
;------------------------------------------------------------------------------
	
DisplayMem:
	move.b #'E',d1
	bsr	OutputChar
	move.b d4,d1
	bsr OutputChar
	bsr DisplaySpace
	move.l a0,d1
	bsr	DisplayTetra
	moveq #7,d2						; assume bytes
	cmpi.b #'L',d4
	bne.s .0004
	moveq	#1,d2
	bra.s dspmem1
.0004:
	cmpi.b #'W',d4
	bne.s dspmem1
	moveq #3,d2
dspmem1:
	move.b #' ',d1
	bsr	OutputChar
	cmpi.b #'L',d4
	bne.s .0005
	move.l (a0)+,d1
	bsr	DisplayTetra
	bra.s .0006
.0005:
	cmpi.b #'W',d4
	bne.s .0007
	move.w (a0)+,d1
	bsr	DisplayWyde
	bra.s .0006
.0007:
	move.b (a0)+,d1
	bsr DisplayByte
.0006:
	dbra d2,dspmem1
	bsr	DisplayTwoSpaces
	move.b #34,d1
	bsr	OutputChar
	lea	-8(a0),a0
	moveq	#7,d2
.0002:
	move.b (a0)+,d1
	cmp.b	#' ',d1
	blo.s	.0003
	cmp.b	#127,d1
	bls.s	.0001
.0003:
	move.b #'.',d1
.0001:
	bsr	OutputChar
	dbra d2,.0002
	move.b #34,d1
	bsr	OutputChar
	bsr	CheckForCtrlC
	bra	CRLF

;------------------------------------------------------------------------------
; Dump Registers
;    The dump is in a format that allows the register value to be edited.
;
; RegD0 12345678
; RegD1 77777777
;	... etc
;------------------------------------------------------------------------------

cmdDumpRegs:
	bsr	CRLF
	move.w #15,d3						; number of registers-1
	lea	msg_reglist,a0			;
	lea	msg_regs,a1
	lea	Regsave,a2					; a2 points to register save area
.0001:
	bsr			DisplayString
	move.b	(a0)+,d1
	bsr			OutputChar
	move.b	(a0)+,d1
	bsr			OutputChar
	bsr			DisplaySpace
	move.l	(a2)+,d1
	bsr			DisplayTetra
	bsr			CRLF
	dbra		d3,.0001
	bsr			DisplayString
	move.b	(a0)+,d1
	bsr			OutputChar
	move.b	(a0)+,d1
	bsr			OutputChar
	bsr			DisplaySpace
	move.l	Regsave+$44,d1
	bsr			DisplayTetra
	bsr			CRLF
	bsr			DisplayString
	move.b	(a0)+,d1
	bsr			OutputChar
	move.b	(a0)+,d1
	bsr			OutputChar
	bsr			DisplaySpace
	move.w	Regsave+$40,d1
	bsr			DisplayWyde
	bsr			CRLF
	bra			Monitor

msg_regs:
	dc.b	"Reg",0
msg_reglist:
	dc.b	"D0D1D2D3D4D5D6D7A0A1A2A3A4A5A6A7PCSR",0

	align	1

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

cmdTestSerialReceive:
.0002:
	moveq		#36,d0				; serial get char from buffer
	trap		#15
;	bsr			SerialPeekCharDirect
	tst.w		d1
	bmi.s		.0001
	cmpi.b	#CTRLZ,d1
	beq			.0003
	bsr			OutputChar
.0001:	
	bsr			CheckForCtrlC
	bra			.0002
.0003:
	bsr			_KeybdInit
	bra			Monitor

;------------------------------------------------------------------------------
; Get a hexidecimal number. Maximum of eight digits.
;
; Returns:
;		d0 = number of digits
;		d1 = value of number
;		zf = number of digits == 0
;------------------------------------------------------------------------------

GetHexNumber:
	move.l d2,-(a7)
	clr.l	d2
	moveq	#0,d0
.0002
	bsr	FromScreen
	bsr	AsciiToHexNybble
	cmpi.b #$ff,d1
	beq.s	.0001
	lsl.l	#4,d2
	andi.l #$0f,d1
	or.l d1,d2
	addq #1,d0
	cmpi.b #8,d0
	blo.s	.0002
.0001
	move.l d2,d1
	move.l (a7)+,d2
	tst.b	d0
	rts	

GetDecNumber:
	movem.l d2/d3,-(a7)
	clr.l d2
	clr.l d0
.0002
	bsr FromScreen					; grab a character off the screen
	bsr	AsciiToHexNybble		; convert to an ascii nybble
	cmpi.b #$ff,d1
	beq.s	.0001
	andi.l #$0F,d1					; d1 = 0 to 9
	move.l d2,d3						; d3 = current number
	add.l d3,d3							; d3*2
	lsl.l #3,d2							; current number * 8
	add.l d3,d2							; current number * 10
	add.l d1,d2							; add in new digit
	addq #1,d0							; increment number of digits
	cmpi.b #9,d0						; make sure 9 or fewer
	blo .0002
.0001
	move.l d2,d1						; return number in d1
	movem.l (a7)+,d2/d3
	tst.b d0
	rts
	
	include "FloatToString.x68"
	include "GetFloat.asm"

;------------------------------------------------------------------------------
; Convert ASCII character in the range '0' to '9', 'a' tr 'f' or 'A' to 'F'
; to a hex nybble.
;------------------------------------------------------------------------------

AsciiToHexNybble:
	cmpi.b	#'0',d1
	blo.s		gthx3
	cmpi.b	#'9',d1
	bhi.s		gthx5
	subi.b	#'0',d1
	rts
gthx5:
	cmpi.b	#'A',d1
	blo.s		gthx3
	cmpi.b	#'F',d1
	bhi.s		gthx6
	addi.b	#10-'A',d1
	rts
gthx6:
	cmpi.b	#'a',d1
	blo.s		gthx3
	cmpi.b	#'f',d1
	bhi.s		gthx3
	addi.b	#10-'a',d1
	rts
gthx3:
	moveq	#-1,d1		; not a hex number
	rts

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

DisplayTwoSpaces:
	move.l	d1,-(a7)
	move.b	#' ',d1
	bsr			OutputChar
dspspc1:
	bsr			OutputChar
	move.l	(a7)+,d1
	rts

DisplaySpace:
	move.l	d1,-(a7)
	move.b	#' ',d1
	bra			dspspc1

;------------------------------------------------------------------------------
; Display the 32 bit word in D1.L
;------------------------------------------------------------------------------

DisplayTetra:
	swap	d1
	bsr		DisplayWyde
	swap	d1

;------------------------------------------------------------------------------
; Display the byte in D1.W
;------------------------------------------------------------------------------

DisplayWyde:
	ror.w		#8,d1
	bsr			DisplayByte
	rol.w		#8,d1

;------------------------------------------------------------------------------
; Display the byte in D1.B
;------------------------------------------------------------------------------

DisplayByte:
	ror.b		#4,d1
	bsr			DisplayNybble
	rol.b		#4,d1

;------------------------------------------------------------------------------
; Display nybble in D1.B
;------------------------------------------------------------------------------

DisplayNybble:
	move.l	d1,-(a7)
	andi.b	#$F,d1
	addi.b	#'0',d1
	cmpi.b	#'9',d1
	bls.s		.0001
	addi.b	#7,d1
.0001:
	bsr			OutputChar
	move.l	(a7)+,d1
	rts

;------------------------------------------------------------------------------
; Buffer tetra in d0 to buffer pointed to by a6
;------------------------------------------------------------------------------

BufTetra:
	swap d0
	bsr BufWyde
	swap d0

BufWyde:
	ror.w #8,d0
	bsr BufByte
	rol.w #8,d0
	
BufByte:
	ror.b #4,d0
	bsr BufNybble
	rol.b #4,d0

BufNybble:
	move.l d0,-(a7)
	andi.b #$F,d0
	addi.b #'0',d0
	cmpi.b #'9',d0
	bls.s .0001
	addi.b #7,d0
.0001:
	move.b d0,(a6)+
	move.l (a7)+,d0
	rts

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
;
;DisplayHexNumber:
;	move.w	#$A6A6,leds		; diagnostics
;	move.l	#VDGREG,a6
;	move.w	#7,d2		; number-1 of digits to display
;disphnum1:
;	move.b	d1,d0		; get digit into d0.b
;	andi.w	#$0f,d0
;	cmpi.w	#$09,d0
;	bls.s	disphnum2
;	addi.w	#7,d0
;disphnum2:
;	addi.w	#$30,d0	; convert to display char
;	move.w	d2,d3		; char count into d3
;	asl.w	#3,d3		; scale * 8
;disphnum3:
;	move.w	$42C(a6),d4			; read character queue index into d4
;	cmp.w	#28,d4					; allow up 28 entries to be in progress
;	bhs.s	disphnum3				; branch if too many chars queued
;	ext.w	d0						; zero out high order bits
;	move.w	d0,$420(a6)			; set char code
;	move.w	#WHITE,$422(a6)		; set fg color
;	move.w	#DARK_BLUE,$424(a6)	; set bk color
;	move.w	d3,$426(a6)			; set x pos
;	move.w	#8,$428(a6)			; set y pos
;	move.w	#$0707,$42A(a6)		; set font x,y extent
;	move.w	#0,$42E(a6)			; pulse character queue write signal
;	ror.l	#4,d1					; rot to next digit
;	dbeq	d2,disphnum1
;	jmp		(a5)

	include "ramtest.x68"
	include "LoadS19.x68"
	
AudioInputTest:
	rts
BouncingBalls:
	rts
GraphicsDemo:
	rts
ClearScreen:
	bra		clear_screen
	rts

;------------------------------------------------------------------------------
; Reverse the order of bytes in d1.
;------------------------------------------------------------------------------

rbo:
	rol.w	#8,d1
	swap d1
	rol.w	#8,d1
	rts

;==============================================================================
; Serial I/O routines
;==============================================================================

;------------------------------------------------------------------------------
; Setup the console device
; stdout = text screen controller
;------------------------------------------------------------------------------

serial_init:
setup_serial:
	moveq #31,d0
	lea.l serial_dcb,a0
.0001:
	clr.l (a0)+
	dbra d0,.0001
	move.l #$20424344,serial_dcb+DCB_MAGIC				; 'DCB'
	move.l #$204F4F43,serial_dcb+DCB_NAME				; 'COM'
	move.l #serial_cmdproc,serial_dcb+DCB_CMDPROC
	move.l #SerRcvBuf,serial_dcb+DCB_INBUFPTR
	move.l #SerXmitBuf,serial_dcb+DCB_OUTBUFPTR
	move.l #4096,serial_dcb+DCB_INBUFSIZE
	bsr SerialInit
	rts

	align 2
COM_CMDTBL:
	dc.l serial_init
	dc.l serial_stat
	dc.l serial_putchar
	dc.l serial_putbuf
	dc.l serial_getchar
	dc.l serial_getbuf
	dc.l serial_set_inpos
	dc.l serial_set_outpos
	dc.l serial_getchar_direct
	dc.l serial_peek_char
	dc.l serial_peek_char_direct
	dc.l serial_putchar_direct

serial_cmdproc:
	cmpi.b #12,d6
	bhs.s .0001
	tst.b d6
	bmi.s .0001
	movem.l d6/a0,-(a7)
	asl.b #2,d6
	ext.w d6
	lea COM_CMDTBL,a0
	move.l (a0,d6.w),a0
	jsr (a0)
	movem.l (a7)+,d6/a0
	rts
.0001:
	moveq #E_Func,d0
	rts

serial_stat:
	moveq #E_Ok,d0
	rts

serial_putchar:
	bsr SerialPutChar
	moveq #E_Ok,d0
	rts

serial_getchar:
	bsr SerialGetChar
	moveq #E_Ok,d0
	rts

serial_getchar_direct:
	bsr SerialPeekCharDirect
	moveq #E_Ok,d0
	rts

serial_peek_char:
	bsr SerialPeekChar
	moveq #E_Ok,d0
	rts

serial_peek_char_direct:
	bsr SerialPeekCharDirect
	moveq #E_Ok,d0
	rts

serial_putchar_direct:
	bsr SerialPutCharDirect
	moveq #E_Ok,d0
	rts

serial_putbuf:
serial_getbuf:
serial_set_inpos:
serial_set_outpos:
	moveq #E_NotSupported,d0
	rts

;------------------------------------------------------------------------------
; Initialize the serial port an enhanced 6551 circuit.
;
; Select internal baud rate clock divider for 9600 baud
; Reset fifos, set threshold to 3/4 full on transmit and 3/4 empty on receive
; Note that the byte order is swapped.
;------------------------------------------------------------------------------

SerialInit:
	clr.w		SerHeadRcv					; clear receive buffer indexes
	clr.w		SerTailRcv
	clr.w		SerHeadXmit					; clear transmit buffer indexes
	clr.w		SerTailXmit
	clr.b		SerRcvXon						; and Xon,Xoff flags
	clr.b		SerRcvXoff
	move.l	#$09000000,d0				; dtr,rts active, rxint enabled, no parity
	move.l	d0,ACIA+ACIA_CMD
;	move.l	#$1E00F700,d0				; fifos enabled
	move.l	#$1E000000,d0				; fifos disabled
	move.l	d0,ACIA+ACIA_CTRL
	rts
;	move.l	#$0F000000,d0				; transmit a break for a while
;	move.l	d0,ACIA+ACIA_CMD
;	move.l	#300000,d2					; wait 100 ms
;	bra			.0001
;.0003:
;	swap		d2
;.0001:
;	nop
;	dbra		d2,.0001
;.0002:
;	swap		d2
;	dbra		d2,.0003
;	move.l	#$07000000,d0				; clear break
;	move.l	d0,ACIA+ACIA_CMD
;	rts
	
;------------------------------------------------------------------------------
; SerialGetChar
;
; Check the serial port buffer to see if there's a char available. If there's
; a char available then return it. If the buffer is almost empty then send an
; XON.
;
; Stack Space:
;		2 long words
; Parameters:
;		none
; Modifies:
;		d0,a0
; Returns:
;		d1 = character or -1
;------------------------------------------------------------------------------

SerialGetChar:
	move.l		d2,-(a7)
	movec			coreno,d0
	swap			d0
	moveq			#SERIAL_SEMA,d1
	bsr				LockSemaphore
	bsr				SerialRcvCount			; check number of chars in receive buffer
	cmpi.w		#8,d0								; less than 8?
	bhi				.sgc2
	tst.b			SerRcvXon						; skip sending XON if already sent
	bne	  		.sgc2            		; XON already sent?
	move.b		#XON,d1							; if <8 send an XON
	clr.b			SerRcvXoff					; clear XOFF status
	move.b		d1,SerRcvXon				; flag so we don't send it multiple times
	bsr				SerialPutChar				; send it
.sgc2:
	move.w		SerHeadRcv,d1				; check if anything is in buffer
	cmp.w			SerTailRcv,d1
	beq				.NoChars						; no?
	lea				SerRcvBuf,a0
	move.b		(a0,d1.w),d1				; get byte from buffer
	addi.w		#1,SerHeadRcv
	andi.w		#$FFF,SerHeadRcv		; 4k wrap around
	andi.l		#$FF,d1
	bra				.Xit
.NoChars:
	moveq			#-1,d1
.Xit:
	exg				d1,d2
	movec			coreno,d0
	swap			d0
	moveq			#SERIAL_SEMA,d1
	bsr				UnlockSemaphore
	exg				d2,d1
	move.l		(a7)+,d2
	rts

;------------------------------------------------------------------------------
; SerialPeekChar
;
; Check the serial port buffer to see if there's a char available. If there's
; a char available then return it. But don't update the buffer indexes. No need
; to send an XON here.
;
; Stack Space:
;		1 long word
; Parameters:
;		none
; Modifies:
;		d0,a0
; Returns:
;		d1 = character or -1
;------------------------------------------------------------------------------

SerialPeekChar:
	move.l d2,-(a7)
	movec	coreno,d0
	swap d0
	moveq	#SERIAL_SEMA,d1
	bsr	LockSemaphore
	move.w SerHeadRcv,d2		; check if anything is in buffer
	cmp.w	SerTailRcv,d2
	beq	.NoChars				; no?
	lea	SerRcvBuf,a0
	move.b (a0,d2.w),d2		; get byte from buffer
	bra	.Xit
.NoChars:
	moveq	#-1,d2
.Xit:
	movec	coreno,d0
	swap d0
	moveq	#SERIAL_SEMA,d1
	bsr	UnlockSemaphore
	move.l	d2,d1
	move.l (a7)+,d2
	rts

;------------------------------------------------------------------------------
; SerialPeekChar
;		Get a character directly from the I/O port. This bypasses the input
; buffer.
;
; Stack Space:
;		0 words
; Parameters:
;		none
; Modifies:
;		d
; Returns:
;		d1 = character or -1
;------------------------------------------------------------------------------

SerialPeekCharDirect:
	move.b	ACIA+ACIA_STAT,d1	; get serial status
	btst		#3,d1							; look for Rx not empty
	beq.s		.0001
	moveq.l	#0,d1							; clear upper bits of return value
	move.b	ACIA+ACIA_RX,d1		; get data from ACIA
	rts												; return
.0001:
	moveq		#-1,d1
	rts

;------------------------------------------------------------------------------
; SerialPutChar
;		If there is a transmit buffer, adds the character to the transmit buffer
; if it can, otherwise will wait for a byte to be freed up in the transmit
; buffer (blocks).
;		If there is no transmit buffer, put a character to the directly to the
; serial transmitter. This routine blocks until the transmitter is empty. 
;
; Stack Space
;		4 long words
; Parameters:
;		d1.b = character to put
; Modifies:
;		none
;------------------------------------------------------------------------------

SerialPutChar:
.0004:
	tst.w serial_dcb+DCB_OUTBUFSIZE	; buffered output?
	beq.s SerialPutCharDirect
	movem.l d0/d1/d2/a0,-(a7)
	movec	coreno,d0
	swap d0
	moveq	#SERIAL_SEMA,d1
	bsr	LockSemaphore
	move.w SerTailXmit,d0
	move.w d0,d2
	addi.w #1,d0
	cmp.w serial_dcb+DCB_OUTBUFSIZE,d0
	blo.s .0002
	clr.w d0
.0002:
	cmp.w SerHeadXmit,d0			; Is Xmit buffer full?
	bne.s .0003
	movec	coreno,d0						; buffer full, unlock semaphore and wait
	swap d0
	moveq	#SERIAL_SEMA,d1
	bsr	UnlockSemaphore
	bra.s .0004
.0003:
	move.w d0,SerTailXmit			; update tail pointer
	lea SerXmitBuf,a0
	move.b d1,(a0,d2.w)				; store byte in Xmit buffer
	movec	coreno,d0						; unlock semaphore
	swap d0
	moveq	#SERIAL_SEMA,d1
	bsr	UnlockSemaphore
	movem.l (a7)+,d0/d1/d2/a0
	rts

SerialPutCharDirect:
	movem.l	d0/d1,-(a7)							; push d0,d1
.0001:
	move.b ACIA+ACIA_STAT,d0	; wait until the uart indicates tx empty
	btst #4,d0								; bit #4 of the status reg
	beq.s	.0001			    			; branch if transmitter is not empty
	move.b d1,ACIA+ACIA_TX		; send the byte
	movem.l	(a7)+,d0/d1				; pop d0,d1
	rts
	
;------------------------------------------------------------------------------
; Reverse the order of bytes in d1.
;------------------------------------------------------------------------------

SerialRbo:
	rol.w		#8,d1
	swap		d1
	rol.w		#8,d1
	rts

;------------------------------------------------------------------------------
; Calculate number of character in input buffer
;
; Returns:
;		d0 = number of bytes in buffer.
;------------------------------------------------------------------------------

SerialRcvCount:
	move.w	SerTailRcv,d0
	sub.w		SerHeadRcv,d0
	bge			.0001
	move.w	#$1000,d0
	sub.w		SerHeadRcv,d0
	add.w		SerTailRcv,d0
.0001:
	rts

;------------------------------------------------------------------------------
; Serial IRQ routine
;
; Keeps looping as long as it finds characters in the ACIA recieve buffer/fifo.
; Received characters are buffered. If the buffer becomes full, new characters
; will be lost.
;
; Parameters:
;		none
; Modifies:
;		none
; Returns:
;		d1 = -1 if IRQ handled, otherwise zero
;------------------------------------------------------------------------------

SerialIRQ:
	move.w	#$2300,sr						; disable lower level IRQs
	movem.l	d0/d1/d2/a0,-(a7)
	movec	coreno,d0
	swap d0
	moveq	#SERIAL_SEMA,d1
	bsr	LockSemaphore
sirqNxtByte:
	move.b ACIA+ACIA_STAT,d1		; check the status
	btst #3,d1									; bit 3 = rx full
	beq	notRxInt
	move.b ACIA+ACIA_RX,d1
sirq0001:
	move.w SerTailRcv,d0				; check if recieve buffer full
	addi.w #1,d0
	andi.w #$FFF,d0
	cmp.w	SerHeadRcv,d0
	beq	sirqRxFull
	move.w d0,SerTailRcv				; update tail pointer
	subi.w #1,d0								; backup
	andi.w #$FFF,d0
	lea	SerRcvBuf,a0						; a0 = buffer address
	move.b d1,(a0,d0.w)					; store recieved byte in buffer
	tst.b	SerRcvXoff						; check if xoff already sent
	bne	sirqNxtByte
	bsr	SerialRcvCount					; if more than 4080 chars in buffer
	cmpi.w #4080,d0
	blo	sirqNxtByte
	move.b #XOFF,d1							; send an XOFF
	clr.b	SerRcvXon							; clear XON status
	move.b d1,SerRcvXoff				; set XOFF status
	bsr	SerialPutChar						; send XOFF
	bra	sirqNxtByte     				; check the status for another byte
sirqRxFull:
notRxInt:
	btst #4,d1									; TX empty?
	beq.s notTxInt
	tst.b SerXmitXoff						; and allowed to send?
	bne.s sirqXmitOff
	tst.l serial_dcb+DCB_OUTBUFSIZE	; Is there a buffer being transmitted?
	beq.s notTxInt
	move.w SerHeadXmit,d0
	cmp.w SerTailXmit,d0
	beq.s sirqTxEmpty
	lea SerXmitBuf,a0
	move.b (a0,d0.w),d1
	move.b d1,ACIA+ACIA_TX			; transmit character
	addi.w #1,SerHeadXmit				; advance head index
	move.w serial_dcb+DCB_OUTBUFSIZE,d0
	cmp.w SerHeadXmit,d0
	bhi.s sirq0002
	clr.w SerHeadXmit						; wrap around
sirq0002:
sirqXmitOff:
sirqTxEmpty:
notTxInt:
	movec	coreno,d0
	swap d0
	moveq	#SERIAL_SEMA,d1
	bsr	UnlockSemaphore
	movem.l	(a7)+,d0/d1/d2/a0
	rte

nmeSerial:
	dc.b		"Serial",0

;===============================================================================
; Generic I2C routines
;===============================================================================

	even
; i2c
i2c_setup:
;		lea		I2C,a6				
;		move.w	#19,I2C_PREL(a6)	; setup prescale for 400kHz clock
;		move.w	#0,I2C_PREH(a6)
init_i2c:
	lea	I2C2,a6				
	move.b #19,I2C_PREL(a6)	; setup prescale for 400kHz clock, 40MHz master
	move.b #0,I2C_PREH(a6)
	rts

; Wait for I2C transfer to complete
;
; Parameters
; 	a6 - I2C controller base address

i2c_wait_tip:
	move.l d0,-(a7)
.0001				
	move.b I2C_STAT(a6),d0		; wait for tip to clear
	btst #1,d0
	bne.s	.0001
	move.l (a7)+,d0
	rts

; Parameters
;	d0.b - data to transmit
;	d1.b - command value
;	a6	 - I2C controller base address
;
i2c_wr_cmd:
	move.b d0,I2C_TXR(a6)
	move.b d1,I2C_CMD(a6)
	bsr	i2c_wait_tip
	move.b I2C_STAT(a6),d0
	rts

i2c_xmit1:
	move.l d0,-(a7)
	move.b #1,I2C_CTRL(a6)		; enable the core
	moveq	#$76,d0				; set slave address = %0111011
	move.w #$90,d1				; set STA, WR
	bsr i2c_wr_cmd
	bsr	i2c_wait_rx_nack
	move.l (a7)+,d0
	move.w #$50,d1				; set STO, WR
	bsr i2c_wr_cmd
	bsr	i2c_wait_rx_nack

i2c_wait_rx_nack:
	move.l d0,-(a7)
.0001						
	move.b I2C_STAT(a6),d0		; wait for RXack = 0
	btst #7,d0
	bne.s	.0001
	move.l (a7)+,d0
	rts

;===============================================================================
; Realtime clock routines
;===============================================================================

rtc_read:
	movea.l	#I2C2,a6
	lea	RTCBuf,a5
	move.b	#$80,I2C_CTRL(a6)	; enable I2C
	move.b	#$DE,d0				; read address, write op
	move.b	#$90,d1				; STA + wr bit
	bsr	i2c_wr_cmd
	tst.b	d0
	bmi	.rxerr
	move.b #$00,d0				; address zero
	move.b #$10,d1				; wr bit
	bsr	i2c_wr_cmd
	tst.b	d0
	bmi	.rxerr
	move.b #$DF,d0				; read address, read op
	move.b #$90,d1				; STA + wr bit
	bsr i2c_wr_cmd
	tst.b	d0
	bmi	.rxerr
		
	move.w #$20,d2
.0001
	move.b #$20,I2C_CMD(a6)	; rd bit
	bsr	i2c_wait_tip
	bsr	i2c_wait_rx_nack
	move.b I2C_STAT(a6),d0
	tst.b	d0
	bmi	.rxerr
	move.b I2C_RXR(a6),d0
	move.b d0,(a5,d2.w)
	addi.w #1,d2
	cmpi.w #$5F,d2
	bne	.0001
	move.b #$68,I2C_CMD(a6)	; STO, rd bit + nack
	bsr i2c_wait_tip
	bsr i2c_wait_rx_nack
	move.b I2C_STAT(a6),d0
	tst.b	d0
	bmi	.rxerr
	move.b I2C_RXR(a6),d0
	move.b d0,(a5,d2.w)
	move.b #0,I2C_CTRL(a6)		; disable I2C and return 0
	moveq	#0,d0
	rts
.rxerr
	move.b #0,I2C_CTRL(a6)		; disable I2C and return status
	rts

rtc_write:
	movea.l	#I2C2,a6
	lea	RTCBuf,a5
	move.b #$80,I2C_CTRL(a6)	; enable I2C
	move.b #$DE,d0				; read address, write op
	move.b #$90,d1				; STA + wr bit
	bsr	i2c_wr_cmd
	tst.b	d0
	bmi	.rxerr
	move.b #$00,d0				; address zero
	move.b #$10,d1				; wr bit
	bsr	i2c_wr_cmd
	tst.b	d0
	bmi	.rxerr
	move.w #$20,d2
.0001
	move.b (a5,d2.w),d0
	move.b #$10,d1
	bsr	i2c_wr_cmd
	tst.b	d0
	bmi	.rxerr
	addi.w #1,d2
	cmpi.w #$5F,d2
	bne.s	.0001
	move.b (a5,d2.w),d0
	move.b #$50,d1				; STO, wr bit
	bsr	i2c_wr_cmd
	tst.b	d0
	bmi	.rxerr
	move.b #0,I2C_CTRL(a6)		; disable I2C and return 0
	moveq	#0,d0
	rts
.rxerr:
	move.b #0,I2C_CTRL(a6)		; disable I2C and return status
	rts

msgRtcReadFail:
	dc.b	"RTC read/write failed.",$0A,$0D,$00

msgBusErr:
	dc.b	$0A,$0D,"Bus error at: ",$00
	even

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
	even

bus_err:
	nop
	lea.l msgBusErr,a1
	bsr DisplayString
	move.l 2(a7),d1
	bsr DisplayTetra
	bsr CRLF
	bra	Monitor

trap3:
	; First save all registers
	movem.l		d0/d1/d2/d3/d4/d5/d6/d7/a0/a1/a2/a3/a4/a5/a6/a7,Regsave
	move.w		(a7)+,Regsave+$40
	move.l		(a7)+,Regsave+$44
	move.l		#$40FFC,a7			; reset stack pointer
	move.w		#$2500,sr				; enable interrupts
	move.w		NumSetBreakpoints,d0
	subi.w		#1,d0
	lea				Breakpoints,a0
	move.l		Regsave+$44,d1
.0001:
	cmp.l			(a0)+,d1
	beq.s			ProcessBreakpoint
	dbra			d0,.0001
	bra				Monitor					; not a breakpoint
ProcessBreakpoint:
	bsr				DisarmAllBreakpoints
	bra				cmdDumpRegs

;------------------------------------------------------------------------------
; DisarmAllBreakpoints, used when entering the monitor.
;------------------------------------------------------------------------------

DisarmAllBreakpoints:
	movem.l	d0/a0/a1/a2,-(a7)			; stack some regs
	move.w	NumSetBreakpoints,d0	; d0 = number of breakpoints that are set
	cmpi.w	#numBreakpoints,d0		; check for valid number
	bhs.s		.0001
	lea			Breakpoints,a2				; a2 = pointer to breakpoint address table
	lea			BreakpointWords,a0		; a0 = pointer to breakpoint instruction word table
	bra.s		.0003									; enter loop at bottom
.0002:
	move.l	(a2)+,a1							; a1 = address of breakpoint
	move.w	(a0)+,(a1)						; copy instruction word back to code
.0003:
	dbra		d0,.0002
	movem.l	(a7)+,d0/a0/a1/a2			; restore regs
.0001:
	rts	

;------------------------------------------------------------------------------
; ArmAllBreakpoints, used when entering the monitor.
;------------------------------------------------------------------------------

ArmAllBreakpoints:
	movem.l		d0/a0/a1/a2,-(a7)			; stack some regs
	move.w		NumSetBreakpoints,d0	; d0 = number of breakpoints
	cmpi.w		#numBreakpoints,d0		; is the number valid?
	bhs.s			.0001
	lea				Breakpoints,a2				; a2 = pointer to breakpoint address table
	lea				BreakpointWords,a0		; a0 = pointer to instruction word table
	bra.s			.0003									; enter loop at bottom
.0002:
	move.l		(a2)+,a1							; a1 = address of breakpoint
	move.w		(a1),(a0)							; copy instruction word to table
	move.w		#$4E43,(a0)+					; set instruction = TRAP3
.0003:
	dbra			d0,.0002
	movem.l		(a7)+,d0/a0/a1/a2			; restore regs
.0001:
	rts	

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

ArmBreakpoint:
	movem.l		d0/d1/d2/a0/a1/a2,-(a7)
	move.w		NumSetBreakpoints,d0	; d0 = number of breakpoints
	cmpi.w		#numBreakpoints,d0		; check if too many
	bhs.s			.0001
	addi.w		#1,NumSetBreakpoints	; increment number of breakpoints
	move.l		d0,d2
	bsr				ignBlanks
	bsr				GetHexNumber
	beq.s			.0001									; was there an address?
	btst			#0,d1									; address value must be even
	bne.s			.0001
	; See if the breakpoint is in the table already
	lea				Breakpoints,a1				; a1 points to breakpoint table
	move.w		#numBreakpoints-1,d2
.0002:
	cmp.l			(a1)+,d1
	beq.s			.0003									; breakpoint is in table already
	dbra			d2,.0002
	; Add breakpoint to table
	; Search for empty entry
	lea				Breakpoints,a1				; a1 = pointer to breakpoint address table
	clr.w			d2										; d2 = count
.0006:
	tst.l			(a1)									; is the entry empty?
	beq.s			.0005									; branch if found empty entry
	lea				4(a1),a1							; point to next entry
	addi.w		#1,d2									; increment count
	cmpi.w		#numBreakpoints,d2		; safety: check against max number
	blo.s			.0006
	bra.s			.0001									; what? no empty entries found, table corrupt?
.0005:
	asl.w			#2,d2									; d2 = long word index
	move.l		d1,(a1,d2.w)					; move breakpoint address to table
	move.l		d1,a2
	lsr.w			#1,d2									; d2 = word index
.0004:
	lea				BreakpointWords,a1
	move.w		(a2),(a1,d2.w)				; copy instruction word to table
	move.w		#$4E43,(a2)						; replace word with TRAP3
.0001:
	movem.l		(a7)+,d0/d1/d2/a0/a1/a2
	rts
.0003:
	move.l		-4(a1),a2							; a2 = pointer to breakpoint address from table
	cmpi.w		#$4E43,(a2)						; see if breakpoint already armed
	beq.s			.0001
	asl.l			#1,d2									; d2 = word index
	bra.s			.0004


;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

DisarmBreakpoint:
	movem.l		d0/d1/d2/a0/a1/a2,-(a7)
	move.w		NumSetBreakpoints,d0	; d0 = number of breakpoints
	cmpi.w		#numBreakpoints,d0		; check if too many
	bhi.s			.0001
	move.l		d0,d2
	bsr				ignBlanks
	bsr				GetHexNumber
	beq.s			.0001									; was there an address?
	btst			#0,d1									; address value must be even
	bne.s			.0001
	; See if the breakpoint is in the table already
	lea				Breakpoints,a1				; a1 points to breakpoint table
	subi.w		#1,d2
.0002:
	cmp.l			(a1)+,d1
	beq.s			.0003									; breakpoint is in table already
	dbra			d2,.0002
	bra				.0001									; breakpoint was not in table
.0003:
	; Remove breakpoint from table
	subi.w		#1,NumSetBreakpoints	; decrement number of breakpoints
	move.l		-4(a1),a2							; a2 = pointer to breakpoint address from table
	clr.l			-4(a1)								; empty out breakpoint
	lea				BreakpointWords,a1
	asl.l			#1,d2									; d2 = word index
	move.w		(a1,d2.w),(a2)				; copy instruction from table back to code
.0001:
	movem.l		(a7)+,d0/d1/d2/a0/a1/a2
	rts

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

ListBreakpoints:
	bsr			CRLF
	move.w	#numBreakpoints,d2
	lea			Breakpoints,a1
.0001:
	move.l	(a1)+,d1
	bsr			DisplayTetra
	bsr			CRLF
	dbra		d2,.0001
	bra			Monitor

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

ClearBreakpointList:
	move.w	#numBreakpoints,d2
	lea			Breakpoints,a1
.0001:
	clr.l		(a1)+
	dbra		d2,.0001
	rts

;------------------------------------------------------------------------------
; SendMsg
; 00100xy0
;
; Parameters:
;		d1 = target core number
;		d2 = argument 1
;		d3 = argument 2
;		d4 = argument 3
;
;------------------------------------------------------------------------------

SendMsg:
	movem.l	d5/a1,-(a7)
	lsl.w		#8,d1
	movec		coreno,d5
	lsl.w		#4,d5
	or.w		d5,d1
	lea			$00100000,a1
	tst.l		0(a1,d1.w)
	bne			.msgFull
	movec		coreno,d5
	move.l	d5,0(a1,d1.w)
	move.l	d2,4(a1,d1.w)
	move.l	d3,8(a1,d1.w)
	move.l	d4,12(a1,d1.w)
	movem.l	(a7)+,d5/a1
	moveq		#0,d1
	rts
.msgFull:
	movem.l	(a7)+,d5/a1
	moveq		#-1,d1
	rts

;------------------------------------------------------------------------------
; ReceiveMsg
;		Scan the message table for messages and dispatch them.
; 00100xy0
;
; Parameters:
;------------------------------------------------------------------------------

ReceiveMsg:
	movem.l		d1/d2/d3/d4/d5/d6/d7/a1,-(a7)
	lea				$00100000,a1
	movec			coreno,d5
	lsl.w			#8,d5
	moveq			#2,d6
.nextCore:
	move.w		d6,d7
	lsl.w			#4,d7
	add.w			d5,d7
	tst.l			0(a1,d7.w)			; Is there a message from core d6?
	beq.s			.noMsg
	move.l		0(a1,d7.w),d1
	move.l		4(a1,d7.w),d2
	move.l		8(a1,d7.w),d3
	move.l		12(a1,d7.w),d4
	clr.l			0(a1,d7.w)			; indicate message was received
	bsr				DispatchMsg
.noMsg:
	addq			#1,d6
	cmp.w			#9,d6
	bls				.nextCore
	movem.l		(a7)+,d1/d2/d3/d4/d5/d6/d7/a1
	rts

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

DispatchMsg:
	rts

;------------------------------------------------------------------------------
; Trap #15, function 39 - convert floating-point to string and display
;
; Parameters
;		a1 = pointer to buffer
;		fp0 = number to print
;		d1 = width of print field
;		d2 = precision
;		d3 = 'E' or 'e'
;------------------------------------------------------------------------------

prtflt:
	link a2,#-48
	move.l _canary,44(sp)
	movem.l d0/d1/d2/d3/d6/a0/a1/a2,(sp)
	fmove.x fp0,32(sp)
	move.l a1,a0						; a0 = pointer to buffer to use
	move.b d1,_width
	move.l d2,_precision
	move.b d3,_E
	bsr _FloatToString
	bsr DisplayString
	fmove.x 32(sp),fp0
	movem.l (sp),d0/d1/d2/d3/d6/a0/a1/a2
	cchk 44(sp)
	unlk a2
	rts

T15FloatToString:
	link a2,#-44
	movem.l d0/d1/d2/d3/d6/a0/a1,(sp)
	fmove.x fp0,28(sp)
	move.l a1,a0						; a0 = pointer to buffer to use
	move.b d1,_width
	move.l d2,_precision
	move.b d3,_E
	bsr _FloatToString
	fmove.x 28(sp),fp0
	movem.l (sp),d0/d1/d2/d3/d6/a0/a1
	unlk a2
	rts

;==============================================================================
; Parameters:
;		d7 = device number
;		d6 = function number
;		d0 to d5 = arguments
;==============================================================================

io_trap:
	cmpi.b #2,d7							; make sure legal device
	bhi.s .0002
	tst.b d7
	bmi.s .0002
	movem.l d7/a0,-(a7)
	mulu #DCB_SIZE,d7					; index to DCB
	move.l #null_dcb,a0
	move.l DCB_CMDPROC(a0,d7.w),a0
	jsr (a0)
	movem.l (a7)+,d7/a0
	rte
.0002:
	moveq #E_BadDevNum,d0
	rte

;==============================================================================
; Output a character to the current output device.
;==============================================================================

OutputChar:
	movem.l d6/d7,-(a7)
	clr.l d7
	move.b OutputDevice,d7		; d7 = output device
	move.w #DEV_PUTCHAR,d6		; d6 = function
	trap #0
	movem.l (a7)+,d6/d7
	rts

	cmpi.b #1,OutputDevice	; stdout
	bne .0001
	bra DisplayChar
.0001:
	cmpi.b #2,OutputDevice
	bne .0003
	bra	SerialPutChar
.0003:
	rts

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

InitIRQ:
	moveq		#6,d0
	lea			KeybdIRQ,a0
	bsr			InstallIRQ
	lea			TickIRQ,a0
	bsr			InstallIRQ
	moveq		#3,d0
	lea			SerialIRQ,a0
	; fall through

;------------------------------------------------------------------------------
; Install an IRQ handler.
;
; Parameters:
;		a0 = pointer to bucket containing vector
;		d0 = vector (64 to 255)
; Returns:
;		d0 = 0 if successfully added, otherwise E_NotAlloc
;		nf = 0, zf = 1 if successfully added, otherwise nf = 1, zf = 0
;------------------------------------------------------------------------------

InstallIRQ:
	movem.l a1/a2,-(a7)				; save working register
	tst.l (a0)								; link field must be NULL
	bne.s .0003
	cmpi.w #64,d0							; is vector in range (64 to 255)?
	blo.s .0003
	cmpi.w #255,d0
	bhi.s .0003
	lea	irq_list_tbl,a2				; a2 points to installed IRQ list
	lsl.w	#3,d0								; multiply by 2 long words
	move.l (a2,d0.w),a1				; get first link
	lea (a2,d0.w),a2					; 
.0002:
	cmpa.l a1,a0							; installed already?
	beq.s .0003
	cmpa.l #0,a1							; is link NULL?
	beq.s .0001
	move.l a1,a2							; save previous link
	move.l (a1),a1						; get next link
	bra .0002
.0001:
	move.l a0,(a2)						; set link
	movem.l (a7)+,a1/a2
	moveq #E_Ok,d0
	rts
.0003:
	movem.l (a7)+,a1/a2
	moveq #E_NotAlloc,d0			; return failed to add
	rts

;------------------------------------------------------------------------------
; TickIRQ
; - this IRQ is processed by all cores.
; - reset the edge circuit.
; - an IRQ live indicator is updated on the text screen for the core
;------------------------------------------------------------------------------

TickIRQ:
	move.w #$2600,sr					; disable lower level IRQs
	movem.l	d1/d2/d3/a0,-(a7)
	addi.l #1,tickcnt
	move.b #1,IRQFlag					; tick interrupt indicator in local memory
	movec	coreno,d1						; d1 = core number
	move.l d1,d3
	if (SCREEN_FORMAT==1)
		asl.l #2,d3								; 4 bytes per text cell
	else
		asl.l #3,d3								; 8 bytes per text cell
	endif
	move.l #$1D000000,PLIC+$14	; reset edge sense circuit
	lea $FD0000C8,a0					; display field address
	move.l 4(a0,d3.w),d2			; get char from screen
;	rol.l #8,d2								; extract char field
;	clr.b d2									; clear char field
;	addi.b #'0',d1						; binary to ascii core number
;	or.b	d1,d2								; insert core number
;	ror.l #8,d2								; reposition to proper place
;	addi.w #1,d2							; flashy colors
	addi.l #$0001,d2
	move.l d2,4(a0,d3.w)			; update onscreen IRQ flag
	bsr	ReceiveMsg
	movem.l	(a7)+,d1/d2/d3/a0
	rte

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

irq3_rout:
;	movem.l	d0/d1/a0/a1,-(a7)
;	lea			InstalledIRQ+8*4*3,a0
;	bra			irq_rout

irq6_rout:
;	movem.l	d0/d1/a0/a1,-(a7)
;	lea			InstalledIRQ+8*4*6,a0
irq_rout:
	moveq		#7,d0
.nextHandler:
	move.l	(a0)+,a1
	beq.s		.0003
	jsr			(a1)
	tst.l		d1								; was IRQ handled?
	bmi.s		.0002							; first one to return handled quits loop
.0003:
	dbra		d0,.nextHandler
.0002:
	movem.l	(a7)+,d0/d1/a0/a1	; return

; Load head of list into an address register, then branch to a generic routine.

;	rept 192
;	macIRQ_proc_label REPTN
;	movem.l a0/a1,-(a7)
;	move.l irq_list_tbl+REPTN*4,a1	; get the head of the list
;	jmp irq_proc_generic
;	endr

irq_proc_generic:
.0003:
	move.l 4(a1),a0									; a0 = vector
	cmpa.l #0,a0										; ugh. move to address does not set flags
	beq.s .0001											; valid vector?
	jsr (a0)												; call the interrupt routine
	tst.l d1												; IRQ handled?
	bmi.s .0002											
.0001:
	move.l (a1),a1
	cmpa.l #0,a0										; end of list?
	bne.s .0003
.0002:
	movem.l (a7)+,a0/a1
	rte 

SpuriousIRQ:
	rte

;	bsr			KeybdIRQ
;	tst.l		d1								; handled by KeybdIRQ?
;	bmi.s		.0002							; if yes, go return
;.0001:
;	move.l	#$1D000000,PLIC+$14	; reset edge sense circuit
;	move.l	TextScr,a0				; a0 = screen address
;	addi.l	#1,40(a0)					; update onscreen IRQ flag
;.0002:	
;	movem.l	(a7)+,d0/d1/a0/a1	; return
;	rte

nmi_rout:
	movem.l	d0/d1/a0,-(a7)
	move.b	#'N',d1
	bsr			OutputChar
	movem.l	(a7)+,d0/d1/a0		; return
	rte

addr_err:
	addq		#2,sp						; get rid of sr
	move.l	(sp)+,d1				; pop exception address
	bsr			DisplayTetra		; and display it
	lea			msgAddrErr,a1	; followed by message
	bsr			DisplayStringCRLF
.0001:
	bra			.0001
	bra			Monitor
	
brdisp_trap:
	movem.l	d0/d1/d2/d3/d4/d5/d6/d7/a0/a1/a2/a3/a4/a5/a6/a7,Regsave
	move.w	(a7)+,Regsave+$40
	move.l	(a7)+,Regsave+$44
	move.l	#$40FFC,a7			; reset stack pointer
	move.w	#$2500,sr				; enable interrupts
	lea			msg_bad_branch_disp,a1
	bsr			DisplayString
	bsr			DisplaySpace
	move.l	Regsave+$44,d1	; exception address
	bsr			DisplayTetra		; and display it
;	move.l	(sp)+,d1				; pop format word 68010 mode only
	bra			cmdDumpRegs

illegal_trap:
	addq		#2,sp						; get rid of sr
	move.l	(sp)+,d1				; pop exception address
	bsr			DisplayTetra		; and display it
	lea			msg_illegal,a1	; followed by message
	bsr			DisplayString
.0001:
	bra			.0001
	bra			Monitor
	
io_irq:
	addq #2,sp
	move.l (sp)+,d1
	bsr DisplayTetra
	lea msg_io_access,a1
	bsr DisplayString
	bra cmdDumpRegs

; -----------------------------------------------------------------------------
; -----------------------------------------------------------------------------

msg_start:
	dc.b	"Femtiki rf68k Multi-core OS Starting",LF,CR,0
;	dc.b	"rf68k System Starting",CR,LF,0
msg_core_start:
	dc.b	" core starting",CR,LF,0
msgAddrErr
	dc.b	" address err",0
msg_illegal:
	dc.b	" illegal opcode",CR,LF,0
msg_bad_branch_disp:
	dc.b	" branch selfref: ",0
msg_test_done:
	dc.b	" CPU test done.",0
msg_io_access
	dc.b " unpermitted access to I/O",0
msgChk
	dc.b " check failed",0
msgStackCanary
	dc.b " stack canary overwritten",0

	even

;-------------------------------------------------------------------------
; File HEX2DEC   HEX2DEC convert hex to decimal                   11/02/81
;
;    CONVERT BINARY TO DECIMAL  REG  D0 PUT IN ( A6) BUFFER AS ASCII

; Shift buffer one character to left
ShiftBuf:
	movem.l d0/a2/a4,-(a7)
	move.l a3,d0
	addi.l #BUFSIZE,d0
.0001:
	move.b 1(a4),(a4)+
	cmp.l a4,d0
	blo.s .0001
	movem.l (a7)+,d0/a2/a4
	rts

HEX2DEC2:
	movem.l d0/d1/a3/a4/a5,-(a7)
	move.l a6,a3
	move.l a6,a4
	move.l d0,d1
	bpl.s .0001
	neg.l d0										;
	bmi.s .0002									; neg and still minus, must be -tve zero
	move.b #'-',(a6)+
	move.l a6,a4
.0001:
	divu #100,d1								; scale d1 - chop last 2 decimal digits
	bin2bcd d1									; convert to BCD
	bsr BufTetra								; capture in buffer (8 digits)
	move.l d0,d1
	bin2bcd d1									; convert to BCD
	bsr BufByte									; capture last 2 digits in buffer
.0004:
	cmpi.b #'0',(a4)						; Is there a leading zero?
	bne.s .0003									; No, we're done shifting
	bsr ShiftBuf								; Shift the buffer over a character
	subq.l #1,a6								; adjust buffer pos.
	bra.s .0004									; go check next character
.0003:
	tst.b (a4)
	beq.s .0002
	cmpi.b #' ',(a4)						; is the buffer empty?
	bne.s .0005
.0002:
	move.b #'0',(a4)+						; ensure at least a '0'
	move.l a4,a6
.0005:
	movem.l (a7)+,d0/d1/a3/a4/a5
	rts

HEX2DEC: 
	movem.l D1-D4/D6-D7,-(A7)   ; SAVE REGISTERS
	move.l D0,D7          			; SAVE IT HERE
	bpl.s HX2DC
	neg.l D7              			; CHANGE TO POSITIVE
	bmi.s HX2DC57          			; SPECIAL CASE (-0)
	move.b #'-',(A6)+      			; PUT IN NEG SIGN
HX2DC:  
	clr.w D4              			; FOR ZERO SURPRESS
	moveq #10,D6          			; COUNTER
HX2DC0:
  moveq #1,D2           			; VALUE TO SUB
	move.l D6,D1          			; COUNTER
	subq.l #1,D1           			; ADJUST - FORM POWER OF TEN
	beq.s HX2DC2           			; IF POWER IS ZERO
HX2DC1:
  move.w D2,D3          			; D3=LOWER WORD
	mulu #10,D3
	swap D2              				; D2=UPPER WORD
	mulu #10,D2
	swap D3              				; ADD UPPER TO UPPER
	add.w D3,D2
	swap D2              				; PUT UPPER IN UPPER
	swap D3              				; PUT LOWER IN LOWER
	move.w D3,D2          			; D2=UPPER & LOWER
	subq.l #1,D1
	bne.s HX2DC1
HX2DC2:
  clr.l D0              			; HOLDS SUB AMT
HX2DC22:
	cmp.l D2,D7
  blt.s HX2DC3           			; IF NO MORE SUB POSSIBLE
	addq.l #1,D0           			; BUMP SUBS
	sub.l D2,D7          				; COUNT DOWN BY POWERS OF TEN
	bra.s HX2DC22          			; DO MORE
HX2DC3:
  tst.b D0              			; ANY VALUE?
	bne.s HX2DC4
	tst.w D4              			; ZERO SURPRESS
	beq.s HX2DC5
HX2DC4:
  addi.b #$30,D0         		; BINARY TO ASCII
	move.b D0,(A6)+       			; PUT IN BUFFER
	move.b D0,D4          			; MARK AS NON ZERO SURPRESS
HX2DC5:
  subq.l #1,D6           			; NEXT POWER
	bne.s HX2DC0
	tst.w D4              			; SEE IF ANYTHING PRINTED
	bne.s HX2DC6
HX2DC57:
 move.b #'0',(A6)+      			; PRINT AT LEST A ZERO
HX2DC6:
	movem.l (A7)+,D1-D4/D6-D7 ; RESTORE REGISTERS
  rts                      	; END OF ROUTINE


PNT4HX:
PNT4HEX:
	bra BufWyde
PNT6HX:
	swap d0
	bsr BufByte
	swap d0
	bra BufWyde
PNT8HX:
	bra BufTetra
	
; FORMAT RELATIVE ADDRESS  AAAAAA+Rn
;        ENTER     D0 = VALUE
;                  A6 = STORE POINTER
;
FRELADDR:
	movem.l D1/D5-D7/A0,-(A7)
	lea OFFSET,A0
	moveq #-1,D7        	; D7 = DIFF. BEST FIT
	clr.l D6            	; D6 = OFFSET POSITION
FREL10:
  move.l D0,D1
	tst.l (a0)
	beq.s FREL15         	; ZERO OFFSET
	sub.l (a0),d1      		; D1 = DIFF.
	bmi.s FREL15         	; NO FIT
	cmp.l D7,D1
	bcc.s FREL15         	; OLD FIT BETTER
	move.l D1,D7        	; D7 = NEW BEST FIT
	move.l D6,D5        	; D5 = POSITION
FREL15:
  addq.l #4,A0
	addq.l #1,D6
	cmpi.w #8,D6
	bne.s FREL10         	; MORE OFFSETS TO CHECK
	tst.l D7
	bmi.s FREL25         	; NO FIT
	tst D6
	bne.s FREL20
	tst.l OFFSET
	beq.s FREL25         	; R0 = 000000; NO FIT
FREL20:
  move.l D7,D0
	bsr	PNT6HX         		; FORMAT OFFSET
	move.b #'+',(A6)+    	; +
	move.b #'R',(A6)+    	; R
	addi.b #'0',D5       	; MAKE ASCII
	bra.s FREL30
FREL25:
  bsr	PNT6HX         	; FORMAT ADDRESS AS IS
	move.b #BLANK,D5
	move.b D5,(A6)+     	; THREE SPACES FOR ALIGNMENT
	move.b D5,(A6)+
FREL30:
  move.b D5,(A6)+
	movem.l (A7)+,D1/D5-D7/A0
	rts

	include "dcode68k.x68"
 	include "games/asteroids/asteroids 1_0.x68"
