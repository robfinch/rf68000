; ============================================================================
;        __
;   \\__/ o\    (C) 2025  Robert Finch, Waterloo
;    \  __ /    All rights reserved.
;     \/_//     robfinch<remove>@opencores.org
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

;==============================================================================
; Serial I/O routines
;==============================================================================

	code
	align 2
COM_CMDTBL:
	dc.l serial_init
	dc.l serial_stat
	dc.l serial_putchar
	dc.l serial_putbuf
	dc.l serial_getchar
	dc.l serial_getbuf
	dc.l serial_set_inpos
	dc.l serial_set_outpos
	dc.l serial_getchar_direct
	dc.l serial_peek_char
	dc.l serial_peek_char_direct
	dc.l serial_putchar_direct

;------------------------------------------------------------------------------
; Setup the console device
; stdout = text screen controller
;------------------------------------------------------------------------------
	even

serial_init:
setup_serial:
	movem.l d0/a0/a1,-(a7)
	moveq #31,d0
	lea.l serial_dcb,a0
.0001:
	clr.l (a0)+
	dbra d0,.0001
	move.l #$44434220,serial_dcb+DCB_MAGIC			; 'DCB'
	move.l #$434F4D00,serial_dcb+DCB_NAME				; 'COM'
	move.l #serial_cmdproc,serial_dcb+DCB_CMDPROC
	move.l #SerRcvBuf,serial_dcb+DCB_INBUFPTR
	move.l #SerXmitBuf,serial_dcb+DCB_OUTBUFPTR
	move.l #4096,serial_dcb+DCB_INBUFSIZE
	bsr SerialInit
	lea.l serial_dcb,a1
	jsr DisplayString
	jsr CRLF
	movem.l (a7)+,d0/a0/a1
	rts

serial_cmdproc:
	cmpi.b #12,d6
	bhs.s .0001
	movem.l d6/a0,-(a7)
	ext.w d6
	lsl.w #2,d6
	lea COM_CMDTBL,a0
	move.l (a0,d6.w),a0
	jsr (a0)
	movem.l (a7)+,d6/a0
	rts
.0001:
	moveq #E_Func,d0
	rts

serial_stat:
	moveq #E_Ok,d0
	rts

serial_putchar:
	bsr SerialPutChar
	moveq #E_Ok,d0
	rts

serial_getchar:
	bsr SerialGetChar
	moveq #E_Ok,d0
	rts

serial_getchar_direct:
	bsr SerialPeekCharDirect
	moveq #E_Ok,d0
	rts

serial_peek_char:
	bsr SerialPeekChar
	moveq #E_Ok,d0
	rts

serial_peek_char_direct:
	bsr SerialPeekCharDirect
	moveq #E_Ok,d0
	rts

serial_putchar_direct:
	bsr SerialPutCharDirect
	moveq #E_Ok,d0
	rts

serial_putbuf:
serial_getbuf:
serial_set_inpos:
serial_set_outpos:
	moveq #E_NotSupported,d0
	rts

;------------------------------------------------------------------------------
; Initialize the serial port an enhanced 6551 circuit.
;
; Select internal baud rate clock divider for 9600 baud
; Reset fifos, set threshold to 3/4 full on transmit and 3/4 empty on receive
; Note that the byte order is swapped.
;------------------------------------------------------------------------------

SerialInit:
	clr.w		SerHeadRcv					; clear receive buffer indexes
	clr.w		SerTailRcv
	clr.w		SerHeadXmit					; clear transmit buffer indexes
	clr.w		SerTailXmit
	clr.b		SerRcvXon						; and Xon,Xoff flags
	clr.b		SerRcvXoff
	move.l	#$00000009,d0				; dtr,rts active, rxint enabled, no parity
	move.l	d0,ACIA+ACIA_CMD
;	move.l	#$1E00F700,d0				; fifos enabled
	move.l	#$0000001E,d0				; fifos disabled
	move.l	d0,ACIA+ACIA_CTRL
	rts
;	move.l	#$0F000000,d0				; transmit a break for a while
;	move.l	d0,ACIA+ACIA_CMD
;	move.l	#300000,d2					; wait 100 ms
;	bra			.0001
;.0003:
;	swap		d2
;.0001:
;	nop
;	dbra		d2,.0001
;.0002:
;	swap		d2
;	dbra		d2,.0003
;	move.l	#$07000000,d0				; clear break
;	move.l	d0,ACIA+ACIA_CMD
;	rts
	
;------------------------------------------------------------------------------
; SerialGetChar
;
; Check the serial port buffer to see if there's a char available. If there's
; a char available then return it. If the buffer is almost empty then send an
; XON.
;
; Stack Space:
;		2 long words
; Parameters:
;		none
; Modifies:
;		d0,a0
; Returns:
;		d1 = character or -1
;------------------------------------------------------------------------------

SerialGetChar:
	move.l		d2,-(a7)
	movec			coreno,d0
	swap			d0
	moveq			#SERIAL_SEMA,d1
	bsr				LockSemaphore
	bsr				SerialRcvCount			; check number of chars in receive buffer
	cmpi.w		#8,d0								; less than 8?
	bhi				.sgc2
	tst.b			SerRcvXon						; skip sending XON if already sent
	bne	  		.sgc2            		; XON already sent?
	move.b		#XON,d1							; if <8 send an XON
	clr.b			SerRcvXoff					; clear XOFF status
	move.b		d1,SerRcvXon				; flag so we don't send it multiple times
	bsr				SerialPutChar				; send it
.sgc2
	move.w		SerHeadRcv,d1				; check if anything is in buffer
	cmp.w			SerTailRcv,d1
	beq				.NoChars						; no?
	lea				SerRcvBuf,a0
	move.b		(a0,d1.w),d1				; get byte from buffer
	addi.w		#1,SerHeadRcv
	andi.w		#$FFF,SerHeadRcv		; 4k wrap around
	andi.l		#$FF,d1
	bra				.Xit
.NoChars
	moveq			#-1,d1
.Xit
	exg				d1,d2
	movec			coreno,d0
	swap			d0
	moveq			#SERIAL_SEMA,d1
	bsr				UnlockSemaphore
	exg				d2,d1
	move.l		(a7)+,d2
	rts

;------------------------------------------------------------------------------
; SerialPeekChar
;
; Check the serial port buffer to see if there's a char available. If there's
; a char available then return it. But don't update the buffer indexes. No need
; to send an XON here.
;
; Stack Space:
;		1 long word
; Parameters:
;		none
; Modifies:
;		d0,a0
; Returns:
;		d1 = character or -1
;------------------------------------------------------------------------------

SerialPeekChar:
	move.l d2,-(a7)
	movec	coreno,d0
	swap d0
	moveq	#SERIAL_SEMA,d1
	bsr	LockSemaphore
	move.w SerHeadRcv,d2		; check if anything is in buffer
	cmp.w	SerTailRcv,d2
	beq	.NoChars				; no?
	lea	SerRcvBuf,a0
	move.b (a0,d2.w),d2		; get byte from buffer
	bra	.Xit
.NoChars
	moveq	#-1,d2
.Xit
	movec	coreno,d0
	swap d0
	moveq	#SERIAL_SEMA,d1
	bsr	UnlockSemaphore
	move.l	d2,d1
	move.l (a7)+,d2
	rts

;------------------------------------------------------------------------------
; SerialPeekChar
;		Get a character directly from the I/O port. This bypasses the input
; buffer.
;
; Stack Space:
;		0 words
; Parameters:
;		none
; Modifies:
;		d
; Returns:
;		d1 = character or -1
;------------------------------------------------------------------------------

SerialPeekCharDirect:
	move.b	ACIA+ACIA_STAT,d1	; get serial status
	btst		#3,d1							; look for Rx not empty
	beq.s		.0001
	moveq.l	#0,d1							; clear upper bits of return value
	move.b	ACIA+ACIA_RX,d1		; get data from ACIA
	rts												; return
.0001
	moveq		#-1,d1
	rts

;------------------------------------------------------------------------------
; SerialPutChar
;		If there is a transmit buffer, adds the character to the transmit buffer
; if it can, otherwise will wait for a byte to be freed up in the transmit
; buffer (blocks).
;		If there is no transmit buffer, put a character to the directly to the
; serial transmitter. This routine blocks until the transmitter is empty. 
;
; Stack Space
;		4 long words
; Parameters:
;		d1.b = character to put
; Modifies:
;		none
;------------------------------------------------------------------------------

SerialPutChar:
.0004
	tst.w serial_dcb+DCB_OUTBUFSIZE	; buffered output?
	beq.s SerialPutCharDirect
	movem.l d0/d1/d2/a0,-(a7)
	movec	coreno,d0
	swap d0
	moveq	#SERIAL_SEMA,d1
	bsr	LockSemaphore
	move.w SerTailXmit,d0
	move.w d0,d2
	addi.w #1,d0
	cmp.w serial_dcb+DCB_OUTBUFSIZE,d0
	blo.s .0002
	clr.w d0
.0002
	cmp.w SerHeadXmit,d0			; Is Xmit buffer full?
	bne.s .0003
	movec	coreno,d0						; buffer full, unlock semaphore and wait
	swap d0
	moveq	#SERIAL_SEMA,d1
	bsr	UnlockSemaphore
	bra.s .0004
.0003
	move.w d0,SerTailXmit			; update tail pointer
	lea SerXmitBuf,a0
	move.b d1,(a0,d2.w)				; store byte in Xmit buffer
	movec	coreno,d0						; unlock semaphore
	swap d0
	moveq	#SERIAL_SEMA,d1
	bsr	UnlockSemaphore
	movem.l (a7)+,d0/d1/d2/a0
	rts

SerialPutCharDirect:
	movem.l	d0/d1,-(a7)							; push d0,d1
.0001
	move.b ACIA+ACIA_STAT,d0	; wait until the uart indicates tx empty
	btst #4,d0								; bit #4 of the status reg
	beq.s	.0001			    			; branch if transmitter is not empty
	move.b d1,ACIA+ACIA_TX		; send the byte
	movem.l	(a7)+,d0/d1				; pop d0,d1
	rts
	
;------------------------------------------------------------------------------
; Calculate number of character in input buffer
;
; Returns:
;		d0 = number of bytes in buffer.
;------------------------------------------------------------------------------

SerialRcvCount:
	move.w	SerTailRcv,d0
	sub.w		SerHeadRcv,d0
	bge.s		.0001
	move.w	#$1000,d0
	sub.w		SerHeadRcv,d0
	add.w		SerTailRcv,d0
.0001
	rts

;------------------------------------------------------------------------------
; Serial IRQ routine
;
; Keeps looping as long as it finds characters in the ACIA recieve buffer/fifo.
; Received characters are buffered. If the buffer becomes full, new characters
; will be lost.
;
; Parameters:
;		none
; Modifies:
;		none
; Returns:
;		d1 = -1 if IRQ handled, otherwise zero
;------------------------------------------------------------------------------

SerialIRQ:
	move.w	#$2300,sr						; disable lower level IRQs
	movem.l	d0/d1/d2/a0,-(a7)
	lea $FD000000+(TEXTCOL-2)*4,a0			; display field address
	move.l (a0),d2						; get char from screen
	eori.l #$000000FF,d2
	move.l d2,(a0)						; update onscreen IRQ flag
	movec	coreno,d0
	swap d0
	moveq	#SERIAL_SEMA,d1
	bsr	LockSemaphore
sirqNxtByte
	move.b ACIA+ACIA_STAT,d1		; check the status
	btst #3,d1									; bit 3 = rx full
	beq	notRxInt
	move.b ACIA+ACIA_RX,d1
sirq0001
	move.w SerTailRcv,d0				; check if recieve buffer full
	addi.w #1,d0
	andi.w #$FFF,d0
	cmp.w	SerHeadRcv,d0
	beq	sirqRxFull
	move.w d0,SerTailRcv				; update tail pointer
	subi.w #1,d0								; backup
	andi.w #$FFF,d0
	lea	SerRcvBuf,a0						; a0 = buffer address
	move.b d1,(a0,d0.w)					; store recieved byte in buffer
	tst.b	SerRcvXoff						; check if xoff already sent
	bne	sirqNxtByte
	bsr	SerialRcvCount					; if more than 4080 chars in buffer
	cmpi.w #4080,d0
	blo	sirqNxtByte
	move.b #XOFF,d1							; send an XOFF
	clr.b	SerRcvXon							; clear XON status
	move.b d1,SerRcvXoff				; set XOFF status
	bsr	SerialPutChar						; send XOFF
	bra	sirqNxtByte     				; check the status for another byte
sirqRxFull
notRxInt
	btst #4,d1									; TX empty?
	beq.s notTxInt
	tst.b SerXmitXoff						; and allowed to send?
	bne.s sirqXmitOff
	tst.l serial_dcb+DCB_OUTBUFSIZE	; Is there a buffer being transmitted?
	beq.s notTxInt
	move.w SerHeadXmit,d0
	cmp.w SerTailXmit,d0
	beq.s sirqTxEmpty
	lea SerXmitBuf,a0
	move.b (a0,d0.w),d1
	move.b d1,ACIA+ACIA_TX			; transmit character
	addi.w #1,SerHeadXmit				; advance head index
	move.w serial_dcb+DCB_OUTBUFSIZE,d0
	cmp.w SerHeadXmit,d0
	bhi.s sirq0002
	clr.w SerHeadXmit						; wrap around
sirq0002
sirqXmitOff
sirqTxEmpty
notTxInt
	movec	coreno,d0
	swap d0
	moveq	#SERIAL_SEMA,d1
	bsr	UnlockSemaphore
	movem.l	(a7)+,d0/d1/d2/a0
	rte

nmeSerial:
	dc.b		"Serial",0

