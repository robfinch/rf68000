; ============================================================================
;        __
;   \\__/ o\    (C) 2025  Robert Finch, Waterloo
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
; Handle:
;		d7.low word = tv_unit (screen number)
;		d7.high word = device #
; ============================================================================

	include "..\Femtiki\source\inc\const.x68"
	include "..\Femtiki\source\inc\config.x68"
	include "..\Femtiki\source\inc\device.x68"

	extrn Delay3s

TEXTREG_CURSOR_POS	equ $24

	section local_ram
tv_inuse
	ds.w	1
	align 2
tv_screen1	equ	*
tv_dimen_x equ *-tv_screen1
	ds.w	1
tv_dimen_y equ *-tv_screen1
	ds.w	1
tv_fg_color equ *-tv_screen1
	ds.l	1
tv_bk_color equ *-tv_screen1
	ds.l	1
tv_bufptr equ *-tv_screen1
	ds.l	1
tv_bufsize equ *-tv_screen1
	ds.l	1
tv_outpos_x equ *-tv_screen1
	ds.w	1
tv_outpos_y equ *-tv_screen1
	ds.w	1
tv_inpos_x equ *-tv_screen1
	ds.w	1
tv_inpos_y equ *-tv_screen1
	ds.w	1
tv_unit equ *-tv_screen1
	ds.b	1

	rept 8
	ds.b	32
	endr

	code
	even
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; Setup the text video device
; stdout = text screen controller
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

TBLE macro arg1
	dc.w (\1-TEXTVID_CMDTBL)
endm

	code
	even

	align 2
TEXTVID_CMDTBL:
	TBLE textvid_stub					; 0 NOP
	TBLE textvid_setup				; 1
	TBLE textvid_init					; 2
	TBLE textvid_stat					; 3
	TBLE textvid_stub					; 4 media check
	TBLE textvid_stub					; 5 reserved
	TBLE textvid_open					; 6 open
	TBLE textvid_close				; 7 close
	TBLE textvid_getchar			; 8 get char
	TBLE textvid_stub					; 9 peek char
	TBLE textvid_stub					; 10 get char direct
	TBLE textvid_stub					; 11 peek char direct
	TBLE textvid_stub					; 12 input status
	TBLE textvid_putchar			; 13 putchar
	TBLE textvid_stub					; 14 reserved
	TBLE textvid_stub					; 15 set position
	TBLE textvid_getbuf			  ; 16 read block
	TBLE textvid_putbuf				; 17 write block
	TBLE textvid_stub					; 18 verify block
	TBLE textvid_stub					; 19 output status
	TBLE textvid_stub					; 20 flush input
	TBLE textvid_stub					; 21 flush output
	TBLE textvid_stub					; 22 IRQ
	TBLE textvid_is_removeable	; 23 is removeable
	TBLE textvid_stub					; 24 IOCTRL read
	TBLE textvid_stub					; 25 IOCTRL write
	TBLE textvid_stub					; 26 output until busy
	TBLE textvid_stub					; 27 shutdown
	TBLE textvid_clear				; 28 clear
	TBLE textvid_stub					; 29 swap buf
	TBLE textvid_stub					; 30 setbuf 1
	TBLE textvid_stub					; 31 setbuf 2
	TBLE textvid_getbuf1			; 32 getbuf 1
	TBLE textvid_stub					; 33 getbuf 2
	TBLE textvid_get_dimen		; 34 get dimensions
	TBLE textvid_get_color		; 35 get color
	TBLE textvid_stub					; 36 get position
	TBLE textvid_stub					; 37 set color
	TBLE textvid_stub					; 38 set color 123
	TBLE textvid_stub					; 39 reserved
	TBLE textvid_stub					; 40 plot point
	TBLE textvid_stub					; 41 draw line
	TBLE textvid_stub					; 42 draw triangle
	TBLE textvid_stub					; 43 draw rectangle
	TBLE textvid_stub					; 44 draw curve
	TBLE textvid_stub					; 45 set dimensions
	TBLE textvid_stub					; 46 set color depth
	TBLE textvid_stub					; 47 set destination buffer
	TBLE textvid_stub					; 48 set display buffer
	TBLE textvid_get_inpos	  ; 49 get input position
	TBLE textvid_set_inpos		; 50 set input position
	TBLE textvid_set_outpos		; 51 set output position
	TBLE textvid_get_outpos		; 52 get output position
	TBLE textvid_get_inptr		; 53 get input pointer
	TBLE textvid_get_outptr		; 54 get output pointer

	code
	even
_textvid_cmdproc:
textvid_cmdproc:
	cmpi.b #55,d6
	bhs.s .0001
	movem.l d6/d7/a0/a3,-(a7)
	ext.w d6
	ext.l d6
	lsl.w #1,d6
	lea TEXTVID_CMDTBL(pc),a0
	move.w (a0,d6.w),d6
	ext.l d6
	add.l d6,a0
	and.l #7,d7
	lsl.l #5,d7											; size of variable set (32 bytes)
	lea tv_screen1,a3
	add.l d7,a3
	jsr (a0)
	movem.l (a7)+,d6/d7/a0/a3
	rts
.0001:
	moveq #E_NotSupported,d0
	rts
	global _textvid_cmdproc

	align 2
setup_textvid:
_setup_textvid:
textvid_setup:
	movem.l d0/a0/a1,-(a7)
	move.l d0,a0
	move.l d0,a1
	moveq #15,d0
.0001:
	clr.l (a1)+
	dbra d0,.0001
	move.l #$44434220,DCB_MAGIC(a0)				; 'DCB '
	move.l #$54455854,DCB_NAME(a0)				; 'TEXTVID'
	move.l #$56494400,DCB_NAME+4(a0)			;
	move.l #textvid_cmdproc,DCB_CMDPROC(a0)
	clr.w tv_inuse
	lea tv_screen1,a3
	bsr textvid_init
	jsr Delay3s
	bsr textvid_clear
	moveq #13,d0
	lea.l DCB_MAGIC(a0),a1
	trap #15
	movem.l (a7)+,d0/a0/a1
	rts
	global _setup_textvid

	align 2
textvid_init:
	move.l d0,-(a7)
	if (SCREEN_FORMAT==1)
		move.l #$0000ff,tv_fg_color(a3)
		move.l #$000002,tv_bk_color(a3)		; medium blue
	else
		move.l #$1fffff,tv_fg_color(a3)		; set foreground / background color (white)
		move.l #$00003f,tv_bk_color(a3)		; medium blue
	endif
	movec.l	coreno,d0					; get core number (2 to 9)
	subi.b #2,d0							; adjust (0 to 7)
	if (SCREEN_FORMAT==1)
		mulu #TEXTROW*TEXTCOL*4,d0	; compute screen location
	else
		mulu #TEXTROW*TEXTCOL*8,d0	; compute screen location
	endif
	if HAS_MMU
		addi.l #$01E00000,d0
	else
		addi.l #$FD000000,d0
	endif
	move.l d0,tv_bufptr(a3)
;	move.l d0,TextScr
	if (SCREEN_FORMAT==1)
		move.l #TEXTROW*TEXTCOL*4,tv_bufsize(a3)
	else
		move.l #TEXTROW*TEXTCOL*8,tv_bufsize(a3)
	endif
	move.w #TEXTCOL,tv_dimen_x(a3)			; set rows and columns
	move.w #TEXTROW,tv_dimen_y(a3)
;	move.b #TEXTCOL,TextCols				; set rows and columns
;	move.b #TEXTROW,TextRows
	clr.w tv_inpos_x(a3)
	clr.w tv_inpos_y(a3)
	clr.w tv_outpos_x(a3)
	clr.w tv_outpos_y(a3)
	move.l (a7)+,d0
	rts

	align 2
textvid_stat:
	moveq #E_Ok,d0
	rts

	align 2
textvid_is_removeable:
	moveq #0,d1
	moveq #E_Ok,d0
	rts

	align 2
textvid_getchar:
	movem.l d2/a0,-(sp)
	move.w tv_bufptr(a3),a0
	move.w tv_inpos_x(a3),d0
	move.w tv_inpos_y(a3),d1
	move.w tv_dimen_x(a3),d2
	mulu d1,d2
	ext.l d0
	add.l d0,d2
	if (SCREEN_FORMAT==1)
		lsl.l #2,d2
		move.l (a0,d2.l),d1
	else
		lsl.l #3,d2
		move.l 4(a0,d2.l),d1
	endif
	rol.w #8,d1			; swap byte order
	swap d1
	rol.w #8,d1
	andi.l #$0FF,d1
	bsr IncInputPos
	movem.l (sp)+,d2/a0
	moveq #E_Ok,d0
	rts

	align 2
textvid_stub:
	moveq #E_NotSupported,d0
	rts

	align 2
textvid_get_inpos:
	clr.l d1
	clr.l d2
	move.w tv_inpos_x(a3),d1
	move.w tv_inpos_y(a3),d2
	clr.l d3
	move.l #E_Ok,d0
	rts

	align 2
textvid_set_inpos:
	move.w d1,tv_inpos_x(a3)
	move.w d2,tv_inpos_y(a3)
	move.l #E_Ok,d0
	rts

	align 2
textvid_set_outpos:
	move.w d1,tv_outpos_x(a3)
	move.w d2,tv_outpos_y(a3)
	bsr SyncCursor
	move.l #E_Ok,d0
	rts

	align 2
textvid_get_outpos:
	clr.l d1
	clr.l d2
	move.w tv_outpos_x(a3),d1
	move.w tv_outpos_y(a3),d2
	clr.l d3
	move.l #E_Ok,d0
	rts

	align 2
textvid_get_outptr:
	move.l d2,-(a7)
	move.w tv_outpos_x(a3),d1
	move.w tv_outpos_y(a3),d0
	move.w tv_dimen_x(a3),d2
	mulu d2,d0
	ext.l d1
	add.l d0,d1
	if (SCREEN_FORMAT==1)
		lsl.l #2,d1
	else
		lsl.l #3,d1
	endif
	add.l tv_bufptr(a3),d1
	move.l (a7)+,d2
	move.l #E_Ok,d0
	rts

	align 2
textvid_get_inptr:
	move.l d2,-(a7)
	move.w tv_inpos_x(a3),d1
	move.w tv_inpos_y(a3),d0
	move.w tv_dimen_x(a3),d2
	mulu d2,d0
	ext.l d1
	add.l d0,d1
	if (SCREEN_FORMAT==1)
		lsl.l #2,d1
	else
		lsl.l #3,d1
	endif
	add.l tv_bufptr(a3),d1
	move.l (a7)+,d2
	move.l #E_Ok,d0
	rts

	align 2
textvid_get_color:
	move.l tv_fg_color(a3),d1
	move.l tv_bk_color(a3),d2
	move.l #E_Ok,d0
	rts

	align 2
textvid_getbuf1:
	move.l tv_bufptr(a3),d1
	move.l tv_bufsize(a3),d2
	move.l #E_Ok,d0
	rts

	align 2
textvid_set_unit:
	move.b d1,tv_unit
	move.l #E_Ok,d0
	rts

	align 2
textvid_get_dimen:
	cmpi.b #0,d0
	bne.s .0001
	clr.l d1
	clr.l d2
	move.w tv_dimen_x(a3),d1
	move.w tv_dimen_y(a3),d2
	clr.l d3
	move.l #E_Ok,d0
	rts
.0001:
	clr.l d1
	clr.l d2
	move.w tv_dimen_x(a3),d1
	move.w tv_dimen_y(a3),d2
	clr.l d3
	move.l #E_Ok,d0
	rts

; Returns:
;		d1 = tv_unit number
;		d0 = E_Ok if available, otherwise E_NoDev

textvid_open:
	moveq #0,d1
	move.w tv_inuse,d0
.0002
	bset.l d1,d0
	beq.s .0001
	addq.l #1,d1
	cmpi.b #8,d1
	blo.s .0002
	moveq #E_NoDev,d0
	rts
.0001
	move.w d0,tv_inuse
	move.l #E_Ok,d0
	rts

textvid_close:
	move.w tv_inuse,d0
	bclr d1,d0
	move.w d0,tv_inuse
	move.l #E_Ok,d0
	rts

; -----------------------------------------------------------------------------
; -----------------------------------------------------------------------------

	align 2
textvid_clear:
;	move.l #$FFFFFFFF,leds
	movem.l	d1/d2/d3/d4/a0,-(a7)
	movec	coreno,d0
	swap d0	
;	moveq		#SCREEN_SEMA,d1
;	bsr			LockSemaphore
	move.l tv_bufptr(a3),d1
	move.l tv_bufsize(a3),d2
	move.l #$FEFEFEFE,leds
	move.l d1,a0								; a0 = pointer to screen area
	move.l d2,d4
	if (SCREEN_FORMAT==1)
		lsr.l #2,d4									; number of cells to clear
	else
		lsr.l #3,d4									; number of cells to clear
	endif
	move.l tv_fg_color(a3),d1
	move.l tv_bk_color(a3),d2
	move.l #$FDFDFDFD,leds
;	bsr	get_screen_color				; get the color bits
	if (SCREEN_FORMAT==1)
		ext.l d1
		lsl.l #8,d1
		ext.l d2									; clear high order bits
		or.l d1,d2								; forground color in bits 24 to 31
		swap d2										; color in bits 16 to 23
		ori.w #32,d2							; insert character to display (space)
		rol.w #8,d2								; reverse byte order
		swap d2
		rol.w #8,d2
loop3:
		move.l d2,(a0)+						; copy to cell
	else
		lsl.l #5,d1								; high order background color bits go in bits 0 to 4
		move.l d2,d3
		swap d3
		andi.l #$1f,d3
		or.l d3,d1
		; we want bkcolor in bits 16 to 32
		; char in bits 0 to 15
		swap d2										; color in bits 16 to 32
		move.w #32,d2							; load space character
		rol.w	#8,d2								; swap endian, text controller expects little endian
		swap d2
		rol.w	#8,d2
		rol.w	#8,d0								; swap endian
		swap d0
		rol.w	#8,d0
loop3:
		move.l d2,(a0)+						; copy char plus bkcolor to cell
		move.l d1,(a0)+						; copy fgcolor to cell
	endif
	dbra d4,loop3
	movec coreno,d0
	swap d0	
;	moveq #SCREEN_SEMA,d1
;	bsr UnlockSemaphore
	move.l #$FCFCFCFC,leds
	movem.l (a7)+,d1/d2/d3/d4/a0
	move.l #E_Ok,d0
	rts

; -----------------------------------------------------------------------------
; Gets the screen color in d0 and d1. Setup already to be able to insert
; character code.
; -----------------------------------------------------------------------------

	align 2
get_screen_color:
	move.l d2,-(a7)
	move.l tv_fg_color(a3),d1
	move.l tv_bk_color(a3),d2
	if (SCREEN_FORMAT==1)
		lsl.l #8,d1							; foreground color in bits 8 to 15
		andi.w #$ff,d2
		or.w d2,d1							; background color in bits 0 to 7
		swap d1									; foreground color in bits 24 to 31, bk in 16 to 23
		move.w #0,d1						; clear character
		move.l d1,d0
	else
		asl.l	#5,d1							; shift into position
		ori.l	#$40000000,d1			; set priority
		move.l d2,d0
		lsr.l	#8,d2
		lsr.l	#8,d2
		andi.l #31,d2						; mask off extra bits
		or.l d2,d1							; set background color bits in upper long word
		asl.l	#8,d0							; shift into position for display ram
		asl.l	#8,d0
	endif
	move.l (a7)+,d2
	rts

;------------------------------------------------------------------------------
; Calculate screen memory location from CursorRow,CursorCol.
; Destroys d0,d2,a0
;------------------------------------------------------------------------------

	align 2
CalcScreenLoc:
	movem.l d0/d1/d5,-(a7)
	move.w tv_outpos_x(a3),d0
	move.w tv_outpos_y(a3),d5
	move.w tv_dimen_x(a3),d1
	mulu d1,d5							; y * num cols
	ext.l d5
	add.l d5,d0							; plus x
	if (SCREEN_FORMAT==1)
		asl.l #2,d0							; 4 bytes per char
	else
		asl.l	#3,d0							; 8 bytes per char
	endif
	move.l tv_bufptr(a3),a0
	add.l	d0,a0								; a0 = screen location
	movem.l (a7)+,d0/d1/d5
	rts

;------------------------------------------------------------------------------
; This function will get any number of characters from the text display.
; The text position will increment as characters are fetched.
;
;	Parameters:
;		d1 = pointer to buffer
;		d2 = count
; Returns:
;		d0 = E_Ok
;		d1 = count
;------------------------------------------------------------------------------

	align 2
textvid_getbuf:
	tst.l d2
	beq.s .0002
	movem.l d3/a0,-(sp)
	move.l d2,d3
	moveq #1,d0
	movec d0,dfc
.0001
	bsr textvid_getchar
	moves.b d1,(a0)+
	dbra d2,.0001
	move.l d3,d1
	move.l d3,d2
	movem.l (sp)+,d3/a0
	moveq #E_Ok,d0
	rts
.0002
	moveq #0,d1
	moveq #E_Ok,d0
	rts

;------------------------------------------------------------------------------
; This function will put any number of characters to the text display. If
; needed the screen scrolls. The text position will increment as characters
; are displayed.
;
;	Parameters:
;		d1 = pointer to buffer
;		d2 = count
; Returns:
;		d0 = E_Ok
;		d1 = count
;------------------------------------------------------------------------------

	align 2
textvid_putbuf:
	tst.l d2
	beq.s .0002
	movem.l d3/a0,-(sp)
	move.l d2,d3
	moveq #1,d0
	movec d0,sfc
.0001
	moves.b (a0)+,d1
	bsr textvid_putchar
	dbra d2,.0001
	move.l d3,d1
	move.l d3,d2
	movem.l (sp)+,d3/a0
	moveq #E_Ok,d0
	rts
.0002
	moveq #0,d1
	moveq #E_Ok,d0
	rts

;------------------------------------------------------------------------------
; Display a single character on the screen
;
; Parameters:
; 	d1.b = char to display
;------------------------------------------------------------------------------

	align 2
textvid_putchar:
	movem.l	d1/d2/d3,-(a7)
	movec	coreno,d2
	cmpi.l #2,d2
	move.b d2,leds
;	bne.s		.0001
;	bsr			SerialPutChar
.0001:
	andi.l #$ff,d1				; zero out upper bytes of d1
	cmpi.b #13,d1				; carriage return ?
	bne.s	dccr
	clr.w	tv_outpos_x(a3)		; just set cursor column to zero on a CR
dcx14:
	bsr	SyncCursor				; set position in text controller
dcx7:
	movem.l	(a7)+,d1/d2/d3
	moveq #E_Ok,d0
	rts
dccr:
	cmpi.b #$91,d1			; cursor right ?
	bne.s dcx6
	move.w tv_dimen_x(a3),d2
	subq.w #1,d2
	sub.w	tv_outpos_x(a3),d2
	beq.s	dcx7
	addq.w #1,tv_outpos_x(a3)
	bra.s dcx14
dcx6:
	cmpi.b #$90,d1			; cursor up ?
	bne.s	dcx8
	tst.w tv_outpos_y(a3)
	beq.s	dcx7
	subq.w #1,tv_outpos_y(a3)
	bra.s	dcx14
dcx8:
	cmpi.b #$93,d1			; cursor left?
	bne.s	dcx9
	tst.w tv_outpos_x(a3)
	beq.s	dcx7
	subq.w #1,tv_outpos_x(a3)
	bra.s	dcx14
dcx9:
	cmpi.b #$92,d1			; cursor down ?
	bne.s	dcx10
	move.w tv_dimen_y(a3),d2
	subq.w #1,d2
	cmp.w	tv_outpos_y(a3),d2
	beq.s	dcx7
	addq.w #1,tv_outpos_y(a3)
	bra.s	dcx14
dcx10:
	cmpi.b #$94,d1			; cursor home ?
	bne.s	dcx11
	tst.w	tv_outpos_x(a3)
	beq.s	dcx12
	clr.w	tv_outpos_x(a3)
	bra	dcx14
dcx12:
	clr.w	tv_outpos_y(a3)
	bra	dcx14
dcx11:
	movem.l	a0,-(a7)
	cmpi.b #$99,d1				; delete ?
	beq.s	doDelete
	cmpi.b #CTRLH,d1			; backspace ?
	beq.s doBackspace
	cmpi.b #CTRLX,d1			; delete line ?
	beq	doCtrlX
	cmpi.b #10,d1					; linefeed ?
	beq.s dclf

	; regular char
	move.l #$FFFFFFFF,leds
	bsr	CalcScreenLoc			; a0 = screen location
	move.l #$FFFFFFFE,leds
	move.l d1,d2					; d2 = char
	bsr get_screen_color	; d0,d1 = color
	or.l d2,d0						; d0 = char + color
	rol.w	#8,d0						; swap bytes - text controller expects little endian data
	swap d0								; swap halfs
	rol.w	#8,d0						; swap remaining bytes
	if (SCREEN_FORMAT==1)
		move.l d0,(a0)+
	else
		move.l d0,(a0)+
		rol.w	#8,d1					; swap bytes
		swap d1							; swap halfs
		rol.w	#8,d1					; swap remaining bytes
		move.l d1,(a0)
	endif
	bsr	IncCursorPos
	bra	dcx16
dclf:
	bsr IncCursorRow
dcx16:
	bsr	SyncCursor
dcx4:
	movem.l	(a7)+,a0			; get back a0
	movem.l	(a7)+,d1/d2/d3
	moveq #E_Ok,d0
	rts

	;---------------------------
	; CTRL-H: backspace
	;---------------------------
doBackspace:
	tst.w	tv_outpos_x(a3)				; if already at start of line
	beq.s dcx4						; nothing to do
	subq.w #1,tv_outpos_x(a3)		; decrement column

	;---------------------------
	; Delete key
	;---------------------------
doDelete:
	movem.l	d0/d1/a0,-(a7)	; save off screen location
	bsr	CalcScreenLoc				; a0 = screen location
	move.w tv_outpos_x(a3),d0
.0001:
	if (SCREEN_FORMAT==1)
		move.l 4(a0),(a0)				; pull remaining characters on line over 1
		adda.l #4,a0
	else
		move.l 8(a0),(a0)				; pull remaining characters on line over 1
		move.l 12(a0),4(a0)
		adda.l #8,a0
	endif
	addq.w #1,d0
	cmp.w	tv_dimen_x(a3),d0
	blo.s	.0001
	bsr	get_screen_color
	if (SCREEN_FORMAT==1)
		move.w #' ',d0
		rol.w	#8,d0
		swap d0
		rol.w	#8,d0
		move.l d0,-4(a0)
	else
		move.w #' ',d0					; terminate line with a space
		rol.w	#8,d0
		swap d0
		rol.w	#8,d0
		move.l d0,-8(a0)
	endif
	movem.l	(a7)+,d0/d1/a0
	bra.s		dcx16				; finished

	;---------------------------
	; CTRL-X: erase line
	;---------------------------
doCtrlX:
	clr.w	tv_outpos_x(a3)			; Reset cursor to start of line
	move.w tv_dimen_x(a3),d0	; and display TextCols number of spaces
	ext.w	d0
	ext.l	d0
	move.b #' ',d1			; d1 = space char
.0001:
	; textvid_putchar is called recursively here
	; It's safe to do because we know it won't recurse again due to the
	; fact we know the character being displayed is a space char
	bsr	textvid_putchar
	subq #1,d0
	bne.s	.0001
	clr.w	tv_outpos_x(a3)			; now really go back to start of line
	bra	dcx16						; we're done

;------------------------------------------------------------------------------
; Increment the cursor position, scroll the screen if needed.
;------------------------------------------------------------------------------

IncCursorPos:
	addq.w #1,tv_outpos_x(a3)
	move.w tv_dimen_x(a3),d0
	cmp.w	tv_outpos_x(a3),d0
	bhs.s	icc1
	clr.w tv_outpos_x(a3)
IncCursorRow:
	addq.w #1,tv_outpos_y(a3)
	move.w tv_dimen_y(a3),d0
	cmp.w tv_outpos_y(a3),d0
	bhi.s	icc1
	move.w tv_dimen_y(a3),d0
	move.w d0,tv_outpos_y(a3)		; in case CursorRow is way over
	subq.w #1,tv_outpos_y(a3)
	bsr	ScrollUp
	bsr SyncCursor
icc1
	rts

IncInputPos:
	move.l d0,-(sp)
	addq.w #1,tv_inpos_x(a3)
	move.w tv_dimen_x(a3),d0
	cmp.w	tv_inpos_x(a3),d0
	bhs.s	icc2
	clr.w tv_inpos_x(a3)
IncInputRow:
	addq.w #1,tv_inpos_y(a3)
	move.w tv_dimen_y(a3),d0
	cmp.w tv_inpos_y(a3),d0
	bhi.s	icc2
	move.w tv_dimen_y(a3),d0
	move.w d0,tv_inpos_y(a3)		; in case CursorRow is way over
	subq.w #1,tv_inpos_y(a3)
icc2
	move.l (sp)+,d0
	rts

;------------------------------------------------------------------------------
; Scroll screen up.
;------------------------------------------------------------------------------

	align 2
ScrollUp:
	movem.l	d0/d1/a0/a5,-(a7)		; save off some regs
	movec	coreno,d0
	swap d0	
	moveq	#SCREEN_SEMA,d1
;	bsr	LockSemaphore
	move.l tv_bufptr(a3),a0
	move.l a0,a5								; a5 = pointer to text screen
.0003:								
	move.w tv_dimen_x(a3),d0					; d0 = columns
	move.w tv_dimen_y(a3),d1					; d1 = rows
	ext.l d0
	if (SCREEN_FORMAT==1)
		asl.l	#2,d0								; make into cell index
	else
		asl.l	#3,d0								; make into cell index
	endif
	lea	0(a5,d0.l),a0						; a0 = pointer to second row of text screen
	if (SCREEN_FORMAT==1)
		lsr.l	#2,d0								; get back d0
	else
		lsr.l	#3,d0								; get back d0
	endif
	subq.w #1,d1									; number of rows-1
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
;	bsr UnlockSemaphore
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
;	bsr	LockSemaphore
	move.l tv_bufptr(a3),a0
	move.w tv_dimen_x(a3),d0					; d0 = columns
	move.w tv_dimen_y(a3),d1					; d1 = rows
	subq.w #1,d1									; last row = #rows-1
	mulu d1,d0									; d0 = index of last line
	if (SCREEN_FORMAT==1)
		lsl.l	#2,d0								; *4 bytes per char
	else
		lsl.l	#3,d0								; *8 bytes per char
	endif
	lea	(a0,d0.l),a0						; point a0 to last row
	move.w tv_dimen_x(a3),d2					; number of text cells to clear
	subq.w #1,d2								; count must be one less than desired
	bsr	get_screen_color				; d0,d1 = screen color
	if (SCREEN_FORMAT==1)
		move.w #32,d0
	else
		move.w #32,d0								; set the character for display in low 16 bits
	endif
	rol.w	#8,d0
	swap d0
	rol.w	#8,d0
.0001:
	if (SCREEN_FORMAT==1)
		move.l d0,(a0)+
	else
		move.l d0,(a0)+
		bsr rbo
		move.l d1,(a0)+
	endif
	dbra d2,.0001
	movec	coreno,d0
	swap d0	
	moveq #SCREEN_SEMA,d1
;	bsr UnlockSemaphore
	movem.l	(a7)+,d0/d1/d2/a0
	rts

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

	align 2
HomeCursor:
	clr.w tv_outpos_x(a3)
	clr.w tv_outpos_y(a3)
	bra SyncCursor
	global HomeCursor

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

	align 2
SyncCursor:
	movem.l	d0/d1/d2,-(a7)
	movec.l	coreno,d0
	cmp.l	IOFocus,d0
;	cmp.l #2,d0
	bne.s .0001
	move.w tv_outpos_x(a3),d0
	move.w tv_outpos_y(a3),d1
	move.w tv_dimen_x(a3),d2
	mulu d1,d2
	ext.l d0
	add.l d0,d2
	rol.w	#8,d2					; swap byte order
	swap d2
	rol.w #8,d2
	move.l d2,TEXTREG+TEXTREG_CURSOR_POS
.0001:	
	movem.l	(a7)+,d0/d1/d2
	rts
	global SyncCursor
	
