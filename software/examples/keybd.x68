;==============================================================================
; Keyboard stuff
;
; KeyState2_
; 876543210
; ||||||||+ = shift
; |||||||+- = alt
; ||||||+-- = control
; |||||+--- = numlock
; ||||+---- = capslock
; |||+----- = scrolllock
; ||+------ =
; |+------- = 
; +-------- = extended
;
;==============================================================================

;------------------------------------------------------------------------------
; Setup the Keyboard device
;------------------------------------------------------------------------------
setup_keybd:
keybd_init:
	movem.l d0/a0/a1,-(a7)
	moveq #32,d0
	lea.l keybd_dcb,a0
.0001:
	clr.l (a0)+
	dbra d0,.0001
	move.l #$44434220,keybd_dcb+DCB_MAGIC				; 'DCB '
	move.l #$4B424400,keybd_dcb+DCB_NAME				; 'KBD'
	move.l #keybd_cmdproc,keybd_dcb+DCB_CMDPROC
	move.l #_KeybdBuf,keybd_dcb+DCB_INBUFPTR
	move.l #_KeybdOBuf,keybd_dcb+DCB_OUTBUFPTR
	move.l #32,keybd_dcb+DCB_INBUFSIZE
	move.l #32,keybd_dcb+DCB_OUTBUFSIZE
	clr.b keybd_dcb+DCB_OUTDIMX	; set rows and columns
	clr.b keybd_dcb+DCB_OUTDIMY
	clr.b keybd_dcb+DCB_INDIMX		; set rows and columns
	clr.b keybd_dcb+DCB_INDIMY
;	bsr KeybdInit
	lea.l keybd_dcb+DCB_MAGIC,a1
	jsr DisplayString
	jsr CRLF
	movem.l (a7)+,d0/a0/a1
	rts

	align 2
KBD_CMDTBL:
	dc.l keybd_init				; 0
	dc.l keybd_stat
	dc.l keybd_putchar
	dc.l keybd_putbuf
	dc.l keybd_getchar
	dc.l keybd_getbuf
	dc.l keybd_set_inpos
	dc.l keybd_set_outpos

keybd_cmdproc:
	cmpi.b #8,d6
	bhs.s .0001
	movem.l d6/a0,-(a7)
	asl.b #2,d6
	ext.w d6
	lea KBD_CMDTBL,a0
	move.l (a0,d6.w),a0
	jsr (a0)
	movem.l (a7)+,d6/a0
	rts
.0001:
	moveq #E_Func,d0
	rts

keybd_stat:
	bsr _KeybdGetStatus
	moveq #E_Ok,d0
	rts

keybd_putchar:
	bsr KeybdSendByte
	moveq #E_Ok,d0
	rts

keybd_getchar:
	bsr GetKey
	moveq #E_Ok,d0
	rts

keybd_putbuf:
keybd_getbuf:
keybd_set_inpos:
keybd_set_outpos:
	moveq #E_NotSupported,d0
	rts

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Get ID - get the keyboards identifier code.
;
; Parameters: none
; Returns: d = $AB83, $00 on fail
; Modifies: d, KeybdID updated
; Stack Space: 2 words
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

KeybdGetID:
	move.w	#$F2,d1
	bsr			KeybdSendByte
	bsr			KeybdWaitTx
	bsr			KeybdRecvByte
	btst		#7,d1
	bne			kgnotKbd
	cmpi.b	#$AB,d1
	bne			kgnotKbd
	bsr			KeybdRecvByte
	btst		#7,d1
	bne			kgnotKbd
	cmpi.b	#$83,d1
	bne			kgnotKbd
	move.l	#$AB83,d1
kgid1:
	move.w	d1,KeybdID
	rts
kgnotKbd:
	moveq		#0,d1
	bra			kgid1

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Set the LEDs on the keyboard.
;
; Parameters:
;		d1.b = LED state
;	Modifies:
;		none
; Returns:
;		none
; Stack Space:
;		1 long word
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

KeybdSetLED:
	move.l	d1,-(a7)
	move.b	#$ED,d1
	bsr			KeybdSendByte
	bsr			KeybdWaitTx
	bsr			KeybdRecvByte
	tst.b		d1
	bmi			.0001
	cmpi.b	#$FA,d1
	move.l	(a7),d1
	bsr			KeybdSendByte
	bsr			KeybdWaitTx
	bsr			KeybdRecvByte
.0001:
	move.l	(a7)+,d1
	rts

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Initialize the keyboard.
;
; Parameters:
;		none
;	Modifies:
;		none
; Returns:
;		none
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

_KeybdInit:
KeybdInit:
;	movem.l	d0/d1/d3/a1,-(a7)
	clr.b	_KeyState1		; records key up/down state
	clr.b	_KeyState2		; records shift,ctrl,alt state
	rts

	bsr			Wait300ms
	bsr			_KeybdGetStatus	; wait for response from keyboard
	tst.b		d1
	bpl			.0001					; is input buffer full ? no, branch
	bsr	_KeybdGetScancode
	bsr _KeybdClearIRQ
	cmpi.b	#$AA,d1				; keyboard Okay
	beq			kbdi0005
.0001:
	moveq		#10,d3
kbdi0002:
	bsr			Wait10ms
	clr.b		KEYBD+1				; clear receive register (write $00 to status reg)
	bsr net_delay
	moveq		#-1,d1				; send reset code to keyboard
	move.b	d1,KEYBD+1		; write $FF to status reg to clear TX state
	bsr net_delay
	bsr			KeybdSendByte	; now write ($FF) to transmit register for reset
	bsr			KeybdWaitTx		; wait until no longer busy
	tst.l		d1
	bmi			kbdiXmitBusy
	bsr			KeybdRecvByte	; look for an ACK ($FA)
	cmpi.b	#$FA,d1
	bne			.0001
	bsr			KeybdRecvByte	; look for BAT completion code ($AA)
.0001:
	cmpi.b	#$FC,d1				; reset error ?
	beq			kbdiTryAgain
	cmpi.b	#$AA,d1				; reset complete okay ?
	bne			kbdiTryAgain

	; After a reset, scan code set #2 should be active
.config:
	move.w	#$F0,d1			; send scan code select
	move.b	d1,leds
	bsr net_delay
	bsr			KeybdSendByte
	bsr			KeybdWaitTx
	tst.l		d1
	bmi			kbdiXmitBusy
	bsr			KeybdRecvByte	; wait for response from keyboard
	tst.w		d1
	bmi			kbdiTryAgain
	cmpi.b	#$FA,d1				; ACK
	beq			kbdi0004
kbdiTryAgain:
	dbra		d3,kbdi0002
.keybdErr:
	lea			msgBadKeybd,a1
	bsr			DisplayStringCRLF
	bra			ledxit
kbdi0004:
	moveq		#2,d1			; select scan code set #2
	bsr			KeybdSendByte
	bsr			KeybdWaitTx
	tst.l		d1
	bmi			kbdiXmitBusy
	bsr			KeybdRecvByte	; wait for response from keyboard
	tst.w		d1
	bmi			kbdiTryAgain
	cmpi.b	#$FA,d1
	bne			kbdiTryAgain
kbdi0005:
	bsr			KeybdGetID
ledxit:
	moveq		#$07,d1
	bsr			KeybdSetLED
	bsr			Wait300ms
	moveq		#$00,d1
	bsr			KeybdSetLED
	movem.l	(a7)+,d0/d1/d3/a1
	rts
kbdiXmitBusy:
	lea			msgXmitBusy,a1
	bsr			DisplayStringCRLF
	movem.l	(a7)+,d0/d1/d3/a1
	rts
	
msgBadKeybd:
	dc.b		"Keyboard error",0
msgXmitBusy:
	dc.b		"Keyboard transmitter stuck",0

	even
_KeybdGetStatus:
	movec coreno,d1
	cmpi.b #2,d1
	bne .0001
	moveq	#0,d1
	move.b KEYBD+1,d1
	rts
.0001:
	moveq #0,d1
	move.b KEYBD+3,d1
	rts

; Get the scancode from the keyboard port

_KeybdGetScancode:
	movec coreno,d1
	cmpi.b #2,d1
	bne .0001
	moveq		#0,d1
	move.b	KEYBD,d1				; get the scan code
	rts
.0001:
	moveq #0,d1
	move.b KEYBD+2,d1
	rts

_KeybdClearIRQ:
	move.l d1,-(a7)
	movec coreno,d1
	cmpi.b #2,d1
	bne .0001
	move.b	#0,KEYBD+1			; clear receive register
.0001:
	move.l (a7)+,d1
	rts

; Recieve a byte from the keyboard, used after a command is sent to the
; keyboard in order to wait for a response.
;
KeybdRecvByte:
	move.l	d3,-(a7)
	move.w	#100,d3		; wait up to 1s
.0003:
	bsr			_KeybdGetStatus	; wait for response from keyboard
	tst.b		d1
	bmi			.0004			; is input buffer full ? yes, branch
	bsr			Wait10ms	; wait a bit
	dbra		d3,.0003	; go back and try again
	move.l	(a7)+,d3
	moveq		#-1,d1		; return -1
	rts
.0004:
	bsr	_KeybdGetScancode
	bsr _KeybdClearIRQ
	move.l	(a7)+,d3
	rts


; Wait until the keyboard transmit is complete
; Returns -1 if timedout, 0 if transmit completed
;
KeybdWaitTx:
	movem.l	d2/d3,-(a7)
	moveq		#100,d3		; wait a max of 1s
.0001:
	bsr	_KeybdGetStatus
	btst #6,d1				; check for transmit complete bit
	bne	.0002					; branch if bit set
	bsr	Wait10ms			; delay a little bit
	dbra d3,.0001			; go back and try again
	movem.l	(a7)+,d2/d3
	moveq	#-1,d1			; return -1
	rts
.0002:
	movem.l	(a7)+,d2/d3
	moveq	#0,d1		; return 0
	rts

;------------------------------------------------------------------------------
; d1.b 0=echo off, non-zero = echo on
;------------------------------------------------------------------------------

SetKeyboardEcho:
	move.b	d1,KeybdEcho
	rts

;------------------------------------------------------------------------------
; Get key pending status into d1.b
;
; Returns:
;		d1.b = 1 if a key is available, otherwise zero.
;------------------------------------------------------------------------------

CheckForKey:
	moveq.l	#0,d1					; clear high order bits
;	move.b	KEYBD+1,d1		; get keyboard port status
;	smi.b		d1						; set true/false
;	andi.b	#1,d1					; return true (1) if key available, 0 otherwise
	tst.b	_KeybdCnt
	sne.b	d1
	rts

;------------------------------------------------------------------------------
; GetKey
; 	Get a character from the keyboard. 
;
; Modifies:
;		d1
; Returns:
;		d1 = -1 if no key available or not in focus, otherwise key
;------------------------------------------------------------------------------

GetKey:
	move.l	d0,-(a7)					; push d0
	move.b	IOFocus,d1				; Check if the core has the IO focus
	movec.l	coreno,d0
	cmp.b	d0,d1
	bne.s	.0004								; go return no key available, if not in focus
	bsr	KeybdGetCharNoWait		; get a character
	tst.l	d1									; was a key available?
	bmi.s	.0004
	tst.b	KeybdEcho						; is keyboard echo on ?
	beq.s	.0003								; no echo, just return the key
	cmpi.b #CR,d1							; convert CR keystroke into CRLF
	bne.s	.0005
	bsr	CRLF
	bra.s	.0003
.0005:
	bsr	OutputChar
.0003:
	move.l (a7)+,d0						; pop d0
	rts												; return key
; Return -1 indicating no char was available
.0004:
	move.l (a7)+,d0						; pop d0
	moveq	#-1,d1							; return no key available
	rts

;------------------------------------------------------------------------------
; Check for the cntrl-C keyboard sequence. Abort running routine and drop
; back into the monitor.
;------------------------------------------------------------------------------

CheckForCtrlC:
	move.l d1,-(a7)
	bsr	KeybdGetCharNoWait
	cmpi.b #CTRLC,d1
	beq	Monitor
	move.l (a7)+,d1
	rts

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

KeybdGetCharNoWait:
	clr.b	KeybdWaitFlag
	bra	KeybdGetChar

KeybdGetCharWait:
	move.b #-1,KeybdWaitFlag

KeybdGetChar:
	movem.l	d0/d2/d3/a0,-(a7)
.0003:
	movec	coreno,d0
	swap d0
	moveq	#KEYBD_SEMA,d1
	bsr	LockSemaphore
	move.b	_KeybdCnt,d2		; get count of buffered scan codes
	beq.s		.0015						;
	move.b	_KeybdHead,d2		; d2 = buffer head
	ext.w		d2
	lea			_KeybdBuf,a0		; a0 = pointer to keyboard buffer
	clr.l		d1
	move.b	(a0,d2.w),d1		; d1 = scan code from buffer
	addi.b	#1,d2						; increment keyboard head index
	andi.b	#31,d2					; and wrap around at buffer size
	move.b	d2,_KeybdHead
	subi.b	#1,_KeybdCnt		; decrement count of scan codes in buffer
	exg			d1,d2						; save scancode value in d2
	movec		coreno,d0
	swap		d0
	moveq		#KEYBD_SEMA,d1
	bsr			UnlockSemaphore
	exg			d2,d1						; restore scancode value
	bra			.0001						; go process scan code
.0014:
	bsr		_KeybdGetStatus		; check keyboard status for key available
	bmi		.0006							; yes, go process
.0015:
	movec		coreno,d0
	swap		d0
	moveq		#KEYBD_SEMA,d1
	bsr			UnlockSemaphore
	tst.b		KeybdWaitFlag			; are we willing to wait for a key ?
	bmi			.0003							; yes, branch back
	movem.l	(a7)+,d0/d2/d3/a0
	moveq		#-1,d1						; flag no char available
	rts
.0006:
	bsr	_KeybdGetScancode
	bsr _KeybdClearIRQ
.0001:
	move.w	#1,leds
	cmp.b	#SC_KEYUP,d1
	beq		.doKeyup
	cmp.b	#SC_EXTEND,d1
	beq		.doExtend
	cmp.b	#SC_CTRL,d1
	beq		.doCtrl
	cmp.b	#SC_LSHIFT,d1
	beq		.doShift
	cmp.b	#SC_RSHIFT,d1
	beq		.doShift
	cmp.b	#SC_NUMLOCK,d1
	beq		.doNumLock
	cmp.b	#SC_CAPSLOCK,d1
	beq		.doCapsLock
	cmp.b	#SC_SCROLLLOCK,d1
	beq		.doScrollLock
	cmp.b   #SC_ALT,d1
	beq     .doAlt
	move.b	_KeyState1,d2			; check key up/down
	move.b	#0,_KeyState1			; clear keyup status
	tst.b	d2
	bne	    .0003					; ignore key up
	cmp.b   #SC_TAB,d1
	beq     .doTab
.0013:
	move.b	_KeyState2,d2
	bpl		.0010					; is it extended code ?
	and.b	#$7F,d2					; clear extended bit
	move.b	d2,_KeyState2
	move.b	#0,_KeyState1			; clear keyup
	lea		_keybdExtendedCodes,a0
	move.b	(a0,d1.w),d1
	bra		.0008
.0010:
	btst	#2,d2					; is it CTRL code ?
	beq		.0009
	and.w	#$7F,d1
	lea		_keybdControlCodes,a0
	move.b	(a0,d1.w),d1
	bra		.0008
.0009:
	btst	#0,d2					; is it shift down ?
	beq  	.0007
	lea		_shiftedScanCodes,a0
	move.b	(a0,d1.w),d1
	bra		.0008
.0007:
	lea		_unshiftedScanCodes,a0
	move.b	(a0,d1.w),d1
	move.w	#$0202,leds
.0008:
	move.w	#$0303,leds
	movem.l	(a7)+,d0/d2/d3/a0
	rts
.doKeyup:
	move.b	#-1,_KeyState1
	bra		.0003
.doExtend:
	or.b	#$80,_KeyState2
	bra		.0003
.doCtrl:
	move.b	_KeyState1,d1
	clr.b	_KeyState1
	tst.b	d1
	bpl.s	.0004
	bclr	#2,_KeyState2
	bra		.0003
.0004:
	bset	#2,_KeyState2
	bra		.0003
.doAlt:
	move.b	_KeyState1,d1
	clr.b	_KeyState1
	tst.b	d1
	bpl		.0011
	bclr	#1,_KeyState2
	bra		.0003
.0011:
	bset	#1,_KeyState2
	bra		.0003
.doTab:
	move.l	d1,-(a7)
  move.b  _KeyState2,d1
  btst	#1,d1                 ; is ALT down ?
  beq     .0012
;    	inc     _iof_switch
  move.l	(a7)+,d1
  bra     .0003
.0012:
  move.l	(a7)+,d1
  bra     .0013
.doShift:
	move.b	_KeyState1,d1
	clr.b	_KeyState1
	tst.b	d1
	bpl.s	.0005
	bclr	#0,_KeyState2
	bra		.0003
.0005:
	bset	#0,_KeyState2
	bra		.0003
.doNumLock:
	bchg	#4,_KeyState2
	bsr		KeybdSetLEDStatus
	bra		.0003
.doCapsLock:
	bchg	#5,_KeyState2
	bsr		KeybdSetLEDStatus
	bra		.0003
.doScrollLock:
	bchg	#6,_KeyState2
	bsr		KeybdSetLEDStatus
	bra		.0003

KeybdSetLEDStatus:
	movem.l	d2/d3,-(a7)
	clr.b		KeybdLEDs
	btst		#4,_KeyState2
	beq.s		.0002
	move.b	#2,KeybdLEDs
.0002:
	btst		#5,_KeyState2
	beq.s		.0003
	bset		#2,KeybdLEDs
.0003:
	btst		#6,_KeyState2
	beq.s		.0004
	bset		#0,KeybdLEDs
.0004:
	move.b	KeybdLEDs,d1
	bsr			KeybdSetLED
	movem.l	(a7)+,d2/d3
	rts

KeybdSendByte:
	move.b d1,KEYBD
	rts
	
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Wait for 10 ms
;
; Parameters: none
; Returns: none
; Modifies: none
; Stack Space: 2 long words
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Wait10ms:
	movem.l	d0/d1,-(a7)
	movec	tick,d0
	addi.l #400000,d0			; 400,000 cycles at 40MHz
.0001:
	movec	tick,d1
	cmp.l	d1,d0
	bhi	.0001
	movem.l	(a7)+,d0/d1
	rts

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Wait for 300 ms
;
; Parameters: none
; Returns: none
; Modifies: none
; Stack Space: 2 long words
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Wait300ms:
	movem.l	d0/d1,-(a7)
	movec		tick,d0
	addi.l	#12000000,d0			; 12,000,000 cycles at 40MHz
.0001:
	movec		tick,d1
	cmp.l		d1,d0
	bhi			.0001
	movem.l	(a7)+,d0/d1
	rts

;--------------------------------------------------------------------------
; Keyboard IRQ routine.
; - only core 2 processes keyboard interrupts.
; - the keyboard buffer is in shared global scratchpad space.
;
; Returns:
; 	d1 = -1 if keyboard routine handled interrupt, otherwise positive.
;--------------------------------------------------------------------------

KeybdIRQ:
	move.w #$2600,sr					; disable lower interrupts
	movem.l	d0/d1/a0,-(a7)
	eori.l #-1,$FD000000
	moveq	#0,d1								; check if keyboard IRQ
	move.b KEYBD+1,d1					; get status reg
	tst.b	d1
	bpl	.0001									; branch if not keyboard
	movec	coreno,d0
	swap d0
	moveq	#KEYBD_SEMA,d1
	bsr LockSemaphore
	move.b KEYBD,d1						; get scan code
	clr.b KEYBD+1							; clear status register (clears IRQ AND scancode)
	btst #1,_KeyState2				; Is Alt down?
	beq.s	.0003
	cmpi.b #SC_TAB,d1					; is Alt-Tab?
	bne.s	.0003
	movec tick,d0
	sub.l _Keybd_tick,d0
	cmp.l #10,d0							; has it been 10 or more ticks?
;	blo.s .0002
	movec tick,d0							; update tick of last ALT-Tab
	move.l d0,_Keybd_tick
	bsr	rotate_iofocus
	clr.b	_KeybdHead					; clear keyboard buffer
	clr.b	_KeybdTail
	clr.b	_KeybdCnt
	bra	.0002									; do not store Alt-Tab
.0003:
	; Insert keyboard scan code into raw keyboard buffer
	cmpi.b #32,_KeybdCnt			; see if keyboard buffer full
	bhs.s	.0002
	move.b _KeybdTail,d0			; keyboard buffer not full, add to tail
	ext.w	d0
	lea	_KeybdBuf,a0					; a0 = pointer to buffer
	move.b d1,(a0,d0.w)				; put scancode in buffer
	addi.b #1,d0							; increment tail index
	andi.b #31,d0							; wrap at buffer limit
	move.b d0,_KeybdTail			; update tail index
	addi.b #1,_KeybdCnt				; increment buffer count
.0002:
	movec	coreno,d0
	swap d0
	moveq	#KEYBD_SEMA,d1
	bsr	UnlockSemaphore
.0001:
	movem.l	(a7)+,d0/d1/a0		; return
	rte

;--------------------------------------------------------------------------
; PS2 scan codes to ascii conversion tables.
;--------------------------------------------------------------------------
;
_unshiftedScanCodes:
	dc.b	$2e,$a9,$2e,$a5,$a3,$a1,$a2,$ac
	dc.b	$2e,$aa,$a8,$a6,$a4,$09,$60,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$71,$31,$2e
	dc.b	$2e,$2e,$7a,$73,$61,$77,$32,$2e
	dc.b	$2e,$63,$78,$64,$65,$34,$33,$2e
	dc.b	$2e,$20,$76,$66,$74,$72,$35,$2e
	dc.b	$2e,$6e,$62,$68,$67,$79,$36,$2e
	dc.b	$2e,$2e,$6d,$6a,$75,$37,$38,$2e
	dc.b	$2e,$2c,$6b,$69,$6f,$30,$39,$2e
	dc.b	$2e,$2e,$2f,$6c,$3b,$70,$2d,$2e
	dc.b	$2e,$2e,$27,$2e,$5b,$3d,$2e,$2e
	dc.b	$ad,$2e,$0d,$5d,$2e,$5c,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$08,$2e
	dc.b	$2e,$95,$2e,$93,$94,$2e,$2e,$2e
	dc.b	$98,$7f,$92,$2e,$91,$90,$1b,$af
	dc.b	$ab,$2e,$97,$2e,$2e,$96,$ae,$2e

	dc.b	$2e,$2e,$2e,$a7,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$fa,$2e,$2e,$2e,$2e,$2e

_shiftedScanCodes:
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$09,$7e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$51,$21,$2e
	dc.b	$2e,$2e,$5a,$53,$41,$57,$40,$2e
	dc.b	$2e,$43,$58,$44,$45,$24,$23,$2e
	dc.b	$2e,$20,$56,$46,$54,$52,$25,$2e
	dc.b	$2e,$4e,$42,$48,$47,$59,$5e,$2e
	dc.b	$2e,$2e,$4d,$4a,$55,$26,$2a,$2e
	dc.b	$2e,$3c,$4b,$49,$4f,$29,$28,$2e
	dc.b	$2e,$3e,$3f,$4c,$3a,$50,$5f,$2e
	dc.b	$2e,$2e,$22,$2e,$7b,$2b,$2e,$2e
	dc.b	$2e,$2e,$0d,$7d,$2e,$7c,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$08,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$7f,$2e,$2e,$2e,$2e,$1b,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e

	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e

; control
_keybdControlCodes:
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$09,$7e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$11,$21,$2e
	dc.b	$2e,$2e,$1a,$13,$01,$17,$40,$2e
	dc.b	$2e,$03,$18,$04,$05,$24,$23,$2e
	dc.b	$2e,$20,$16,$06,$14,$12,$25,$2e
	dc.b	$2e,$0e,$02,$08,$07,$19,$5e,$2e
	dc.b	$2e,$2e,$0d,$0a,$15,$26,$2a,$2e
	dc.b	$2e,$3c,$0b,$09,$0f,$29,$28,$2e
	dc.b	$2e,$3e,$3f,$0c,$3a,$10,$5f,$2e
	dc.b	$2e,$2e,$22,$2e,$7b,$2b,$2e,$2e
	dc.b	$2e,$2e,$0d,$7d,$2e,$7c,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$08,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$7f,$2e,$2e,$2e,$2e,$1b,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e

_keybdExtendedCodes:
	dc.b	$2e,$2e,$2e,$2e,$a3,$a1,$a2,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$2e,$2e,$2e,$2e,$2e,$2e,$2e
	dc.b	$2e,$95,$2e,$93,$94,$2e,$2e,$2e
	dc.b	$98,$99,$92,$2e,$91,$90,$2e,$2e
	dc.b	$2e,$2e,$97,$2e,$2e,$96,$2e,$2e

