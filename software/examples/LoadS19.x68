;==============================================================================
; Load an S19 format file
;
; Register Usage
;		d1 = temp, character fetched from serial
;		d3 = byte count for record
;		d4 = temp, record type
;		d5 = number of bytes in address
;		a1 = memory address to update
;		a2 = dispatch address (Sn routines)
;		
;==============================================================================

S19TblAddr macro arg1
	dc.b ((\1-S19ProcTbl)>>2)
endm

	code
	even
cmdLoadS19:
	bsr CRLF					; move display to next line
	bra	ProcessRec

; The addresses in this table must be within 1kB of the loader
; The stored displacement is shifted right by two bits.
; Table must be four bytes aligned.
	align 2
S19ProcTbl:
	S19TblAddr NextRec		; manufacturer ID record, ignore
	S19TblAddr ProcessS1
	S19TblAddr ProcessS2
	S19TblAddr ProcessS3
	S19TblAddr NextRec
	S19TblAddr NextRec		; record count record, ignore
	S19TblAddr NextRec
	S19TblAddr ProcessS7
	S19TblAddr ProcessS8
	S19TblAddr ProcessS9

	align 2
NextRec:
	bsr	sGetChar					; get character from serial port routines
	cmpi.b #LF,d1					; look for a line-feed
	bne	NextRec
	move.b #'.',d1				; progress display
	bsr	OutputChar
ProcessRec:
	jsr CheckForCtrlC			; check for CTRL-C once per record
	bsr	sGetChar
	cmpi.b #CR,d1
	beq.s	ProcessRec
	move.b d1,d4
	cmpi.b #CTRLZ,d4			; CTRL-Z ?
	beq	Monitor
	cmpi.b #'S',d4				; All records must begin with an 'S'
	bne.s	NextRec
	bsr	sGetChar
	move.b d1,d4
	cmpi.b #'0',d4				; Record type must be between '0' and '9'
	blo.s	NextRec
	cmpi.b #'9',d4				; d4 = record type
	bhi.s	NextRec
	clr.b S19Checksum
	bsr S19GetByte				; get byte count for record
	move.b d1,d3					; d3 = byte count
	sub.b #'0',d4
	ext.w d4
	lea S19ProcTbl(pc),a2
	move.b (a2,d4.w),d4
	ext.w d4
	ext.l d4
	lsl.l #2,d4
	add.l d4,a2
	clr.l d2							; will hold address
	clr.l d5							; d5 = number of bytes in address
	jmp (a2)

	even

; Get a byte and add to checksum.
;		
; Returns:
;		d1 = byte

S19GetByte:
	bsr	sGetChar
	bsr	AsciiToHexNybble
	move.b d1,d2
	bsr	sGetChar
	bsr	AsciiToHexNybble
	lsl.b	#4,d2
	or.b d2,d1
	add.b d1,S19Checksum
	rts

;------------------------------------------------------------------------------
; Process S record. Three entry points depending on address size.
;------------------------------------------------------------------------------

	align 2
ProcessS1:
	bsr	S19Get16BitAddress
	bra	pcssxa
	align 2
ProcessS2:
	bsr	S19Get24BitAddress
	bra	pcssxa
	align 2
ProcessS3:
	bsr	S19Get32BitAddress
	; fall through

;------------------------------------------------------------------------------
; Parameters:
; 	a1 = address pointer
; 	d3 = byte count
; Modifies:
;		d1 = temp
;		d2 = checksum
;		d3 decremented to -1
;		a1 incremented by count
;		S19Checksum variable
;------------------------------------------------------------------------------

pcssxa:
	andi.w #$ff,d3		
	subi.w #2,d3			; one less for dbra, one less for checksum
	sub.w d5,d3				; subtract out size of address (2 to 4 bytes)
	bmi NextRec
.0001
	bsr S19GetByte
	move.b d1,(a1)+		; move byte to memory
	dbf d3,.0001
	bsr S19GetByte		; Get the checksum byte (does not go to memory)
	cmp.b	#$FF,S19Checksum
	beq	NextRec
	bsr DisplayByte
	move.b #'E',d1
	bsr	OutputChar
	bra	NextRec

	align 2
ProcessS7:
	bsr	S19Get32BitAddress
	move.l a1,S19StartAddress
	bra	Monitor
	align 2
ProcessS8:
	bsr	S19Get24BitAddress
	move.l a1,S19StartAddress
	bra	Monitor
	align 2
ProcessS9:
	bsr	S19Get16BitAddress
	move.l a1,S19StartAddress
	bra	Monitor

;------------------------------------------------------------------------------
; Get an address. Three entry points to get a 32,24, or 16 bit address.
;
; Modifies:
;		d1,d2
; Returns:
;		a1 = address
;		d5 = number of bytes in address
;------------------------------------------------------------------------------

S19Get32BitAddress:
	bsr S19GetByte
	move.b d1,d2
	lsl.l #8,d2
	add.w #1,d5
	;fall through
S19Get24BitAddress:
	bsr S19GetByte
	move.b d1,d2
	lsl.l #8,d2
	add.w #1,d5
	; fall through
S19Get16BitAddress:
	bsr S19GetByte
	move.b d1,d2
	lsl.l #8,d2
	bsr S19GetByte
	move.b d1,d2
	move.l d2,a1
	add.w #2,d5
	rts

;------------------------------------------------------------------------------
; Get a character from auxillary input. Waiting for a character is limited to
; 320000 tries. If a character is not available within the limit, then a return
; to the monitor is done.
;
;	Parameters:
;		none
; Returns:
;		d1.w = character from receive buffer or -1 if no char available
;------------------------------------------------------------------------------

sGetChar:
	movem.l	d0/d2,-(a7)
	move.l	#320000,d2
	bra .0001
.0004
	swap d2
.0001
	moveq	#36,d0				; serial get char from buffer
	trap #15
	cmpi.w #-1,d1				; was there a char available?
	bne.s	.0002
	dbra d2,.0001				; no - try again
	jsr CheckForCtrlC
	swap d2
	dbra d2,.0004
	movem.l	(a7)+,d0/d2
.0003
;	bsr			_KeybdInit
	bra	Monitor						; ran out of tries
.0002
	movem.l (a7)+,d0/d2
	cmpi.b #CTRLZ,d1			; receive end of file?
	beq .0003
	rts
