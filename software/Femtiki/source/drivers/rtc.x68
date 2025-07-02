	include "..\inc\const.x68"

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; Real Time Clock
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
	align 2
RTC_CMDTBL:
	dc.l rtc_init				; 0
	dc.l rtc_stat
	dc.l rtc_putchar
	dc.l rtc_putbuf
	dc.l rtc_getchar
	dc.l rtc_getbuf
	dc.l rtc_set_inpos
	dc.l rtc_set_outpos
	dc.l rtc_stub
	dc.l rtc_stub
	dc.l rtc_stub				; 10
	dc.l rtc_stub
	dc.l rtc_clear
	dc.l rtc_stub
	dc.l rtc_stub
	dc.l rtc_stub
	dc.l rtc_stub
	dc.l rtc_stub
	dc.l rtc_stub
	dc.l rtc_stub
	dc.l rtc_stub	; 20
	dc.l rtc_stub
	dc.l rtc_stub
	dc.l rtc_stub
	dc.l rtc_stub
	dc.l rtc_stub
	dc.l rtc_stub
	dc.l rtc_stub
	dc.l rtc_stub
	dc.l rtc_stub
	dc.l rtc_stub	;30

	code
	even

rtc_cmdproc:
	cmpi.b #13,d6
	bhs.s .0001
	movem.l d6/a0,-(a7)
	ext.w d6
	ext.l d6
	lsl.w #2,d6
	lea.l RTC_CMDTBL,a0
	move.l (a0,d6.w),a0
	jsr (a0)
	movem.l (a7)+,d6/a0
	rts
.0001:
	moveq #E_NotSupported,d0
	rts

rtc_init:
rtc_putchar:
rtc_putbuf:
rtc_getchar:
rtc_getbuf:
rtc_stub:
rtc_clear:
	moveq #E_NotSupported,d0
	rts

rtc_stat:
rtc_set_inpos:
rtc_set_outpos:
	moveq #E_Ok,d0
	rts
