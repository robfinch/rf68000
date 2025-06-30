	include "..\inc\const.x68"
	include "..\inc\config.x68"

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

;------------------------------------------------------------------------------
; Initialize the Femtiki OS.
;------------------------------------------------------------------------------

FemtikiInit:
	moveq #1,d0
	movec d0,tr
;	bsr TCBInit
;	clr.b QueueCycle
FemtikiInitIRQ:
	lea _FMTK_TimerIRQ,a1						; Set timer IRQ vector to Femtiki
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
	macOSCallAddr	_FMTK_StartTask
	macOSCallAddr	_FMTK_ExitTask
	macOSCallAddr	_FMTK_KillTask
	macOSCallAddr	_FMTK_SetTaskPriority
	macOSCallAddr	_FMTK_Sleep
	macOSCallAddr	_FMTK_WaitMsg
	macOSCallAddr	_FMTK_SendMsg
	macOSCallAddr	_FMTK_PeekMsg
	macOSCallAddr	_FMTK_CheckMsg
	macOSCallAddr	_FMTK_AllocMbx
	macOSCallAddr	_FMTK_FreeMbx
	macOSCallAddr	_FMTK_StartApp
	macOSCallAddr	_FMTK_RegisterService
	macOSCallAddr	_FMTK_UnregisterService
	macOSCallAddr	_FMTK_GetServiceMbx


	even
_FMTK_Dispatch:
	movem.l d1-d7/a0-a6,-(sp)
	ext.w d7
	lsl.w #1,d7
	lea OSCallTable,a0
	move.l (a0,d7.w),a0
	; Lock the system semaphore, trashes d0 to d2
	movem.l d0-d2,-(sp)
	macLockSemaphore OSSEMA,100000
	tst.l d0
	beq.s .0001							; lock achieved?
	movem.l (sp)+,d0-d2			; get back d0 to d2
	add.w #1,_extFMTKCall
	jsr (a0)								; call the system  routine
	sub.w #1,_extFMTKCall
	move.l d0,-(sp)
	macUnlockSemaphore OSSEMA
	move.l (sp)+,d0					; get back d0
	movem.l (sp)+,d1-d7/a0-a6
	rte
.0001
	add.l #12,sp
	moveq #E_Busy,d0
	movem.l (sp)+,d1-d7/a0-a6
	rte

	global _FMTK_Dispatch

_FMTK_TimerIRQLaunchpad:
	movem.l d0-d7/a0-a6,-(sp)		; save all regs
	move.l usp,a0								; including usp
	move.l a0,-(sp)							; supply pointer to save area to IRQ routine
	move.l sp,d0
	jsr _FMTK_TimerIRQ					; call the IRQ routine
	move.l (sp)+,a0							; restore usp
	move.l a0,usp
	movem.l (sp)+,d0-d7/a0-a6		; and the rest of the registers
	rte

	global _FMTK_TimerIRQLaunchpad

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
