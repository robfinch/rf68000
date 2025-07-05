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

	include "..\Femtiki\source\inc\const.x68"
	include "..\Femtiki\source\inc\config.x68"
	include "..\Femtiki\source\inc\device.x68"

	section gvars
	align 2
gfx_inbuf_ptr
	ds.l	1
gfx_outbuf_ptr
	ds.l	1
gfx_inbuf_ptr2
	ds.l	1
gfx_outbuf_ptr2
	ds.l	1
gfx_inbuf_size
	ds.l	1
gfx_outbuf_size
	ds.l	1
gfx_color_comp
	ds.l	1
	
	code
	even
GFXACCEL_CMDTBL_ADDR macro arg1
	dc.w ((\1-GFXACCEL_CMDTBL))
endm

GFX_CTRL		equ	$00
GFX_STATUS	equ $04
GFX_TARGET_BASE		equ $10
GFX_TARGET_SIZE_X	equ $14
GFX_TARGET_SIZE_Y equ $18
GFX_DEST_PIXEL_X  equ $38
GFX_DEST_PIXEL_Y  equ $3c
GFX_DEST_PIXEL_Z  equ $40
GFX_CLIP_PIXEL0_X	equ $74
GFX_CLIP_PIXEL0_Y	equ $78
GFX_CLIP_PIXEL1_X	equ $7C
GFX_CLIP_PIXEL1_Y	equ $80
GFX_COLOR0	equ $84
GFX_COLOR1	equ $88
GFX_COLOR2	equ $8C
GFX_TARGET_X0	equ $B0
GFX_TARGET_Y0 equ $B4
GFX_TARGET_X1	equ $B8
GFX_TARGET_Y1	equ $BC
GFX_COLOR_COMP equ $D0
GFX_PPS equ $D4

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; Graphics accelerator
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
	align 2
GFXACCEL_CMDTBL:
;	GFXACCEL_CMDTBL_ADDR gfxaccel_writeat
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub					; 0 NOP
	GFXACCEL_CMDTBL_ADDR gfxaccel_setup				; 1
	GFXACCEL_CMDTBL_ADDR gfxaccel_init					; 2
	GFXACCEL_CMDTBL_ADDR gfxaccel_stat					; 3
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub					; 4 media check
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub					; 5 reserved
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub					; 6 open
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub					; 7 close
	GFXACCEL_CMDTBL_ADDR gfxaccel_getchar				; 8 get char
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub					; 9 peek char
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub					; 10 get char direct
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub					; 11 peek char direct
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub					; 12 input status
	GFXACCEL_CMDTBL_ADDR gfxaccel_putchar			; 13 putchar
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub					; 14 reserved
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub					; 15 set position
	GFXACCEL_CMDTBL_ADDR gfxaccel_getbuf			  ; 16 read block
	GFXACCEL_CMDTBL_ADDR gfxaccel_putbuf				; 17 write block
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub					; 18 verify block
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub					; 19 output status
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub					; 20 flush input
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub					; 21 flush output
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub					; 22 IRQ
	GFXACCEL_CMDTBL_ADDR gfxaccel_is_removeable	; 23 is removeable
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub					; 24 IOCTRL read
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub					; 25 IOCTRL write
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub					; 26 output until busy
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub					; 27 shutdown
	GFXACCEL_CMDTBL_ADDR gfxaccel_clear					; 28 clear
	GFXACCEL_CMDTBL_ADDR gfxaccel_swapbuf				; 29 swap buf
	GFXACCEL_CMDTBL_ADDR gfxaccel_setbuf1				; 30 setbuf 1
	GFXACCEL_CMDTBL_ADDR gfxaccel_setbuf2				; 31 setbuf 2
	GFXACCEL_CMDTBL_ADDR gfxaccel_getbuf1				; 32 getbuf 1
	GFXACCEL_CMDTBL_ADDR gfxaccel_getbuf2				; 33 getbuf 2
	GFXACCEL_CMDTBL_ADDR gfxaccel_get_dimen		; 34 get dimensions
	GFXACCEL_CMDTBL_ADDR gfxaccel_get_color		; 35 get color
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub					; 36 get position
	GFXACCEL_CMDTBL_ADDR gfxaccel_set_color		; 37 set color
	GFXACCEL_CMDTBL_ADDR gfxaccel_set_color123	; 38 set color 123
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub					; 39 reserved
	GFXACCEL_CMDTBL_ADDR gfxaccel_plot_point
	GFXACCEL_CMDTBL_ADDR gfxaccel_draw_line
	GFXACCEL_CMDTBL_ADDR gfxaccel_draw_triangle
	GFXACCEL_CMDTBL_ADDR gfxaccel_draw_rectangle	;30
	GFXACCEL_CMDTBL_ADDR gfxaccel_draw_curve
	GFXACCEL_CMDTBL_ADDR gfxaccel_set_dimen			; 45 set dimensions
	GFXACCEL_CMDTBL_ADDR gfxaccel_set_color_depth	; 46 set color depth
	GFXACCEL_CMDTBL_ADDR gfxaccel_set_destbuf		; 47 set destination buffer
	GFXACCEL_CMDTBL_ADDR gfxaccel_set_dispbuf		; 48 set display buffer
	GFXACCEL_CMDTBL_ADDR gfxaccel_get_inpos	  ; 49 get input position
	GFXACCEL_CMDTBL_ADDR gfxaccel_set_inpos		; 50 set input position
	GFXACCEL_CMDTBL_ADDR gfxaccel_set_outpos		; 51 set output position
	GFXACCEL_CMDTBL_ADDR gfxaccel_get_outpos		; 52 get output position
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub		; 53 get input pointer
	GFXACCEL_CMDTBL_ADDR gfxaccel_get_outptr		; 54 get output pointer
	GFXACCEL_CMDTBL_ADDR gfxaccel_set_unit			; 55 set unit


	code
	even

_gfxaccel_cmdproc:
gfxaccel_cmdproc:
	cmpi.b #56,d6
	bhs.s .0001
	movem.l d6/a0,-(a7)
	ext.w d6
	ext.l d6
	lsl.w #1,d6
	lea.l GFXACCEL_CMDTBL(pc),a0
	move.w (a0,d6.w),d6
	ext.l d6
	add.l d6,a0
	jsr (a0)
	movem.l (a7)+,d6/a0
	rts
.0001:
	moveq #E_NotSupported,d0
	rts
	global _gfxaccel_cmdproc

_setup_gfxaccel:
setup_gfxaccel:
gfxaccel_setup:
	movem.l d0/a0/a1,-(a7)
	move.l d0,a0
	move.l d0,a1
	moveq #15,d0
.0001:
	clr.l (a0)+
	dbra d0,.0001
	move.l #$44434220,DCB_MAGIC(a1)			; 'DCB'
	move.l #$47465841,DCB_NAME(a1)				; 'GFXACCEL'
	move.l #$4343454C,DCB_NAME+4(a1)
	move.l #gfxaccel_cmdproc,DCB_CMDPROC(a1)
	move.l #$00000000,d0
	move.l d0,gfx_inbuf_ptr
	move.l d0,gfx_outbuf_ptr
	add.l #$400000,d0
	move.l d0,gfx_inbuf_ptr2
	move.l d0,gfx_outbuf_ptr2
	move.l #$00400000,gfx_inbuf_size
	move.l #$00400000,gfx_outbuf_size
	move.l #$00008888,GFXACCEL+GFX_COLOR_COMP
	lea.l DCB_MAGIC(a1),a1
	moveq #13,d0
	trap #15
	movem.l (a7)+,d0/a0/a1

gfxaccel_init:
	move.l d1,-(a7)
	moveq #8,d1
	bsr gfxaccel_wait
	move.l #0,d1
	move.l d1,gfxaccel_ctrl
	move.l d1,GFXACCEL+GFX_CTRL
	move.l #$00000000,d1
	move.l d1,GFXACCEL+GFX_TARGET_BASE	; base draw address
	move.l #VIDEO_X,d1
	move.l d1,GFXACCEL+GFX_TARGET_SIZE_X	; render target x dimension
	move.l d1,GFXACCEL+GFX_TARGET_X1
	move.l #VIDEO_Y,d1
	move.l d1,GFXACCEL+GFX_TARGET_SIZE_Y	; render target y dimension
	move.l d1,GFXACCEL+GFX_TARGET_Y1
	move.l #0,GFXACCEL+GFX_TARGET_X0
	move.l #0,GFXACCEL+GFX_TARGET_Y0
	move.l (a7)+,d1
	rts
	global setup_gfxaccel
	global _setup_gfxaccel

gfxaccel_stat:
	move.l GFXACCEL+GFX_STATUS,d1
	moveq #E_Ok,d0
	rts

gfxaccel_is_removeable:
	moveq #0,d1
	moveq #E_Ok,d0
	rts

gfxaccel_putchar:
gfxaccel_getchar:
gfxaccel_putbuf:
gfxaccel_getbuf:
gfxaccel_set_inpos:
gfxaccel_set_outpos:
gfxaccel_stub:
gfxaccel_swapbuf:
gfxaccel_setbuf1:
gfxaccel_setbuf2:
gfxaccel_getbuf1:
gfxaccel_getbuf2:
gfxaccel_writeat:
gfxaccel_set_unit:
gfxaccel_get_dimen:
gfxaccel_get_inpos:
gfxaccel_get_outpos:
gfxaccel_get_outptr:
gfxaccel_set_dispbuf:
	move.l #E_NotSupported,d0
	rts

gfxaccel_set_dimen:
	move.l d1,-(a7)
	move.l d1,d0
	moveq #5,d1
	bsr gfxaccel_wait					; wait for an open slot
	move.l d0,d1
	move.l d1,GFXACCEL+GFX_TARGET_SIZE_X	; render target x dimension
	move.l d1,GFXACCEL+GFX_TARGET_X1
	move.l d2,GFXACCEL+GFX_TARGET_SIZE_Y	; render target y dimension
	move.l d2,GFXACCEL+GFX_TARGET_Y1
	move.l (a7)+,d1
	moveq #E_Ok,d0
	rts

gfxaccel_set_destbuf:
	move.l d1,d0
	moveq #2,d1
	bsr gfxaccel_wait					; wait for an open slot
	move.l d0,GFXACCEL+GFX_TARGET_BASE
	move.l d0,d1
	move.l #E_Ok,d0
	rts

; Clears destination buffer

gfxaccel_clear:
	movem.l d1/d2/d4/a0,-(a7)
	move.l GFXACCEL+GFX_TARGET_SIZE_X,d1
	move.l GFXACCEL+GFX_TARGET_SIZE_Y,d2
	mulu d1,d2							; d2 = X dimen * Y dimen = number of pixels
	move.l GFXACCEL+GFX_PPS,d4	; d4 = pixels per strip reg
	andi.w #$3ff,d4					; extract pixels per strip
	ext.l d4
	add.l d4,d2							; round number of pixels on screen up a strip
	move.l d2,d1						; d1 = total pixels
	lsr.l #5,d1							; pixel count/burst length
	move.l d4,d2						; d2 = pixels per strip
	jsr div32								; number might be too big for divu
	move.l d1,d0						; d0 = number of strips to set
	move.l GFXACCEL+GFX_COLOR0,d4
	move.l GFXACCEL+GFX_TARGET_BASE,d1
	move.l d1,a0
	move.l #$3F000000,$7FFFFFF8			; set burst length 64 (double causes overlap)
	bra.s .loop
.loop2:
	swap d0
.loop:
	move.l a0,d1
	jsr rbo
	move.l d1,$7FFFFFF4			; set destination address
	move.l d4,$7FFFFFFC			; write value (color) to use and trigger write op
	lea 1024(a0),a0					; advance pointer 32 bytes * 32 strips
	dbra d0,.loop
	swap d0
	dbra d0,.loop2
	movem.l (a7)+,d1/d2/d4/a0
	move.l #E_Ok,d0
	rts


gfxaccel_set_color_depth:
	move.l d1,d0
	moveq #2,d1
	bsr gfxaccel_wait					; wait for an open slot
	move.l d0,GFXACCEL+GFX_COLOR_COMP
	move.l d0,d1
	moveq #E_Ok,d0
	rts
	
gfxaccel_get_color:
	move.l GFXACCEL+GFX_COLOR0,d1
	moveq #E_Ok,d0
	rts

gfxaccel_set_color:
	movem.l d1/d3,-(a7)
	move.l d1,d3
	moveq #2,d1
	bsr gfxaccel_wait					; wait for an open slot
	move.l d3,GFXACCEL+GFX_COLOR0
	movem.l (a7)+,d1/d3
	moveq #E_Ok,d0
	rts

gfxaccel_set_color123:
	movem.l d1/d4,-(a7)
	move.l d1,d4
	moveq #4,d1
	bsr gfxaccel_wait					; wait for an open slot
	move.l d4,GFXACCEL+GFX_COLOR0
	move.l d2,GFXACCEL+GFX_COLOR1
	move.l d3,GFXACCEL+GFX_COLOR2
	movem.l (a7)+,d1/d4
	moveq #E_Ok,d0
	rts

gfxaccel_clip_rect:
	movem.l d1/d5,-(a7)
	move.l d1,d5
	moveq #5,d1
	bsr gfxaccel_wait					; wait for an open slot
	move.l d5,GFXACCEL+GFX_CLIP_PIXEL0_X
	move.l d2,GFXACCEL+GFX_CLIP_PIXEL0_Y
	move.l d3,GFXACCEL+GFX_CLIP_PIXEL1_X
	move.l d4,GFXACCEL+GFX_CLIP_PIXEL1_Y
	movem.l (a7)+,d1/d5
	moveq #E_Ok,d0
	rts

; Assumes the point number is valid
;
; Parameters:
;		d2.l = active point to set (0 to 2)
;
gfxaccel_set_active_point:
	swap d2													; move point number to bits 16,17
	move.l gfxaccel_ctrl,d1
	andi.l #$FFF8FFFF,d1						; clear point number bits
	or.l d2,d1											; set the point number bits
	move.l d1,gfxaccel_ctrl
	ori.l #$00040000,d1							; set active point+forward point bit
	move.l d1,GFXACCEL+GFX_CTRL
	rts

; Graphics accelerator expects that co-ordinates are in 16.16 format.
;
; Parameters:
;		d1 = x
;		d2 = y
;		d3 = z
; 
gfxaccel_plot_point:
	movem.l d1/d5,-(a7)
	move.l d1,d5
	moveq #6,d1
	bsr gfxaccel_wait								; wait for an open slot
	move.l d5,GFXACCEL+GFX_DEST_PIXEL_X
	move.l d2,GFXACCEL+GFX_DEST_PIXEL_Y
	move.l d3,GFXACCEL+GFX_DEST_PIXEL_Z
	moveq #0,d2											; point 0
	bsr gfxaccel_set_active_point
	move.l gfxaccel_ctrl,d1
	ori.l #$00000080,d1							; point write, bit will clear automatically
	move.l d1,GFXACCEL+GFX_CTRL
	movem.l (a7)+,d1/d5
	moveq #E_Ok,d0
	rts

; Parameters:
;		d1 = x0
;		d2 = y0
;		d3 = z0
;		d4 = x1
;		d5 = y1
;		d0 = z1
; 
gfxaccel_draw_line:
	movem.l d1/d2/d6,-(a7)
	move.l d1,d6
	moveq #9,d1
	bsr gfxaccel_wait								; wait for an open slot
	move.l d6,GFXACCEL+GFX_DEST_PIXEL_X
	move.l d2,GFXACCEL+GFX_DEST_PIXEL_Y
	move.l d3,GFXACCEL+GFX_DEST_PIXEL_Z
	moveq #0,d2											; point 0
	bsr gfxaccel_set_active_point
	move.l d4,GFXACCEL+GFX_DEST_PIXEL_X
	move.l d5,GFXACCEL+GFX_DEST_PIXEL_Y
	move.l d0,GFXACCEL+GFX_DEST_PIXEL_Z
	moveq #1,d2											; point 1
	bsr gfxaccel_set_active_point
	move.l gfxaccel_ctrl,d1					; get the control reg
	ori.l #$00000200,d1							; trigger draw line
	move.l d1,GFXACCEL+GFX_CTRL
	movem.l (a7)+,d1/d2/d6
	moveq #E_Ok,d0
	rts

; Draw a rectangle in the currently selected color
;
; Parameters:
;		d1 	- x0 pos
;		d2	- y0 pos
;		d3	- x1 pos
;		d4	- y1 pos

gfxaccel_draw_rectangle:
	movem.l d1/d2/d6,-(a7)
	move.l d1,d6
	moveq #9,d1
	bsr gfxaccel_wait								; wait for an open slot
	move.l d6,GFXACCEL+GFX_DEST_PIXEL_X
	move.l d2,GFXACCEL+GFX_DEST_PIXEL_Y
	move.l d3,GFXACCEL+GFX_DEST_PIXEL_Z
	moveq #0,d2											; point 0
	bsr gfxaccel_set_active_point
	move.l d4,GFXACCEL+GFX_DEST_PIXEL_X
	move.l d5,GFXACCEL+GFX_DEST_PIXEL_Y
	move.l d0,GFXACCEL+GFX_DEST_PIXEL_Z
	moveq #1,d2											; point 1
	bsr gfxaccel_set_active_point
	move.l gfxaccel_ctrl,d1					; get the control reg
	ori.l #$00000100,d1							; trigger draw rectangle
	move.l d1,GFXACCEL+GFX_CTRL
	movem.l (a7)+,d1/d2/d6
	moveq #E_Ok,d0
	rts

; Draw a triangle in the currently selected color
;
; Parameters:
;		d1 	- x0 pos
;		d2	- y0 pos
;		d3	- z0 pos
;		d4	- x1 pos
;	  d5	- y1 pos
;		d0	- z1 pos
;		a1	- x2
;		a2	- y2
;		a3	- z2
;		a4 = $400 to draw triangle, +$800 for curve, +$1000 for interpolate, $2000 for inside

gfxaccel_draw_triangle:
	movem.l d1/d2/d7,-(a7)
	move.l d1,d7
	moveq #13,d1
	bsr gfxaccel_wait								; wait for an open slot
	move.l d7,GFXACCEL+GFX_DEST_PIXEL_X
	move.l d2,GFXACCEL+GFX_DEST_PIXEL_Y
	move.l d3,GFXACCEL+GFX_DEST_PIXEL_Z
	moveq #0,d2											; point 0
	bsr gfxaccel_set_active_point
	move.l d4,GFXACCEL+GFX_DEST_PIXEL_X
	move.l d5,GFXACCEL+GFX_DEST_PIXEL_Y
	move.l d0,GFXACCEL+GFX_DEST_PIXEL_Z
	moveq #1,d2											; point 1
	bsr gfxaccel_set_active_point
	move.l a1,GFXACCEL+GFX_DEST_PIXEL_X
	move.l a2,GFXACCEL+GFX_DEST_PIXEL_Y
	move.l a3,GFXACCEL+GFX_DEST_PIXEL_Z
	moveq #2,d2											; point 2
	bsr gfxaccel_set_active_point
	move.l gfxaccel_ctrl,d1					; get the control reg
	move.l a4,d2
	or.l d2,d1											; trigger draw triangle
	move.l d1,GFXACCEL+GFX_CTRL
	movem.l (a7)+,d1/d2/d7
	moveq #E_Ok,d0
	rts

gfxaccel_draw_curve:
	movem.l d1/d2/d7,-(a7)
	move.l d1,d7
	moveq #13,d1
	bsr gfxaccel_wait								; wait for an open slot
	move.l d7,GFXACCEL+GFX_DEST_PIXEL_X
	move.l d2,GFXACCEL+GFX_DEST_PIXEL_Y
	move.l d3,GFXACCEL+GFX_DEST_PIXEL_Z
	moveq #0,d2											; point 0
	bsr gfxaccel_set_active_point
	move.l d4,GFXACCEL+GFX_DEST_PIXEL_X
	move.l d5,GFXACCEL+GFX_DEST_PIXEL_Y
	move.l d0,GFXACCEL+GFX_DEST_PIXEL_Z
	moveq #1,d2											; point 1
	bsr gfxaccel_set_active_point
	move.l a1,GFXACCEL+GFX_DEST_PIXEL_X
	move.l a2,GFXACCEL+GFX_DEST_PIXEL_Y
	move.l a3,GFXACCEL+GFX_DEST_PIXEL_Z
	moveq #2,d2											; point 2
	bsr gfxaccel_set_active_point
	move.l gfxaccel_ctrl,d1					; get the control reg
	move.l a4,d2
	or.l d2,d1											; trigger draw curve+triangle+interp $1C00
	move.l d1,GFXACCEL+GFX_CTRL
	movem.l (a7)+,d1/d2/d7
	moveq #E_Ok,d0
	rts

; Waits until the specified number of queue slots are available.
;
; Parameters:
;		d1 = number of queue slots required

gfxaccel_wait:
	movem.l d1/d2/d3,-(a7)
	move.l d1,d2
	move.l d1,d3
.0001:
	move.l GFXACCEL+GFX_STATUS,d1
	btst.l #0,d1			; first check busy bit
	bne.s .0001
	swap d1						; que count is in bits 16 to 31
	ext.l d1
	move.l d3,d2
	add.l d1,d2
	cmpi.l #2020,d2
	bhi.s .0001
	movem.l (a7)+,d1/d2/d3
	rts
