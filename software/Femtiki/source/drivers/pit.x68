;==============================================================================
; PIT - programmable interval timer
;
; Reg. Offs.
;	00 = current count bits 0 to 31, read-only
;	04 = current count bits 32 to 47
; 08 = max count bits 0 to 31
;	0C = max count bits 32 to 47
;	10 = on time bits 0 to 31
;	14 = on time bits 32 to 47
; 18 = control
;		bit in control byte
;		0 = 1 = load, automatically clears
;	  1 = 1 = enable counting, 0 = disable counting
;		2 = 1 = auto-reload on terminal count, 0 = no reload
;		3 = 1 = use external clock, 0 = internal clk_i
;   4 = 1 = use gate to enable count, 0 = ignore gate
;		7 = 1 = set registers immediately, 0 = wait for sync
;		16 to 31 = mailbox
; 1C = vector
;==============================================================================

	include "..\Femtiki\source\inc\device.x68"

_setup_pit:
pit_setup:
pit_init:
init_pit:
	lea	PIT,a0							; a0 points to PIT
	move.l #93750,$88(a0)		; setup for 33.3 Hz
	clr.l $8C(a0)						; maxcount bits 32 to 47
	move.l #50,$90(a0)			; on for 50 clocks
	clr.l $94(a0)						; on time bits 32 to 47
	move.l #$07,$98(a0)			; load,enable,auto-reload,internal clock,ignore gate,set
	move.l #$80,$98(a0)			; load,enable,auto-reload,internal clock,ignore gate,set
	move.l #192,$1040(a0)		; set base vector
	jsr _SetupAlarmISRs
	move.l #16,$1000(a0)		; enable timer #4 interrupts
	move.l #_FMTK_TimerISRLaunchpad,(192+4)*4	; override default for system tick timer
	rts

	global _setup_pit
	global pit_setup
	global pit_init

_reset_pit_irq:
	movem.l d0/a0,-(sp)
	lea PIT,a0
	move.l $800(a0),d0			; read underflow register
	move.l d0,$800(a0)			; write it back
	movem.l (sp)+,d0/a0
	rts

	global _reset_pit_irq

_pit_isr:
	movem.l d0-d7/a0-a6,-(sp)
	lea PIT,a0
	move.l $800(a0),d0		; get underflow status
	clr.l d2
.0002
	btst.l d2,d0
	bne.s .0001
	addq #1,d2
	cmpi.b #32,d2
	blo.s .0002
	; no timer underflowed, just return
	movem.l (sp)+,d0-d7/a0-a6
	rte
.0001
	moveq #1,d1
	lsl.l d2,d1
	move.l d1,$800(a0)			; write to underflow to clear
	lsl.l #5,d2							; d2 points to base timer reg
	lea (a0,d2.w),a0				; a0 points to timer register set
	jsr _pit_cisr
	movem.l (sp)+,d0-d7/a0-a6
	rte
	
	
	
	