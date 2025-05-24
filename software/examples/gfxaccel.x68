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

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; Graphics accelerator
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
	align 2
GFXACCEL_CMDTBL:
	dc.l gfxaccel_init				; 0
	dc.l gfxaccel_stat
	dc.l gfxaccel_putchar
	dc.l gfxaccel_putbuf
	dc.l gfxaccel_getchar
	dc.l gfxaccel_getbuf
	dc.l gfxaccel_set_inpos
	dc.l gfxaccel_set_outpos
	dc.l gfxaccel_stub
	dc.l gfxaccel_stub
	dc.l gfxaccel_stub				; 10
	dc.l gfxaccel_stub
	dc.l gfxaccel_clear
	dc.l gfxaccel_swapbuf
	dc.l gfxaccel_setbuf1
	dc.l gfxaccel_setbuf2
	dc.l gfxaccel_getbuf1
	dc.l gfxaccel_getbuf2
	dc.l gfxaccel_writeat
	dc.l gfxaccel_set_unit
	dc.l gfxaccel_get_dimen	; 20
	dc.l gfxaccel_get_color
	dc.l gfxaccel_get_inpos
	dc.l gfxaccel_get_outpos
	dc.l gfxaccel_get_outptr
	dc.l gfxaccel_set_color
	dc.l gfxaccel_set_color123
	dc.l gfxaccel_plot_point
	dc.l gfxaccel_draw_line
	dc.l gfxaccel_draw_triangle
	dc.l gfxaccel_draw_rectangle

	code
	even
setup_gfxaccel:
gfxaccel_init:
	move.l #1,GFXACCEL							; select 16bpp color
	move.l #$00000000,d1
	bsr rbo
	move.l d1,GFXACCEL+$10	; base draw address
	move.l #32640,d1
	bsr rbo
	move.l d1,GFXACCEL+$14				; render target x dimension
	move.l #16384,d1
	bsr rbo
	move.l d1,GFXACCEL+$18				; render target y dimension
	rts

gfxaccel_cmdproc:
	cmpi.b #27,d6
	bhs.s .0001
	movem.l d6/a0,-(a7)
	ext.w d6
	lsl.w #2,d6
	lea GFXACCEL_CMDTBL,a0
	move.l (a0,d6.w),a0
	jsr (a0)
	movem.l (a7)+,d6/a0
	rts
.0001:
	moveq #E_Func,d0
	rts

gfxaccel_stat:
	move.l GFXACCEL+4,d1
	moveq #E_Ok,d0
	rts
	
gfxaccel_clear:
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
gfxaccel_plot_point:
gfxaccel_draw_line:
	move.l #E_NotSupported,d0
	rts

gfxaccel_get_color:
	move.l GFXACCEL+$84,d1
	moveq #E_Ok,d0
	rts

gfxaccel_set_color:
	movem.l d1/d3,-(a7)
	bsr rbo
	move.l d1,d3
	move.l #1,d1
	bsr gfxaccel_wait
	move.l d3,GFXACCEL+$84
	movem.l (a7)+,d1/d3
	moveq #E_Ok,d0
	rts

gfxaccel_set_color123:
	movem.l d1/d4,-(a7)
	bsr rbo
	move.l d1,d4
	move.l #3,d1
	bsr gfxaccel_wait
	move.l d4,GFXACCEL+$84
	move.l d2,GFXACCEL+$88
	move.l d3,GFXACCEL+$8C
	movem.l (a7)+,d1/d4
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
	movem.l d1/d2,-(a7)
	moveq #7,d1
	bsr gfxaccel_wait
	movem.l (a7)+,d1/d2
	bsr rbo
	move.l d1,GFXACCEL+$38					; p0 x
	move.l d2,d1
	bsr rbo
	move.l d1,GFXACCEL+$3C					; p0 y
	move.l #$00040001,d1						; set active point 0
	bsr rbo
	move.l d1,GFXACCEL
	move.l d3,d1
	bsr rbo
	move.l d1,GFXACCEL+$38
	move.l d4,d1
	bsr rbo
	move.l d1,GFXACCEL+$3C
	move.l #$00050001,d1						; set active point 1
	bsr rbo
	move.l d1,GFXACCEL
	move.l #$00000101,d1
	bsr rbo
	move.l d1,GFXACCEL
	moveq #E_Ok,d0
	rts

; Draw a triangle in the currently selected color
;
; Parameters:
;		d1 	- x0 pos
;		d2	- y0 pos
;		d3	- x1 pos
;		d4	- y1 pos
;	  d5	- x2 pos
;		d6	- y2 pos

gfxaccel_draw_triangle:
	movem.l d1/d2,-(a7)
	moveq #13,d1
	bsr gfxaccel_wait
	movem.l (a7)+,d1/d2
	bsr rbo
	move.l d1,GFXACCEL+$38					; p0 x
	move.l d2,d1
	bsr rbo
	move.l d1,GFXACCEL+$3C					; p0 y
	move.l #$00040001,d1						; set active point 0
	bsr rbo
	move.l d1,GFXACCEL
	move.l d3,d1
	bsr rbo
	move.l d1,GFXACCEL+$38
	move.l d4,d1
	bsr rbo
	move.l d1,GFXACCEL+$3C
	move.l #$00050001,d1						; set active point 1
	bsr rbo
	move.l d1,GFXACCEL
	move.l #$00000101,d1
	move.l d1,GFXACCEL
	move.l d5,d1
	bsr rbo
	move.l d5,GFXACCEL+$38
	move.l d6,d1
	bsr rbo
	move.l d6,GFXACCEL+$3C
	move.l #$00060001,d1						; set active point 2
	bsr rbo
	move.l d1,GFXACCEL
	move.l #$00000401,d1						; write triangle
	bsr rbo
	move.l d1,GFXACCEL
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
	move.l GFXACCEL+$04,d1
	bsr rbo
	btst.l #0,d1			; first check busy bit
	bne.s .0001
	swap d1
	ext.l d1
	move.l d3,d2
	add.l d1,d2
	cmpi.l #1020,d2
	bhi.s .0001
	movem.l (a7)+,d1/d2/d3
	rts
