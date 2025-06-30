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
; macro to reverse byte order

macRbo macro arg1
	rol.w #8,\1
	swap \1
	rol.w #8,\1
endm

NCORES equ 4

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

	include "..\Femtiki\source\inc\device.x68"
	include "..\Femtiki\FemtikiTop.x68"

DDATA EQU $FFFFFFF0     ; DS.L    3
HISPC EQU $FFFFFFFC     ; DS.L    1

	if HAS_MMU
TEXTREG		EQU	$1E3FF00	; virtual addresses
txtscreen	EQU	$1E00000
semamem		EQU	$1E50000
ACIA			EQU	$1E60100
ACIA_RX		EQU	0
ACIA_TX		EQU	0
ACIA_STAT	EQU	4
ACIA_CMD	EQU	8
ACIA_CTRL	EQU	12
I2C2 			equ $01E69010
I2C_PREL 	equ 0
I2C_PREH 	equ 1
I2C_CTRL 	equ 2
I2C_RXR 	equ 3
I2C_TXR 	equ 3
I2C_CMD 	equ 4
I2C_STAT 	equ 4
PLIC			EQU	$1E90000
keybd			EQU	$1EFFE00
RAND			EQU	$1EFFD00
RAND_NUM	EQU	$1EFFD00
RAND_STRM	EQU	$1EFFD04
RAND_MZ		EQU $1EFFD08
RAND_MW		EQU	$1EFFD0C
RST_REG		EQU	$1EFFC00
IO_BITMAP	EQU $1F00000
	else
;TEXTREG		equ	$FD080000
;TEXTREG_CURSOR_POS	equ $24
txtscreen	EQU	$FD000000
RST_REG		EQU	$FDFF0000
RAND			EQU	$FDFF4010
RAND_NUM	EQU	$FDFF4010
RAND_STRM	EQU	$FDFF4014
RAND_MZ		EQU $FDFF4018
RAND_MW		EQU	$FDFF401C
keybd			EQU	$FDFF8000
;ACIA			EQU	$FDFE0000
I2C2 			equ $FDFE4000
IO_BITMAP	EQU $FDE00000
;GFXACCEL	equ	$FD210000
PSG				EQU $FD240000
I2C1 			equ $FD250000
ADAU1761 	equ $FD254000
SPI_MASTER1	equ	$FD280000
SPI_MASTER2	equ $FD284000
COPPER		equ $FD288000
semamem		equ	$FD300000

;ACIA_RX		equ	0
;ACIA_TX		equ	0
;ACIA_STAT	equ	4
;ACIA_CMD	equ	8
;ACIA_CTRL	equ	12
I2C_PREL 	equ 0
I2C_PREH 	equ 1
I2C_CTRL 	equ 2
I2C_RXR 	equ 3
I2C_TXR 	equ 3
I2C_CMD 	equ 4
I2C_STAT 	equ 4

	endif

macIRQ_proc	macro arg1
	dc.l IRQ_proc\1
endm

macIRQ_proc_label	macro arg1
IRQ_proc\1:
endm

macHmash macro arg1
	swap \1
	eori.l #DEV_HMASH,\1
endm

macUnhmash macro arg1
	eori.l #DEV_HMASH,\1
	swap \1
endm

	data
	; 0
	dc.l		$00047FFC
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

;CursorRow	equ		$40000
;CursorCol	equ		$40001
;TextPos		equ		$40002
;TextCurpos	equ	$40002
;TextScr			equ	$40004
;S19StartAddress	equ	$40008
;KeybdEcho		equ	$4000C
;KeybdWaitFlag	equ	$4000D
;CmdBuf			equ $40040
;CmdBufEnd		equ	$40080
;fgColor			equ	$40084
;bkColor			equ	$40088
;TextRows		equ	$4008C
;TextCols		equ	$4008D
;_fpTextIncr	equ $40094
;_canary			equ $40098
;tickcnt			equ $4009C
;IRQFlag			equ $400A0
;InputDevice	equ $400A4
;OutputDevice	equ $400A8
;Regsave			equ	$40100
numBreakpoints	equ		8
;BreakpointFlag	equ		$40200
;NumSetBreakpoints	equ	$40202	; to $40203
;Breakpoints			equ		$40220	; to $40240
;BreakpointWords	equ		$40280	; to $402A0
;fpBuf       equ $402C0
;RunningTCB  equ $40300
;_exp equ $40500
;_digit equ $40504
;_width equ $40508
;_E equ $4050C
;_digits_before_decpt equ $40510
;_precision equ $40514
;_fpBuf equ $40520	; to $40560
;_fpWork equ $40600
;_dasmbuf	equ	$40800
;OFFSET equ $40880
;pen_color equ $40890
;gr_x equ $40894
;gr_y equ $40898
;gr_width equ $4089C
;gr_height equ $408A0
;gr_bitmap_screen equ $408A4
;gr_raster_op equ $408A8
;gr_double_buffer equ $408AC
;gr_bitmap_buffer equ $408B0
;sys_switches equ $408B8
;gfxaccel_ctrl equ $408C0
;m_z equ $408D0
;m_w equ $408D4
;next_m_z equ $408D8
;next_m_w equ $408DC
;TimeBuf equ $408E0
;numwka equ $40980
EightPixels equ $40100000	; to $40200020

;null_dcb equ $0040A00		; 0
;keybd_dcb equ null_dcb+DCB_SIZE	; 1
;textvid_dcb equ keybd_dcb+DCB_SIZE	; 2
;err_dcb equ textvid_dcb+DCB_SIZE		; 3
;serial_dcb equ err_dcb+DCB_SIZE*2		; 5
;framebuf_dcb equ serial_dcb+DCB_SIZE	; 6
;gfxaccel_dcb equ framebuf_dcb+DCB_SIZE	; 7
;rtc_dcb equ gfxaccel_dcb+DCB_SIZE		; 8

;spi_buff equ $0042000

; Keyboard buffer is in shared memory
;scratch_ram	equ $00100000
;IOFocus			equ	$00100000
;memend			equ $00100004
;KeybdLEDs		equ	$0010000E
;_KeyState1	equ	$0010000F
;_KeyState2	equ	$00100010
;_KeybdHead	equ	$00100011
;_KeybdTail	equ	$00100012
;_KeybdCnt		equ	$00100013
;KeybdID			equ	$00100018
;_Keybd_tick	equ $0010001C
;_KeybdBuf		equ	$00100020
;_KeybdOBuf	equ	$00100080
;S19Checksum	equ	$00100150
;SerTailRcv	equ	$00100160
;SerHeadRcv	equ	$00100162
;SerRcvXon		equ	$00100164
;SerRcvXoff	equ	$00100165
;SerTailXmit	equ	$00100166
;SerHeadXmit	equ	$00100168
;SerXmitXoff	equ	$0010016A
;SerRcvBuf		equ	$00101000
;SerXmitBuf	equ	$00102000
;RTCBuf			equ $00100200	; to $0010023F

	code
	align		2
start:
;	fadd (a0)+,fp2
	move.b #1,leds
	move.w #$2700,sr					; enable level 6 and higher interrupts
	move.l #2,IOFocus					; Set the IO focus in global memory
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
	move.b #2,leds
.stp	
	movec.l coreno,d0							; set initial value of thread register
;	cmpi.b #2,d0
;	bne .stp
	move.b d0,leds
	swap d0											; coreno in high eight bits
	lsl.l #8,d0
	movec d0,tr
	; Prepare local variable storage
	move.w #767,d0						; 768 longs to clear
;	lea	$40000,a0							; non shared local memory address
;.0111:
;	clr.l	(a0)+								; clear the memory area
;	dbra d0,.0111
	move.b #5,leds
	move.l #$10000,InputDevice			; select keyboard input
	move.l #$20000,OutputDevice		; select text screen output
	move.l #_DeviceTable+2*DCB_SIZE,d0
	jsr setup_textvid
	bsr test_scratchpad_ram
	move.b #3,leds
	jsr setup_null
	move.b #4,leds
	move.l #_DeviceTable+1*DCB_SIZE,d0
	jsr setup_keybd
	move.b #6,leds
	move.l #_DeviceTable+5*DCB_SIZE,d0
	jsr setup_serial
	move.b #7,leds
	movec.l	coreno,d0					; get core number
	cmpi.b #2,d0
	bne	start_other
	jsr setup_framebuf
	move.b #8,leds
	jsr setup_gfxaccel
	move.b #9,leds
	clr.l sys_switches
	lea I2C2,a6
	bsr i2c_setup
	lea I2C1,a6
	bsr i2c_setup
	move.l #2,IOFocus					; Set the IO focus in global memory
	bsr scan_for_dev
;	lea SPI_MASTER1,a1
;	bsr spi_setup
;	lea SPI_MASTER2,a1
;	bsr spi_setup
	if HAS_MMU
		bsr InitMMU							; Can't access anything till this is done'
	endif
	bsr	InitIOPBitmap					; not going to get far without this
	bsr	InitSemaphores
	bsr	InitRand
	bsr RandGetNum
	andi.l #$FFFFFF00,d1
;	move.l d1,_canary
;	movec d1,canary
;	bsr AudioTestOn
	bsr Delay3s
;	bsr AudioTestOff
;	bsr	Delay3s						; give devices time to reset
;	move.l #$20000,d7					; device 2
;	moveq #DEV_CLEAR,d6	; clear
;	trap #0
;	bsr	textvid_clear

;	jsr	_KeybdInit
;	bsr	InitIRQ
;	move.l #_DeviceTable+5*DCB_SIZE,d0
;	jsr	SerialInit
;	bsr init_i2c
;	bsr rtc_read

	; Write startup message to screen

	lea	msg_start,a1
	bsr	DisplayString
;	bsr	FemtikiInit
	bsr Delay3s
	movec	coreno,d0
	swap d0
	moveq	#1,d1
;	bsr	UnlockSemaphore	; allow another cpu access
	moveq #37,d0				; Unlock semaphore
	trap #15
	moveq	#BIOS_SEMA,d1
	trap #15
;	bsr	UnlockSemaphore	; allow other cpus to proceed
	move.w #$A4A4,leds			; diagnostics
	jsr	setup_pic				; initialize interrupt controller
	jmp	StartMon

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
.0001
	move.l #$20000,d7
	bra.s .0001
	move.l #DEV_CLEAR,d6
	trap #0
	movec		coreno,d1
	bsr			DisplayByte
	lea			msg_core_start,a1
	bsr			DisplayString
;	bsr			FemtikiInitIRQ
do_nothing:	
	bra			StartMon
	bra			do_nothing

;==============================================================================
; Test the scratchpad RAM using a checkerboard pattern.
; Starts just past the I/O focus variable, the fourth byte of the RAM.
;==============================================================================

test_scratchpad_ram:
	lea msgTestScratch,a1		; announce
	moveq #13,d0
	trap #15

	move.l #$aaaaaaaa,d3		; checkerboard pattern
	move.l #$55555555,d4
	lea scratch_ram+4,a0
	move.l #16382,d2				; 32768 lwords (128kB)
	; Fill SRAM with checkerboard
.0001
	move.l d3,(a0)					; fill odd lword with 'a's
	move.l d4,4(a0)					; fill even lword with 5s
	lea 8(a0),a0						; advance eight bytes
	dbra d2,.0001
	; Readback stored values
	lea scratch_ram+4,a0
	move.l #16382,d2				; 32768 lwords (128kB)
.0002
	move.l (a0),d3
	move.l 4(a0),d4
	move.l d3,d1
	cmp.l #$aaaaaaaa,d3
	bne.s .log_err
	move.l d4,d1
	cmp.l #$55555555,d4
	bne.s .log_err
.0003
	lea 8(a0),a0
	dbra d2,.0002	
	rts
.log_err:
	bsr DisplayTetra
	moveq #' ',d1
	bsr OutputChar
	move.l a0,d1
	bsr DisplayTetra
	bsr CRLF
	bra.s .0003

msgTestScratch
	dc.b "Testing scratchpad RAM...",0
	
	even

;==============================================================================
; Scan the I/O discovery address space looking for I/O devices.
;
; The I/O discovery address space has the upper four bits of the address
; equal to $D. Only the $D0 block is scanned.
;
; Each I/O device has a 16kB block of address space reserved for it. A device
; has an eleven character NULL terminated device name stored at $80 in the
; discovery block.
;
;==============================================================================

scan_for_dev:
	moveq #13,d0					; DisplayStringCRLF
	lea msgScanning(pc),a1
	trap #15
	move.l #$D0000000,a0
	moveq #0,d2
.0001
	move.l (a0),d0
	cmpi.l #-1,d0
	bne.s .0002
.0003
	add.l #$4000,a0
	cmp.l #$D1000000,a0
	blo.s .0001
	moveq #3,d0
	move.l d2,d1
	trap #15
	lea msgDeviceCount(pc),a1
	moveq #13,d0
	trap #15
	rts
.0002
	addq.l #1,d2
	moveq #14,d0					; DisplayString
	lea msgFound(pc),a1
	trap #15
	move.l $80(a0),d1
	macRbo d1
	move.l d1,numwka+12
	move.l $84(a0),d1
	macRbo d1
	move.l d1,numwka+8
	move.l $88(a0),d1
	macRbo d1
	move.l d1,numwka+4
	move.l $8C(a0),d1
	macRbo d1
	move.l d1,numwka
	moveq #1,d0						; DisplayStringLimited
	moveq #16,d1					; max 16 chars
	lea numwka,a1
	trap #15
	lea msgAt(pc),a1
	moveq #14,d0
	trap #15
	move.l a0,d1
	bsr DisplayTetra
	bsr CRLF
	bra .0003

msgScanning
	dc.b "Scanning for devices...",0
msgFound
	dc.b "Found ",0
msgAt
	dc.b " at ",0
msgDeviceCount
	dc.b " devices",0

	even
	
;==============================================================================
; TRAP #15 handler
;
; Parameters:
;		d0.b = function number to perform
;==============================================================================

T15DTAddr macro arg1
	dc.l (\1-T15DispatchTable)
endm

	align	2
T15DispatchTable:
	T15DTAddr	DisplayStringLimitedCRLF
	T15DTAddr	DisplayStringLimited
	T15DTAddr	StubRout
	T15DTAddr	DisplayNumber
	T15DTAddr	StubRout
	T15DTAddr	GetKey
	T15DTAddr	OutputChar
	T15DTAddr	CheckForKey
	T15DTAddr	GetTick
	T15DTAddr	StubRout
	; 10
	T15DTAddr	StubRout
	T15DTAddr	T15Cursor
	T15DTAddr	SetKeyboardEcho
	T15DTAddr	DisplayStringCRLF
	T15DTAddr	DisplayString
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	CheckForKey
	; 20
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	T15ReadScreenChar
	T15DTAddr	T15Wait100ths
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	; 30
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	SimHardware	;rotate_iofocus
	T15DTAddr	T15GetWindowSize	;SerialPeekCharDirect
	T15DTAddr	SerialPutChar
	T15DTAddr	SerialPeekChar
	T15DTAddr	SerialGetChar
	T15DTAddr	T15LockSemaphore
	T15DTAddr	T15UnlockSemaphore
	T15DTAddr	prtflt
	; 40
	T15DTAddr  _GetRand
	T15DTAddr	T15GetFloat
	T15DTAddr	T15Abort
	T15DTAddr	T15FloatToString
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	; 50
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	; 60
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	; 70
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	; 80
	T15DTAddr	SetPenColor
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	DrawToXY
	T15DTAddr	MoveToXY
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	; 90
	T15DTAddr	T15Rectangle
	T15DTAddr	StubRout
	T15DTAddr	SetDrawMode
	T15DTAddr	StubRout
	T15DTAddr	GRBufferToScreen
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout
	T15DTAddr	StubRout

TRAP15:
	movem.l	d0/a0,-(a7)
	lea T15DispatchTable(pc),a0
	ext.w d0
	lsl.w #2,d0
	move.l (a0,d0.w),d0
	add.l d0,a0
	jsr (a0)
	movem.l (a7)+,d0/a0
	rte


; Parameters:
; 	d1 = text co-ordinates
;		d1.low word = colum
; 	d1.high word = row
; Returns:
;		d1.w = ascii code for screen character

T15ReadScreenChar:
	movem.l d2/d3/a0,-(sp)
	move.l d1,d2
	ext.l d2				; d2 = col
	swap d1
	ext.l d1				; d1 = row
	move.b TextCols,d3
	ext.w d3
	mulu d3,d1			; d1 row * #cols
	add.l d2,d1			; d1 = row * #cols + col
	if (SCREEN_FORMAT==1)
		lsl.l #2,d1
	else
		lsl.l #3,d1
	endif
	add.l TextScr,d1
	move.l d1,a0
	move.l (a0),d1
	bsr rbo
	and.l #$01FF,d1
	movem.l (sp)+,d2/d3/a0
	rts


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

	align 2
;------------------------------------------------------------------------------
; Device drivers
;------------------------------------------------------------------------------

;	include "..\Femtiki\source\kernel\Femtiki_vars.x68"
	include "..\Femtiki\source\drivers\null.x68"
	include "..\Femtiki\source\drivers\keybd.x68"
	include "..\Femtiki\source\drivers\textvid.x68"
	include "..\Femtiki\source\drivers\err.x68"
	include "..\Femtiki\source\drivers\serial.x68"
	include "..\Femtiki\source\drivers\framebuf.x68"
	include "..\Femtiki\source\drivers\gfxaccel.x68"
	include "..\Femtiki\source\drivers\audio.x68"
	include "..\Femtiki\source\drivers\pic.x68"

;------------------------------------------------------------------------------
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
	move.l #$12345678,m_z		; initialize to some value
	move.l #$98765432,m_w
	move.l #$82835438,next_m_z
	move.l #$08723746,next_m_w
	movem.l	d0/d1,-(a7)
	moveq #37,d0								; lock semaphore
	moveq	#RAND_SEMA,d1
	trap #15
	movec coreno,d0							; d0 = core number
	sub.l #2,d0									; make 0 to 9
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
	sub.l #2,d0									; make 0 to 9
	lsl.l	#6,d0
	move.l d0,RAND_STRM					; select the stream
	move.l RAND_NUM,d2					; d2 = random number
	move.l d2,RAND_NUM		 		  ; generate next number
	bsr T15UnlockSemaphore
	move.l d2,d1
	movem.l	(a7)+,d0/d2
	rts

prng:
	move.l d2,-(a7)
	move.l m_z,d1
	move.l d1,d2
	mulu #6969,d1
	swap d2
	ext.l d2
	add.l d1,d2
	move.l d2,next_m_z

	move.l m_w,d1
	move.l d1,d2
	mulu #18000,d1
	swap d2
	ext.l d2
	add.l d1,d2
	move.l d2,next_m_w
	
	move.l m_z,d1
	swap d1
	clr.w d1
	add.l m_w,d1
	move.l next_m_z,m_z
	move.l next_m_w,m_w
	move.l (a7)+,d2
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
;		d2 = retry count
;	Returns:
;		d0 = -1 for success, 0 if failed
; -----------------------------------------------------------------------------

LockSemaphore:
	movem.l	d1/d2/a0,-(a7)	; save registers
	lea	semamem,a0					; point to semaphore memory lock area
	andi.w #255,d1					; make d1 word value
	lsl.w	#2,d1							; align to memory
.0001
	move.l d0,(a0,d1.w)			; try and write the semaphore
	cmp.l (a0,d1.w),d0			; did it lock?
	dbeq d2,.0001						; no, try again
	seq d0									; d0
	ext.w d0
	ext.l d0
	movem.l	(a7)+,a0/d1/d2	; restore regs
	rts
	
; -----------------------------------------------------------------------------
; Unlocks a semaphore even if not the owner.
;
; Parameters:
;		d1.w semaphore number
; -----------------------------------------------------------------------------

ForceUnlockSemaphore:
	movem.l	d1/a0,-(a7)				; save registers
	lea	semamem+$3000,a0			; point to semaphore memory read/write area
	andi.w #255,d1						; make d1 word value
	lsl.w	#2,d1								; align to memory
	clr.l	(a0,d1.w)						; write zero to unlock
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
	lea	semamem+$1000,a0			; point to semaphore memory unlock area
	andi.w #255,d1						; make d1 word value
	lsl.w	#2,d1								; align to memory
	move.l d0,(a0,d1.w)				; write matching value to unlock
	movem.l	(a7)+,a0/d1				; restore regs
	rts

; -----------------------------------------------------------------------------
; Parameters:
;		d1 = semaphore to lock / unlock
;		d2 = timeout for lock
; -----------------------------------------------------------------------------

T15LockSemaphore:	
	movec tr,d0
	bra LockSemaphore

T15UnlockSemaphore:
	movec tr,d0
	bra UnlockSemaphore

; Parameters:
; 	a1 = pointer to input text
; 	d1 = input stride (how many bytes to advance per character)
; Returns:
;		a1 = updated text pointer
;		d1 = number of digits in number
;		fp0 = float number

T15GetFloat:
	movem.l d0/a0,-(a7)
	move.l a1,a0
	move.l d1,d0
	bsr _GetFloat
	move.l a0,a1
	move.l d0,d1
	movem.l (a7)+,d0/a0
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
; -----------------------------------------------------------------------------

get_screen_address:
	movem.l d0/d1/d2/d6/d7,-(a7)
	move.l #$20000,d7
	moveq #DEV_GETBUF1,d6
	trap #0
	move.l d1,a0
	movem.l (a7)+,d0/d1/d2/d6/d7
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

; divide d1 by d2
;
; Returns:
;		d1 = quotient
;		d2 = remainder
	
msgDivZero
	dc.b "Divide by zero ",0

	even
div32:
	movem.l d0/d3/d4/d7,-(sp)
	tst.l d2							; check for divide-by-zero
	bne .0006
  lea	msgDivZero(pc),a1
  bsr DisplayStringCRLF
  bra Monitor
.0006
	moveq #31,d0					; iteration count for 32 bits
	moveq #0,d3						; q = 0
	moveq #0,d4						; r = 0
	move.l d2,d7
	eor.l d1,d7
	tst.l d1							; take absolute value of d1 (a)
	bpl .0001
	neg d1
.0001
	tst.l d2							; take absolute value of d2 (b)
	bpl .0002
	neg d2
.0002
	lsl.l #1,d3						; q <<= 1
	lsl.l #1,d1						; a <<= 1
	addx d4,d4						; r <<= 1 | a MSB
	cmp.l d2,d4						; is b < r?
	blt.s .0004
	sub.l d2,d4						; r -= b	
	ori.l #1,d3						; q |= 1
.0004
	dbra d0,.0002
	tst.l d7
	bpl.s .0005
	neg d4
	neg d3
.0005
	move.l d4,d2
	move.l d3,d1
	movem.l (sp)+,d0/d3/d4/d7
	rts
	
; d1 = number to print
; d2 = number of digits
; Register Usage
;	d5 = number of padding spaces

DisplayNumber:
	movem.l d1/d2/d5/d6/a0,-(sp)
	lea	numwka,a0		; a0 = pointer to numeric work area
	move.l d1,d6		; save number for later
	move.l d2,d5		; d5 = min number of chars
	tst.l d1				; is it negative?
	bpl .0001				; if not
	neg.l d1				; else make it positive
	subi.b #1,d5		; one less for width count
.0001
	moveq #10,d2		; divide by 10
	bsr div32
	add.b #'0',d2		; convert remainder to ascii
	move.b d2,(a0)+	; and store in buffer
	subi.b #1,d5		; decrement width
	tst.l d1
	bne.s .0001
.0002
	tst.b d5				; test pad count
	ble .0003
.0004
	move.b #' ',d1
	bsr OutputChar
	subi.b #1,d5
	bne .0004
.0003
	tst.l d6				; is number negative?
	bpl.s .0005
	move.b #'-',d1	; if so, display the sign
	bsr OutputChar
.0005
	move.b -(a0),d1	; now unstack the digits and display
	bsr OutputChar
	cmpa.l #numwka,a0
	bhi .0005
	movem.l (sp)+,d1/d2/d5/d6/a0
	rts

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

T15Wait100ths:
	move.l d1,-(a7)
	cmp.l #2,d1
	bls.s .0002
	add.l tickcnt,d1
.0001:
	cmp.l tickcnt,d1
	bne.s .0001
.0002:
	move.l (a7)+,d1
	rts

;------------------------------------------------------------------------------
;
SetDrawMode:
	cmpi.b #10,d1
	bne.s .0001
	move.b #5,framebuf_dcb+DCB_OPCODE			; 'OR' operation
	rts
.0001:
	cmpi.b #17,d1
	bne.s .0002
	move.w #1,gr_double_buffer
	rts
.0002:
	rts
	
SetPenColor:
	bsr gfxaccel_set_color
	move.l d1,framebuf_dcb+DCB_FGCOLOR
	rts

; parameters:
;		d0 = color
;		d1 = width
;		d2 = height
;		d3 = x co-ord
;		d4 = y co-ord

T15Rectangle:
	movem.l d1/d2,-(a7)
	add.l d3,d1
	add.l d4,d2
	bsr gfxaccel_draw_rectangle
	movem.l (a7)+,d1/d2
	rts

T15GetPixel:
	movem.l d1/d2/a0,-(a7)
	ext.l d1								; clear upper bits
	ext.l d2
	move.l framebuf_dcb+DCB_OUTBUFPTR,a0
	mulu #800,d2						; y * pixels per line
	add.l d1,d2							; + x
	lsl.l #2,d2							; * 4 bytes per pixel
	move.l (a0,d2.l),d0			; get color
	movem.l (a7)+,d1/d2/a0
	rts

T15GetWindowSize:
	cmpi.b #0,d1
	bne.s .0001
	move.w #800,d1
	swap d1
	move.w #600,d1
	rts
.0001:
	move.l #0,d1
	move.l #0,d1
	rts

;------------------------------------------------------------------------------
; Page flip between two buffers.
;------------------------------------------------------------------------------

GRBufferToScreen:
	move.l #$60000,d7						; framebuffer device
	move.l #DEV_SWAPBUF,d6	; swap buffers
	trap #0
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


TestBitmap:
;	move.w #$0700,pen_color		; dark blue
	move.w #$0700,framebuf_dcb+DCB_BKCOLOR
	move.l #$60000,d7
	move.l #DEV_CLEAR,d6
	trap #0
;	bsr clear_bitmap_screen4
	moveq #94,d0							; page flip (display blank screen)
	trap #15
	move.w #$007c,pen_color		; red pen
	move.l #$60000,d7
	moveq #DEV_SET_OUTPOS,d6
	moveq #0,d1
	moveq #1,d2
	trap #0
	moveq #DEV_GET_DIMEN,d6
	trap #0
	subq.l #1,d1
	move.l d1,d3
	moveq #1,d4
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
	jsr CheckForCtrlC
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
	move.l #$60000,d7
	moveq #DEV_GET_OUTPOS,d6
	trap #0
	move.l #1,d5			; assume increment
	cmp.l d1,d3
	bhi.s .0001
	neg.l d5					; switch to decrement
.0001:
	move.l #$60000,d7
;	moveq #DEV_WRITEAT,d6
	trap #0
	cmp.l d1,d3
	beq.s .0002
	add.l d5,d1
	move.l #$60000,d7
	moveq #DEV_SET_OUTPOS,d6
	trap #0
	bra.s .0001
.0002:
	move.l #$60000,d7
	moveq #DEV_SET_OUTPOS,d6	; update output position
	trap #0
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
; Pass $FF00 to clear the screen
; Pass $FF01 in d1.w to get the output position
;	Pass $FF02 in d1.w to get the input position
;
; Parameters:
;		d1.l cursor position, bits 0 to 7 are row, bits 8 to 15 are column.
;		d1[bit16]: 0=set output position, 1=set input position
;	Returns (get position):
;		d1.[15:8] = column
;		d1.[7:0] = row
;		d1[bit 16] = 0=output position,1=input position
;		none
;------------------------------------------------------------------------------

T15Cursor:
	cmpi.w #$FF00,d1
	blo.s .0002
	cmpi.w #$FF00,d1					; clear screen request?
	beq.s .0003
	movem.l d2/d3/d6/d7,-(sp)
	move.l #$20000,d7
	moveq #DEV_GET_OUTPOS,d6
	moveq #0,d3
	btst.l #0,d1
	bne.s .0004
	moveq #DEV_GET_INPOS,d6
	bset.l #16,d3
.0004
	trap #0
	lsl.l #8,d1
	or.w d2,d1	; d1[15:8] = col, d1[7:0] = row
	or.l d3,d1
	movem.l (sp)+,d2/d3/d6/d7
	rts
.0003
	movem.l d0/d1/d2/d3/d6/d7,-(a7)
	move.l #$20000,d7
	moveq #DEV_CLEAR,d6	; clear screen
	trap #0
	moveq #DEV_SET_OUTPOS,d6
	moveq #0,d1
	moveq #0,d2
	moveq #0,d3
	trap #0
	movem.l (a7)+,d0/d1/d2/d3/d6/d7
	rts
.0002
	move.l #$20000,d7
	moveq #DEV_SET_OUTPOS,d6
	btst #16,d1
	beq.s .0005
	moveq #DEV_SET_INPOS,d6
.0005
	clr.l d2
	move.b d1,d2		; d2 = row (y pos)
	lsr.w #8,d1			; d1 = col (x pos)
	ext.w d1
	ext.l d1
	moveq #0,d3
	trap #0
	movem.l (a7)+,d0/d1/d2/d3/d6/d7
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
	move.l IOFocus,d0					; d0 = focus, we can trash d0
	addq.l #1,d0							; increment the focus
	cmp.l	#NCORES+1,d0				; limit to 2 to 9
	bls.s	.0001
	move.l #2,d0
.0001:
select_focus1:
	move.l d0,IOFocus				;	 set IO focus
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
	dc.b	'SET_TIM','E'+$80
	dc.b	'TIM','E'+$80
	dc.b	'T','R'+$80				; TR test serial receive
	dc.b	'TSC','D'+$80			; Test SD card
	dc.b	'T'+$80						; T test CPU
	dc.b	'S'+$80						; S send serial
	dc.b	"RESE",'T'+$80		; RESET <n>
	dc.b	"CLOC",'K'+$80		; CLOCK <n>
	dc.b	'R'+$80						; R receive serial
	dc.b	'V'+$80
	dc.b	'G','R'+$80				; graphics demo
	dc.b	'p','l','a','n','t','s'+$80	; plants
	dc.b	0,0

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
	dc.l	cmdSetTime
	dc.l	cmdTime
	dc.l	cmdTestSerialReceive
	dc.l	cmdTestSD
	dc.l	cmdTestCPU
	dc.l	cmdSendSerial
	dc.l	cmdReset
	dc.l	cmdClock
	dc.l	cmdReceiveSerial	
	dc.l	cmdVideoMode
	dc.l	cmdGrDemo
	dc.l	cmdPlants
	dc.l	cmdMonitor

; Get a word from screen memory and swap byte order

FromScreen:
	if (SCREEN_FORMAT==1)
		move.l (a0)+,d1
	else
		move.l 4(a0),d1
		lea 8(a0),a0
	endif
	rol.w #8,d1
	swap d1
	rol.w #8,d1
	rts

StartMon:
	clr.w	NumSetBreakpoints
	bsr	ClearBreakpointList
cmdMonitor:
Monitor:
	move.l #2,IOFocus					; Set the IO focus in global memory
	; Reset the stack pointer on each entry into the monitor
	move.l #$47FFC,sp		; reset core's stack
	pea Monitor					; Cause any RTS to go here
	move.w #$2200,sr		; enable level 2 and higher interrupts
	movec	coreno,d0
	swap d0
	moveq	#1,d1					; Unlock semaphore #1
	moveq #38,d0
	trap #15
;	bsr	UnlockSemaphore
	clr.b KeybdEcho			; turn off keyboard echo
PromptLn:
	bsr	CRLF
	move.b #'$',d1
	bsr OutputChar

; Get characters until a CR is keyed
;
Prompt3:
	move.l #2,IOFocus					; Set the IO focus in global memory
	move.l #$10000,d7					; keyboard
	moveq #DEV_GETCHAR,d6
	trap #0
;	jsr	GetKey
	cmpi.w #-1,d1
	beq.s	Prompt3
	cmpi.b #CR,d1
	beq.s	Prompt1
	bsr	OutputChar
	bra.s	Prompt3

; Process the screen line that the CR was keyed on

Prompt1:
	move.l #$20000,d7
	moveq #DEV_GET_OUTPOS,d6
	trap #0
	move.b #$A8,leds
	move.l #$20000,d7
	moveq #DEV_SET_INPOS,d6
	moveq #0,d1						; go back to the start of the line
	trap #0
	move.b #$A7,leds
	move.l #$20000,d7
	moveq #DEV_GET_INPTR,d6
	trap #0
	move.l d1,a0					; a0 = screen memory input location
	move.b #$A6,leds
.0001
	bsr	FromScreen				; grab character off screen
	cmpi.b #'$',d1				; skip over '$' prompt character
	beq.s	.0001
.0002
	cmpi.b #' ',d1				; skip over leading spaces
	bne.s .0003
	bsr FromScreen
	bra .0002
.0003

; Dispatch based on command string

cmdDispatch:
	move.b #$A7,leds
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
	move.l #$20000,d7
	move.l #DEV_CLEAR,d6
	trap #0
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

cmdPlants:
	pea Monitor
	jmp start_plants

cmdSetTime:
	bsr ignBlanks
	bsr GetHexNumber
	move.b d1,d3					; d3 = hours
	or.b #$40,d3					; set 12 hour format
	bsr ignBlanks
	bsr FromScreen
	cmpi.b #':',d1
	bne Monitor
	bsr ignBlanks
	bsr GetHexNumber
	move.b d1,RTCBuf+$01	; save minutes
	bsr ignBlanks
	bsr FromScreen
	cmpi.b #':',d1
	bne Monitor
	bsr ignBlanks
	bsr GetHexNumber
	ori.b #$80,d1					; flag to turn on oscillator
	move.b d1,RTCBuf+$00	; save seconds
	bsr ignBlanks		
	bsr FromScreen
	cmpi.b #'p',d1
	bne .0001
	ori.b #$20,d3					; set pm bit
.0001
	move.b d3,RTCBuf+$02	; set hours
	bsr rtc_write
	bra Monitor

; Display the time
;		4:17:00 am
	
cmdTime:
	lea TimeBuf,a6
	bsr get_time
	move.l a6,a1
	bsr DisplayStringCRLF
	bra Monitor

; Get the time into a buffer
; Parameters:
;		a6 = pointer to buffer to store time as a string

get_time:
	movem.l d0/d3/a6,-(sp)	; save buffer address
	bsr rtc_read					; read the RTC registers
	move.b RTCBuf+$02,d0
	move.b #0,d3					; flag 24 hour format
	btst #6,d0						; 0 = 24 hour format
	beq.s .0001
	move.b #'a',d3				; default to am
	btst #5,d0
	beq.s .0002
	move.b #'p',d3
.0002
	andi.b #$1F,d0
	bra .0003
.0001
	andi.b #$3F,d0
.0003
	bsr BufByte						; copy hours to buffer
	move.b #':',(a6)+
	move.b RTCBuf+$01,d0
	bsr BufByte						; copy minutes to buffer
	move.b #':',(a6)+
	move.b RTCBuf+$00,d0	
	andi.b #$3F,d0
	bsr BufByte						; copy seconds to buffer
	tst.b d3							; 24 hour format?
	beq .0004
	move.b #' ',(a6)+
	move.b d3,d0
	move.b d3,(a6)+
	move.b #'m',(a6)+
.0004	
	move.b #0,(a6)+				; NULL terminate
	movem.l (sp)+,d0/d3/a6
	rts

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
	moveq #0,d7							; Femtiki Initialize
	trap #1
	bra Monitor

cmdTestFP:
	moveq #41,d0						; function #41, get float
	moveq #4,d1							; d1 = input stride
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

cmdTestSD:
	bsr ignBlanks
	bsr GetHexNumber
	move.l #SPI_MASTER1,d3
	cmpi.b #1,d1
	beq.s .0005
	move.l #SPI_MASTER2,d3
.0005
	move.l d3,d1
	macHmash d1
	bsr spi_setup
	tst.b d0
	bne.s .0001
	move.l #HelpMsg,d3
	moveq #1,d2				; write block #1
	bsr spi_write_block
	tst.b d0
	bne.s .0003
	moveq #1,d2
	move.l #spi_buff,d3
	bsr spi_read_block
	tst.b d0
	bne.s .0004
	bra Monitor
.0001
	move.b #'S',d1
.0002
	bsr OutputChar
	move.l d0,d1
	bsr DisplayTetra
	bsr CRLF
	bra Monitor
.0003
	move.b #'W',d0
	bra .0002
.0004
	move.b #'R',d0
	bra .0002	

HelpMsg:
	dc.b	"? = Display help",LF,CR
	dc.b  "CORE n = switch to core n, n = 2 to 9",LF,CR
	dc.b  "RESET n = reset core n",LF,CR
	dc.b	"CLS = clear screen",LF,CR
	dc.b	"EB = Edit memory bytes, EW, EL",LF,CR
	dc.b	"FB = Fill memory bytes, FW, FL",LF,CR
	dc.b	"FMTK = run Femtiki OS",LF,CR
	dc.b	"GR = Graphics command",LF,CR
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
		jsr		GetKey
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
	jsr	CheckForCtrlC
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
	jsr	CheckForCtrlC
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
	jsr	CheckForCtrlC
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
;	swap d2
	move.l d2,(a1)+
	clr.l	d2
	bsr EditMemHelper
	bsr EditMemHelper
;	swap d2
	move.l d2,(a1)+
	bra Monitor
.0005:
	clr.l	d2
	bsr EditMemHelper
	bsr EditMemHelper
	bsr EditMemHelper
	bsr EditMemHelper
	exg d1,d2
;	bsr rbo
	move.l d1,(a1)+
;	bsr rbo
	exg d1,d2
	clr.l	d2
	bsr EditMemHelper
	bsr EditMemHelper
	bsr EditMemHelper
	bsr EditMemHelper
	exg d1,d2
;	bsr rbo
	move.l d1,(a1)+
;	bsr rbo
	exg d1,d2
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

cmdGrDemo:
	move.l #$00008888,d1		; 32 bpp
	move.l #$60000,d7							; framebuf device
	moveq #DEV_SET_COLOR_DEPTH,d6
	trap #0
	move.l #$70000,d7							; same for graphics accelerator device
	trap #0
	move.l #$00110001,d1		; enable, scale 1 clocks/scanlines per pixel, page zero
;	move.l d1,FRAMEBUF+FRAMEBUF_CTRL
	move.l #$0F000063,d1		; burst length of 100, interval of F00h
	move.l d1,FRAMEBUF+FRAMEBUF_CTRL+4		
	move.l #$60000,d7							; framebuf device
	moveq #DEV_SET_DIMEN,d6
	moveq #0,d0
	move.l #VIDEO_X,d1
	move.l #VIDEO_Y,d2
	move.l #0,d3
	trap #0
	move.l #$70000,d7							; same for graphics accelerator device
	trap #0
;	move.l #$60000,d7
;	moveq #2,d0							; set window dimensions
;	trap #0
	; Set destination buffer #0
	move.l #$70000,d7
	moveq #DEV_SET_DESTBUF,d6	; write to buffer 0
	moveq #0,d1
	trap #0
	move.l #$70000,d7
	moveq #DEV_SET_COLOR,d6
	moveq #0,d1
	trap #0
	; Clear the screen
	move.l #$70000,d7
	moveq #DEV_CLEAR,d6
	trap #0
	; Now display the clear screen
	move.l #$60000,d7
	moveq #DEV_SET_DISPBUF,d6
	moveq #0,d1							; display buffer 0
	trap #0

;	moveq #0,d1
;	moveq #0,d2
;	move.l #1920,d3
;	move.l #1080,d4
;	bsr gfxaccel_clip_rect
	; Draw two diagonal white lines
	move.l #VIDEO_Y,d3
	move.l #$40000000,a4
.0002:
	move.l #$00FFFFFF,d2	; white
	move.l d2,(a4)
	add.l #VIDEO_X*4+4,a4
	dbra d3,.0002
	move.l #VIDEO_Y,d3
	move.l #$40000000+VIDEO_X*4,a4
.0007:
	move.l d2,(a4)
	add.l #VIDEO_X*4-4,a4
	dbra d3,.0007
	bra Monitor

;	bra Monitor
plot_rand_points:
	move.l #$7F127F12,d1
	move.l #$70000,d7
	moveq #DEV_SET_COLOR,d6
	trap #0
	move.l #10000,d5
.0005:
	move.l #$40000000,a4
	bsr RandGetNum
	move.l d1,d4					; color
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_Y,d1
	move.l d1,d2
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_X,d1
	swap d2
	swap d1
	mulu #VIDEO_X,d2
	add.l d2,d1
	lsl.l #2,d1
	move.l d4,(a4,d1.l)	; plot point
	dbra d5,.0005
	bra Monitor

;clear_graphics_screen:
;	move.l #0,d1
;	move.l #$60000,d7
;	moveq #DEV_SET_COLOR,d6		; set color in frame buffer
;	trap #0
;	move.l #$70000,d7								; and in graphics accelerator
;	trap #0
;	move.l #$60000,d7								; clear frame buffer
;	moveq #DEV_CLEAR,d6
;	trap #0
;	moveq #DEV_SWAPBUF,d6			; and display it
;	trap #0
;	rts

;	move.l #0,d1
;	bsr gfxaccel_set_color
;	move.l #0,d1
;	move.l #0,d2
;	move.l #1920<<16,d3
;	move.l #1080<<16,d4
;	bsr gfxaccel_draw_rectangle
	move.l #VIDEO_X*VIDEO_Y,d5		; compute number of strips to write
	lsr.l #3,d5						; 8 pixels per strip
;	move.l framebuf_dcb+DCB_OUTBUFPTR,a4
	move.l #$40000000,a4
	move.l #0,$7FFFFFF8		; burst length of zero
	bra.s .0001
.0002:
	swap d5
.0001:
	move.l a4,d1
	bsr rbo
	move.l d1,$7FFFFFF4		; target address
	move.l #0,$7FFFFFFC		; value to write
	lea.l 32(a4),a4
	dbra d5,.0001
;	swap d5
;	dbra d5,.0002
	rts

clear_graphics_screen2:
;	move.l #0,d1
;	bsr gfxaccel_set_color
;	move.l #0,d1
;	move.l #0,d2
;	move.l #1920<<16,d3
;	move.l #1080<<16,d4
;	bsr gfxaccel_draw_rectangle
	move.l #VIDEO_X*VIDEO_Y,d5		; compute number of strips to write
	lsr.l #3,d5						; 8 pixels per strip
	lsr.l #4,d5						; and burst writing 16 strips at once
	move.l framebuf_dcb+DCB_OUTBUFPTR,a4
	move.l #15,$7FFFFFF8		; burst length = 16
	bra.s .0001
.0002:
	swap d5
.0001:
	move.l a4,d1
	bsr rbo
	move.l d1,$7FFFFFF4		; target address
	moveq #15,d1
	bsr rbo
	move.l d1,$7FFFFFF8	; burst length = 16
	move.l #0,$7FFFFFFC		; value to write
	lea.l 32*16(a4),a4
	dbra d5,.0001
;	swap d5
;	dbra d5,.0002
	bra Monitor

wait1ms:
	movem.l d0/d1,-(a7)
	movec tick,d0
	add.l #1000000,d0
	andi.l #$FFFFF000,d0
.0001
	movec tick,d1
	andi.l #$FFFFF000,d1
	cmp.l d0,d1
	bne.s .0001
	movem.l (a7)+,d0/d1
	rts

white_rect:
	move.l #$FFFFFFFF,d1
	move.l #$70000,d7
	moveq #DEV_SET_COLOR,d6
	trap #0
	move.l #100<<16,d1
	move.l #300<<16,d2
	move.l #20,d3
	move.l #250<<16,d4
	move.l #550<<16,d5
	move.l #20,d0
	moveq #DEV_DRAW_RECTANGLE,d6
	trap #0
	bra Monitor

rand_points:
	move.l #30000,d5
.0004:
	move.l #$70000,d7
	moveq #DEV_SET_COLOR,d6
	bsr RandGetNum
	trap #0
	move.l #0,d3					; Z
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_Y,d1
	move.l d1,d2
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_X,d1
	move.l #$70000,d7
	moveq #DEV_PLOT_POINT,d6
	trap #0
	bsr wait1ms
	dbra d5,.0004
	bra Monitor

rand_lines:
	move.l #30000,d5
.0001:
.0006:
	move.l d5,-(sp)
	jsr CheckForCtrlC
	move.l #$70000,d7
	moveq #DEV_SET_COLOR,d6
	bsr RandGetNum
	trap #0
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_Z,d1
	moveq #0,d0
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_Y,d1
	move.l d1,d5
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_X,d1
	move.l d1,d4
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_Z,d1
	moveq #0,d3
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_Y,d1
	move.l d1,d2
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_X,d1
	move.l #$70000,d7
	moveq #DEV_DRAW_LINE,d6
	trap #0
	bsr wait1ms
	move.l (sp),d5
	dbra d5,.0001
	bra Monitor

rand_rect:
	move.l #30000,d5
.0003:
.0006:
	move.l d5,-(sp)
	jsr CheckForCtrlC
	move.l #$70000,d7
	moveq #DEV_SET_COLOR,d6
	bsr RandGetNum
	trap #0
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_Z,d1
	moveq #0,d0
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_Y,d1
	move.l d1,d5
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_X,d1
	move.l d1,d4
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_Z,d1
	moveq #0,d3
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_Y,d1
	move.l d1,d2
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_X,d1
	move.l #$70000,d7
	moveq #DEV_DRAW_RECTANGLE,d6
	trap #0
	bsr wait1ms
	move.l (sp),d5
	dbra d5,.0003
	bra Monitor

rand_rect2:
	move.l #10000,d5
.0003:
.0006:
	jsr CheckForCtrlC
	bsr RandGetNum
	bsr gfxaccel_set_color
	bsr RandGetNum
	move.l d1,d4
	divu #VIDEO_Y,d4
	bsr RandGetNum
	move.l d1,d3
	divu #VIDEO_X,d3
	bsr RandGetNum
	move.l d1,d2
	divu #VIDEO_Y,d2
	bsr RandGetNum
	divu #VIDEO_X,d1
	bsr gfxaccel_draw_rectangle
	bsr wait1ms
	dbra d5,.0003
	bra Monitor

rand_triangle:
	move.l #30000,d7
.0006
	move.l d7,-(sp)
	jsr CheckForCtrlC
	move.l #$70000,d7
	moveq #DEV_SET_COLOR,d6
	bsr RandGetNum
	trap #0
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_Z,d1
	move.l #0,a3
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_Y,d1
	move.l d1,a2
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_X,d1
	move.l d1,a1
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_Z,d1
	move.l #0,d0
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_Y,d1
	move.l d1,d5
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_X,d1
	move.l d1,d4
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_Z,d1
	move.l #0,d3
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_Y,d1
	move.l d1,d2
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_X,d1
	move.l #$400,a4			; triangle draw
	move.l #$70000,d7
	moveq #DEV_DRAW_TRIANGLE,d6
	trap #0
	bsr wait1ms
	move.l (sp)+,d7
	dbra d7,.0006
	bra Monitor

rand_curve:
	move.l #10000,d7
.0006:
	move.l d7,-(sp)
	jsr CheckForCtrlC
	move.l #$70000,d7
	moveq #DEV_SET_COLOR,d6
	bsr RandGetNum
	trap #0
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_Z,d1
	move.l #0,a3
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_Y,d1
	move.l d1,a2
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_X,d1
	move.l d1,a1
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_Z,d1
	move.l #0,d0
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_Y,d1
	move.l d1,d5
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_X,d1
	move.l d1,d4
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_Z,d1
	move.l #0,d3
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_Y,d1
	move.l d1,d2
	bsr RandGetNum
	andi.l #$0FFFF,d1
	mulu #VIDEO_X,d1
	move.l #$70000,d7
	move.l #$0C00,a4						; curve draw
	moveq #DEV_DRAW_CURVE,d6
	move.l (sp)+,d7
	bsr wait1ms
	dbra d7,.0006
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
	jsr	CheckForCtrlC
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
	jsr			CheckForCtrlC
	bra			.0002
.0003:
	jsr			_KeybdInit
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
	include "GetFloat.x68"

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
	move.l #$20000,d7
	move.l #DEV_CLEAR,d6
	trap #0
	rts

;------------------------------------------------------------------------------
; Reverse the order of bytes in d1.
;------------------------------------------------------------------------------

rbo:
	rol.w	#8,d1
	swap d1
	rol.w	#8,d1
	rts

;===============================================================================
;===============================================================================

SPI_MASTER_VERSION_REG equ 0
SPI_MASTER_CTRL_REG	equ 1
SPI_TRANS_TYPE_REG equ 2
SPI_TRANS_CTRL_REG equ 3
SPI_TRANS_STS_REG equ 4
SPI_TRANS_ERR_REG equ 5
SPI_DIRECT_ACCESS_DATA_REG equ 6
SPI_ADDR_70 equ 7
SPI_ADDR_158 equ 8
SPI_ADDR_2316 equ 9
SPI_ADDR_3124 equ 10
SPI_CLK_DEL_REG equ 11
SPI_RX_FIFO_DATA_REG equ 16
SPI_RX_FIFO_DATA_COUNT_MSB equ 18
SPI_RX_FIFO_DATA_COUNT_LSB equ 19
SPI_RX_FIFO_CTRL_REG equ 20
SPI_TX_FIFO_DATA_REG equ 32
SPI_TX_FIFO_CTRL_REG equ 36

SPI_DIRECT_ACCESS equ	0
SPI_INIT_SD equ 1
SPI_RW_READ_SD_BLOCK	equ 2
SPI_RW_WRITE_SD_BLOCK	equ 3

; Setup the SPI device.
;
; Parameters:
;		d1 = pointer to SPI master device (handle)
; Returns:
;		d0 = E_Ok if successful
;				 E_NoDev is card not present

spi_setup:
spi_init:
init_spi:
	movem.l d1/a1,-(sp)
	macUnhmash d1
	move.l d1,a1
	; Turn on the power (negate reset) to the card and reset the logic
	move.b #$01,SPI_MASTER_CTRL_REG(a1)
	btst #2,SPI_MASTER_CTRL_REG(a1)		; ensure there is a card present
	beq.s .0005
	; reset fifos
	move.b #1,SPI_TX_FIFO_CTRL_REG(a1)
	move.b #1,SPI_RX_FIFO_CTRL_REG(a1)
	move.b #SPI_INIT_SD,SPI_TRANS_TYPE_REG(a1)
	move.b #1,SPI_TRANS_CTRL_REG(a1)
.0001
	jsr CheckForCtrlC
	btst #0,SPI_TRANS_STS_REG(a1)	
	bne.s .0001
.0004
	move.b SPI_TRANS_ERR_REG(a1),d0
	andi.b #3,d0
	bne.s .err
	movem.l (sp)+,d1/a1
	moveq #E_Ok,d0
	rts
.err
	movem.l (sp)+,d1/a1
	moveq #E_InitErr,d0
	rts
.0005
	movem.l (sp)+,d1/a1
	moveq #E_NoDev,d0
	rts

;		d1 = pointer to SPI master device (handle)
;		d2 = byte to write
;
spi_send_byte:
	movem.l d1/a1,-(sp)
	move.l d1,a1
	macUnhmash d1
.0001
	jsr CheckForCtrlC
	btst #0,SPI_TRANS_STS_REG
	bne.s .0001
	move.b d2,SPI_DIRECT_ACCESS_DATA_REG(a1)
	move.b #0,SPI_TRANS_TYPE_REG(a1)
	move.b #1,SPI_TRANS_CTRL_REG(a1)
	movem.l (sp)+,d1/a1
	rts

; Parameters:
;		d1 = pointer to SPI master device (handle)
;		d2 = command
;		d3 = command arg
;		d4 = checksum

spi_send_cmd:
	movem.l d2/d4/a1,-(sp)
	ori.b #$40,d2
	bsr spi_send_byte
	move.l d3,d2
	rol.l #8,d2
	bsr spi_send_byte
	rol.l #8,d2
	bsr spi_send_byte
	rol.l #8,d2
	bsr spi_send_byte
	rol.l #8,d2
	bsr spi_send_byte
	move.b d4,d2
	bsr spi_send_byte
	move.w #31,d4
.0002
	move.b #$FF,d2
	bsr spi_send_byte
	macUnhmash d1
	move.l d1,a1
	move.b SPI_DIRECT_ACCESS_DATA_REG(a1),d2
	macHmash d1
	btst.l #7,d2
	beq.s .0001
	dbra d4,.0002
.0001	
	move.b d2,d1
	movem.l (sp)+,d2/d4/a1
	move.b #E_Ok,d0
	rts

;
;		d1 = pointer to SPI master device (handle)
;		d2 = block number to write
;
spi_setpos:
spi_set_block_address:
	movem.l d1/a1,-(sp)
	macUnhmash d1
	move.l d1,a1
	; set the block read address
	btst #1,SPI_MASTER_CTRL_REG(a1)		; check for high-density card
	bne.s .0001
	lsl.l #8,d2										; for a low density card the address is 
	lsl.l #1,d2										; specified directly, is not a block address
.0001:
	move.b d2,SPI_ADDR_70(a1)
	ror.l #8,d2
	move.b d2,SPI_ADDR_158(a1)
	ror.l #8,d2
	move.b d2,SPI_ADDR_2316(a1)
	ror.l #8,d2
	move.b d2,SPI_ADDR_3124(a1)
	ror.l #8,d2
	movem.l (sp)+,d1/a1
	rts

; Parameters:
;		d1 = pointer to SPI master device (handle)
;		d2 = block number to read
;		d3 = buffer to put read data in
;
; Returns:
;		d0 = E_ReadError if there was a read error
;		     E_Ok if successful
;
spi_read_block:
	movem.l d1/a0/a1,-(sp)
	macUnhmash d1
	move.l d1,a1
	move.l d3,a0
	; set the block read address
	bsr spi_set_block_address
	move.b #SPI_RW_READ_SD_BLOCK,SPI_TRANS_TYPE_REG(a1)	; set read transaction
	move.b #1,SPI_TRANS_CTRL_REG(a1)	; start transaction
.0002
	jsr CheckForCtrlC
	btst.b #0,SPI_TRANS_STS_REG(a1)		; wait for transaction not busy
	bne.s .0002
	move.b SPI_TRANS_ERR_REG(a1),d0
	andi.b #$0c,d0
	bne.s .readerr
	; now read the data from the fifo
	move.w #512,d0	
.0003
	move.b SPI_RX_FIFO_DATA_REG(a1),(a0)+
	dbra d0,.0003
	movem.l (sp)+,d1/a0/a1
	moveq #E_Ok,d0
	rts
.readerr:
	movem.l (sp)+,d1/a0/a1
	moveq #E_ReadError,d0
	rts

; Parameters:
;		d1 = pointer to SPI master device (handle)
;		d2 = block number to write
;		d3 = buffer to output write data from
;
; Returns:
;		d0 = E_WriteError if there was a write error
;		     E_Ok if successful
;
spi_write_block:
	movem.l d1/a0/a1,-(sp)
	macUnhmash d1
	move.l d1,a1
	move.l d3,a0
	; First load up the write fifo with data
	move.w #512,d0
.0001
	move.b (a0)+,SPI_TX_FIFO_DATA_REG(a1)
	dbra d0,.0001	
	bsr spi_set_block_address
	move.b #SPI_RW_WRITE_SD_BLOCK,SPI_TRANS_TYPE_REG(a1)	; set write transaction
	move.b #1,SPI_TRANS_CTRL_REG(a1)	; start transaction
.0002
	jsr CheckForCtrlC
	btst.b #0,SPI_TRANS_STS_REG(a1)		; wait for transaction not busy
	bne.s .0002
	move.b SPI_TRANS_ERR_REG(a1),d0
	andi.b #$30,d0
	bne.s .writeerr
	movem.l (sp)+,d1/a0/a1
	moveq #E_Ok,d0
	rts
.writeerr
	movem.l (sp)+,d1/a0/a1
	moveq #E_WriteError,d0
	rts

; Parameters:
;		d1 = pointer to SPI master device (handle)
;		d2 = first block number to read
;		d3 = address of buffer
;		d4 = length of buffer
;
; Returns:
;		d0 = E_WriteError if there was a write error
;		     E_Ok if successful
;
spi_getbuf:
	movem.l d1/d2/d3/d4/a0/a1,-(sp)
	macUnhmash d1
	move.l d1,a1					; a1 = pointer to SPI device
	move.l d3,a0					; a0 = address of buffer
	move.l d2,d1					; d1 = block number to write
	add.l #511,d4					; round length up to even block number
	andi.l #$FFFFFE00,d4
	subq.l #1,d4					; loop the correct number of times
.0001
	bsr spi_read_block
	tst.b d0
	bne.s .err
	lea 512(a0),a0				; advance pointer to next block
	addq.l #1,d1					; advance block number
	dbra d4,.0001
	movem.l (sp)+,d1/d2/d3/d4/a0/a1
	moveq #E_Ok,d0
	rts
.err
	movem.l (sp)+,d1/d2/d3/d4/a0/a1
	rts

; Parameters:
;		d1 = pointer to SPI master device (handle)
;		d2 = first block number to write
;		d3 = address of buffer
;		d4 = length of buffer
;
; Returns:
;		d0 = E_WriteError if there was a write error
;		     E_Ok if successful
;
spi_putbuf:
	movem.l d1/d2/d3/d4/a0/a1,-(sp)
	macUnhmash d1
	move.l d1,a1					; a1 = pointer to SPI device
	move.l d3,a0					; a0 = address of buffer
	move.l d2,d1					; d1 = block number to write
	add.l #511,d4					; round length up to even block number
	andi.l #$FFFFFE00,d4
	subq.l #1,d4					; loop the correct number of times
.0001
	bsr spi_write_block
	tst.b d0
	bne.s .err
	lea 512(a0),a0				; advance pointer to next block
	addq.l #1,d1					; advance block number
	dbra d4,.0001
	movem.l (sp)+,d1/d2/d3/d4/a0/a1
	moveq #E_Ok,d0
	rts
.err
	movem.l (sp)+,d1/d2/d3/d4/a0/a1
	rts

;===============================================================================
; Generic I2C routines
;
; a6 points to I2C device
;===============================================================================

	even
; i2c
i2c_setup:
;		lea		I2C,a6				
;		move.w	#19,I2C_PREL(a6)	; setup prescale for 400kHz clock
;		move.w	#0,I2C_PREH(a6)
init_i2c:
;	lea	I2C2,a6				
	move.b #0,I2C_CTRL(a6)		; make sure I2C disabled
	move.b #49,I2C_PREL(a6)		; setup prescale for 400kHz clock, 100MHz master
	move.b #0,I2C_PREH(a6)
	lea msgI2CSetup(pc),a1
	moveq #13,d0
	trap #15
	rts

msgI2CSetup:
	dc.b "I2C setup",0
	
	even
i2c_enable:
	move.b #$80,I2C_CTRL(a6)	; enable I2C
	rts

i2c_disable:
	move.b #0,I2C_CTRL(a6)		; disable I2C and return status
	rts

; Wait for I2C transfer to complete
;
; Parameters
; 	a6 - I2C controller base address

i2c_wait_tip:
.0001
	jsr CheckForCtrlC				
	btst #1,I2C_STAT(a6)			; wait for tip to clear
	bne.s	.0001
	rts

; Reads the i2c then outputs a STOP
;
; Parameters
;		a6	 - I2C controller base address
; Returns:
;		d0.b - I2C status

i2c_read_stop:
	move.b #$68,I2C_CMD(a6)		; rd bit, STO + nack
	bsr	i2c_wait_tip
	bsr	i2c_wait_rx_nack
i2c_get_status:	
	move.b I2C_STAT(a6),d0
	rts

i2c_read_ack:
	move.b #$20,I2C_CMD(a6)		; rd bit+ACK
	bsr	i2c_wait_tip
	move.b I2C_STAT(a6),d0
	rts

i2c_read:
	move.b I2C_RXR(a6),d0
	rts

; Parameters
;		a6	 - I2C controller base address
;		d0.b - data to transmit
;		d1.b - command value
; Returns:
;		d0.b - I2C status

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
.0001						
	jsr CheckForCtrlC
	btst #7,I2C_STAT(a6)		; wait for RXack = 0
	bne.s	.0001
	rts

;===============================================================================
; Realtime clock routines
;===============================================================================

rtc_read:
	movem.l d1/d2/d3/a5/a6,-(sp)
	lea	I2C2,a6
	lea	RTCBuf,a5
	move.w #20,d3
	moveq #0,d2
	bsr i2c_enable
.0002	
	move.b #$DE,d0				; read address, write op
	move.b #$90,d1				; STA + wr bit
	bsr	i2c_wr_cmd
	tst.b	d0							; look for ACK(bit7=0)
	dbpl d3,.0002
	bmi	.rxerr
	move.b d2,d0					; d0=address
	move.b #$50,d1				; wr bit + STO
	bsr	i2c_wr_cmd
	tst.b	d0
	dbpl d3,.0002
	bmi	.rxerr
	move.w #20,d3
.0001
	move.b #$DF,d0				; read address, read op
	move.b #$90,d1				; STA + wr bit
	bsr	i2c_wr_cmd
	tst.b	d0							; look for ACK(bit7=0)
	dbpl d3,.0001
	bmi	.rxerr
.0003
	bsr i2c_read_ack
	bsr i2c_read
	move.b d0,(a5,d2.w)
	addi.w #1,d2
	cmpi.w #$5f,d2
	bne	.0003
	bsr i2c_read_stop
	bsr i2c_read
	move.b d0,(a5,d2.w)
	bsr i2c_disable
	movem.l (sp)+,d1/d2/d3/a5/a6
	moveq	#0,d0
	rts
.rxerr
	bsr i2c_disable
	movem.l (sp)+,d1/d2/d3/a5/a6
	rts

rtc_write:
	movem.l d1/d2/d3/a5/a6,-(sp)
	movea.l	#I2C2,a6
	lea	RTCBuf,a5
	bsr i2c_enable
	move.w #$00,d2
	move.w #20,d3
.0002
	move.b #$DE,d0				; read address, write op
	move.b #$90,d1				; STA + wr bit
	bsr	i2c_wr_cmd
	tst.b	d0
	dbpl d3,.0002
	bmi .rxerr
	move.b d2,d0					; address zero
	move.b #$10,d1				; wr bit
	bsr	i2c_wr_cmd
	tst.b	d0
	dbpl d3,.0002						; received a NACK, try again
	bmi.s .rxerr
.0004
	move.w #20,d3
.0001
	move.b (a5,d2.w),d0
	move.b #$10,d1				; wr bit
	bsr	i2c_wr_cmd
	tst.b d0
	dbpl d3,.0001
	bmi.s .rxerr
	addi.w #1,d2
	cmpi.w #$5f,d2
	bne.s	.0004
	move.w #20,d3
.0003
	move.b (a5,d2.w),d0
	move.b #$50,d1				; wr bit + STO
	bsr	i2c_wr_cmd
	tst.b d0
	dbpl d3,.0003
	bmi.s .rxerr
	bsr i2c_disable
	movem.l (sp)+,d1/d2/d3/a5/a6
	moveq	#0,d0
	rts
.rxerr:
	bsr i2c_disable
	movem.l (sp)+,d1/d2/d3/a5/a6
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
	move.b #10,leds
	link a2,#-48
	movem.l d0/d1/d2/d3/d6/a0/a1/a2,(sp)
	fmove.x fp0,32(sp)
	move.b #11,leds
	move.l a1,a0						; a0 = pointer to buffer to use
	move.b d1,_width
	move.l d2,_precision
	move.b d3,_E
	bsr _FloatToString
	move.b #12,leds
	bsr DisplayString
	move.b #13,leds
	fmove.x 32(sp),fp0
	move.b #14,leds
	movem.l (sp),d0/d1/d2/d3/d6/a0/a1/a2
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
;		d7 = device handle, d7.high word = device number
;		d6 = function number
;		d0 to d5 = arguments
;==============================================================================

io_trap:
	cmpi.l #$200000,d7							; make sure legal device
	bhs.s .0002
	move.l a0,-(sp)
	move.l d7,-(sp)
	swap d7
	ext.w d7
	mulu #DCB_SIZE,d7					; index to DCB
	lea _DeviceTable,a0
	move.l DCB_CMDPROC(a0,d7.w),a0
	move.l (sp),d7
	jsr (a0)
	move.l (sp)+,d7
	move.l (sp)+,a0
	rte
.0002:
	moveq #E_BadDevNum,d0
	rte

;==============================================================================
; Output a character to the current output device.
;
; Parameters:
;		d1.b	 character to output
; Returns:
;		none
;==============================================================================

OutputChar:
	movem.l d0/d6/d7,-(a7)
	clr.l d7
	clr.l d6
	move.l OutputDevice,d7		; d7 = output device
	move.w #DEV_PUTCHAR,d6		; d6 = function
	trap #0
	movem.l (a7)+,d0/d6/d7
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
	lea $FD000000+(TEXTCOL-10)*4,a0			; display field address
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
	move.l	#$47FFC,a7			; reset stack pointer
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
	include "games/plants/plants.x68"

	global Delay3s
	global DisplayString
	global DisplayStringCRLF
	global CRLF
