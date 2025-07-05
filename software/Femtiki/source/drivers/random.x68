;==============================================================================
; random
;
;
;==============================================================================

	include "..\Femtiki\source\inc\const.x68"
	include "..\Femtiki\source\inc\device.x68"
	include "..\Femtiki\source\inc\const.x68"

RAND_NUM	EQU	$FDFF4000
RAND_STRM	EQU	$FDFF4004
RAND_MZ		EQU $FDFF4008
RAND_MW		EQU	$FDFF400C

	section local_ram
random_vars	equ	*
random_avail equ *-random_vars
	ds.b	128
random_obufptr equ *-random_vars
	ds.l	1

	code
	even


RANDOM_CMDADDR macro arg1
	dc.w (\1-RANDOM_CMDTBL)
endm

	align 2
RANDOM_CMDTBL:
	RANDOM_CMDADDR random_nop					; 0
	RANDOM_CMDADDR random_setup				; 1
	RANDOM_CMDADDR random_init				; 2
	RANDOM_CMDADDR random_stat				; 3
	RANDOM_CMDADDR random_stub				; 4 media check
	RANDOM_CMDADDR random_stub				; 5 reserved
	RANDOM_CMDADDR random_open				; 6 open
	RANDOM_CMDADDR random_close				; 7 close
	RANDOM_CMDADDR random_getchar			; 8
	RANDOM_CMDADDR random_peekchar		; 9 peek char
	RANDOM_CMDADDR random_stub				; 10 get char direct
	RANDOM_CMDADDR random_stub				; 11 peek char direct
	RANDOM_CMDADDR random_stub				; 12 input status
	RANDOM_CMDADDR random_stub				; 13 put char
	RANDOM_CMDADDR random_stub				; 14 reserved
	RANDOM_CMDADDR random_stub				; 15 set position
	RANDOM_CMDADDR random_getbuf			; 16 read block
	RANDOM_CMDADDR random_stub				; 17 write block
	RANDOM_CMDADDR random_stub				; 18 verify block
	RANDOM_CMDADDR random_stub				; 19 output status
	RANDOM_CMDADDR random_stub				; 20 flush input
	RANDOM_CMDADDR random_stub				; 21 flush output
	RANDOM_CMDADDR random_stub				; 22 IRQ
	RANDOM_CMDADDR random_is_removeable	; 23 is removeable
	RANDOM_CMDADDR random_stub				; 24 IOCTRL read
	RANDOM_CMDADDR random_stub				; 25 IOCTRL write
	RANDOM_CMDADDR random_stub				; 26 output until busy
	RANDOM_CMDADDR random_stub				; 27 shutdown
	RANDOM_CMDADDR random_stub				; 28 clear
	RANDOM_CMDADDR random_stub				; 29 swap buf
	RANDOM_CMDADDR random_stub				; 30 setbuf 1
	RANDOM_CMDADDR random_stub				; 31 setbuf 2
	RANDOM_CMDADDR random_stub				; 32 getbuf 1
	RANDOM_CMDADDR random_stub				; 33 getbuf 2
	RANDOM_CMDADDR random_stub				; 34 get dimensions
	RANDOM_CMDADDR random_stub				; 35 get color
	RANDOM_CMDADDR random_stub				; 36 get position
	RANDOM_CMDADDR random_stub				; 37 set color
	RANDOM_CMDADDR random_stub				; 38 set color 123
	RANDOM_CMDADDR random_stub				; 39 reserved
	RANDOM_CMDADDR random_stub				; 40 plot point
	RANDOM_CMDADDR random_stub				; 41 draw line
	RANDOM_CMDADDR random_stub				; 42 draw triangle
	RANDOM_CMDADDR random_stub				; 43 draw rectangle
	RANDOM_CMDADDR random_stub				; 44 draw cxurve
	RANDOM_CMDADDR random_stub				; 45 set dimensions
	RANDOM_CMDADDR random_stub				; 46 set color depth
	RANDOM_CMDADDR random_stub				; 47 set destination buffer
	RANDOM_CMDADDR random_stub				; 48 set display buffer
	RANDOM_CMDADDR random_stub				; 49 get input position
	RANDOM_CMDADDR random_stub				; 50 set input position
	RANDOM_CMDADDR random_set_outpos	; 51 set output position
	RANDOM_CMDADDR random_stub				; 52 get output position
	RANDOM_CMDADDR random_stub				; 53 get input pointer
	RANDOM_CMDADDR random_stub				; 54 get output pointer
	RANDOM_CMDADDR random_stub				; 55 set unit
	RANDOM_CMDADDR random_stub				; 56 set unit

_random_cmdproc:
random_cmdproc:
	cmpi.b #57,d6
	bhs.s .0001
	movem.l d6/a0/a3,-(a7)
	ext.w d6
	lsl.l #1,d6
	lea RANDOM_CMDTBL(pc),a0
	move.w (a0,d6.w),d6
	ext.l d6
	add.l d6,a0
	move.l #random_vars,a3
	jsr (a0)
	movem.l (a7)+,d6/a0/a3
	rts
.0001:
	moveq #E_NotSupported,d0
	rts

	global _random_cmdproc

;------------------------------------------------------------------------------
; Setup the Keyboard device
;------------------------------------------------------------------------------

_setup_random:
setup_random:
random_setup:
	move.l a3,-(sp)
	move.l #random_vars,a3
	bsr random_init
	move.l (sp)+,a3
	rts

	global setup_random
	global _setup_random

random_init:
	movem.l d0/a0/a1,-(a7)
	move.l d0,a0
	move.l d0,a1
	moveq #15,d0
.0001:
	clr.l (a1)+
	dbra d0,.0001
	move.l #$44434220,DCB_MAGIC(a0)				; 'DCB '
	move.l #$52414E44,DCB_NAME(a0)				; 'RAND'
	move.l #$4F4D0000,DCB_NAME(a0)				; 'OM'
	move.l #random_cmdproc,DCB_CMDPROC(a0)
	bsr RandInit
	moveq #13,d0									; DisplayStringCRLF function
	lea.l DCB_MAGIC(a0),a1
	trap #15
	movem.l (a7)+,d0/a0/a1
	rts

random_stat:
random_nop:
	moveq #E_Ok,d0
	rts

random_set_outpos:
random_stub:
	moveq #E_NotSupported,d0
	rts

random_is_removeable:
	moveq #0,d1									; nope
	moveq #E_Ok,d0
	rts

; Set the seed to some value for each stream. The seed cannot be zero.
;
InitRand:
RandInit:
	movem.l	d0/d1,-(a7)
	moveq #37,d0								; lock semaphore
	moveq	#RAND_SEMA,d1
	trap #15
	move.w #1023,d0							; 1024 streams
.0001
	move.l d0,RAND_STRM					; select the stream
	move.l #$12345678,RAND_MZ		; initialize to some value
	move.l #$98765432,RAND_MW
	move.l #777777777,RAND_NUM	; generate first number
	dbra d0,.0001
	moveq #38,d0								; unlock semaphore
	moveq	#RAND_SEMA,d1
	trap #15
	movem.l	(a7)+,d0/d1
	rts
	global InitRand

;------------------------------------------------------------------------------
;	Gets a random number and generate the next number.
;
; Returns
;		d1 = random integer
;------------------------------------------------------------------------------

random_getchar:
RandGetNum:
	movem.l	d0/d2,-(a7)
	move.l d7,d0
	and.l #$03ff,d0							; get stream number
	move.l d0,RAND_STRM					; select the stream
	move.l RAND_NUM,d1					; d1 = random number
	move.l d1,RAND_NUM		 		  ; generate next number for stream
	movem.l	(a7)+,d0/d2
	rts
	global RandGetNum

;------------------------------------------------------------------------------
;	Gets a random number without generating the next number.
;
; Returns
;		d1 = random number
;------------------------------------------------------------------------------

random_peekchar:
	movem.l	d0/d2,-(a7)
	and.l #$03ff,d0							; get stream number
	move.l d0,RAND_STRM					; select the stream
	move.l RAND_NUM,d1					; d1 = random number
	movem.l	(a7)+,d0/d2
	rts

;------------------------------------------------------------------------------
;	Open a random stream.
;
; Parameters:
;		d1 = stream number
; Returns
;		d0 = E_Ok
;		d1 = handle (including device number)
;------------------------------------------------------------------------------

random_open:
	move.l a0,-(sp)
	lea random_avail,a0
	clr.l d0
	clr.l d1
.0002
	bset d1,(a0,d0.l)		; set the bit, even if set already
	beq.s .0001					; if bit was not set, then stream was available
	addq #1,d1					; try next bit
	cmpi.b #7,d1				; 8 bits max (0 to 7)
	bls .0002
	clr.l d1
	addq.l #1,d0				; next byte
	cmpi.w #127,d0			; 128 bytes max
	bls .0002
	; Here all the streams were in use
	moveq #E_TooManyStreams,d0
	move.l (sp)+,a0
	rts
.0001
	move.l (sp)+,a0
	move.l d7,d0				; d7 contained the device number, and stream of zero
	and.l #$FFFF0000,d0	; ensure it is zero (it should already be)
	or.l d0,d1					; or in the opened stream number
	moveq #E_Ok,d0			; return ok status with file handle in d1
	rts

;------------------------------------------------------------------------------
;	Close a random stream.
;
; Parameters:
;		d1 = stream number
; Returns
;		d0 = E_Ok
;------------------------------------------------------------------------------

random_close:
	cmpi.l #1024,d1			; check for valid stream number
	bhs.s .0001
	movem.l d1/a0,-(sp)
	move.l d1,d0
	lsr.l #3,d0					; / 8 bits per byte to get byte index
	and.l #7,d1					; d1 = bit of lword
	lea random_avail,a0
	bclr d1,(a0,d0.l)
	movem.l (sp)+,d1/a0
.0001
	moveq #E_Ok,d0
	rts

;------------------------------------------------------------------------------
;	Get a buffer full of random numbers.
;
; Parameters:
;		d7 = stream number
;		d1 = pointer to buffer
;		d2 = size of buffer
;
; Returns
;		d0 = E_Ok
;		d2 = number of bytes transferred
;------------------------------------------------------------------------------

random_getbuf:
	move.l d7,d0
	and.l #$0ffff,d0			; d0 = stream number
	cmpi.l #1024,d0				; check for valid stream number
	bhs .0001
	movem.l d1/a0,-(sp)
	movem.l d0/d1/d2,-(sp)
	; Lock out other selections
	moveq #37,d0					; lock semaphore
	moveq	#RAND_SEMA,d1
	move.l #200000,d2			; try this many times for lock
	trap #15
	cmpi.b #-1,d0
	bne.s .0002
	movem.l (sp)+,d0/d1/d2

	move.l d1,a0					; a0 = buffer pointer

	; Set which stream we are working with
	move.l d0,RAND_STRM		; select the stream

	; Set count
	move.l d2,d0
	lsr.l #2,d0						; convert byte count to lword count, round down
	tst.l d0							; zero to move?
	beq.s .0005
	subq.l #1,d0					; loop count must be one less
	clr.l d2							; d2 = count of bytes
	bra.s .0003
.0004
	swap d0
.0003
	move.l RAND_NUM,d1		; d1 = random number
	move.l d1,RAND_NUM		; generate next number for stream
	move.l d1,(a0)+				; store number to buffer
	addq.l #4,d2
	dbra d0,.0003
	swap d0
	dbra d0,.0004
	moveq #38,d0					; unlock semaphore
	moveq	#RAND_SEMA,d1
	trap #15
	movem.l (sp)+,d1/a0
	; d2 contains byte count
	moveq #E_Ok,d0
	rts

	; Here, the count was zero
.0005
	moveq #38,d0					; unlock semaphore
	moveq	#RAND_SEMA,d1
	trap #15
	movem.l (sp)+,d1/a0
	moveq #0,d2
	moveq #E_Ok,d0
	rts

	; Here, the random could not be locked for access
.0002
	moveq #38,d0					; unlock semaphore
	moveq	#RAND_SEMA,d1
	trap #15
	movem.l (sp)+,d0/d1/d2
	movem.l (sp)+,d1/a0
	moveq #0,d2
	moveq #E_Busy,d0
	rts
	; Here, a bad stream number was passed
.0001
	moveq #0,d2
	moveq #E_Arg,d0
	rts
