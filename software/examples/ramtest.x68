;===============================================================================
;    Perform ram test. (Uses checkerboard testing).
; 
;    Local ram, which does not get tested, is used for the stack.
;===============================================================================
	code
	even
DisplayAddr:
	move.l a0,d1
	moveq #20,d2
	lsr.l d2,d1
	subi.w #1024,d1
	bin2bcd d1
	bsr	DisplayWyde
	bsr DisplaySpace
	move.b #CR,d1
	bsr _OutputChar
	rts
	
cmdTestRAM:
ramtest:
	move.w	#$A5A5,leds		; diagnostics
  move.l #$aaaaaaaa,d3
  move.l #$55555555,d4
  bsr ramtest0
  ; switch checkerboard pattern and repeat test.
  exg d3,d4
  bsr ramtest0
	; Save last ram address in end of memory pointer.
rmtst5:
	moveq #37,d0					; lock semaphore
	moveq #MEMORY_SEMA,d1
;	trap #15
  movea.l #$7FFFFFE0,a0
  move.l a0,memend
	; Create very first memory block.
  movea.l #$3FFFFFD0,a0
  move.l a0,$40000004		; length of block
  move.l #$46524545,$40000000
	moveq #38,d0					; unlock semaphore
	moveq #MEMORY_SEMA,d1
	trap #15
	bra Monitor
;  rts

ramtest0:
	move.l d3,d0
  movea.l #$40000000,a0
;-----------------------------------------------------------
;   Write checkerboard pattern to ram then read it back to
; find the highest usable ram address (maybe). This address
; must be lower than the start of the rom (0xe00000).
;-----------------------------------------------------------
ramtest1:
  move.l d3,(a0)+
  move.l d4,(a0)+
  move.l a0,d1
  tst.w	d1
  bne.s rmtst1
  bsr DisplayAddr
  jsr CheckForCtrlC
rmtst1:
  cmpa.l #$7FFFFFC0,a0
  blo.s ramtest1
  bsr	CRLF
;------------------------------------------------------
;   Save maximum useable address for later comparison.
;------------------------------------------------------
ramtest6:
	move.w	#$A7A7,leds		; diagnostics
  movea.l a0,a2
  movea.l #$40000000,a0
;--------------------------------------------
;   Read back checkerboard pattern from ram.
;--------------------------------------------
ramtest2
  move.l (a0)+,d5
  move.l (a0)+,d6
  cmpa.l a2,a0
  bhs.s	ramtest3
  move.l a0,d1
  tst.w	d1
  bne.s	rmtst2
  bsr	DisplayAddr
	jsr CheckForCtrlC
rmtst2
  cmp.l d3,d5
  bne.s rmtst3
  cmp.l d4,d6
  beq.s ramtest2
;----------------------------------
; Report error in ram.
;----------------------------------
rmtst3
	bsr CRLF
	moveq	#'E',d1
	bsr _OutputChar
	bsr DisplaySpace
	move.l a0,d1
	bsr DisplayTetra
	bsr DisplaySpace
	move.l d5,d1
	bsr DisplayTetra
	jsr CheckForCtrlC
	bra ramtest2
ramtest3
	rts
