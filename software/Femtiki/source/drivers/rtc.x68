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
	dc.l rtc_swapbuf
	dc.l rtc_setbuf1
	dc.l rtc_setbuf2
	dc.l rtc_getbuf1
	dc.l rtc_getbuf2
	dc.l rtc_writeat
	dc.l rtc_set_unit
	dc.l rtc_get_dimen	; 20
	dc.l rtc_get_color
	dc.l rtc_get_inpos
	dc.l rtc_get_outpos
	dc.l rtc_get_outptr
	dc.l rtc_set_color
	dc.l rtc_set_color123
	dc.l rtc_plot_point
	dc.l rtc_draw_line
	dc.l rtc_draw_triangle
	dc.l rtc_draw_rectangle	;30
	dc.l rtc_draw_curve
	dc.l rtc_set_dimen
	dc.l rtc_set_color_depth
	dc.l rtc_set_destbuf
	dc.l rtc_set_dispbuf

	code
	even

rtc_cmdproc:
	cmpi.b #36,d6
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
	moveq #E_Func,d0
	rts

