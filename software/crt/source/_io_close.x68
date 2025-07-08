	extrn _errno

	code
	align 2
; Parameters
;		d7 = device handle
; Returns:
;		d0 = device handle with unit, 0 if unsuccessful
;
__io_close:
	move.l d6,-(sp)
	moveq #DEV_CLOSE,d6
	trap #0
	cmpi.l #E_Ok,d0
	bne.s .0001
	move.l (sp)+,d6
	rts
.0001
	move.l d0,_errno
	move.l (sp)+,d6
	moveq #-1,d0
	rts
	global __io_close

