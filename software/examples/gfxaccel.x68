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

GFXACCEL_CMDTBL_ADDR macro arg1
	dc.w ((\1-GFXACCEL_CMDTBL))
endm

GFX_CTRL		equ	$100
GFX_STATUS	equ $104
GFX_TARGET_BASE		equ $110
GFX_TARGET_SIZE_X	equ $114
GFX_TARGET_SIZE_Y equ $118
GFX_DEST_PIXEL_X  equ $138
GFX_DEST_PIXEL_Y  equ $13c
GFX_DEST_PIXEL_Z  equ $140
GFX_CLIP_PIXEL0_X	equ $174
GFX_CLIP_PIXEL0_Y	equ $178
GFX_CLIP_PIXEL1_X	equ $17C
GFX_CLIP_PIXEL1_Y	equ $180
GFX_COLOR0	equ $184
GFX_COLOR1	equ $188
GFX_COLOR2	equ $18C
GFX_TARGET_X0	equ $1B0
GFX_TARGET_Y0 equ $1B4
GFX_TARGET_X1	equ $1B8
GFX_TARGET_Y1	equ $1BC
GFX_COLOR_COMP equ $1D0
GFX_PPS equ $1D4

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; Graphics accelerator
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
	align 2
GFXACCEL_CMDTBL:
	GFXACCEL_CMDTBL_ADDR gfxaccel_init				; 0
	GFXACCEL_CMDTBL_ADDR gfxaccel_stat
	GFXACCEL_CMDTBL_ADDR gfxaccel_putchar
	GFXACCEL_CMDTBL_ADDR gfxaccel_putbuf
	GFXACCEL_CMDTBL_ADDR gfxaccel_getchar
	GFXACCEL_CMDTBL_ADDR gfxaccel_getbuf
	GFXACCEL_CMDTBL_ADDR gfxaccel_set_inpos
	GFXACCEL_CMDTBL_ADDR gfxaccel_set_outpos
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub				; 10
	GFXACCEL_CMDTBL_ADDR gfxaccel_stub
	GFXACCEL_CMDTBL_ADDR gfxaccel_clear
	GFXACCEL_CMDTBL_ADDR gfxaccel_swapbuf
	GFXACCEL_CMDTBL_ADDR gfxaccel_setbuf1
	GFXACCEL_CMDTBL_ADDR gfxaccel_setbuf2
	GFXACCEL_CMDTBL_ADDR gfxaccel_getbuf1
	GFXACCEL_CMDTBL_ADDR gfxaccel_getbuf2
	GFXACCEL_CMDTBL_ADDR gfxaccel_writeat
	GFXACCEL_CMDTBL_ADDR gfxaccel_set_unit
	GFXACCEL_CMDTBL_ADDR gfxaccel_get_dimen	; 20
	GFXACCEL_CMDTBL_ADDR gfxaccel_get_color
	GFXACCEL_CMDTBL_ADDR gfxaccel_get_inpos
	GFXACCEL_CMDTBL_ADDR gfxaccel_get_outpos
	GFXACCEL_CMDTBL_ADDR gfxaccel_get_outptr
	GFXACCEL_CMDTBL_ADDR gfxaccel_set_color
	GFXACCEL_CMDTBL_ADDR gfxaccel_set_color123
	GFXACCEL_CMDTBL_ADDR gfxaccel_plot_point
	GFXACCEL_CMDTBL_ADDR gfxaccel_draw_line
	GFXACCEL_CMDTBL_ADDR gfxaccel_draw_triangle
	GFXACCEL_CMDTBL_ADDR gfxaccel_draw_rectangle	;30
	GFXACCEL_CMDTBL_ADDR gfxaccel_draw_curve
	GFXACCEL_CMDTBL_ADDR gfxaccel_set_dimen
	GFXACCEL_CMDTBL_ADDR gfxaccel_set_color_depth
	GFXACCEL_CMDTBL_ADDR gfxaccel_set_destbuf
	GFXACCEL_CMDTBL_ADDR gfxaccel_set_dispbuf

	code
	even

gfxaccel_cmdproc:
	cmpi.b #36,d6
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

setup_gfxaccel:
	movem.l d0/a0/a1,-(a7)
	moveq #32,d0
	lea.l gfxaccel_dcb,a0
.0001:
	clr.l (a0)+
	dbra d0,.0001
	move.l #$44434220,gfxaccel_dcb+DCB_MAGIC			; 'DCB'
	move.l #$47465841,gfxaccel_dcb+DCB_NAME				; 'GFXACCEL'
	move.l #$4343454C,gfxaccel_dcb+DCB_NAME+4
	move.l #gfxaccel_cmdproc,gfxaccel_dcb+DCB_CMDPROC
	move.l #$00000000,d0
	move.l d0,gfxaccel_dcb+DCB_INBUFPTR
	move.l d0,gfxaccel_dcb+DCB_OUTBUFPTR
	add.l #$400000,d0
	move.l d0,gfxaccel_dcb+DCB_INBUFPTR2
	move.l d0,gfxaccel_dcb+DCB_OUTBUFPTR2
	move.l #$00400000,gfxaccel_dcb+DCB_INBUFSIZE
	move.l #$00400000,gfxaccel_dcb+DCB_OUTBUFSIZE
	move.l #$00008888,GFXACCEL+GFX_COLOR_COMP
	lea.l gfxaccel_dcb+DCB_MAGIC,a1
	jsr DisplayString
	jsr CRLF
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

gfxaccel_stat:
	move.l GFXACCEL+GFX_STATUS,d1
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
	bsr div32								; number might be too big for divu
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
	bsr rbo
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
	ori.l #$00000400,d1							; trigger draw triangle
	move.l d1,GFXACCEL+GFX_CTRL
	movem.l (a7)+,d1/d2/d7
	moveq #E_Ok,d0
	rts

gfxaccel_draw_curve:
	movem.l d1/d2/d7,-(a7)
	move.l d1,d7
	moveq #11,d1
	bsr gfxaccel_wait								; wait for an open slot
	move.l d7,GFXACCEL+GFX_DEST_PIXEL_X
	move.l d2,GFXACCEL+GFX_DEST_PIXEL_Y
	clr.l GFXACCEL+GFX_DEST_PIXEL_Z
	moveq #0,d2											; point 0
	bsr gfxaccel_set_active_point
	move.l d3,GFXACCEL+GFX_DEST_PIXEL_X
	move.l d4,GFXACCEL+GFX_DEST_PIXEL_Y
	clr.l GFXACCEL+GFX_DEST_PIXEL_Z
	moveq #1,d2											; point 1
	bsr gfxaccel_set_active_point
	move.l d5,GFXACCEL+GFX_DEST_PIXEL_X
	move.l d0,GFXACCEL+GFX_DEST_PIXEL_Y
	clr.l GFXACCEL+GFX_DEST_PIXEL_Z
	moveq #2,d2											; point 2
	bsr gfxaccel_set_active_point
	move.l gfxaccel_ctrl,d1					; get the control reg
	ori.l #$00001C00,d1							; trigger draw curve+triangle+interp
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
	cmpi.l #2040,d2
	bhi.s .0001
	movem.l (a7)+,d1/d2/d3
	rts
