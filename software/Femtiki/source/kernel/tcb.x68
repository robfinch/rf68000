; ============================================================================
;        __
;   \\__/ o\    (C) 2022-2025  Robert Finch, Waterloo
;    \  __ /    All rights reserved.
;     \/_//     robfinch<remove>@finitron.ca
;       ||
;  
;
; BSD 3-Clause License
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions are met:
;
; 1. Redistributions of source code must retain the above copyright notice, this
;    list of conditions and the following disclaimer.
;
; 2. Redistributions in binary form must reproduce the above copyright notice,
;    this list of conditions and the following disclaimer in the documentation
;    and/or other materials provided with the distribution.
;
; 3. Neither the name of the copyright holder nor the names of its
;    contributors may be used to endorse or promote products derived from
;    this software without specific prior written permission.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
; DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
; FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
; SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
; CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
; OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
; OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;
; ============================================================================

;------------------------------------------------------------------------------
; Initialize variables related to TCBs.
;------------------------------------------------------------------------------

TCBInit:
	lea tcbs,a0
	movec a0,tcba
	moveq #2*8-1,d0		; 2 cores, 32 bytes (8 lwords) per queue
	moveq #-1,d1			; value to set
	lea readyQ,a0			; clear out ready queue
.0001
	move.l d1,(a0)+
	dbra d0,.0001
	move.l #TCB_SIZE*NR_TCB/4-1,d0
.clearTCBs
	clr.l (a0)+
	dbra d0,.clearTCBs
	rts

;------------------------------------------------------------------------------
; Convert a TCB handle into a pointer.
;
; Parameters:
;		d0.w = TCB handle
; Returns:
;		a0 = pointer to TCB
;------------------------------------------------------------------------------

TCBHandleToPointer:
	move.l d1,-(a7)
	andi.l #MAX_TID,d0		; limit to # threads
	movec tcba,d1
	ext.l d0							; assume hTCB < 32768
	subq.l #1,d0
	lsl.l #LOG_TCBSIZE,d0
	add.l d0,d1
	move.l d1,a0
	lsr.l #LOG_TCBSIZE,d0	; restore d0
	addq.l #1,d0
	move.l (a7)+,d1
	rts

;------------------------------------------------------------------------------
; Convert a TCB pointer into a handle.
;
; Parameters:
;		a0 = TCB pointer
; Returns:
;		d0.w = TCB handle
;------------------------------------------------------------------------------

TCBPointerToHandle:
	move.l d1,-(a7)				; save d1
	movec tcba,d1
	sub.l d1,a0
	move.l a0,d0
	lsr.l #LOG_TCBSIZE,d0
	addq.l #1,d0
	move.l (a7)+,d1				; restore d1
	rts

;------------------------------------------------------------------------------
; Internal TCB allocation function.
;
; Parameters:
;		none
; Returns:
;		d0 = handle for allocated TCB, NULL if none available
;------------------------------------------------------------------------------

TCBIAlloc:
	move.w FreeTCB,d0				; d1 = Free handle
	beq .0001
	move.l a0,-(sp)
	bsr TCBHandleToPointer	; convert to pointer
	move.w TCBNext(a0),d1		; d1 = next on free list
	move.w d1,FreeTCB				; update head of free list
	bsr TCBPointerToHandle	; convert pointer to handle
	move.l (sp)+,a0
	rts
	; Here there was no free TCB available. Return a NULL
.0001
	rts
	
;------------------------------------------------------------------------------
; TCB allocation function. Locks the system semaphore during allocation.
;
; Parameters:
;		none
; Returns:
;		d1 = handle for allocated TCB, NULL if none available
;		d0 = E_Ok
;------------------------------------------------------------------------------

TCBAlloc:
	bsr LockSysSemaphore
	bsr	TCBIAlloc
	bsr UnlockSysSemaphore
	moveq #E_Ok,d1
	exg d0,d1
	rts
	
;------------------------------------------------------------------------------
; Internal TCB free function.
;
; Modifies:
;		none
; Parameters:
;		d0 = handle to TCB
; Returns:
;		d0 = handle to TCB
;------------------------------------------------------------------------------

TCBIFree:
	move.l a0,-(sp)
	bsr TCBHandleToPointer
	move.w FreeTCB,TCBNext(a0)
	move.w d0,FreeTCB
	move.l (sp)+,a0
	rts

;------------------------------------------------------------------------------
; TCB free function. Locks the system sempaphore while freeing.
;
; Modifies:
;		none
; Parameters:
;		d0 = handle to TCB
; Returns:
;		d1 = handle to TCB
;		d0 = E_Ok
;------------------------------------------------------------------------------

TCBFree:
	bsr LockSysSemaphore
	bsr TCBIFree
	bsr UnlockSysSemaphore
	moveq #E_Ok,d1
	exg d0,d1
	rts

;------------------------------------------------------------------------------
; Given an affinity, chose the core number to run on.
;
; Parameters:
;		a0 = pointer to TCB
;	Returns:
;		d0 = core number to run on
;------------------------------------------------------------------------------

TCBAffineChose:
	movem.l d1/d3,-(sp)
	move.w #31,d3										; limit number of bit selects to 32
	move.b TCBAffinityBase(a0),d1		; d1 = starting bit
	move.l TCBAffinity(a0),d0				; d0 = affinity mask
.0002
	btst.l d1,d0										; is bit d1 set?
	bne .0001												; if set, exit loop
	addq #1,d1
	dbra d3,.0002
	; no bits set? How?
	move.b #2,TCBAffinityBase(a0)
	moveq #0,d0											; just return core #2 (0)
	rts
.0001
	move.b d1,d0
	subi.b #2,d0										; cores start at #2
	ext.w d0
	ext.l d0
	addq #1,d1											; increment bit selection for next time
	move.b d1,TCBAffinityBase(a0)		; and store in TCB
	movem.l (sp)+,d1/d3
	rts

;------------------------------------------------------------------------------
; Insert thread into ready queue. The thread is added at the tail of the 
; queue. The queue is a doubly linked list.
;
; Stack Space:
;		8 lwords
; Modifies:
;		none
; Parameters:
;		d0 = thread id to insert
; Returns:
;		d0 = TCB handle
; ----------------------------------------------------------------------------

TCBInsertIntoReadyQueue:
	movem.l d1-d3/a0-a3,-(sp)
	move.l d0,d2											; d2 = thread to insert
	bsr TCBHandleToPointer
	move.l a0,a3											; a3 = TCB pointer of thread to insert
	bsr LockSysSemaphore
	ori.b #TS_RUNNING,TCBStatus(a0)
	bsr TCBAffineChose								; Chose which cores queue to use
	lsl.l #5,d0												; 32 bytes per readyQ head/tail per core
	clr.l d1
	move.b TCBPriority(a0),d1					; d1 = priority
	andi.l #7,d1
	lsl.l #2,d1												; 4 bytes per priority level
	add.l d0,d1												; add in base queue
	add.l #readyQ,d1									; add in start of ready queues
	move.l d1,a1
	move.w 4(a1),d0										; d0 = tail entry
	move.w d0,d3											; d3 = tail entry
	tst.w d0
	beq .qempty
	bsr TCBHandleToPointer						; a0 = pointer to tail
	move.l a0,a2
	move.l TCBNext,d0
	bsr TCBHandleToPointer						; a0 = tail->next
	move.l d2,TCBPrev(a0)							; tail->next->prev = new entry
	move.l d2,TCBNext(a2)							; tail->next = new entry
	move.l d0,TCBNext(a3)							; new entry->next = tail->next
	move.l d3,TCBPrev(a3)							; new entry->prev = tail
	bra .0002
.qempty
	tst.w (a1)												; check if there is a list head
	bgt .0002													; head with no tail -> list corrupt
	move.w d2,4(a1)										; head and tail equal new entry
	move.w d2,(a1)
	move.w d2,TCBNext(a3)							; next and prev of new entry point to self
	move.w d2,TCBPrev(a3)
	; Head but no tail, list corrupt?
.0002
	bsr UnlockSysSemaphore
	movem.l (sp)+,d1-d3/a0-a3
	rts

;------------------------------------------------------------------------------
; Remove a thread from the ready queue. Actual removal is not done here, it
; is done the next time the thread is selected to run. Just mark the thread as
; not running.
;
; Parameters:
;		d0 = thread id to remove
; Returns:
;		none
; -----------------------------------------------------------------------------

TCBRemoveFromReadyQueue:
	cmpi.w #0,d0
	beq .0001
	andi.l #MAX_TID,d0									; limit to # of threads
	move.l a0,-(sp)
	bsr	TCBHandleToPointer
	bsr LockSysSemaphore
	andi.b #TS_RUNNING^$FF,TCBStatus(a0)
	bsr UnlockSysSemaphore
	move.l (sp)+,a0
.0001
	rts
	
; ----------------------------------------------------------------------------
; Register Usage
;		d0 = temporary
;		d1 = index into list of queues
;		d2 = index to queue set
;		d4 = queue counter, goes from 7 down to 0
;		d5 = temporary
;		d6 = next on list
;		a0 = temporary pointer to TCB
;		a1 = pointer to queue
;		a2 = pointer to old head of list
;		a3 = pointer to TCB at head of queue
; Modifies:
;		none
; Parameters:
;		none
; Returns:
;		a0 = pointer to TCB, NULL if none on list
;		d0 = TCB handle
; ----------------------------------------------------------------------------

StartQ
	dc.b 1,2,3,4,1,5,6,7

	even
TCBPopReadyQueue:
	movem.l	d1-d6/a1-a3,-(a7)
	movec coreno,d2					; select the queue set based on the core number
	subi.b #2,d2						; cores start at #2
	lsl.l #5,d2							; d2 = index to queue set, 32 bytes per queue set
	moveq #7,d4							; d4 = queue count
	bsr LockSysSemaphore
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
	lea readyQ,a1						; a1 = pointer to list of ready queues
	add.l d2,a1							; a1 = pointer to queue set
	move.w (a1,d1.w),d3			; d3 = old head of list
	blt .nextQ							; anything on list?, if not go next queue
	move.w d3,d0						; d0 = old head of list
	bsr TCBHandleToPointer
	move.l a0,a2						; a2 = pointer to old head of list
	move.w TCBNext(a2),d5		; remove head of list from list
	cmp.l d0,d5							; removing last TCB?
	beq .removeLast
	move.w d5,d6						; d6 = next on list
	move.w d5,d0						; d0 = next on list
	bsr TCBHandleToPointer	; a0 = pointer to next TCB on list
	move.w TCBPrev(a2),d5		; d5 = previous TCB from head
	move.w d5,TCBPrev(a0)		; next->prev = head->prev
	move.w d5,d0
	bsr TCBHandleToPointer	; a0 = pointer to previous TCB from head
	move.w d6,TCBNext(a0)		; head->prev->next = next
.0003
	move.w d6,(a1,d1.w)			; reset head of list to next
	move.w d3,TCBNext(a2)		; point links back to self
	move.w d3,TCBPrev(a2)
	move.w d3,d0						; return handle in d0
	ext.l d0
	move.l a2,a0						; return pointer in a0
.0004
	bsr UnlockSysSemaphore
	movem.l	(a7)+,d1-d6/a1-a3
	rts
.removeLast
	moveq #-1,d6						; set head to negative when removing last
	move.w d6,2(a1,d1.w)		; tail = negative
	bra .0003
.nextQ
	addi.w #4,d1						; increment queue number by lword
	andi.w #$1C,d1					; limit to number of queues
	dbra d4,.0002						; go back and check the next queue
	moveq #-1,d0						; return handle < 0 if nothing in any queue
	suba.l a0,a0						; and NULL pointer
	bra	.0004								; return NULL pointer if nothing in any queue

;------------------------------------------------------------------------------
; Remove a thread from the timeout list.
; Called when a mailbox is freed and a thread is waiting at the
; mailbox.
;
; Parameters:
;		d0 = task id to remove
; Modifies:
;		none
; Returns:
;		none
;------------------------------------------------------------------------------

TCBRemoveFromTimeoutList:
	movem.l d0/d1/d2/a0/a1/a2,-(sp)
	cmp.w TimeoutList,d0			; head of timeout list?
	beq.s 0001
	bsr TCBHandleToPointer
	move.l a0,a1
	move.w TCBNext(a1),d0			; d0 = next
	move.w TCBPrev(a1),d1			; d1 = prev
	move.w d0,d2							; d2 = next
	bsr TCBHandleToPointer
	move.l a0,a2							; a2 = next
	move.l d1,TCBPrev(a2)			; next->prev = prev
	move.w d1,d0
	bsr TCBHandleToPointer		; a0 = prev
	move.w d2,TCBNext(a0)			; prev->next = next
.0002
	clr.w TCBNext(a1)
	clr.w TCBPrev(a1)
	movem.l (sp)+,d0/d1/d2/a0/a1/a2
	rts
.0001
	bsr TCBHandleToPointer
	move.w TCBNext(a0),d0			; d0 = next
	move.w d0,TimeoutList			; timeoutList = next
	bsr TCBHandleToPointer		; a0 = next
	clr.w TCBPrev(a0)					; next->prev = NULL
	bra .0002

;// ----------------------------------------------------------------------------
;// Pop the top entry from the timeout list.
;// ----------------------------------------------------------------------------
;
;hTCB PopTimeoutList()
;{
;    TCB *p;
;    hTCB h;
;
;    h = TimeoutList;
;    if (TimeoutList > 0 && TimeoutList < NR_TCB) {
;        TimeoutList = tcbs[TimeoutList].next;
;        if (TimeoutList >= 0 && TimeoutList < NR_TCB) {
;            tcbs[TimeoutList].prev = h->prev;
;            h->prev->next = TimeoutList;
;        }
;    }
;    return h;
;}
;
; Returns:
;		d0.w = task at top of list
;

TCBPopTimeoutList:
	movem.l d1/d2/d3/a0/a1,-(sp)
	move.w TimeoutList,d0
	move.w d0,d3							; save for later
	tst.w d0									; anything on the timeout list?
	beq.s .0001
	cmpi.w #NR_TCB,d0					; hTCB in range?
	bhs.s .0001
	bsr TCBHandleToPointer		; a0 = timeoutList
	move.l a0,a1							; a1 = timeoutList
	move.w TCBNext(a1),d0			; d0 = timeoutList->next
	move.w d0,d2							; save next for later
	move.w TCBPrev(a1),d1			; d1 = timeoutList->prev
	move.w d0,TimeoutList			; TimeoutList = next
	tst.w d0
	beq.s .0001
	cmpi.w #NR_TCB,d0
	bhs.s .0001
	bsr TCBHandleToPointer		; a0 = timeoutList
	move.l d1,TCBPrev(a0)			; timeoutList->prev = prev
	move.l d1,d0
	bsr TCBHandleToPointer		; a0 = prev
	move.l d2,TCBNext(a0)			; prev->next = next
	clr.w TCBNext(a1)
	clr.w TCBPrev(a1)
	move.w d3,d0
.0001
	ext.l d0
	movem.l (sp)+,d1/d2/d3/a0/a1
	rts

; ----------------------------------------------------------------------------
; ----------------------------------------------------------------------------

DispTwoSpace:
	bsr	DispSpace
DispSpace:
	move.l #' ',-(sp)
	bsr _OutputChar
	add.l #4,sp
	rts

DumpTCBs:
	bsr _OutputCRLF
	lea msgTID,a0
	move.l a0,-(sp)
	bsr _OutputStringCRLF
	add.l #4,sp
	moveq #1,d0
.0002:
	bsr TCBHandleToPointer
	move.w TCBtid(a0),d0
	bsr _DisplayWyde
	bsr DispSpace
	move.b TCBStatus(a0),d0
	bsr _DisplayByte
	bsr DispTwoSpace
	bsr _OutputCRLF
	move.w TCBNext(a0),d0
	tst.w d0
	bne.s .0002
	rts

msgTID
	dc.b " TID Stat",0


