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
;	include "..\inc\device.x68"

	section gvars
	align 2
fb_fg_color
	ds.l	1
fb_bk_color
	ds.l	1
fb_inbuf_ptr
	ds.l	1
fb_outbuf_ptr
	ds.l	1
fb_inbuf_size
	ds.l	1
fb_outbuf_size
	ds.l	1
fb_inpos_x
	ds.l	1
fb_inpos_y
	ds.l	1
fb_outpos_x
	ds.l	1
fb_outpos_y
	ds.l	1
fb_opcode
	ds.b	1
	align 2
fb_dimen_x
	ds.w	1
fb_dimen_y
	ds.w	1
fb_inbuf_ptr2
	ds.l	1
fb_outbuf_ptr2
	ds.l	1
fb_outbuf_size2
	ds.l	1
fb_unit
	ds.l	1

FB_CTA macro arg1
	dc.w (\1-FRAMEBUF_CMDTBL)
endm

FRAMEBUF_CTRL equ 0
FRAMEBUF_PAGE1_ADDR equ 2*8
FRAMEBUF_PAGE2_ADDR equ 3*8
FRAMEBUF_BMPSIZE_X equ 13*8
FRAMEBUF_BMPSIZE_Y equ 13*8+4
FRAMEBUF_WINDOW_DIMEN	equ	15*8
FRAMEBUF_COLOR_COMP	equ 19*8
FRAMEBUF_PRGB equ 20*8
FRAMEBUF_COLOR equ 21*8
FRAMEBUF_PPS equ 22*8

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; Video frame buffer
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
	code
	even
	align 2
FRAMEBUF_CMDTBL:
;	FB_CTA framebuf_writeat

	FB_CTA framebuf_stub					; 0 NOP
	FB_CTA framebuf_setup				; 1
	FB_CTA framebuf_init					; 2
	FB_CTA framebuf_stat					; 3
	FB_CTA framebuf_stub					; 4 media check
	FB_CTA framebuf_stub					; 5 reserved
	FB_CTA framebuf_stub					; 6 open
	FB_CTA framebuf_stub					; 7 close
	FB_CTA framebuf_getchar				; 8 get char
	FB_CTA framebuf_stub					; 9 peek char
	FB_CTA framebuf_stub					; 10 get char direct
	FB_CTA framebuf_stub					; 11 peek char direct
	FB_CTA framebuf_stub					; 12 input status
	FB_CTA framebuf_putchar				; 13 putchar
	FB_CTA framebuf_stub					; 14 reserved
	FB_CTA framebuf_stub					; 15 set position
	FB_CTA framebuf_getbuf			  ; 16 read block
	FB_CTA framebuf_putbuf				; 17 write block
	FB_CTA framebuf_stub					; 18 verify block
	FB_CTA framebuf_stub					; 19 output status
	FB_CTA framebuf_stub					; 20 flush input
	FB_CTA framebuf_stub					; 21 flush output
	FB_CTA framebuf_stub					; 22 IRQ
	FB_CTA framebuf_is_removeable	; 23 is removeable
	FB_CTA framebuf_stub					; 24 IOCTRL read
	FB_CTA framebuf_stub					; 25 IOCTRL write
	FB_CTA framebuf_stub					; 26 output until busy
	FB_CTA framebuf_stub					; 27 shutdown
	FB_CTA framebuf_clear					; 28 clear
	FB_CTA framebuf_swapbuf				; 29 swap buf
	FB_CTA framebuf_setbuf1				; 30 setbuf 1
	FB_CTA framebuf_setbuf2				; 31 setbuf 2
	FB_CTA framebuf_getbuf1				; 32 getbuf 1
	FB_CTA framebuf_getbuf2				; 33 getbuf 2
	FB_CTA framebuf_get_dimen		; 34 get dimensions
	FB_CTA framebuf_get_color		; 35 get color
	FB_CTA framebuf_stub					; 36 get position
	FB_CTA framebuf_stub					; 37 set color
	FB_CTA framebuf_stub					; 38 set color 123
	FB_CTA framebuf_stub					; 39 reserved
	FB_CTA framebuf_stub					; 40 plot point
	FB_CTA framebuf_stub					; 41 draw line
	FB_CTA framebuf_stub					; 42 draw triangle
	FB_CTA framebuf_stub					; 43 draw rectangle
	FB_CTA framebuf_stub					; 44 draw curve
	FB_CTA framebuf_set_dimen			; 45 set dimensions
	FB_CTA framebuf_set_color_depth	; 46 set color depth
	FB_CTA framebuf_set_destbuf		; 47 set destination buffer
	FB_CTA framebuf_set_dispbuf		; 48 set display buffer
	FB_CTA framebuf_stub	  ; 49 get input position
	FB_CTA framebuf_set_inpos		; 50 set input position
	FB_CTA framebuf_stub		; 51 get output position
	FB_CTA framebuf_set_outpos		; 52 set output position
	FB_CTA framebuf_stub		; 53 get input pointer
	FB_CTA framebuf_stub		; 54 get output pointer
	FB_CTA framebuf_set_unit			; 55 set unit

	code
	even
_framebuf_cmdproc:
framebuf_cmdproc:
	cmpi.b #56,d6
	bhs.s .0001
	movem.l d6/a0,-(a7)
	ext.w d6
	ext.l d6
	lsl.w #1,d6
	lea.l FRAMEBUF_CMDTBL(pc),a0
	move.w (a0,d6.w),d6
	ext.l d6
	add.l d6,a0
	jsr (a0)
	movem.l (a7)+,d6/a0
	rts
.0001:
	moveq #E_NotSupported,d0
	rts
	global _framebuf_cmdproc

setup_framebuf:
framebuf_setup:
	movem.l d0/a0/a1,-(a7)
	move.l d0,a0
	move.l d0,a1
	moveq #15,d0
.0001:
	clr.l (a0)+
	dbra d0,.0001
	move.l #$44434220,DCB_MAGIC(a1)			; 'DCB '
	move.l #$4652414D,DCB_NAME(a1)				; 'FRAMEBUF'
	move.l #$42554600,DCB_NAME+4(a1)
	move.l #framebuf_cmdproc,DCB_CMDPROC(a1)
	move.l #$00000000,d0
	move.l d0,fb_inbuf_ptr
	move.l d0,fb_outbuf_ptr
	move.l #$00400000,fb_inbuf_size
	move.l #$00400000,fb_outbuf_size
	lea.l DCB_MAGIC(a1),a1
	moveq #13,d0									; DisplayStringCRLF function
	trap #15
	bsr framebuf_init
	movem.l (a7)+,d0/a0/a1
	rts

framebuf_init:
	move.b #1,FRAMEBUF+0		; turn on frame buffer
	move.l #$00002AAA,FRAMEBUF+FRAMEBUF_COLOR_COMP	; 2-10-10-10 color
	move.b #$11,FRAMEBUF+2	; hres 1:1 vres 1:1
	move.l #$0F000063,FRAMEBUF+4		; burst length, burst interval
	move.l #$3fffffff,fb_fg_color	; white
	move.l #$000000ff,fb_bk_color	; medium blue
	clr.l fb_outpos_x
	clr.l fb_outpos_y
	clr.l fb_inpos_x
	clr.l fb_inpos_y
	move.b #1,fb_opcode	; raster op = copy
	move.w #1024,fb_dimen_x		; set rows and columns
	move.w #768,fb_dimen_y
	move.w #1024,fb_dimen_x			; set rows and columns
	move.w #768,fb_dimen_y
	move.l #$00000000,fb_inbuf_ptr
	move.l #$00400000,fb_inbuf_ptr2
	move.l #$00000000,fb_outbuf_ptr
	move.l #$00400000,fb_outbuf_ptr2
	move.l #$00000000,FRAMEBUF+FRAMEBUF_PAGE1_ADDR	; base addr 1
	move.l #$00400000,FRAMEBUF+FRAMEBUF_PAGE2_ADDR	; base addr 2
	rts

framebuf_stat:
framebuf_putchar:
framebuf_getchar:
framebuf_set_destbuf:
	rts

framebuf_is_removeable:
	moveq #0,d1
	moveq #E_Ok,d0
	rts

framebuf_set_inpos:
	move.l d1,fb_inpos_x
	move.l d2,fb_inpos_y
	rts
framebuf_set_outpos:
	move.l d1,fb_outpos_x
	move.l d2,fb_outpos_y
	rts

framebuf_getbuf1:
	move.l fb_outbuf_ptr,d1
	rts
framebuf_getbuf2:
	move.l fb_outbuf_ptr2,d1
	rts
framebuf_setbuf1:
	move.l d1,fb_outbuf_ptr
	move.l d2,fb_outbuf_size
	rts
framebuf_setbuf2:
	move.l d1,fb_outbuf_ptr2
	move.l d2,fb_outbuf_size2
	rts

framebuf_swapbuf:
	movem.l d1/d2,-(a7)
	move.b FRAMEBUF+3,d1
	eor.b #1,d1
	move.b d1,FRAMEBUF+3					; page flip
	move.l fb_outbuf_ptr,d2
	move.l fb_outbuf_ptr2,d0
	move.l d2,fb_outbuf_ptr2
	move.l d0,fb_outbuf_ptr
	move.l d0,GFXACCEL+FRAMEBUF_PAGE1_ADDR
	move.l fb_inbuf_ptr,d2
	move.l fb_inbuf_ptr2,d0
	move.l d2,fb_inbuf_ptr2
	move.l d0,fb_inbuf_ptr
	movem.l (a7)+,d1/d2
	move.l #E_Ok,d0
	rts

framebuf_set_dispbuf:
	move.l d1,FRAMEBUF+FRAMEBUF_PAGE1_ADDR
	move.b #0,FRAMEBUF+3					; set display page
	move.l #E_Ok,d0
	rts

framebuf_set_unit:
	move.l d1,fb_unit
	move.l #E_Ok,d0
	rts

framebuf_getbuf:
framebuf_putbuf:
framebuf_stub:
	moveq #E_NotSupported,d0
	rts

framebuf_set_color_depth:
	move.l d1,FRAMEBUF+FRAMEBUF_COLOR_COMP
	move.l #E_Ok,d0
	rts
	
framebuf_get_color:
	move.l fb_fg_color,d1
	move.l fb_bk_color,d2
	move.l #E_Ok,d0
	rts

framebuf_get_dimen:
	cmpi.b #0,d0
	bne.s .0001
	move.l fb_dimen_x,d1
	move.l fb_dimen_y,d2
	clr.l d3
	move.l #E_Ok,d0
	rts
.0001:
	move.l fb_dimen_x,d1
	move.l fb_dimen_y,d2
	clr.l d3
	move.l #E_Ok,d0
	rts

framebuf_set_dimen:
	cmpi.b #0,d0
	bne.s .0001
	move.l d1,fb_dimen_x
	move.l d2,fb_dimen_y
	move.l d1,FRAMEBUF+FRAMEBUF_BMPSIZE_X
	move.l d2,FRAMEBUF+FRAMEBUF_BMPSIZE_Y
	move.l #E_Ok,d0
	rts
.0001:
	cmpi.b #1,d0
	bne.s .0002
	move.l d1,fb_dimen_x
	move.l d2,fb_dimen_y
	move.l #E_Ok,d0
	rts
.0002:
	cmpi.b #2,d0		; set window dimensions
	bne.s .0003
	movem.l d1/d2,-(a7)
	ext.l d2
	swap d2
	ext.l d1
	or.l d2,d1
	move.l d1,FRAMEBUF+FRAMEBUF_WINDOW_DIMEN
	movem.l (a7)+,d1/d2
.0003:
	move.l #E_Ok,d0
	rts


;---------------------------------------------------------------------
; The following uses point plot hardware built into the frame buffer.
; It is assumed that previous commands have finished already.
; It may take a few dozen clocks for a command to complete. As long
; as this routine is not called to fast in succession it should be
; okay.
;---------------------------------------------------------------------

framebuf_writeat:
plot:
	bra plot_sw
	movem.l d1/d2/a0,-(a7)
	move.l #FRAMEBUF,a0
.0001:
;	tst.b 40(a0)				; wait for any previous command to finish
;	bne.s .0001										; Then set:
	move.w d1,32(a0)							; pixel x co-ord
	move.w d2,34(a0)							; pixel y co-ord
	move.w fb_fg_color,44(a0)	; pixel color
	move.b fb_opcode,41(a0)	; set raster operation
	move.b #2,40(a0)							; point plot command
	movem.l (a7)+,d1/d2/a0
	rts

;-------------------------------------------
; In case of lacking hardware plot
;-------------------------------------------

plottbl:
	dc.l plot_black
	dc.l plot_copy
	dc.l plot_copy
	dc.l plot_and
	dc.l plot_or
	dc.l plot_xor
	dc.l plot_copy
	dc.l plot_copy
	dc.l plot_copy
	dc.l plot_copy
	dc.l plot_copy
	dc.l plot_copy
	dc.l plot_copy
	dc.l plot_copy
	dc.l plot_white

plot_sw:
	movem.l d1/d2/d3/d4/a0/a1,-(a7)
	mulu fb_dimen_x,d2	; multiply y by screen width
;	move.l d1,d3
;	andi.l #30,d3
;	moveq #30,d4
;	sub.l d4,d3
;	andi.l #$FFFFFFE0,d1
;	or.l d3,d1
	ext.l d1											; clear high-order word of x
	add.l d1,d2										; add in x co-ord
	add.l d2,d2										; *2 for 16 BPP
	move.l fb_outbuf_ptr2,a0		; where the draw occurs
	move.b fb_opcode,d3				; raster operation
	ext.w d3
	lsl.w #2,d3
	move.l plottbl(pc,d3.w),a1
	jmp (a1)
plot_or:
	move.w (a0,d2.l),d4	
	or.w fb_fg_color,d4
	move.w d4,(a0,d2.l)
	movem.l (a7)+,d1/d2/d3/d4/a0/a1
	rts
plot_xor:
	move.w (a0,d2.l),d4
	move.w fb_fg_color,d3	
	eor.w d3,d4
	move.w d4,(a0,d2.l)
	movem.l (a7)+,d1/d2/d3/d4/a0/a1
	rts
plot_and:
	move.w (a0,d2.l),d4	
	and.w fb_fg_color,d4
	move.w d4,(a0,d2.l)
	movem.l (a7)+,d1/d2/d3/d4/a0/a1
	rts
plot_copy:
	move.w fb_fg_color,(a0,d2.l)
	movem.l (a7)+,d1/d2/d3/d4/a0/a1
	rts
plot_black:
	clr.w (a0,d2.l)
	movem.l (a7)+,d1/d2/d3/d4/a0/a1
	rts
plot_white:
	move.w #$FF7F,(a0,d2.l)
	movem.l (a7)+,d1/d2/d3/d4/a0/a1
	rts


clear_graphics_screen:
;	move.l #0,d1
;	bsr gfxaccel_set_color
;	move.l #0,d1
;	move.l #0,d2
;	move.l #1920<<16,d3
;	move.l #1080<<16,d4
;	bsr gfxaccel_draw_rectangle
	move.l #VIDEO_X*VIDEO_Y,d5		; compute number of strips to write
	lsr.l #3,d5						; 8 pixels per strip
;	move.l fb_outbuf_ptr,a4
	move.l #$40000000,a4
	move.l #0,$7FFFFFF8		; burst length of zero
	bra.s .0001
.0002:
	swap d5
.0001:
	move.l a4,d1
	move.l d1,$7FFFFFF4		; target address
	move.l #0,$7FFFFFFC		; value to write
	lea.l 32(a4),a4
	dbra d5,.0001
;	swap d5
;	dbra d5,.0002
	rts


; Clears the page opposite to the display page

framebuf_clear:
	fmove.x fp0,-(a7)
	fmove.x fp1,-(a7)
	movem.l d1/d2/d4/a0,-(a7)
	move.b FRAMEBUF+3,d1		; get displayed page
	cmpi.b #1,d1
	bne.s .0001
	move.l fb_outbuf_ptr,a0		; where the draw occurs
	bra.s .0002
.0001
	move.l fb_outbuf_ptr2,a0		; where the draw occurs
.0002
	move.l fb_dimen_x,d1
	move.l fb_dimen_y,d2
	mulu d1,d2							; d2 = X dimen * Y dimen = number of pixels
	move.l FRAMEBUF+FRAMEBUF_PPS,d1
	andi.w #$3ff,d1					; extract pixels per strip
	ext.l d1
	move.l d1,d4						; d4.w = pixels per strip
	add.l d4,d2							; round number of pixels on screen up a strip
	fmove.l d2,fp0					; number might be too big for divu
	fmove.l d4,fp1					; so use float divider
	fdiv fp1,fp0						; fp0 = screen size / pixels per strip
	fmove.l fp0,d0					; d0 = number of strips to set
	move.l fb_fg_color,d1
	move.l d1,d4
	move.l #0,$7FFFFFF8			; set burst length zero
	bra.s .loop
.loop2:
	swap d0
.loop:
	move.l a0,d1
	move.l d1,$7FFFFFF4			; set destination address
	move.l d4,$7FFFFFFC			; write value (color) to use and trigger write op
	lea 32(a0),a0						; advance pointer
	dbra d0,.loop
	swap d0
	dbra d0,.loop2
	movem.l (a7)+,d1/d2/d4/a0
	fmove.x (a7)+,fp1
	fmove.x (a7)+,fp0
	move.l #E_Ok,d0
	rts

; The following code using bursts of 1k pixels did not work (hardware).
;
;clear_bitmap_screen2:
;	move.l gr_bitmap_screen,a0
;clear_bitmap_screen3:
;	movem.l d0/d2/a0,-(a7)
;	move.l #$3F3F3F3F,$BFFFFFF4	; 32x64 byte burst
;	move.w pen_color,d0
;	swap d0
;	move.w pen_color,d0
;	move.w gr_width,d2		; calc. number of pixels on screen
;	mulu gr_height,d2
;	add.l #1023,d2				; rounding up
;	lsr.l #8,d2						; divide by 1024 pixel update
;	lsr.l #2,d2
;.0001:
;	move.l a0,$BFFFFFF8		; write update address
;	add.l #2048,a0				; update pointer
;	move.l d0,$BFFFFFFC		; trigger burst write of 2048 bytes
;	dbra d2,.0001
;	movem.l (a7)+,d0/d2/a0
;	rts

; More conventional but slow way of clearing the screen.
;
;clear_bitmap_screen:
;	move.l gr_bitmap_screen,a0
;clear_bitmap_screen1:
;	movem.l d0/d2/a0,-(a7)
;	move.w pen_color,d0
;	swap d0
;	move.w pen_color,d0
;	move.w gr_width,d2		; calc. number of pixels on screen
;	mulu gr_height,d2			; 800x600 = 480000
;	bra.s .0001
;.0002:
;	swap d2
;.0001:
;	move.l d0,(a0)+
;	dbra d2,.0001
;	swap d2
;	dbra d2,.0002
;	movem.l (a7)+,d0/d2/a0
;	rts

