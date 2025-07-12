;==============================================================================
; PIT - programmable interval timer
;
; Reg. Offs.
;	00 = curent count, read-only
; 04 = max count
;	08 = on time
; 0C = control
;		bit in control byte
;		0 = 1 = load, automatically clears
;	  1 = 1 = enable counting, 0 = disable counting
;		2 = 1 = auto-reload on terminal count, 0 = no reload
;		3 = 1 = use external clock, 0 = internal clk_i
;   4 = 1 = use gate to enable count, 0 = ignore gate
;		7 = 1 = set registers immediately, 0 = wait for sync
;==============================================================================

	include "..\Femtiki\source\inc\device.x68"

_setup_pit:
pit_setup:
pit_init:
init_pit:
	lea	PIT,a0							; a0 points to PIT
	move.l #1000000,$44(a0)	; setup for 100.0 Hz
	move.l #50,$48(a0)			; on for 50 clocks
	move.l #$87,$4C(a0)			; load,enable,auto-reload,internal clock,ignore gate,set
	move.l #16,$808(a0)			; enable timer #4 interrupts
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
