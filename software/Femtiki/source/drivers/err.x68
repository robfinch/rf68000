	include "..\Femtiki\source\inc\const.x68"
	include "..\Femtiki\source\inc\device.x68"

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; Setup the err device
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

setup_err:
err_init:
	movem.l d0/a0/a1,-(sp)
	move.l d0,a0
	move.l d0,a0
	moveq #31,d0
.0001:
	clr.l (a0)+
	dbra d0,.0001
	move.l #$20424344,DCB_MAGIC(a1)				; 'DCB'
	move.l #$4C4C554E,DCB_NAME(a1)					; 'err'
	move.l #err_cmdproc,DCB_CMDPROC(a1)
err_ret:
	movem.l (sp)+,d0/a0/a1
	rts

err_cmdproc:
	moveq #E_Ok,d0
	rts

