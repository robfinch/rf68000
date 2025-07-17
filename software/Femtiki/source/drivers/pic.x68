;==============================================================================
; PIC - programmable interrupt controller
;
; Register layout:
;   bits 0 to 7  = cause code to issue (vector number)
;   bits 8 to 11 = irq level to issue
;   bit 16 = irq enable
;   bit 17 = edge sensitivity
;   bit 18,19 = 0=vpa, 1=inta, 2= vpa2
;		bit 20 = rotate
;		bit 24 to 29 target core
;
; Note byte order must be reversed for PIC.
;==============================================================================

	include "..\Femtiki\source\inc\device.x68"

setup_pic:
pic_setup:
pic_init:
init_pic:
	lea	PIC,a0							; a0 points to PIC
;	move.l #$02050000,$1c(a0)	; set min/max core number for rotate
	lea	$80+4*29(a0),a1			; point to timer registers (29)
	move.l #$00060902,(a1)	; initialize, core=2,edge sensitive,enabled,irq6,inta
;	move.l #$00060302,(a1)	; initialize, core=2,edge sensitive,disabled,irq6,vpa2
	lea	4(a1),a1						; point to keyboard registers (30)
	move.l #$3C050502,(a1)	; core=2,level sensitive,enabled,irq5,inta
	lea	4(a1),a1						; point to nmi button register (31)
	move.l #$00070302,(a1)	; initialize, core=2,edge sensitive,enabled,irq7,vpa
	lea	$80+4*16(a0),a1			; a1 points to ACIA register
	move.l #$3D030502,(a1)	; core=2,level sensitive,enabled,irq3,inta	
;	lea	$80+4*4(a0),a1			; a1 points to io_bitmap irq
;	move.l #$3B060702,(a1)	; core=2,edge sensitive,enabled,irq6,inta	
	rts

	global setup_pic
	global pic_setup
	global pic_init
