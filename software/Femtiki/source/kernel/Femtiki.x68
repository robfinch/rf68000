	code
	even
;------------------------------------------------------------------------------
; Initialize the Femtiki OS.
;------------------------------------------------------------------------------

FemtikiInit:
	moveq #1,d0
	movec d0,tr
	bsr TCBInit
	clr.b QueueCycle
FemtikiInitIRQ:
	lea FemtikiTimerIRQ,a1						; Set timer IRQ vector to Femtiki
	movec vbr,a0
	move.l a1,30*4(a0)								; vector #30
	rts

;------------------------------------------------------------------------------
; Operating system call dispatcher.
; On entry, the task state has been saved including the system stack pointer,
; in the task control block.
;------------------------------------------------------------------------------

OSCallTable
	dc.w		0

	even
CallOS:
	move.l	a0,-(a7)
	move.l	RunningTCB,a0
	movem.l d0-d7/a0-a6,TCBRegs(a0)
	move.l	(a7)+,a1
	move.l	a1,32(a0)
	movec		usp,a1
	move.l	a1,TCBUSP(a0)
	move.w	(a7)+,d0					; pop the status register
	move.w	d0,TCBSR(a0)			; save in TCB
	move.l	(a7)+,a1					; pop the program counter
	lea	2(a1),a1							; increment past inline callno argument
	move.l	a1,TCBPC(a0)			; save PC in TCB
	move.l	a7,TCBSSP(a0)			; finally save SSP
	move.w	-2(a1),d0					; d0 = call number
	lsl.w		#2,d0							; make into table index
	lea			OSCallTable,a1
	move.l	(a1,d0.w),a1
	jsr			(a1)							; call the OS function
	; Restore the thread context and return
	move.l	RunningTCB,a0
	move.l	TCBSSP,a7
	move.l	TCBPC(a0),-(a7)		; setup the PC and the SR on the stack
	move.w	TCBSR(a0),-(a7)		; prep for RTE
	move.l	TCBUSP,d0					; restore user stack pointer
	movec		d0,usp
	movem.l	TCBRegs(a0),d0/d1/d2/d3/d4/d5/d6/d7
	movem.l TCBRegs+40(a0),a1/a2/a3/a4/a5/a6
	move.l	TCBRegs+32(a0),a0
	rte

;------------------------------------------------------------------------------
; Get a pointer to the currently running TCB.
;
; Returns:
;		a0 = pointer to running TCB
;------------------------------------------------------------------------------

GetRunningTCBPointer:
	movem.l d0/d1,-(a7)
	movec tr,d0
	bsr TCBHandleToPointer
	andi.l #MAX_TID,d0		; limit to # threads
	movem.l (a7)+,d0/d1
	rts

; ----------------------------------------------------------------------------
; Select a thread to run. Relatively easy. All that needs to be done is to
; keep popping the queue until a valid running task is found. There should
; always be at least one thread in the queue.
;
; Modifies:
;		none
; Returns:
;		d0 = handle of the next thread to run
; ----------------------------------------------------------------------------

SelectThreadToRun:
.0001										; keep popping tasks from the readyQ until a valid one
	bsr	TCBPopReadyQueue	; is found.
	tst.w d0
	beq	.0002
	bsr TCBHandleToPointer
	cmpi.b #TS_RUNNING,TCBStatus(a0)	; ensure the thread is to be running
	bne	.0001													; if not, go get the next thread
	bra	TCBInsertIntoReadyQueue				; insert thread back into queue
	; Nothing in queues? There is supposed to be. Add the OS task to the queue.
.0002
	movec tcba,a0
	move.b #TS_RUNNING,TCBStatus(a0)	; flag as RUNNING
	move.b #4,TCBPriority(a0)					; OS has normal priority
	moveq #0,d0												; fast pointer to handle
	bra TCBInsertIntoReadyQueue

; ----------------------------------------------------------------------------
; Update the IRQ live indicator on screen.
; ----------------------------------------------------------------------------

UpdateIRQLive:
	move.l TextScr,a1					; a1 = screen address
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

; ----------------------------------------------------------------------------
; Femtiki IRQ service routine. This is where a thread switch can occur so,
; the thread context is saved and restored.
; ----------------------------------------------------------------------------

FemtikiTimerIRQ:
	move.w #$2600,sr							; disable lower level IRQs
	move.l d0,-(a7)
	move.l a0,-(a7)
	bsr GetRunningTCBPointer			; a0 = pointer to running TCB
	movem.l #$FFFF,TCBRegs(a0)		; save all registers
	move.l (a7)+,d0
	move.l d0,32(a0)							; save original a0 value
	move.l (a7)+,d0
	move.l d0,(a0)								; save original d0 value
	movec usp,d0									; save user stack pointer
	move.l d0,TCBUSP(a0)
	move.l #TimerStack,a7					; reset stack pointer
	movec	coreno,d1								; d1 = core number
	cmpi.b #2,d1
	bne.s	.0002
	move.l #$1D000000,PLIC+$14		; reset edge sense circuit
	move.b #1,IRQFlag							; set IRQ flag for TinyBasic shell
.0002
	bsr UpdateIRQLive							; Update IRQ live indicator
;	bsr ReceiveMsg								; Check for RPC
	movec tick,d0									; Update time accounting
	move.l d0,TCBEndTick(a0)			; compute number of ticks thread was running
	sub.l	TCBStartTick(a0),d0
	add.l	d0,TCBTicks(a0)					; add to cumulative ticks
	move.b #TS_PREEMPT,TCBStatus(a0)	; set thread status to PREEMPT
	bsr	SelectThreadToRun					; d0 = TCB handle
	movec d0,tr										; set running thread number in tr
	bsr GetRunningTCBPointer			; a0 = pointer to TCB
	move.b #TS_RUNNING,TCBStatus(a0)	; set thread status to RUNNING
	movec	tick,d0
	move.l d0,TCBStartTick(a0)		; record starting tick
	move.l TCBUSP(a0),d0					; restore user stack pointer
	movec d0,usp
	movem.l TCBRegs(a0),#$FFFF		; restore all registers
	addq #8,sp										; "pop" d0/a0, saved stack pointer is off by 8
	rte														; and return

	include "..\Femtiki\source\kernel\Semaphore.x68"

