;===============================================================================
;===============================================================================
;	Registers
;  00      -------- --ffffff ffffffff ffffffff     freq [21:0]
;  04      -------- --pppppp pppppppp pppppppp     pulse width
;	08	    R------- ----oooo trsg-ef- vvvvvv-- 	test, ringmod, sync, gate, filter, output, voice type
;  0C      ---aaaaa aaaaaaaa aaaaaaaa aaaaaaaa     attack
;  10      --dddddd dddddddd dddddddd dddddddd     decay
;  14      -------- -------- -------- ssssssss     sustain / wave volume
;  18      aaaaaaaa rrrrrrrr rrrrrrrr rrrrrrrr     release / wave table buffer length
;  1C      aaaaaaaa aaaaaaaa aaaaaaaa aaa-----     wave table base address
;											vvvvv
;											wnpst
;  20-3C   Voice #2
;  40-5C   Voice #3
;  60-7C   Voice #4
;  80-9C   Voice #5
;  A0-BC   Voice #6
;  C0-DC   Voice #7
;  E0-FC   Voice #8
; 100-11C	Input
;
;	...
;	120     -------- -------- -------- ----vvvv   volume (0-15)
;	124     nnnnnnnn nnnnnnnn nnnnnnnn nnnnnnnn   osc3 oscillator 3
;	128     -------- -------- -------- nnnnnnnn   env[3] envelope 3
;  12C     -sss-sss -sss-sss -sss-sss -sss-sss   env state
;  130     ----oooo -------- RRRRRRRR RRRRRRRR   filter sample rate clock divider, output
;	134			-------- -------- -------i oooooooo		interrupt enable
;	138			-------- -------- -------i oooooooo		interrupt occurred
;	13C			-------- -------- -------i oooooooo		playback ended
;	140			-------- -------- -------i oooooooo		channel sync
;
;  180-1F8   -------- -------- s---kkkk kkkkkkkk   filter coefficients
;

PSG_FREQ equ $00
PSG_VOICE_TYPE equ $04
PSG_CTRL equ $05
PSG_OUTPUT_SEL equ $06
PSG_SUSTAIN equ $14
PSG_MASTER_VOLUME equ $120

AudioTestOn:
	lea PSG,a1
	moveq #7,d2													; eight output channels
	moveq #0,d3
.0001
	move.l #25770,d1
	bsr rbo
	move.l d1,PSG_FREQ(a1,d3.w)					; 600 Hz
	move.b #4,PSG_VOICE_TYPE(a1,d3.w)		; triangle wave
	move.b #16,PSG_CTRL(a1,d3.w)				; gate on, no envelope generator
	move.b #15,PSG_OUTPUT_SEL(a1,d3.w)	; output to all four output channels
	move.b #255,PSG_SUSTAIN(a1,d3.w)		; max sustain level
	add.w #32,d3												; 32 bytes per channel
	dbra d2,.0001
	move.b #12,PSG_MASTER_VOLUME(a1)		; volume 3/4 max
	move.b #3,ADAU1761									; turn on audio interface
	rts

AudioTestOff:
	lea PSG,a1
	moveq #7,d2													; eight output channels
	moveq #0,d3
.0001
	move.b #0,PSG_OUTPUT_SEL(a1,d3.w)		; turn off output to all channels
	add.w #32,d3												; 32 bytes per channel
	dbra d2,.0001
	move.b #0,PSG_MASTER_VOLUME(a1)
	move.b #0,ADAU1761									; turn off audio interface
	rts
