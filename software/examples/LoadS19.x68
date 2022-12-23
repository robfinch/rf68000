;==============================================================================
; Load an S19 format file
;==============================================================================
	code
	even
cmdLoadS19:
	bsr			CRLF					; move display to next line
	bra			ProcessRec
NextRec:
	bsr			sGetChar			; get character from serial port routines
	cmpi.b	#LF,d1				; look for a line-feed
	bne			NextRec
	move.b	#'.',d1				; progress display
	bsr			DisplayChar
ProcessRec:
	bsr			CheckForCtrlC	; check for CTRL-C once per record
	bsr			sGetChar
	cmpi.b	#CR,d1
	beq.s		ProcessRec
	clr.b		S19Checksum		; clear the checksum
	move.b	d1,d4
	cmpi.b	#CTRLZ,d4			; CTRL-Z ?
	beq			Monitor
	cmpi.b	#'S',d4				; All records must begin with an 'S'
	bne.s		NextRec
	bsr			sGetChar
	move.b	d1,d4
	cmpi.b	#'0',d4				; Record type must be between '0' and '9'
	blo.s		NextRec
	cmpi.b	#'9',d4				; d4 = record type
	bhi.s		NextRec
	bsr			sGetChar			; get byte count for record
	bsr			AsciiToHexNybble
	move.b	d1,d2
	bsr			sGetChar
	bsr			AsciiToHexNybble
	lsl.b		#4,d2
	or.b		d2,d1					; d1 = byte count
	move.b	d1,d3					; d3 = byte count
	add.b		d3,S19Checksum
	cmpi.b	#'0',d4				; manufacturer ID record, ignore
	beq			NextRec
	cmpi.b	#'1',d4
	beq			ProcessS1
	cmpi.b	#'2',d4
	beq			ProcessS2
	cmpi.b	#'3',d4
	beq			ProcessS3
	cmpi.b	#'5',d4				; record count record, ignore
	beq			NextRec
	cmpi.b	#'7',d4
	beq			ProcessS7
	cmpi.b	#'8',d4
	beq			ProcessS8
	cmpi.b	#'9',d4
	beq			ProcessS9
	bra			NextRec

pcssxa:
	move.l	a1,d1
	bsr			DisplayTetra
	move.b	#CR,d1
	bsr			DisplayChar
	andi.w	#$ff,d3
	subi.w	#1,d3			; one less for dbra
.0001:
	clr.l		d2
	bsr			sGetChar
	bsr			AsciiToHexNybble
	lsl.l		#4,d2
	or.b		d1,d2
	bsr			sGetChar
	bsr			AsciiToHexNybble
	lsl.l		#4,d2
	or.b		d1,d2
	add.b		d2,S19Checksum
	move.b	d2,(a1)+			; move byte to memory
	dbra		d3,.0001
	; Get the checksum byte
	clr.l		d2
	bsr			sGetChar
	bsr			AsciiToHexNybble
	lsl.l		#4,d2
	or.b		d1,d2
	bsr			sGetChar
	bsr			AsciiToHexNybble
	lsl.l		#4,d2
	or.b		d1,d2
	eor.b		#$FF,d2
	cmp.b		S19Checksum,d2
	beq			NextRec
	move.b	#'E',d1
	bsr			DisplayChar
	bra			NextRec

ProcessS1:
	bsr			S19Get16BitAddress
	bra			pcssxa
ProcessS2:
	bsr			S19Get24BitAddress
	bra			pcssxa
ProcessS3:
	bsr			S19Get32BitAddress
	bra			pcssxa
ProcessS7:
	bsr			S19Get32BitAddress
	move.l	a1,S19StartAddress
	bsr			_KeybdInit
	bra			Monitor
ProcessS8:
	bsr			S19Get24BitAddress
	move.l	a1,S19StartAddress
	bsr			_KeybdInit
	bra			Monitor
ProcessS9:
	bsr			S19Get16BitAddress
	move.l	a1,S19StartAddress
	bsr			_KeybdInit
	bra			Monitor

S19Get16BitAddress:
	clr.l		d2
	bsr			sGetChar
	bsr			AsciiToHexNybble
	move.b	d1,d2
	bra			S1932b

S19Get24BitAddress:
	clr.l		d2
	bsr			sGetChar
	bsr			AsciiToHexNybble
	move.b	d1,d2
	bra			S1932a

S19Get32BitAddress:
	clr.l		d2
	bsr			sGetChar
	bsr			AsciiToHexNybble
	move.b	d1,d2
	bsr			sGetChar
	bsr			AsciiToHexNybble
	lsl.l		#4,d2
	or.b		d1,d2
	bsr			sGetChar
	bsr			AsciiToHexNybble
	lsl.l		#4,d2
	or.b		d1,d2
S1932a:
	bsr			sGetChar
	bsr			AsciiToHexNybble
	lsl.l		#4,d2
	or.b		d1,d2
	bsr			sGetChar
	bsr			AsciiToHexNybble
	lsl.l		#4,d2
	or.b		d1,d2
S1932b:
	bsr			sGetChar
	bsr			AsciiToHexNybble
	lsl.l		#4,d2
	or.b		d1,d2
	bsr			sGetChar
	bsr			AsciiToHexNybble
	lsl.l		#4,d2
	or.b		d1,d2
	bsr			sGetChar
	bsr			AsciiToHexNybble
	lsl.l		#4,d2
	or.b		d1,d2
	clr.l		d4
	move.l	d2,a1
	; Add bytes from address value to checksum
	add.b		d2,S19Checksum
	lsr.l		#8,d2
	add.b		d2,S19Checksum
	lsr.l		#8,d2
	add.b		d2,S19Checksum
	lsr.l		#8,d2
	add.b		d2,S19Checksum
	rts

;------------------------------------------------------------------------------
; Get a character from auxillary input. Waiting for a character is limited to
; 32000 tries. If a character is not available within the limit, then a return
; to the monitor is done.
;
;	Parameters:
;		none
; Returns:
;		d1 = character from receive buffer or -1 if no char available
;------------------------------------------------------------------------------

sGetChar:
	movem.l	d0/d2,-(a7)
	move.w	#32000,d2
.0001:
	moveq		#36,d0				; serial get char from buffer
	trap		#15
	tst.w		d1						; was there a char available?
	bpl.s		.0002
	dbra		d2,.0001			; no - try again
	movem.l	(a7)+,d0/d2
.0003:
;	bsr			_KeybdInit
	bra			Monitor				; ran out of tries
.0002:
	movem.l	(a7)+,d0/d2
	cmpi.b	#CTRLZ,d1			; receive end of file?
	beq			.0003
	rts

