	include "inc\const.x68"
	include "inc\device.x68"
	bss
_InputDevice:
	ds.b 1
_OutputDevice:
	ds.b 1
_FpStrBuf:
	ds.b	60

;==============================================================================
; Output a character to the current output device.
;
; Parameters:
;		d1.b	 character to output
; Returns:
;		none
;==============================================================================
	code
	even
_OutputChar:
OutputChar:
	movem.l d0/d1/d6/d7,-(a7)
	move.l 20(sp),d1
	clr.l d7
	clr.l d6
	move.b _OutputDevice,d7		; d7 = output device
	move.w #DEV_PUTCHAR,d6		; d6 = function
	trap #0
	movem.l (a7)+,d0/d1/d6/d7
	rts

_OutputCRLF:
	move.l #13,-(sp)
	bsr _OutputChar
	move.l #10,-(sp)
	bsr _OutputChar
	add.w #8,sp
	rts

;------------------------------------------------------------------------------
; Display the 32 bit word in D1.L
;------------------------------------------------------------------------------

_OutputTetra:
	move.l d1,-(a7)
	move.l 8(sp),d1
	swap d1
	move.l d1,-(a7)
	bsr	_OutputWyde
	swap d1
	move.l d1,-(a7)
	bsr	_OutputWyde
	add.w #8,sp
	move.l (a7)+,d1
	rts

;------------------------------------------------------------------------------
; Display the byte in D1.W
;------------------------------------------------------------------------------

_OutputWyde:
	move.l d1,-(a7)
	move.l 8(sp),d1
	ror.w	#8,d1
	move.l d1,-(a7)
	bsr	_OutputByte
	rol.w	#8,d1
	move.l d1,-(a7)
	bsr _OutputByte
	add.w #8,sp
	move.l (a7)+,d1
	rts

;------------------------------------------------------------------------------
; Display the byte in D1.B
;------------------------------------------------------------------------------

_OutputByte:
	move.l d1,-(a7)
	move.l 8(sp),d1
	ror.b	#4,d1
	move.l d1,-(a7)
	bsr	_OutputNybble
	rol.b	#4,d1
	move.l d1,-(a7)
	bsr _OutputNybble
	add.w #8,sp
	move.l (a7)+,d1
	rts

;------------------------------------------------------------------------------
; Display nybble in D1.B
;------------------------------------------------------------------------------

_OutputNybble:
	move.l d1,-(a7)
	move.l 8(sp),d1
	andi.b #$F,d1
	addi.b #'0',d1
	cmpi.b #'9',d1
	bls.s	.0001
	addi.b #7,d1
.0001:
	move.l d1,-(sp)
	bsr	_OutputChar
	add.w #4,sp
	move.l	(a7)+,d1
	rts

; Returns:
;		fp0 = float

_CvtStringToDecflt:
	movem.l d0/d1/a1,-(sp)
	move.l 16(sp),a1				; a1 = pointer to buffer
	moveq #41,d0						; function #41, get float
	moveq #1,d1							; d1 = input stride
	trap #15								; call BIOS get float function
	movem.l (sp)+,d0/d1/a1
	rts

_OutputFloat:
	movem.l d0/d1/d2/d3/a1,-(sp)
	fmove.d 24(sp),fp0
	lea _FpStrBuf,a1
	moveq #40,d1
	moveq #30,d2
	moveq #'e',d3
	moveq #39,d0
	trap #15
	movem.l (sp)+,d0/d1/d2/d3/a1
	rts

_OutputNumber:
	move.l 4(sp),d1
	move.l 8(sp),d2
	moveq #3,d0
	trap #15
	rts
	
_GetChar:
.0001
	moveq #5,d0
	trap #15
	cmpi.w #-1,d0
	beq .0001
	rts

_get_char:
	movem.l d1/d6/d7,-(sp)
	move.l 16(sp),d7
	moveq #DEV_GETCHAR,d6
	trap #0
	move.l d1,d0
	movem.l (sp)+,d1/d6/d7
	rts

_put_char:
	movem.l d0/d1/d6/d7,-(sp)
	move.l 20(sp),d7
	move.l 24(sp),d1
	moveq #DEV_PUTCHAR,d6
	trap #0
	movem.l (sp)+,d0/d1/d6/d7
	rts

_GetCharNonBlocking:
.0001
	moveq #5,d0
	trap #15
	ext.l d0
	rts

_CheckForCtrlC:
	moveq #5,d0
	trap #15
	cmpi.b #3,d0
	seq d0
	rts

_DumpStack:
	movem.l d0/a1,-(sp)
	moveq #29,d0
	lea -48(sp),a1
.0001	
	move.l a1,-(sp)
	bsr _OutputTetra
	move.l #' ',-(sp)
	bsr _OutputChar
	move.l (a1)+,-(sp)
	bsr _OutputTetra
	add.w #12,sp
	bsr _OutputCRLF
	dbra d0,.0001
	movem.l (sp)+,d0/d1
	rts

_clear:
	movem.l d6/d7,-(sp)
	moveq #7,d7
	moveq #DEV_CLEAR,d6
	trap #0
	movem.l (sp)+,d6/d7
	rts

_prtBinFltHelper:
	fmove.x 4(sp),fp0;
	rts

; Parameters:
;		device number
;		x
;		y
;		z
;		color

_plot_point3d:
	movem.l d1/d2/d3/d6/d7,-(sp)
	move.l 24(sp),d7
	move.l 40(sp),d1
	moveq #DEV_SET_COLOR,d6
	trap #0	
	moveq #DEV_PLOT_POINT,d6
	move.l 28(sp),d1
	move.l 32(sp),d2
	move.l 36(sp),d3
	trap #0
	movem.l (sp)+,d1/d2/d3/d6/d7
	rts

_plot_point:
	movem.l d1/d2/d3/d6/d7,-(sp)
	move.l 24(sp),d7
	move.l 36(sp),d1
	moveq #DEV_SET_COLOR,d6
	trap #0	
	moveq #DEV_PLOT_POINT,d6
	move.l 28(sp),d1
	move.l 32(sp),d2
	moveq #0,d3
	trap #0
	movem.l (sp)+,d1/d2/d3/d6/d7
	rts

_set_color_depth:
	movem.l d1/d2/d3/d4/d6/d7,-(sp)
	move.l 28(sp),d7
	move.l 32(sp),d1
	move.l 36(sp),d2
	move.l 40(sp),d3
	move.l 44(sp),d4
	lsl.l #4,d3
	or.l d3,d4
	lsl.l #8,d2
	or.l d2,d4
	swap d1
	lsl.l #4,d1
	or.l d4,d1
	moveq #DEV_SET_COLOR_DEPTH,d6
	trap #0
	movem.l (sp)+,d1/d2/d3/d4/d6/d7
	rts
	
_set_color:
	movem.l d1/d6/d7,-(sp)
	move.l 16(sp),d7
	move.l 20(sp),d1
	moveq #DEV_SET_COLOR,d6
	trap #0
	movem.l (sp)+,d1/d6/d7
	rts

_draw_line3d:
	movem.l d0-d7,-(sp)
	move.l 36(sp),d7
	move.l 64(sp),d1
	moveq #DEV_SET_COLOR,d6
	trap #0	
	moveq #DEV_DRAW_LINE,d6
	move.l 40(sp),d1
	move.l 44(sp),d2
	move.l 48(sp),d3
	move.l 52(sp),d4
	move.l 56(sp),d5
	move.l 60(sp),d0
	trap #0
	movem.l (sp)+,d0-d7
	rts

_draw_line:
	movem.l d0-d7,-(sp)
	move.l 36(sp),d7
	move.l 56(sp),d1
	moveq #DEV_SET_COLOR,d6
	trap #0	
	moveq #DEV_DRAW_LINE,d6
	move.l 40(sp),d1
	move.l 44(sp),d2
	moveq #0,d3
	move.l 48(sp),d4
	move.l 52(sp),d5
	moveq #0,d0
	trap #0
	movem.l (sp)+,d0-d7
	rts

_drawbuf:
	movem.l d1/d6/d7,-(sp)
	move.l 16(sp),d7
	moveq #DEV_SET_DESTBUF,d6
	move.l 20(sp),d1
	trap #0
	movem.l (sp)+,d1/d6/d7
	rts
	
_dispbuf:
	movem.l d1/d6/d7,-(sp)
	move.l 16(sp),d7
	moveq #DEV_SET_DISPBUF,d6
	move.l 20(sp),d1
	trap #0
	movem.l (sp)+,d1/d6/d7
	rts

_get_output_pos:
	movem.l d1/d2/d3/d6/d7/a0,-(sp)
	move.l 28(sp),d7
	moveq #DEV_GET_OUTPOS,d6
	trap #0
	move.l 32(sp),a0
	move.l d1,(a0)
	move.l 36(sp),a0
	move.l d2,(a0)
	move.l 40(sp),a0
	move.l d3,(a0)
	movem.l (sp)+,d1/d2/d3/d6/d7/a0
	rts
	
_get_input_pos:
	movem.l d1/d2/d3/d6/d7/a0,-(sp)
	move.l 28(sp),d7
	moveq #DEV_GET_INPOS,d6
	trap #0
	move.l 32(sp),a0
	move.l d1,(a0)
	move.l 36(sp),a0
	move.l d2,(a0)
	move.l 40(sp),a0
	move.l d3,(a0)
	movem.l (sp)+,d1/d2/d3/d6/d7/a0
	rts
	
_set_input_pos:
	movem.l d1/d2/d3/d6/d7,-(sp)
	move.l 24(sp),d7
	moveq #DEV_SET_INPOS,d6
	move.l 28(sp),d1
	move.l 32(sp),d2
	move.l 36(sp),d3
	trap #0
	movem.l (sp)+,d1/d2/d3/d6/d7
	rts
	
_get_coreno:
	movec.l coreno,d0
	subq.l #2,d0
	rts

_get_tick:
	movec.l tick,d0
	rts

; Parameters:
;		d1 = semaphore to lock
;		d2 = number of retries
;	Returns:
;		d0 = -1 if successful, 0 otherwise

_LockSemaphore:
	movem.l d1/d2,-(sp)
	move.l 12(sp),d1
	move.l 14(sp),d2
	moveq #37,d0
	trap #15
	movem.l (sp)+,d1/d2
	rts

; Parameters:
;		d1 = semaphore to unlock
; Returns:
;		none

_UnlockSemaphore:
	movem.l d0/d1,-(sp)
	move.l 12(sp),d1
	moveq #38,d0
	trap #15
	movem.l (sp)+,d0/d1
	rts
	
__exit:
	move.l 4(sp),d0
	moveq #OS_EXIT_TASK,d7
	trap #1
	rts

	global _OutputChar
	global _OutputCRLF
	global _OutputFloat
	global _OutputDevice
	global _InputDevice
	global _OutputTetra
	global _OutputWyde
	global _OutputByte
	global _OutputNybble
	global _GetChar
	global _CheckForCtrlC
	global _clear
	global _prtBinFltHelper
	global _OutputNumber
	global _CvtStringToDecflt
	global _GetCharNonBlocking
	global _get_output_pos
	global _get_input_pos
	global _set_input_pos
	global _get_char
	global _put_char

	global _DumpStack
	global _set_color_depth
	global _set_color
	global _plot_point
	global _plot_point3d
	global _draw_line
	global _draw_line3d
	global _dispbuf
	global _drawbuf

	global _get_coreno
	global _get_tick
	global _LockSemaphore
	global _UnlockSemaphore
	
	global __exit

	