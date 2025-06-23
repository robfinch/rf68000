;=============================================================================
; This routine will place the link block pointed to by a1 onto the exchange
; pointed to by the a2 register. If a1 is NULL then the routine returns.
;
; Parameters:
;		a1 = pLB
;		a2 = pExch
;
;
enQueueMsg:
	tst.l a1								; if pLBin = NULL THEN Return;
	beq.s .0001
	tst.l a2								; if pExch = NULL return
	beq.s .0001
	clr.l NextLB(a1)
	tst.l EHead(a2)					; if MsgHead==NULL
	bne.s .0002
	move.l a1,EHead(a2)			; set MsgHead = pLBin
	move.l a1,ETail(a2)			; set MsgTail = pLBin
	move.l #1,fEMsg(a2)			; Flag it as a Msg (vice a task)
	rts
.0002
	move.l a3,-(sp)
	move.l ETail(a2),a3			; a3 = msgTail
	move.l a1,NextLB(a3)		; MsgTail->NextLB = pLBin
	move.l a1,Etail(a2)			; MsgTail = pLBin
	move.l #1,fEMsg(a2)			; Flag it as a Msg (vice a task)
	move.l (sp)+,a3
	rts	
.0001
	rts

;=============================================================================
; This routine will dequeue a link block on the exchange pointed to by the
; a1 register and place the pointer to the link block dequeued into d1.
;
; MODIFIES : *prgExch[ESI].msg.head and EBX
;
; Parameters:
;		a1 = pointer to exchange
; Returns:
;		d1 = pointer to message, NULL is non available

deQueueMsg:
	move.l fEMsg(a1),d1				; Get Msg Flag
	tst.l d1
	beq.s .0001								; If not a Msg just return
	move.l a2,-(sp)						
	move.l EHead(a1),a2				; any Msg queued?
	tst.l a2
	beq.s .0002
	move.l NextLB(a2),d1
	move.l d1,EHead(a1)				; MsgHead = MsgHead->next
	move.l a2,d1							; return pLB
	move.l (sp)+,a2
.0001
	rts
.0002
	move.l (sp)+,a2
	clr.l d1
	rts

;=============================================================================
; This routine will dequeue a TCB on the exchange pointed to by the a1
; register and place the pointer to the TCB dequeued into d1.
; d1 return NULL if no PCB is waiting at Exch a1
;
; Parameters:
;		a1 = pointer to exchange
; Returns:
;		d1 = pointer to task control block
;

deQueueTCB:
	clr.l d1						; setup to return NULL
	tst.l fEMsg(a1)			; Is a Msg(1) or a Process(0) queued?
	bne.s .0001					; If Msg no process to dequeue
	move.l EHead(a1),d1
	tst.l d1						; ensure TCB pointer is not NULL
	beq.s .0001
	move.l a2,-(sp)
	move.l d1,a2				; Update link list
	move.l NextTCB(a2),EHead(a1)
	move.l (sp)+,a2
.0001
	rts

;=============================================================================
; This routine will place a TCB pointed to by a1 onto the ReadyQueue. This
; algorithm chooses the proper priority queue based on the TCB priority.
; The Rdy Queue is an array of QUEUES (2 pointers, head & tail per QUEUE).
; This links the TCB to rgQueue[nPRI].
;
;	Parameters:
;		a1 = PCB pointer
;	Returns:
;		none
;
enQueueRdy:
	tst.l a1									; if pTCB = NULL return
	beq.s .0001
	movem.l d2/a2,-(sp)
	add.l #1,_nReady					;
	clr.l NextTCB(a1)					; pTCB->next = NULL
	move.b Priority(a1),d2		; d2 = priority
	andi.b #$3F,d2						; limit to 0 to 63
	ext.w d2
	lsl.w #3,d2								; select RDY queue
	lea RdyQ,a2
	tst.l Head(a2,d2.w)				; If head of RDYQ is NULL
	bne .0002
	move.l a1,Head(a2,d2.w)		; add at head and tail
	move.l a1,Tail(a2,d2.w)
	movem.l (sp)+,d2/a2
.0001
	rts
.0002
	move.l a3,-(sp)						; Otherwise
	move.l Tail(a2,d2.w),a3		; add to tail
	move.l a1,NextTCB(a3)
	move.l a1,Tail(a2,d2.w)
	move.l (sp)+,a3
	movem.l (sp)+,d2/a2
	rts

;=============================================================================
; This routine will return a pointer in d1 to the highest priority task
; queued on the RdyQ. Then the routine will "pop" the TCB from the RdyQ.
; If there was no task queued, d1 is returned as NULL.
;
; Parameters:
;		none
; Returns:
;		d1 = pointer to highest priority task control block
;

deQueueRdy:
	movem.l d3/a1/a2,-(sp)
	moveq #nPRI-1,d3					; Set up the number of times to loop
	lea RdyQ,a1								; Get base address of RdyQ in a1
.0001
	move.l (a1),d1						; Get pTCBout in d1
	tst.l d1									; if pPCB is NULL
	bne.s .0002								; check the next priority
	add.l #sQUEUE,a1					; move to the next QUE
	dbra d3,.0001
.0002
	tst.l d1									; finshed looping or found PCB
	beq.s .done
	sub.l #1,_nReady					; decrease number of ready
	move.l d1,a2
	move.l NextTCB(a2),d3		; move NextTCB into QUEUE
	move.l d3,(a1)
.done
	movem.l (sp)+,d3/a1/a2
	rts

;=============================================================================
; This routine will return a pointer to the highest priority TCB that
; is queued to run. It WILL NOT remove it from the Queue.
; If there was no task queued, d1 is returned as NULL.
;
; Parameters:
;		none
; Returns:
;		d1 = pointer to PCB of highest priority queued
;

ChkRdyQ:
	movem.l d3/a1,-(sp)
	moveq #nPRI-1,d3					; number of times to loop
	lea RdyQ,a1								; base address of ready queues
.0001
	move.l (a1),d1						; d1 = PCB pointer
	tst.l d1									; anything there?
	bne.s .0002								; yep, we're done search
	add.l #sQUEUE,a1					; nope, move to next queue
	dbra d3,.0001
.0002
	movem.l (sp)+,d3/a1
	rts

;=============================================================================
;================= BEGIN NEAR KERNEL HELPER ROUTINES =========================
;=============================================================================

; RemoveRdyJob  (NEAR)
;
; This routine searchs all ready queue priorities for tasks belonging
; to pJCB. When one is found it is removed from the queue
; and the TSS is freed up.  This is called when we are killing
; a job.
;
; Procedural Interface :
;
;		RemoveRdyJob(char *pPCB):ercType
;
; Parameters:
;		d1 = pointer to PCB
;
;	pPCB is a pointer to the PCB that the tasks to kill belong to.
;
; pPCB		 	EQU DWORD PTR [EBP+8]
;
; INPUT :  (pJCB on stack)
; OUTPUT : NONE
; REGISTERS : All general registers are trashed
; MODIFIES : RdyQ
;
;
_RemoveRdyJob:
	moveq #nPRI-1,d3					; number of times to loop
	lea a1,RdyQ								; a1 points to ready queue
	move.l d1,d4							; d4 holds pPCB for comparison
	
		;EBX points to begining of next Priority Queue
RemRdyLoop:
	move.l Head(a1),d1
	move.l d1,a2
	tst.l d1
	bne.s RemRdy0
	    MOV EAX,[EBX+Head]      ; Get pTSS in EAX
		MOV EDI, EAX			; EDI points to last TSS by default (or NIL)
		OR  EAX,EAX             ; Is pTSS 0 (none left queued here)
		JNZ RemRdy0		        ; Valid pTSS!
RemRdyLoop1:
		MOV [EBX+Tail], EDI		; EDI always points to last TSS or NIL
		ADD EBX,sQUEUE          ; Point to the next Priority Queue
		LOOP RemRdyLoop         ; DEC ECX and LOOP IF NOT ZERO

		XOR EAX, EAX			; No error
		POP EBP
		RETN 4					; All done (clean stack)

		;Go here to dequeue a TSS at head of list
RemRdy0:
		CMP EDX, [EAX+TSS_pJCB]	; Is this from the JCB we want?
		JNE RemRdy2				; No

		MOV EDI, [EAX+NextTSS]  ; Yes, deQueue the TSS
		MOV [EBX+Head], EDI     ; Fix link in Queue list

		PUSH EBX				; Save ptr to RdyQue (crnt priority)

		;Free up the TSS (add it to the free list)
		MOV EBX,pFreeTSS        ; pTSSin^.Next <= pFreeTSS;
		MOV [EAX+NextTSS],EBX   ;
		MOV DWORD PTR [EAX+TSS_pJCB], 0	; Make TSS invalid
		MOV pFreeTSS,EAX        ; pFreeTSS <= pTSSin;
		INC _nTSSLeft			;

		POP EBX
		MOV EAX, EDI 		    ; Make EAX point to new head TSS
		OR EAX, EAX				; Is it Zero?
		JZ RemRdyLoop1			; Next Queue please
		JMP RemRdy0				; back to check next at head of list

		;Go here to dequeue a TSS in middle or end of list
RemRdy2:
		MOV EAX, [EDI+NextTSS]	; Get next link in list
		OR EAX, EAX				; Valid pTSS?
		JZ RemRdyLoop1			; No. Next Queue please
		CMP EDX, [EAX+TSS_pJCB]	; Is this from JCB we want?
		JE RemRdy3				; Yes. Trash it.
		MOV	EDI, EAX			; No. Next TSS
		JMP RemRdy2
RemRdy3:
		;EDI points to prev TSS
		;EAX points to crnt TSS
		;Make ESI point to NextTSS

		MOV ESI, [EAX+NextTSS]  ; Yes, deQueue the TSS

		;Now we fix the list (Make Prev point to Next)
		;This extracts EAX from the list

		MOV [EDI+NextTSS], ESI	;Jump the removed link
		PUSH EBX				;Save ptr to RdyQue (crnt priority)

		;Free up the TSS (add it to the free list)
		MOV EBX,pFreeTSS        ; pTSSin^.Next <= pFreeTSS;
		MOV [EAX+NextTSS],EBX   		;
		MOV DWORD PTR [EAX+TSS_pJCB], 0	; Make TSS invalid
		MOV pFreeTSS,EAX    	    	; pFreeTSS <= pTSSin;
		INC _nTSSLeft					;

		POP EBX
		;
		OR  ESI, ESI			;Is EDI the new Tail? (ESI = 0)
		JZ  RemRdyLoop1			;Yes. Next Queue please
		JMP RemRdy2				;back to check next TSS

;=============================================================================
; GetExchOwner  (NEAR)
;
; This routine returns the owner of the exchange specified.
; A pointer to the JCB of the owner is returned.
; ErcNotAlloc is returned if the exchange isn't allocated.
; ErcOutofRange is returned is the exchange number is invalid (too high)
;
; Procedureal Interface :
;
;		GetExchOwner(long Exch, char *pJCBRet): dErrror
;
;	Exch is the exchange number.
;	pJCBRet is a pointer to the JCB that the tasks to kill belong to.
;
; Exch	 	EQU DWORD PTR [EBP+12]
; pJCBRet 	EQU DWORD PTR [EBP+8]

PUBLIC _GetExchOwner:	        ;
		PUSH EBP                ;
		MOV EBP,ESP             ;

		MOV EAX, [EBP+12]		; Get Resp Exchange in EDX
		CMP EAX,nExch           ; Is the exchange out of range?
		JB GEO01	            ; No, continue
		MOV EAX,ErcOutOfRange   ; Yes, Error in EAX register
		JMP GEOEnd				;
GEO01:
		MOV EDX,sEXCH           ; Compute offset of Exch in rgExch
		MUL EDX                 ; sExch * Exch number
		MOV EDX,prgExch         ; Add offset of rgExch => EAX
		ADD EDX,EAX             ; EDX -> Exch
		MOV EAX, [EDX+Owner]
		OR EAX, EAX				; Valid Exch (Allocated)
		JNZ GEO02
		MOV EAX, ErcNotAlloc	; No, not allocated
		JMP SHORT GEOEnd
GEO02:
		MOV ESI, [EBP+8]		;Where to return pJCB of Exchange
		MOV [ESI], EAX			;
		XOR EAX, EAX
GEOEnd:
		MOV ESP,EBP             ;
		POP EBP                 ;
		RETN 8                  ;

