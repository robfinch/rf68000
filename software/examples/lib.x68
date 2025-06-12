	include "..\Femtiki\device.x68"
	bss
_OutputDevice:
	ds.b 0
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

	global _OutputChar
	global _OutputDevice
