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
; 00008000 +----------------+      <+
;					 |    unused      |
; 00040000 +----------------+
;					 |   local ram    |
; 00041000 +----------------+
;					 |    unused      |
; 00100000 +----------------+
;					 |   global ram   |
; 00101000 +----------------+
;					 |    unused      |
; 20000000 +----------------+
;          |                |
;          |                |
;          |                |
;          :  dram memory   : 512 MB
;          |                |
;          |                |
;          |                |
; 40000000 +----------------+
;          |                |
;          :     unused     :
;          |                |
; FFD00000 +----------------+
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
CTRLC	EQU		$03
CTRLH	EQU		$08
CTRLX	EQU		$18
LF		EQU		$0A
CR		EQU		$0D

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

TEXTREG		EQU	$FD03FF00
txtscreen	EQU	$FD000000
semamem		EQU	$FD050000
ACIA			EQU	$FD060000
ACIA_RX		EQU	0
ACIA_TX		EQU	0
ACIA_STAT	EQU	4
PLIC			EQU	$FD090000
leds			EQU	$FD0FFF00
keybd			EQU	$FD0FFE00
KEYBD			EQU	$FD0FFE00
rand			EQU	$FD0FFD00
IOFocus		EQU	$00100000

	data
	dc.l		$00040FFC
	dc.l		start
	dc.l		bus_err
	dc.l		0
	dc.l		illegal_trap		* ILLEGAL instruction
	dc.l		0
	dc.l		EXCEPTION_6			* CHK
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
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		0
	
	; 30
	dc.l		irq_rout					* IRQ 30 - timer
	dc.l		nmi_rout
	dc.l		0
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
	dc.l		0

	; 60
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		brdisp_trap
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		0
	dc.l		0


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
Regsave			equ	$40100
numBreakpoints	equ		8
BreakpointFlag	equ		$40200
NumSetBreakpoints	equ	$40202	; to $40203
Breakpoints			equ		$40220	; to $40240
BreakpointWords	equ		$40280	; to $402A0

; Keyboard buffer is in shared memory
KeybdLEDs		equ	$0010000E
_KeyState1	equ	$0010000F
_KeyState2	equ	$00100010
_KeybdHead	equ	$00100011
_KeybdTail	equ	$00100012
_KeybdCnt		equ	$00100013
_KeybdBuf		equ	$00100020

	code
	align		2
start:
	move.w	#$2700,sr				; enable level 6 and higher interrupts
	; Prepare local variable storage
	move.w	#1023,d0					; 1024 longs to clear
	lea			$40000,a0					; non shared local memory address
.0111:
	clr.l		(a0)+							; clear the memory area
	dbra		d0,.0111
	move.l	#$1fffff,fgColor	; set foreground / background color
	move.l	#$00003f,bkColor
	movec.l	coreno,d0					; get core number (2 to 9)
	subi.b	#2,d0							; adjust (0 to 7)
	mulu		#16384,d0					; compute screen location
	addi.l	#$FD000000,d0
	move.l	d0,TextScr
	move.b	#64,TextCols			; set rows and columns
	move.b	#32,TextRows
	movec.l	coreno,d0					; get core number
	cmpi.b	#2,d0
	bne			start_other
	move.b	d0,IOFocus				; Set the IO focus in global memory
;	bsr			InitSemaphores
	bsr			Delay3s						; give devices time to reset
	bsr			clear_screen

	; Write startup message to screen

	lea			msg_start,a1
	bsr			DisplayString
	moveq.l	#1,d1
	bsr			UnlockSemaphore	; allow another cpu access
	moveq.l	#0,d1
	bsr			UnlockSemaphore	; allow other cpus to proceed
	move.w	#$A4A4,leds			; diagnostics
	bsr			init_plic				; initialize platform level interrupt controller
	bra			StartMon
	bsr			cpu_test
;	lea			brdisp_trap,a0	; set brdisp trap vector
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
	bsr			clear_screen
	movec.l	coreno,d1
	bsr			DisplayByte
	lea			msg_core_start,a1
	bsr			DisplayString
do_nothing:	
	bra			StartMon
	bra			do_nothing

;------------------------------------------------------------------------------
; Initialize semaphores
; - all semaphores are set to one except the first one, which is set to zero.
;
; Parameters:
;		<none>
; Modifies:
;		<none>
; Returns:
;		<none>
;------------------------------------------------------------------------------

InitSemaphores:
	movem.l	d0/d1/a0,-(a7)
	lea			semamem,a0
	move.b	#0,$4000(a0)		; lock the first semaphore
	move.w	#254,d1
	moveq		#1,d0
.0001:
	lea			16(a0),a0
	move.b	d0,$4000(a0)
	dbra		d1,.0001
	movem.l	(a7)+,d0/d1/a0
	rts

; -----------------------------------------------------------------------------
; Test a semaphore to see if it is non-zero.
;
; Parameters:
;		d1 semaphore number
; -----------------------------------------------------------------------------

TestSemaphore:
	movem.l	d1/a0,-(a7)			; save registers
	lea			semamem,a0			; point to semaphore memory
	ext.w		d1							; make d1 word value
	asl.w		#4,d1						; align to memory
	addi.w	#$4000,d1				; point to read / write memory
	tst.b		(a0,d1.w)				; read (test) value for zero
	movem.l	(a7)+,a0/d1			; restore regs
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

IncrementSemaphore:
	movem.l	d1/a0,-(a7)			; save registers
	lea			semamem,a0			; point to semaphore memory
	ext.w		d1							; make d1 word value
	asl.w		#4,d1						; align to memory
	tst.b		1(a0,d1.w)			; read (test) value for zero
	movem.l	(a7)+,a0/d1			; restore regs
	rts
	
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

DecrementSemaphore:
	movem.l	d1/a0,-(a7)			; save registers
	lea			semamem,a0			; point to semaphore memory
	andi.w	#255,d1					; make d1 word value
	asl.w		#4,d1						; align to memory
	tst.b		1(a0,d1.w)			; read (test) value for zero
	movem.l	(a7)+,a0/d1			; restore regs
	rts

; -----------------------------------------------------------------------------
; Parameters:
;		d1 semaphore number
; -----------------------------------------------------------------------------

LockSemaphore:
.0001:
	bsr			DecrementSemaphore
	beq.s		.0001
	rts
	
; -----------------------------------------------------------------------------
; Test a semaphore to see if it is non-zero.
;
; Parameters:
;		d1 semaphore number
; -----------------------------------------------------------------------------

UnlockSemaphore:
	movem.l	d1/a0,-(a7)			; save registers
	lea			semamem,a0			; point to semaphore memory
	andi.w	#255,d1					; make d1 word value
	asl.w		#4,d1						; align to memory
	addi.w	#$4000,d1				; point to read / write memory
	move.b	#1,(a0,d1.w)		; write one to unlock
	movem.l	(a7)+,a0/d1			; restore regs
	rts

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

	include "cputest.asm"

; -----------------------------------------------------------------------------
; Gets the screen color in d0 and d1.
; -----------------------------------------------------------------------------

get_screen_color:
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
	bsr			get_screen_address	; a0 = pointer to screen area
	move.b	TextRows,d0					; d0 = rows
	move.b	TextCols,d2					; d2 = cols
	ext.w		d0									; convert to word
	ext.w		d2									; convert to word
	mulu		d0,d2								; d2 = number of character cells to clear
	bsr			get_screen_color		; get the color bits
	ori.w		#32,d1							; load space character
	rol.w		#8,d1								; swap endian, text controller expects little endian
	swap		d1
	rol.w		#8,d1
	rol.w		#8,d0								; swap endian
	swap		d0
	rol.w		#8,d0
loop3:
	move.l	d1,(a0)+						; copy char plus bkcolor to cell
	nop	
	nop
	nop	
	nop
	move.l	d0,(a0)+					; copy fgcolor to cell
	nop
	nop
	nop	
	nop
	dbra		d2,loop3
	movem.l	(a7)+,d0/d1/d2/a0
	rts

CRLF:
	move.l	d1,-(a7)
	move.b	#13,d1
	bsr			DisplayChar
	move.b	#10,d1
	bsr			DisplayChar
	move.l	(a7)+,d1
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
	bsr			UpdateTextPos
	ext.l		d0								; make it into a long
	asl.l		#3,d0							; 8 bytes per char
	bsr			get_screen_address
	add.l		d0,a0							; a0 = screen location
	rts

;------------------------------------------------------------------------------
; Display a character on the screen
; d1.b = char to display
;------------------------------------------------------------------------------

DisplayChar:
	movem.l	d1/d2/d3,-(a7)
	movec		coreno,d2
	cmpi.b	#2,d2
	bne.s		.0001
	bsr			SerialPutChar
.0001:
	andi.l	#$ff,d1				; zero out upper bytes of d1
	cmpi.b	#13,d1				; carriage return ?
	bne.s		dccr
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
	or.l		d2,d1					; d1 = char + color
	rol.w		#8,d1					; text controller expects little endian data
	swap		d1
	rol.w		#8,d1
	move.l	d1,(a0)
	rol.w		#8,d0					; swap bytes
	swap		d0						; swap halfs
	rol.w		#8,d0					; swap remaining bytes
	move.l	d0,4(a0)
	bsr			IncCursorPos
	bsr			SyncCursor
	bra			dcx4
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
	bsr		  CalcScreenLoc		; a0 = screen location
	move.b	CursorCol,d0
.0001:
	move.l	8(a0),(a0)		; pull remaining characters on line over 1
	move.l	12(a0),4(a0)	; pull remaining characters on line over 1
	lea			8(a0),a0
	addi.b	#1,d0
	cmp.b		TextCols,d0
	blo.s		.0001
	bsr			get_screen_color
	move.w	#' ',d1				; terminate line with a space
	rol.w		#8,d1
	swap		d1
	rol.w		#8,d1
	move.l	d1,-8(a0)
	movem.l	(a7)+,d0/d1/a0
	bra.s		dcx16				; finished

	;---------------------------
	; CTRL-X: erase line
	;---------------------------
doCtrlX:
	clr.b		CursorCol			; Reset cursor to start of line
	move.b	TextCols,d0			; and display TextCols number of spaces
	ext.w		d0
	ext.l		d0
	move.b	#' ',d1				; d1 = space char
.0001:
	; DisplayChar is called recursively here
	; It's safe to do because we know it won't recurse again due to the
	; fact we know the character being displayed is a space char
	bsr		DisplayChar			
	subq	#1,d0
	bne.s	.0001
	clr.b	CursorCol			; now really go back to start of line
	bra.s	dcx16				; we're done

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
	bsr			get_screen_address
	move.l	a0,a5								; a5 = pointer to text screen
.0003:								
	move.b	TextCols,d0					; d0 = columns
	move.b	TextRows,d1					; d1 = rows
	ext.w		d0									; make cols into a word value
	ext.w		d1									; make rows into a word value
	asl.w		#3,d0								; make into cell index
	lea			0(a5,d0.w),a0				; a0 = pointer to second row of text screen
	lsr.w		#3,d0								; get back d0
	subq		#1,d1								; number of rows-1
	mulu		d1,d0								; d0 = count of characters to move
.0001:
	move.l	(a0)+,(a5)+					; each char is 64 bits
	move.l	(a0)+,(a5)+	
	dbra		d0,.0001
	movem.l	(a7)+,d0/d1/a0/a5
	; Fall through into blanking out last line

;------------------------------------------------------------------------------
; Blank out the last line on the screen.
;------------------------------------------------------------------------------

BlankLastLine:
	movem.l	d0/d1/d2/a0,-(a7)
	bsr			get_screen_address
	move.b	TextRows,d0					; d0 = columns
	move.b	TextCols,d1					; d1 = rows
	ext.w		d0
	ext.w		d1
	subq		#1,d1								; last row = #rows-1
	mulu		d1,d0								; d0 = index of last line
	asl.w		#3,d0								; *8 bytes per char
	lea			(a0,d0.w),a0				; point a0 to last row
	move.b	TextCols,d2					; number of text cells to clear
	ext.w		d2
	subi.w	#1,d2								; count must be one less than desired
	bsr			get_screen_color		; d0,d1 = screen color
	move.w	#32,d1							; set the character for display in low 16 bits
	rol.w		#8,d1								; reverse the byte order
	swap		d1
	rol.w		#8,d1
	rol.w		#8,d0
	swap		d0
	rol.w		#8,d0
.0001:
	move.l	d0,(a0)+
	move.l	d1,(a0)+
	dbra		d2,.0001
	movem.l	(a7)+,d0/d1/d2/a0
	rts

;------------------------------------------------------------------------------
; Display a string on the screen.
;------------------------------------------------------------------------------

DisplayString:
	movem.l	d0/d1/a1,-(a7)
dspj1:
	clr.l		d1						; clear upper bits of d1
	move.b	(a1)+,d1			; move string char into d1
	beq.s		dsret					; is it end of string ?
	bsr			DisplayChar		; display character
	bra.s		dspj1					; go back for next character
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
	clr.l		d1						; clear upper bits of d1
	move.b	(a1)+,d1			; move string char into d1
	beq.s		.0002					; is it end of string ?
	bsr			DisplayChar		; display character
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
	movem.l	d0/d2,-(a7)
	bsr			UpdateTextPos
	movec		coreno,d2
	cmp.b		IOFocus,d2
	bne.s		.0001
	rol.w		#8,d0						; swap byte order
	move.w	d0,TEXTREG+$24
.0001:	
	movem.l	(a7)+,d0/d2
	rts

;==============================================================================
; TRAP #15 handler
;
; Parameters:
;		d0.w = function number to perform
;==============================================================================

TRAP15:
	movem.l	d0/a0,-(a7)
	lea			T15DispatchTable,a0
	asl.l		#2,d0
	move.l	(a0,d0.w),a0
	jsr			(a0)
	movem.l	(a7)+,d0/a0
	rte

		align	2
T15DispatchTable:
	dc.l	DisplayStringLimitedCRLF
	dc.l	DisplayStringLimited
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	GetKey
	dc.l	DisplayChar
	dc.l	CheckForKey
	dc.l	StubRout
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
	dc.l	StubRout
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
	dc.l	rotate_iofocus
	dc.l	SerialPeekCharDirect
	dc.l	SerialPutChar
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout
	dc.l	StubRout

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
	move.l		d1,-(a7)
	cmpi.w		#$FF00,d1
	bne.s			.0002
	bsr				clear_screen
	bra				HomeCursor
.0002:
	cmp.b			TextRows,d1		; if cursor pos out of range, ignore setting
	bhs.s			.0003
	move.b		d1,CursorRow
.0003:
	ror.w			#8,d1
	cmp.b			TextCols,d1
	bhs.s			.0001
	move.b		d1,CursorCol
.0001:
	bsr				SyncCursor		; update hardware cursor
	move.l		(a7)+,d1
	rts

;------------------------------------------------------------------------------
; Stub routine for unimplemented functionality.
;------------------------------------------------------------------------------

StubRout:
	rts

;------------------------------------------------------------------------------
; Rotate the IO focus, done when ALT-Tab is pressed.
;
; Modifies:
;		d0, IOFocus BIOS variable
;------------------------------------------------------------------------------

rotate_iofocus:
	move.b	IOFocus,d0				; d0 = focus, we can trash d0
	add.b		#1,d0							; increment the focus
	cmp.b		#9,d0							; limit to 2 to 9
	bls.s		.0001
	move.b	#2,d0
.0001:
	move.b	d0,IOFocus				; set IO focus
	subi.b	#2,d0							; screen is 0 to 7, focus is 2 to 9
	ext.w		d0								; make into long value
	mulu		#2048,d0					; * 2048	cells per screen
	rol.w		#8,d0							; swap byte order
	move.w	d0,TEXTREG+$28		; update screen address in text controller
	bra			SyncCursor				; set cursor position

;==============================================================================
; PLIC - platform level interrupt controller
;
; Register layout:
;   bits 0 to 7  = cause code to issue
;   bits 8 to 11 = irq level to issue
;   bit 16 = irq enable
;   bit 17 = edge sensitivity
;		bit 24 to 29 target core
;
; Note byte order must be reversed for PLIC.
;==============================================================================

init_plic:
	lea		PLIC,a0						; a0 points to PLIC
	lea		$80+4*29(a0),a0		; point to timer registers (29)
	move.l	#$00060302,(a0)	; initialize, core=2,edge sensitive,enabled,irq6
	lea			4(a0),a0				; point to keyboard registers (30)
	move.l	#$00060102,(a0)	; initialize, core=2,level sensitive,enabled,irq6
	lea			4(a0),a0				; point to nmi button register (31)
	move.l	#$00070302,(a0)	; initialize, core=2,edge sensitive,enabled,irq7
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

_KeybdInit:
	clr.b	_KeyState1
	clr.b	_KeyState2
	rts

_KeybdGetStatus:
	moveq		#0,d1
	move.b	KEYBD+1,d1
	rts

; Get the scancode from the keyboard port

_KeybdGetScancode:
	moveq		#0,d1
	move.b	KEYBD,d1				* get the scan code
	move.b	#0,KEYBD+1			* clear receive register
	rts

; Recieve a byte from the keyboard, used after a command is sent to the
; keyboard in order to wait for a response.
;
KeybdRecvByte:
	move.l	d3,-(a7)
	move.w	#100,d3		; wait up to 1s
.0003:
	bsr		_KeybdGetStatus	; wait for response from keyboard
	tst.b	d1
	bmi		.0004		; is input buffer full ? yes, branch
	bsr		Wait10ms		; wait a bit
	dbra	d3,.0003	; go back and try again
	move.l	(a7)+,d3
	moveq	#-1,d1			; return -1
	rts
.0004:
	bsr		_KeybdGetScancode
	move.l	(a7)+,d3
	rts


; Wait until the keyboard transmit is complete
; Returns .CF = 1 if successful, .CF=0 timeout
;
KeybdWaitTx:
	movem.l	d2/d3,-(a7)
	moveq	#100,d3		; wait a max of 1s
.0001:
	bsr		_KeybdGetStatus
	btst	#6,d1		; check for transmit complete bit
	bne	    .0002		; branch if bit set
	bsr		Wait10ms		; delay a little bit
	dbra	d3,.0001	; go back and try again
	movem.l	(a7)+,d2/d3
	moveq	#-1,d1		; return -1
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
	tst.b		_KeybdCnt
	sne.b		d1
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
	cmp.b		d0,d1
	bne.s		.0004							; go return no key available, if not in focus
	bsr			KeybdGetCharNoWait	; get a character
	cmpi.b	#-1,d1						; was a key available?
	beq.s		.0004
	tst.b		KeybdEcho					; is keyboard echo on ?
	beq.s		.0003							; no echo, just return the key
	cmpi.b	#CR,d1						; convert CR keystroke into CRLF
	bne.s		.0005
	bsr			CRLF
	bra.s		.0003
.0005:
	bsr			DisplayChar
.0003:
	move.l	(a7)+,d0					; pop d0
	rts												; return key
; Return -1 indicating no char was available
.0004:
	move.l	(a7)+,d0					; pop d0
	moveq		#-1,d1						; return no key available
	rts

CheckForCtrlC:
	bsr			CheckForKey
	beq.s		.0001
	bsr			KeybdGetChar
	cmp.b		#CTRLC,d1
	beq			Monitor
.0001:
	rts

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

KeybdGetCharNoWait:
	clr.b	KeybdWaitFlag
	bra		KeybdGetChar

KeybdGetCharWait:
	move.b	#-1,KeybdWaitFlag

KeybdGetChar:
	movem.l	d2/d3/a0,-(a7)
.0003:
	moveq		#1,d1
;	bsr			LockSemaphore
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
	moveq		#1,d1
	bsr			UnlockSemaphore
	exg			d2,d1						; restore scancode value
	bra			.0001						; go process scan code
.0014:
	bsr		_KeybdGetStatus		; check keyboard status for key available
	bmi		.0006							; yes, go process
.0015:
	moveq	#1,d1
	bsr		UnlockSemaphore
	tst.b	KeybdWaitFlag			; are we willing to wait for a key ?
	bmi		.0003							; yes, branch back
	movem.l	(a7)+,d2/d3/a0
	moveq	#-1,d1						; flag no char available
	rts
.0006:
	bsr		_KeybdGetScancode
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
	movem.l	(a7)+,d2/d3/a0
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
	clr.b	KeybdLEDs
	btst	#4,_KeyState2
	beq.s	.0002
	move.b	#2,KeybdLEDs
.0002:
	btst	#5,_KeyState2
	beq.s	.0003
	bset	#2,KeybdLEDs
.0003:
	btst	#6,_KeyState2
	beq.s	.0004
	bset	#0,KeybdLEDs
.0004:
	move.b	#$ED,d1
	bsr		KeybdSendByte
	bsr		KeybdWaitTx
	bsr		KeybdRecvByte
	tst.b	d1
	bmi		.0001
	cmp		#$FA,d1
	move.b	KeybdLEDs,d1
	bsr		KeybdSendByte
	bsr		KeybdWaitTx
	bsr		KeybdRecvByte
.0001:
	movem.l	(a7)+,d2/d3
	rts

KeybdSendByte:
	move.b	d1,KEYBD
	rts
	
Wait10ms:
	move.l	d3,-(a7)
	move.l	#1000,d3
.0001:
	dbra	d3,.0001
	move.l	(a7)+,d3
	rts


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
;
; Get a word from screen memory and swap byte order

FromScreen:
	move.l	(a0),d1
	rol.w		#8,d1
	swap		d1
	rol.w		#8,d1
	lea			8(a0),a0	; increment screen pointer
	rts

StartMon:
	clr.w		NumSetBreakpoints
	bsr			ClearBreakpointList
Monitor:
	; Reset the stack pointer on each entry into the monitor
	move.l	#$40FFC,sp	; reset core's stack
	move.w	#$2500,sr		; enable level 6 and higher interrupts
	moveq		#1,d1
	bsr			UnlockSemaphore
	clr.b		KeybdEcho		; turn off keyboard echo
PromptLn:
	bsr			CRLF
	move.b	#'$',d1
	bsr			DisplayChar

; Get characters until a CR is keyed
;
Prompt3:
	bsr			GetKey
	cmpi.b	#-1,d1
	beq.s		Prompt3
	cmpi.b	#CR,d1
	beq.s		Prompt1
	bsr			DisplayChar
	bra.s		Prompt3

; Process the screen line that the CR was keyed on
;
Prompt1:
	clr.b		CursorCol			; go back to the start of the line
	bsr			CalcScreenLoc	; a0 = screen memory location
.0001:
	bsr			FromScreen		; grab character off screen
	cmpi.b	#'$',d1				; skip over '$' prompt character
	beq.s		.0001
	
; Dispatch based on command character
;
Prompt2:
	cmpi.b	#'a',d1
	beq			AudioInputTest
	cmpi.b	#'b',d1
	beq			BouncingBalls
	cmpi.b	#'g',d1
	beq			GraphicsDemo
	cmpi.b	#':',d1			; $: - edit memory
	beq			EditMem
	cmpi.b	#'D',d1			; $D - dump memory
	bne.s		.0003
	bsr			FromScreen
	cmpi.b	#'R',d1			; $DR - dump registers
	beq			DumpRegs
	lea			-8(a0),a0
	bra			DumpMem
.0003:
	cmpi.b	#'F',d1
	beq			FillMem
	cmpi.b	#'B',d1			; $B - start tiny basic
	bne.s	.0001
	bsr			FromScreen
	cmpi.b	#'R',d1
	bne.s		.0004
	bsr			ignBlanks
	bsr			FromScreen
	cmpi.b	#'+',d1
	beq			ArmBreakpoint
	cmpi.b	#'-',d1
	beq			DisarmBreakpoint
	cmpi.b	#'L',d1
	beq			ListBreakpoints
	bra			Monitor
.0004:
	jmp			$FFFCC000
.0001:
	cmpi.b	#'J',d1			; $J - execute code
	beq			ExecuteCode
	cmpi.b	#'L',d1			; $L - load S19 file
	beq			LoadS19
	cmpi.b	#'?',d1			; $? - display help
	beq			DisplayHelp
	cmpi.b	#'C',d1			; $C - clear screen
	beq			TestCLS
	cmpi.b	#'T',d1			; $T - run cpu test program
	bne.s		.0002
	bsr			cpu_test
	lea			msg_test_done,a1
	bsr			DisplayStringCRLF
.0002:
	bra			Monitor

TestCLS:
	bsr			FromScreen
	addq		#1,d2
	cmpi.b	#'L',d1
	bne			Monitor
	bsr			FromScreen
	addq		#1,d2
	cmpi.b	#'S',d1
	bne			Monitor
	bsr			ClearScreen
	bsr			HomeCursor
	bra			Monitor
	
DisplayHelp:
	lea			HelpMsg,a1
	bsr			DisplayString
	bra			Monitor

HelpMsg:
	dc.b	"? = Display help",CR,LF
	dc.b	"CLS = clear screen",CR,LF
	dc.b	": = Edit memory bytes",CR,LF
	dc.b	"F = Fill memory",CR,LF
	dc.b	"L = Load S19 file",CR,LF
	dc.b	"D = Dump memory",CR,LF
	dc.b	"B = start tiny basic",CR,LF
	dc.b  "BR = set breakpoint",CR,LF
	dc.b	"J = Jump to code",CR,LF
	dc.b	"T = cpu test program",CR,LF,0
	even

;------------------------------------------------------------------------------
; This routine borrowed from Gordo's Tiny Basic interpreter.
; Used to fetch a command line. (Not currently used).
;
; d0.b	- command prompt
;------------------------------------------------------------------------------

GetCmdLine:
		bsr		DisplayChar		; display prompt
		move.b	#' ',d0
		bsr		DisplayChar
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
		bsr		DisplayChar
		cmp.b	#CR,d0
		beq		.0007
		cmp.l	#CmdBufEnd-1,a0
		bcs.s	.0001
.0003:
		move.b	#CTRLH,d0
		bsr		DisplayChar
		move.b	#' ',d0
		bsr		DisplayChar
		cmp.l	#CmdBuf,a0
		bls.s	.0001
		move.b	#CTRLH,d0
		bsr		DisplayChar
		subq.l	#1,a0
		bra.s	.0001
.0004:
		move.l	a0,d1
		sub.l	#CmdBuf,d1
		beq.s	.0006
		subq	#1,d1
.0005:
		move.b	#CTRLH,d0
		bsr		DisplayChar
		move.b	#' ',d0
		bsr		DisplayChar
		move.b	#CTRLH,d0
		bsr		DisplayChar
		dbra	d1,.0005
.0006:
		lea		CmdBuf,a0
		bra		.0001
.0007:
		move.b	#LF,d0
		bsr		DisplayChar
		rts

		
;------------------------------------------------------------------------------
; Fill memory
; FB = fill bytes		FB 00000010 100 FF	; fill starting at 10 for 256 bytes
; FW = fill words
; FL = fill longs
; F = fill bytes
;------------------------------------------------------------------------------
;
FillMem:
	bsr			FromScreen
	;bsr		ScreenToAscii
	move.b	d1,d4			; d4 = fill size
	bsr			ignBlanks
	bsr			GetHexNumber
	move.l	d1,a1			; a1 = start
	bsr			ignBlanks
	bsr			GetHexNumber
	move.l	d1,d3			; d3 = count
	bsr			ignBlanks
	bsr			GetHexNumber	; fill value
	cmpi.b	#'L',d4
	bne			fmem1
fmemL:
	move.l	d1,(a1)+
	sub.l	#1,d3
	bne.s	fmemL
	bra		Monitor
fmem1
	cmpi.b	#'W',d4
	bne		fmemB
fmemW:
	move.w	d1,(a1)+
	sub.l	#1,d3
	bne.s	fmemW
	bra		Monitor
fmemB:
	move.b	d1,(a1)+
	sub.l	#1,d3
	bne.s	fmemB
	bra		Monitor

;------------------------------------------------------------------------------
; Modifies:
;	a0	- text pointer
;------------------------------------------------------------------------------
;
ignBlanks:
	move.l	d1,-(a7)
.0001:
	bsr			FromScreen
	cmpi.b	#' ',d1
	beq.s		.0001
	lea			-8(a0),a0
	move.l	(a7)+,d1
	rts

;------------------------------------------------------------------------------
; Edit memory byte.
;------------------------------------------------------------------------------
;
EditMem:
	bsr		ignBlanks
	bsr		GetHexNumber
	move.l	d1,a1
edtmem1:
	bsr		ignBlanks
	bsr		GetHexNumber
	move.b	d1,(a1)+
	bsr		ignBlanks
	bsr		GetHexNumber
	move.b	d1,(a1)+
	bsr		ignBlanks
	bsr		GetHexNumber
	move.b	d1,(a1)+
	bsr		ignBlanks
	bsr		GetHexNumber
	move.b	d1,(a1)+
	bsr		ignBlanks
	bsr		GetHexNumber
	move.b	d1,(a1)+
	bsr		ignBlanks
	bsr		GetHexNumber
	move.b	d1,(a1)+
	bsr		ignBlanks
	bsr		GetHexNumber
	move.b	d1,(a1)+
	bsr		ignBlanks
	bsr		GetHexNumber
	move.b	d1,(a1)+
	bra		Monitor

;------------------------------------------------------------------------------
; Execute code at the specified address.
;------------------------------------------------------------------------------

ExecuteCode:
	bsr			ignBlanks
	bsr			GetHexNumber
	move.l	d1,a0
	jsr			(a0)
	bra     Monitor

;------------------------------------------------------------------------------
; Do a memory dump of the requested location.
; D 0800 0850
;------------------------------------------------------------------------------

DumpMem:
	bsr			ignBlanks
	bsr			GetHexNumber
	beq			Monitor			; was there a number ? no, other garbage, just ignore
	move.l	d1,d3				; save off start of range
	bsr			ignBlanks
	bsr			GetHexNumber
	bne.s		DumpMem1
	move.l	d3,d1
	addi.l	#64,d1			; no end specified, just dump 64 bytes
DumpMem1:
	move.l	d3,a0
	move.l	d1,a1
	bsr			CRLF
.0001:
	cmpa.l	a0,a1
	bls			Monitor
	bsr			DisplayMem
	bra.s		.0001

;------------------------------------------------------------------------------
; Display memory dump in a format suitable for edit.
;
;	:12345678 00 11 22 33 44 55 66 77  "........"
;
; Modifies:
;		d1,d2,a0
;------------------------------------------------------------------------------

DisplayMem:
	move.b	#':',d1
	bsr			DisplayChar
	move.l	a0,d1
	bsr			DisplayTetra
	moveq		#7,d2
dspmem1:
	move.b	#' ',d1
	bsr			DisplayChar
	move.b	(a0)+,d1
	bsr			DisplayByte
	dbra		d2,dspmem1
	bsr			DisplayTwoSpaces
	move.b	#34,d1
	bsr			DisplayChar
	lea			-8(a0),a0
	moveq		#7,d2
.0002:	
	move.b	(a0)+,d1
	cmp.b		#' ',d1
	blo.s		.0003
	cmp.b		#127,d1
	bls.s		.0001
.0003:
	move.b	#'.',d1
.0001:
	bsr			DisplayChar
	dbra		d2,.0002
	move.b	#34,d1
	bsr			DisplayChar
	bsr			CheckForCtrlC
	bra			CRLF

;------------------------------------------------------------------------------
; Dump Registers
;    The dump is in a format that allows the register value to be edited.
;
; RegD0 12345678
; RegD1 77777777
;	... etc
;------------------------------------------------------------------------------

DumpRegs:
	bsr			CRLF
	move.w	#15,d0					; number of registers-1
	lea			msg_reglist,a0	;
	lea			msg_regs,a1
	lea			Regsave,a2			; a2 points to register save area
.0001:
	bsr			DisplayString
	move.b	(a0)+,d1
	bsr			DisplayChar
	move.b	(a0)+,d1
	bsr			DisplayChar
	bsr			DisplaySpace
	move.l	(a2)+,d1
	bsr			DisplayTetra
	bsr			CRLF
	dbra		d0,.0001
	bsr			DisplayString
	move.b	(a0)+,d1
	bsr			DisplayChar
	move.b	(a0)+,d1
	bsr			DisplayChar
	bsr			DisplaySpace
	move.l	Regsave+$44,d1
	bsr			DisplayTetra
	bsr			CRLF
	bsr			DisplayString
	move.b	(a0)+,d1
	bsr			DisplayChar
	move.b	(a0)+,d1
	bsr			DisplayChar
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
; Get a hexidecimal number. Maximum of eight digits.
;
; Returns:
;		d0 = number of digits
;		d1 = value of number
;		zf = number of digits == 0
;------------------------------------------------------------------------------

GetHexNumber:
	move.l	d2,-(a7)
	clr.l		d2
	moveq		#0,d0
.0002:
	bsr			FromScreen
	bsr			AsciiToHexNybble
	cmp.b		#$ff,d1
	beq.s		.0001
	lsl.l		#4,d2
	andi.l	#$0f,d1
	or.l		d1,d2
	addq		#1,d0
	cmpi.b	#8,d0
	blo.s		.0002
.0001:
	move.l	d2,d1
	move.l	(a7)+,d2
	tst.b		d0
	rts	

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
	bsr			DisplayChar
dspspc1:
	bsr			DisplayChar
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
	bsr			DisplayChar
	move.l	(a7)+,d1
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

;==============================================================================
; Load an S19 format file
;==============================================================================
;
LoadS19:
	bra			ProcessRec
NextRec:
	bsr			sGetChar
	cmpi.b	#LF,d0
	bne			NextRec
ProcessRec
	bsr			sGetChar
	move.b	d0,d4
	cmpi.b	#26,d4		; CTRL-Z ?
	beq			Monitor
	cmpi.b	#'S',d4
	bne			NextRec
	bsr			sGetChar
	move.b	d0,d4
	cmpi.b	#'0',d4
	blo			NextRec
	cmpi.b	#'9',d4		; d4 = record type
	bhi			NextRec
	bsr			sGetChar
	bsr			AsciiToHexNybble
	move.b	d1,d2
	bsr		sGetChar
	bsr		AsciiToHexNybble
	lsl.b	#4,d2
	or.b	d2,d1		; d1 = byte count
	move.b	d1,d3		; d3 = byte count
	cmpi.b	#'0',d4		; manufacturer ID record, ignore
	beq		NextRec
	cmpi.b	#'1',d4
	beq		ProcessS1
	cmpi.b	#'2',d4
	beq		ProcessS2
	cmpi.b	#'3',d4
	beq		ProcessS3
	cmpi.b	#'5',d4		; record count record, ignore
	beq		NextRec
	cmpi.b	#'7',d4
	beq		ProcessS7
	cmpi.b	#'8',d4
	beq		ProcessS8
	cmpi.b	#'9',d4
	beq		ProcessS9
	bra		NextRec

pcssxa
	andi.w	#$ff,d3
	subi.w	#1,d3			; one less for dbra
.0001
	clr.l		d2
	bsr			sGetChar
	bsr			AsciiToHexNybble
	lsl.l		#4,d2
	or.b		d1,d2
	bsr			sGetChar
	bsr			AsciiToHexNybble
	lsl.l		#4,d2
	or.b		d1,d2
	move.b	d2,(a1)+
	dbra		d3,.0001
; Get the checksum byte
	clr.l		d2
	bsr			sGetChar
	bsr			AsciiToHexNybble
	lsl.l		#4,d2
	or.b		d1,d2
	bsr			sGetChar
	bsr			AsciiToHexNybble
	lsl.l		#4,d2
	or.b		d1,d2
	bra			NextRec

ProcessS1:
	bsr			S19Get16BitAddress
	bra			pcssxa
ProcessS2:
	bsr			S19Get24BitAddress
	bra			pcssxa
ProcessS3:
	bsr			S19Get32BitAddress
	bra			pcssxa
ProcessS7:
	bsr			S19Get32BitAddress
	move.l	a1,S19StartAddress
	bra			Monitor
ProcessS8:
	bsr			S19Get24BitAddress
	move.l	a1,S19StartAddress
	bra			Monitor
ProcessS9:
	bsr			S19Get16BitAddress
	move.l	a1,S19StartAddress
	bra			Monitor

S19Get16BitAddress:
	clr.l		d2
	bsr			sGetChar
	bsr			AsciiToHexNybble
	move.b	d1,d2
	bra			S1932b

S19Get24BitAddress:
	clr.l	d2
	bsr		sGetChar
	bsr		AsciiToHexNybble
	move.b	d1,d2
	bra		S1932a

S19Get32BitAddress:
	clr.l	d2
	bsr			sGetChar
	bsr			AsciiToHexNybble
	move.b	d1,d2
	bsr			sGetChar
	bsr			AsciiToHexNybble
	lsl.l		#4,d2
	or.b		d1,d2
	bsr			sGetChar
	bsr			AsciiToHexNybble
	lsl.l		#4,d2
	or.b		d1,d2
S1932a:
	bsr			sGetChar
	bsr			AsciiToHexNybble
	lsl.l		#4,d2
	or.b		d1,d2
	bsr			sGetChar
	bsr			AsciiToHexNybble
	lsl.l		#4,d2
	or.b		d1,d2
S1932b:
	bsr			sGetChar
	bsr			AsciiToHexNybble
	lsl.l		#4,d2
	or.b		d1,d2
	bsr			sGetChar
	bsr			AsciiToHexNybble
	lsl.l		#4,d2
	or.b		d1,d2
	bsr			sGetChar
	bsr			AsciiToHexNybble
	lsl.l		#4,d2
	or.b		d1,d2
	clr.l		d4
	move.l	d2,a1
	rts

;------------------------------------------------------------------------------
; Get a character from auxillary input, checking the keyboard status for a
; CTRL-C
;------------------------------------------------------------------------------
;
sGetChar:
	bsr			CheckForKey
	beq			.0001
	moveq		#5,d0					; GetKey
	trap		#15
	cmpi.b	#CTRLC,d1
	beq			Monitor
.0001:
	moveq		#33,d0				; serial peek character direct
	trap		#15
	tst.l		d0
	bmi			sGetChar
	move.b	d0,d1
	rts

AudioInputTest:
	rts
BouncingBalls:
	rts
GraphicsDemo:
	rts
ClearScreen:
	bra		clear_screen
	rts

AUXIN:

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
;		d0 = character or -1
;------------------------------------------------------------------------------

SerialPeekCharDirect:
	move.l	ACIA+ACIA_STAT,d0	; get serial status
	rol.w		#8,d0							; swap byte order
	swap		d0
	rol.w		#8,d0
	btst		#3,d0							; look for Rx not empty
	beq.s		.0001
	moveq.l	#0,d0							; clear upper bits of return value
	move.b	ACIA+ACIA_RX,d0		; get data from ACIA
	rts												; restore SR and return
.0001:
	moveq		#-1,d0
	rts

bus_err:
.0001:
	nop
	bra			.0001

;------------------------------------------------------------------------------
; SerialPutChar
;    Put a character to the serial transmitter. This routine blocks until the
; transmitter is empty. 
;
; Stack Space
;		0 words
; Parameters:
;		d1.b = character to put
; Modifies:
;		none
;------------------------------------------------------------------------------

SerialPutChar:
	movem.l	d0/d1,-(a7)				; push d0,d1
.0001:
	move.l	ACIA+ACIA_STAT,d0	; wait until the uart indicates tx empty
	rol.w		#8,d0
	swap		d0
	rol.w		#8,d0
	btst		#4,d0							; bit #4 of the status reg
	beq.s		.0001			    		; branch if transmitter is not empty
	rol.w		#8,d1
	swap		d1
	rol.w		#8,d1
	move.l	d1,ACIA+ACIA_TX		; send the byte
	movem.l	(a7)+,d0/d1				; pop d0,d1
	rts
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

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
	bra				DumpRegs

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
	subi.w		#1,d2
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
;------------------------------------------------------------------------------

irq_rout:
	movem.l	d0/d1/a0,-(a7)
	moveq		#1,d1
;	bsr			LockSemaphore
	bsr			_KeybdGetStatus		; check if timer or keyboard
	bpl.s		.0001							; branch if not keyboard
	btst		#1,_KeyState2			; Is Alt down?
	beq.s		.0003
	move.b	KEYBD,d0					; get scan code
	cmpi.b	#SC_TAB,d0				; is Alt-Tab?
	bne.s		.0003
	bsr			_KeybdGetScancode	; grab the scan code (clears interrupt)
	bsr			rotate_iofocus
	clr.b		_KeybdHead				; clear keyboard buffer
	clr.b		_KeybdTail
	clr.b		_KeybdCnt
	bra			.0002							; do not store Alt-Tab
.0003:
	; Insert keyboard scan code into raw keyboard buffer
	bsr			_KeybdGetScancode	; grab the scan code (clears interrupt)
	cmpi.b	#32,_KeybdCnt			; see if keyboard buffer full
	bhs.s		.0002
	move.b	_KeybdTail,d0			; keyboard buffer not full, add to tail
	ext.w		d0
	lea			_KeybdBuf,a0			; a0 = pointer to buffer
	move.b	d1,(a0,d0.w)			; put scancode in buffer
	addi.b	#1,d0							; increment tail index
	andi.b	#31,d0						; wrap at buffer limit
	move.b	d0,_KeybdTail			; update tail index
	addi.b	#1,_KeybdCnt			; increment buffer count
	bra			.0002
.0001:
	move.l	#$1D000000,PLIC+$14	; reset edge sense circuit
	move.l	TextScr,a0				; a0 = screen address
	addi.l	#1,40(a0)					; update onscreen IRQ flag
.0002:	
	moveq		#1,d1
	bsr			UnlockSemaphore
	movem.l	(a7)+,d0/d1/a0		; return
	rte

nmi_rout:
	movem.l	d0/d1/a0,-(a7)
	move.b	#'N',d1
	bsr			DisplayChar
	movem.l	(a7)+,d0/d1/a0		; return
	rte

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
	bra			DumpRegs

illegal_trap:
	addq		#2,sp						; get rid of sr
	move.l	(sp)+,d1				; pop exception address
	bsr			DisplayTetra		; and display it
	lea			msg_illegal,a1	; followed by message
	bsr			DisplayString
.0001:
	bra			.0001
	bra			Monitor
	
; -----------------------------------------------------------------------------
; -----------------------------------------------------------------------------

msg_start:
	dc.b	"rf68k System Starting",CR,LF,0
msg_core_start:
	dc.b	" core starting",CR,LF,0
msg_illegal:
	dc.b	" illegal opcode",CR,LF,0
msg_bad_branch_disp:
	dc.b	" branch selfref: ",0
msg_test_done:
	dc.b	" CPU test done.",0



