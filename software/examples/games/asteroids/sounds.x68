;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;														;
;	Sound routines V1.00. This is an include file for asteroids 1_0.x68		;
;														;
;	load the sounds, play an indexed sample. Uses the DirextX sound play and	;
;	requires EASy68K 3.7.10 beta or later.							;
;														;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

sfire_snd	EQU  0
pfire_snd	EQU  1
thrst_snd	EQU  2
smsau_snd	EQU  3
lgsau_snd	EQU  4
sexpl_snd	EQU  5
mexpl_snd	EQU  sexpl_snd+1
lexpl_snd	EQU  sexpl_snd+2
beat1_snd	EQU  8				; beat_2 must be beat_1 XOR 1
beat2_snd	EQU  9				; see above
extra_snd	EQU 10


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; initialise the sounds routine
	code
	even
sound_init
	MOVE.b	#0,s_key(a3)		; clear the last [S] key status
	MOVE.b	#-1,play_sound(a3)	; set the sound flag

	LEA		beat1_sound(pc),a1	; point to the background beat sound file name
	MOVEQ		#beat1_snd,d1		; index 10
	BSR.s		load_sound			; load the sound into directx memory

	LEA		beat2_sound(pc),a1	; point to the background beat sound file name
	MOVEQ		#beat2_snd,d1		; index 9
	BSR.s		load_sound			; load the sound into directx memory

	LEA		lexpl_sound(pc),a1	; point to the large explosion sound file name
	MOVEQ		#lexpl_snd,d1		; index 8
	BSR.s		load_sound			; load the sound into directx memory

	LEA		mexpl_sound(pc),a1	; point to the medium explosion sound file name
	MOVEQ		#mexpl_snd,d1		; index 7
	BSR.s		load_sound			; load the sound into directx memory

	LEA		sexpl_sound(pc),a1	; point to the small explosion sound file name
	MOVEQ		#sexpl_snd,d1		; index 6
	BSR.s		load_sound			; load the sound into directx memory

	LEA		extra_sound(pc),a1	; point to the extra life sound file name
	MOVEQ		#extra_snd,d1		; index 5
	BSR.s		load_sound			; load the sound into directx memory

	LEA		lgsau_sound(pc),a1	; point to the large saucer sound file name
	MOVEQ		#lgsau_snd,d1		; index 4
	BSR.s		load_old_sound		; load the sound into sound memory

	LEA		smsau_sound(pc),a1	; point to the small saucer sound file name
	MOVEQ		#smsau_snd,d1		; index 3
	BSR.s		load_old_sound		; load the sound into directx memory

	LEA		thrst_sound(pc),a1	; point to the ship thrust sound file name
	MOVEQ		#thrst_snd,d1		; index 2
	BSR.s		load_sound			; load the sound into directx memory

	LEA		pfire_sound(pc),a1	; point to the player fire sound file name
	MOVEQ		#pfire_snd,d1		; index 1
	BSR.s		load_sound			; load the sound into directx memory

	LEA		sfire_sound(pc),a1	; point to the saucer fire sound file name
	MOVEQ		#sfire_snd,d1		; index 0


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; load the sound into directx memory

load_sound
	MOVEQ		#74,d0			; load the sound into directx memory
	TRAP		#15

	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; load the sound into sound memory

load_old_sound
	MOVEQ		#71,d0			; load the sound into sound memory
	TRAP		#15

	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; play a sound sample

play_sample
	TST.b		num_players(a3)		; test the number of players in the game
	BEQ.s		exit_play_sample		; if no players left just exit

	TST.b		play_sound(a3)		; test the sound flag
	BEQ.s		exit_play_sample		; if the sound is off just exit

	MOVEQ		#72,d0			; play a sound from sound memory
	CMPI.w	#smsau_snd,d1		; is it the small saucer sound
	BEQ.s		old_sound_play		; if so go play it with the old player

	CMPI.w	#lgsau_snd,d1		; is it the large saucer sound
	BEQ.s		old_sound_play		; if so go play it with the old player

	MOVEQ		#75,d0			; play a sound from directx memory
old_sound_play
	TRAP		#15

exit_play_sample
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; test the sound key

sound_key
	MOVEQ		#$53,d1			; [][][][S] key
	MOVEQ		#19,d0			; check for keypress
	TRAP		#15

	MOVE.b	s_key(a3),d0		; get the last key(s) state
	EOR.b		d1,d0				; compare the result with the last key(s) state,
							; each byte is now $FF if a key has changed or
							; $00 if a key has not changed
	AND.b		d1,d0				; make each byte $FF if key just pressed or
							; $00 if key not just pressed
	EOR.b		d0,play_sound(a3)		; if key just pressed toggle the sound flag
	MOVE.b	d1,s_key(a3)		; save the last [S] key status
	RTS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; sound file names

beat1_sound
	dc.b	'samples\beat1.wav',$00		; background beat sound

beat2_sound
	dc.b	'samples\beat2.wav',$00		; background beat sound

lexpl_sound
	dc.b	'samples\lexplode.wav',$00	; large explosion sound

mexpl_sound
	dc.b	'samples\mexplode.wav',$00	; medium explosion sound

sexpl_sound
	dc.b	'samples\sexplode.wav',$00	; small explosion sound

extra_sound
	dc.b	'samples\extraship.wav',$00	; extra life sound

lgsau_sound
	dc.b	'samples\lgsaucer.wav',$00	; large saucer sound

smsau_sound
	dc.b	'samples\smsaucer.wav',$00	; small saucer sound

thrst_sound
	dc.b	'samples\thrust.wav',$00	; ship thrust sound

pfire_sound
	dc.b	'samples\pfire.wav',$00		; player fire sound

sfire_sound
	dc.b	'samples\sfire.wav',$00		; saucer fire sound

	ds.w	0					; ensure even


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

