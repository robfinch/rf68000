	include "..\inc\const.x68"
	include "..\inc\config.x68"
	include "..\inc\device.x68"

	section local_ram
	align 2
_extFMTKCall
	ds.w	1
	global _extFMTKCall
	code
	even

macLockSemaphore macro wh,tm
	moveq #37,d0					; lock semaphore
	moveq #\1,d1
	move.l #\2,d2
	trap #15
endm

macUnlockSemaphore macro wh
	moveq #38,d0
	moveq #\1,d1
	trap #15
endm

; ----------------------------------------------------------------------------
; Carefully done so that the IM level is not affected until the end. There is
; no transient level.
; ----------------------------------------------------------------------------

_SetImLevelHelper:
	move.l d1,-(sp)
	and.w #7,d0
	lsl.w #8,d0
	move sr,d1
	and.w #$F8FF,d1
	or.w d1,d0
	move.w d0,sr
	move.l (sp)+,d1
	rts
	global _SetImLevelHelper

;------------------------------------------------------------------------------
; Initialize the Femtiki OS.
;------------------------------------------------------------------------------

FemtikiInit:
	moveq #1,d0
	movec d0,tr
;	bsr TCBInit
;	clr.b QueueCycle
FemtikiInitIRQ:
	lea _FMTK_TimerTickISR,a1					; Set timer IRQ vector to Femtiki
	movec vbr,a0
	move.l a1,30*4(a0)								; vector #30
	rts

;------------------------------------------------------------------------------
; Operating system call dispatcher. On entry the register set is saved.
;
; All rescheduling of tasks (task switching) is handled by the TimerIRQ() or
; RescheduleIRQ() functions. Calling a system function does not directly 
; change tasks so there's no reason to save/restore many of the control
; registers that need to be saved and restored by a task switch.
;
; Parameters to the system function are passed in registers d0 to d4.
;------------------------------------------------------------------------------

macOSCallAddr macro arg1
	dc.l \1
endm

OSCallTable:
	macOSCallAddr	_FMTK_Initialize
	macOSCallAddr	_FMTK_StartThread
	macOSCallAddr	_FMTK_ExitThread
	macOSCallAddr	_FMTK_KillThread
	macOSCallAddr	_FMTK_SetThreadPriority
	macOSCallAddr	_FMTK_Sleep
	macOSCallAddr	_FMTK_WaitMsg
	macOSCallAddr	_FMTK_SendMsg
	macOSCallAddr	_FMTK_PostMsg
	macOSCallAddr	_FMTK_PeekMsg
	macOSCallAddr	_FMTK_CheckMsg
	macOSCallAddr	_FMTK_AllocMbx
	macOSCallAddr	_FMTK_FreeMbx
	macOSCallAddr	_FMTK_StartApp
	macOSCallAddr	_FMTK_RegisterService
	macOSCallAddr	_FMTK_UnregisterService
	macOSCallAddr	_FMTK_GetServiceMbx
	macOSCallAddr	_FMTK_AllocSystemPages
	macOSCallAddr	_FMTK_AllocPages
	macOSCallAddr	_FMTK_AliasMem
	macOSCallAddr	_FMTK_DeAliasMem
	macOSCallAddr	_FMTK_AddAlarm


	even
_FMTK_Dispatch:
	movem.l d1-d7/a0-a6,-(sp)
	ext.w d7
	lsl.w #2,d7
	lea OSCallTable,a0
	move.l (a0,d7.w),a0
	; Lock the system semaphore, trashes d0 to d2
;	movem.l d0-d2,-(sp)
;	macLockSemaphore OSSEMA,100000
;	tst.l d0
;	beq.s .0001							; lock achieved?
;	movem.l (sp)+,d0-d2			; get back d0 to d2
	add.w #1,_extFMTKCall
	jsr (a0)								; call the system  routine
	sub.w #1,_extFMTKCall
;	move.l d0,-(sp)
;	macUnlockSemaphore OSSEMA
;	move.l (sp)+,d0					; get back d0
	movem.l (sp)+,d1-d7/a0-a6
	rte
.0001
	add.l #12,sp
	moveq #E_Busy,d0
	movem.l (sp)+,d1-d7/a0-a6
	rte

	global _FMTK_Dispatch

_FMTK_RescheduleISRLaunchpad:
	move.w #$2700,sr						; disable lower interrupts
	; Save register context in TCB
	move.l a0,-(a7)							; push a0
	movec.l tcba,a0							; a0 points to task control block
	movem.l d0-d7/a1-a6,4(a0)		; save registers in task control block
	move usp,a1									; save usp in TCB
	move.l a1,60(a0)
	move.l (sp)+,64(a0)					; pop a0 into TCB
	move.w (sp)+,140(a0)				; status reg
	move.l (sp)+,136(a0)				; program counter
	move.w (sp)+,144(a0)				; and format word
	move.l a7,68(a0)						; finally save a7

	move.l #$47FFC,a7						; setup sp

	; Reset rescheduler IRQ	
	move.l #$03000000,$FD260014	; reset edge sense circuit
	; Call 'C' interrupt handler
	jsr _FMTK_RescheduleISR			; call the ISR routine

	; Restore register context from TCB. Note that a different context may be
	; restored than the one saved.
	movec.l tcba,a0							; a0 points to task control block
	move.l 60(a0),a1						; restore usp
	move.l a1,usp
	movem.l 4(a0),d0-d7/a1-a6		; restore register set
	move.l 68(a0),a7						; restore a7
	move.w 144(a0),-(sp)				; push format word
	move.l 136(a0),-(sp)				; push program counter
	move.w 140(a0),-(sp)				; push status reg
	move.l 64(a0),a0						; restore a0
	rte

	global _FMTK_RescheduleISRLaunchpad

; Timer ISR
;
; The only code modifying the register context is in the timer IRQ. That means
; the register context should not need to be protected by a semaphore. The only
; issue that might arise if if the timer ISR takes too long and overlaps with
; the next one. This should not happen unless the tick interval is set too short.
;
_FMTK_TimerISRLaunchpad:
	move.w #$2700,sr						; disable interrupts
;	move.l d0,-(sp)
;	movec.l coreno,d0
;	cmp.b _InTimerISR,d0				; Is it core's turn to process?
;	bne .0002										; no, just return
;	move.l (sp)+,d0

	; Save register context in TCB
	move.l a0,-(a7)							; push a0
	movec.l tcba,a0							; a0 points to task control block
	movem.l d0-d7/a1-a6,4(a0)		; save registers in task control block
	move usp,a1									; save usp in TCB
	move.l a1,60(a0)
	move.l (sp)+,64(a0)					; pop a0 into TCB
	move.w (sp)+,140(a0)				; status reg
	move.l (sp)+,136(a0)				; program counter
	move.w (sp)+,144(a0)				; and format word
	move.l a7,68(a0)						; finally save a7

	move.l #$47FFC,a7						; setup sp

	; Reset timer IRQ	
	; We know which irq it must have been, would not be in this routine unless
	; it was the right one.
	lea PIT,a0
	move.l #16,$1010(a0)				; write flag value to negate irq,underflow flags
	move.l #$1D000000,$FD260014	; reset edge sense circuit

	; Display IRQ Live indicator
	movec.l coreno,d0
	lsl.l #2,d0
	lea.l $FD0000DC,a0
	move.l (a0,d0.w),d1					; fetch colors from screen
	movec.l coreno,d2
	clr.w d1
	or.w d2,d1									; or in core number
	add.l #$10030,d1						; add ascii '0'
	move.l d1,(a0,d0.w)					; move to screen

	; Call 'C' interrupt handler
	jsr _FMTK_TimerTickISR			; call the IRQ routine

	; Restore register context from TCB. Note that a different context may be
	; restored than the one saved.
	movec.l tcba,a0							; a0 points to task control block
	move.l 60(a0),a1						; restore usp
	move.l a1,usp
	movem.l 4(a0),d0-d7/a1-a6		; restore register set
	move.l 68(a0),a7						; restore a7
	move.w 144(a0),-(sp)				; push format word
	move.l 136(a0),-(sp)				; push program counter
	move.w 140(a0),-(sp)				; push status reg
	move.l 64(a0),a0						; restore a0

;	addi.b #1,_InTimerISR
;	cmpi.b #2,_InTimerISR
;	bls.s .0001
;	move.b #2,_InTimerISR
.0001
	rte
.0002
	move.l (sp)+,d0
	rte

	global _FMTK_TimerISRLaunchpad

macAlarmISR macro
	move.l #_FMTK_AlarmISRLaunchpad\@,REPTN*4+$300
	bra.s _FMTK_NextAlarmISR\@
_FMTK_AlarmISRLaunchpad\@:
	move.w #$2700,sr						; disable interrupts
	movem.l d0-d7/a0-a6,-(sp)
	move.l #REPTN,d0
	jsr _FMTK_AlarmISR
	movem.l (sp)+,d0-d7/a0-a6
	rte
_FMTK_NextAlarmISR\@
	endm

_SetupAlarmISRs:
	rept 64
	macAlarmISR
	endr	
	rts
	global _SetupAlarmISRs

;------------------------------------------------------------------------------
; Get a pointer to the currently running TCB.
;
; Returns:
;		a0 = pointer to running TCB
;------------------------------------------------------------------------------

GetRunningTCBPointer:
	movem.l d0/d1,-(a7)
	movec tr,d0
	jsr _TCBHandleToPointer
	andi.l #NR_TCB,d0			; limit to # tasks
	movem.l (a7)+,d0/d1
	rts

; ----------------------------------------------------------------------------
; Update the IRQ live indicator on screen.
; ----------------------------------------------------------------------------

UpdateIRQLive:
	lea $FD000000,a1 					; a1 = screen address
	move.l (a1),d2
	rol.w	#8,d2								; reverse byte order of d2
	swap d2
	rol.w	#8,d2
	addi.b #'0',d1						; binary to ascii core number
	add.b	d2,d1
	rol.w	#8,d1								; put bytes back in order
	swap d1
	rol.w	#8,d1
	move.l d1,4(a1)						; update onscreen IRQ flag
	addi.l #1,(a1)						; flashy colors
	rts

;	include "semaphore_asm.x68"

_space_strcpy:
	clr.b (a0)								; NULL terminate
	tst.w d0									; anything to copy?
	beq.s .0003
	subq.w #1,d0							; copy counter is one less
	movem.l d0/d1/a0/a2,-(sp)
.0002
	moves.b (a1)+,d1
	move.b d1,(a0)+
	tst.b -1(a1)
	dbeq d0,.0002
	movem.l (sp)+,d0/d1/a0/a1
.0003
	rts
	global _space_strcpy
