	include "..\Femtiki\const.x68"
	include "..\Femtiki\config.x68"
	include "..\Femtiki\types.x68"

	code
	even
;------------------------------------------------------------------------------
; Initialize the Femtiki OS.
;------------------------------------------------------------------------------

FemtikiInit:
	moveq #7,d0
	lea readyQ,a0
.clearReadyQ
	clr.l (a0)+
	dbra d0,.clearReadyQ
	clr.b QueueCycle
	clr.l RunningTCB
	move.l #TCB_SIZE*NR_TCB/4-1,d0
	lea tcbs,a0
.clearTCBs
	clr.l (a0)+
	dbra d0,.clearTCBs
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
	movem.l d0/d1/d2/d3/d4/d5/d6/d7/a0/a1/a2/a3/a4/a5/a6/a7,TCBRegs(a0)
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

; ----------------------------------------------------------------------------
; Select a thread to run. Relatively easy. All that needs to be done is to
; keep popping the queue until a valid running task is found. There should
; always be at least one thread in the queue.
;
; Modifies:
;		none
; Retuns:
;		a0 = next thread to run
; ----------------------------------------------------------------------------

SelectThreadToRun:
.0001										; keep popping tasks from the readyQ until a valid one
	bsr	PopReadyQueue			; is found.
	move.l a0,a0					; tst.l a0
	beq	.0002
	cmpi.b #TS_RUNNING,TCBStatus(a0)	; ensure the thread is to be running
	bne	.0001													; if not, go get the next thread
	bra	InsertIntoReadyQueue					; insert thread back into queue
	; Nothing in queues? There is supposed to be. Add the OS task to the queue.
.0002
	lea tcbs,a0
	move.b #TS_RUNNING,TCBStatus(a0)	; flag as RUNNING
	move.b #4,TCBPriority(a0)					; OS has normal priority
	; fall through to insert

; ----------------------------------------------------------------------------
; Insert thread into ready queue. The thread is added at the tail of the 
; queue unless. The queue is a doubly linked list.
;
; Parameters:
;		a0 = pointer to TCB
; Returns:
;		none
; ----------------------------------------------------------------------------

InsertIntoReadyQueue:
	movem.l	d0/a1/a2/a3,-(a7)
	move.l TCBPriority(a0),d0
	andi.w #7,d0
	lsl.w	#2,d0
	lea	readyQ,a1
	move.l (a1,d0.w),a3
	beq .qempty
	move.l TCBPrev(a3),a2
	move.l a3,TCBNext(a0)
	move.l a2,TCBPrev(a0)
	move.l TCBNext(a2),a0
	move.l TCBPrev(a3),a0
.xit:
	movem.l	(a7)+,d0/a1/a2/a3
	rts
.qempty
	move.l a0,(a1,d0.w)
	move.l a0,TCBNext(a0)
	move.l a0,TCBPrev(a0)
	bra .xit

; ----------------------------------------------------------------------------
; Register Usage
;		d0 = queue counter
;		d1 = index into list of queues
;		a0 = pointer to list of queues
;		a3 = pointer to TCB at head of queue
; Parameters:
;		none
; Returns:
;		a0 = pointer to TCB, NULL if none on list
; ----------------------------------------------------------------------------

StartQ
	dc.b 1,2,3,4,1,5,6,7

	even
PopReadyQueue:
	movem.l	d0/d1/a1/a2/a3,-(a7)
	moveq #7,d0
	; One in four tries pick a different priority to start searching from. 
	move.b QueueCycle,d1		; increment Queue cycle counter
	addi.b #1,d1
	andi.b #7,d1
	move.b d1,QueueCycle
	bne	.0001
	lea StartQ,a1
	ext.w d1
	move.b (a1,d1.w),d1
	andi.w #7,d1						; limit to number of queues
	lsl.w #2,d1							; make into lword index
	bra .0002
.0001
	moveq #0,d1							; start at Queue #0
.0002
	lea readyQ,a0						; a0 = pointer to list of ready queues
	move.l (a0,d1.w),a3			; a3 = head of list
	beq .nextQ							; anything on list?, if not go next queue
	move.l TCBNext(a3),a1		; remove head of list from list
	cmpa.l a1,a3						; removing last TCB?
	beq .removeLast
	move.l TCBPrev(a3),a2
	move.l TCBPrev(a1),a2
	move.l TCBNext(a2),a1
.0003
	move.l	a1,(a0,d1.w)		; reset head of list to next
.0004
	move.l a3,a0						; a0 = old head of list (returned)
	move.l a0,TCBNext(a0)		; point links back to self
	move.l a0,TCBPrev(a0)
	movem.l	(a7)+,d0/d1/a1/a2/a3
	rts
.removeLast
	move.l #0,a1						; set head to zero when removing last
	bra .0003
.nextQ
	addi.w #4,d1						; increment queue number by lword
	andi.w #$1C,d1					; limit to number of queues
	dbra d0,.0002						; go back and check the next queue
	bra	.0004								; return NULL pointer if nothing in any queue
	
; ----------------------------------------------------------------------------
; Femtiki IRQ service routine. This is where a thread switch can occur so,
; the thread context is saved and restored.
; ----------------------------------------------------------------------------

FemtikiTimerIRQ:
	move.w #$2600,sr					; disable lower level IRQs
	;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	; Save thread context
	;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	move.l a0,-(a7)						; stack a temporary
	move.l RunningTCB,a0			; a0 = pointer to running TCB
	bne .0001									; Is there a thread?
	lea tcbs,a0								; point to OS thread
.0001
	movem.l d0/d1/d2/d3/d4/d5/d6/d7/a0/a1/a2/a3/a4/a5/a6/a7,TCBRegs(a0)
	move.l (a7)+,a1						; a1 = a0 original value
	move.l a1,32(a0)					; save original value of a0 in a0 slot
	movec	usp,a1							; save usp
	move.l a1,TCBUSP(a0)
	move.w (a7)+,d0						; pop the status register
	move.w d0,TCBSR(a0)				; save in TCB
	move.l (a7)+,a1						; pop the program counter
	move.l a1,TCBPC(a0)				; save PC in TCB
	move.l a7,TCBSSP(a0)			; finally save SSP
	;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	; Reset IRQ hardware
	;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	movec	coreno,d1						; d1 = core number
	cmpi.b #2,d1
	bne.s	.0002
	move.l #$1D000000,PLIC+$14	; reset edge sense circuit
.0002
	;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	; Update IRQ live indicator
	;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
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
	;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	; Check for RPC
	;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;	bsr ReceiveMsg
	;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	; Update time accounting
	;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	movec tick,d0
	move.l d0,TCBEndTick(a0)			; compute number of ticks thread was running
	sub.l	TCBStartTick(a0),d0
	add.l	d0,TCBTicks(a0)					; add to cumulative ticks
	move.b #TS_PREEMPT,TCBStatus(a0)	; set thread status to PREEMPT
	bsr	SelectThreadToRun
	move.l a0,RunningTCB
	move.b #TS_RUNNING,TCBStatus(a0)	; set thread status to RUNNING
	movec	tick,d0
	move.l d0,TCBStartTick(a0)		; record starting tick
	;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	; Restore the thread context and return
	;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	move.l TCBSSP,a7
	move.l TCBPC(a0),-(a7)		; setup the PC and the SR on the stack
	move.w TCBSR(a0),-(a7)		; prep for RTE
	move.l TCBUSP,d0					; restore user stack pointer
	movec	d0,usp
	movem.l	TCBRegs(a0),d0/d1/d2/d3/d4/d5/d6/d7
	movem.l TCBRegs+40(a0),a1/a2/a3/a4/a5/a6
	move.l TCBRegs+32(a0),a0
	rte
