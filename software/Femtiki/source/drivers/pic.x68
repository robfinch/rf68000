;==============================================================================
; PLIC - platform level interrupt controller
;
; Register layout:
;   bits 0 to 7  = cause code to issue (vector number)
;   bits 8 to 11 = irq level to issue
;   bit 16 = irq enable
;   bit 17 = edge sensitivity
;   bit 18 = 0=vpa, 1=inta
;		bit 24 to 29 target core
;
; Note byte order must be reversed for PLIC.
;==============================================================================

	include "..\Femtiki\source\inc\device.x68"

setup_pic:
pic_setup:
pic_init:
init_pic:
	lea	PLIC,a0							; a0 points to PLIC
	lea	$80+4*29(a0),a1			; point to timer registers (29)
	move.l #$0006033F,(a1)	; initialize, core=63,edge sensitive,enabled,irq6,vpa
	lea	4(a1),a1						; point to keyboard registers (30)
	move.l #$3C060502,(a1)	; core=2,level sensitive,enabled,irq6,inta
	lea	4(a1),a1						; point to nmi button register (31)
	move.l #$00070302,(a1)	; initialize, core=2,edge sensitive,enabled,irq7,vpa
	lea	$80+4*16(a0),a1			; a1 points to ACIA register
	move.l #$3D030502,(a1)	; core=2,level sensitive,enabled,irq3,inta	
	lea	$80+4*4(a0),a1			; a1 points to io_bitmap irq
	move.l #$3B060702,(a1)	; core=2,edge sensitive,enabled,irq6,inta	
	rts

	global setup_pic
	global pic_setup
	global pic_init
