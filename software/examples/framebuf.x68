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

FB_CTA macro arg1
	dc.w ((\1-FRAMEBUF_CMDTBL)>>2)
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
	FB_CTA framebuf_init				; 0
	FB_CTA framebuf_stat
	FB_CTA framebuf_putchar
	FB_CTA framebuf_putbuf
	FB_CTA framebuf_getchar
	FB_CTA framebuf_getbuf
	FB_CTA framebuf_set_inpos
	FB_CTA framebuf_set_outpos
	FB_CTA framebuf_stub
	FB_CTA framebuf_stub
	FB_CTA framebuf_stub				; 10
	FB_CTA framebuf_stub
	FB_CTA framebuf_clear
	FB_CTA framebuf_swapbuf
	FB_CTA framebuf_setbuf1
	FB_CTA framebuf_setbuf2
	FB_CTA framebuf_getbuf1
	FB_CTA framebuf_getbuf2
	FB_CTA framebuf_writeat
	FB_CTA framebuf_set_unit
	FB_CTA framebuf_get_dimen	; 20
	FB_CTA framebuf_get_color
	FB_CTA framebuf_stub
	FB_CTA framebuf_stub
	FB_CTA framebuf_stub
	FB_CTA framebuf_stub
	FB_CTA framebuf_stub
	FB_CTA framebuf_stub
	FB_CTA framebuf_stub
	FB_CTA framebuf_stub
	FB_CTA framebuf_stub			; 30
	FB_CTA framebuf_stub
	FB_CTA framebuf_set_dimen
	FB_CTA framebuf_set_color_depth
	FB_CTA framebuf_set_destbuf
	FB_CTA framebuf_set_dispbuf

	code
	even
framebuf_cmdproc:
	cmpi.b #36,d6
	bhs.s .0001
	movem.l d6/a0,-(a7)
	ext.w d6
	ext.l d6
	lsl.w #2,d6
	lea.l FRAMEBUF_CMDTBL(pc),a0
	move.w (a0,d6.w),d6
	ext.l d6
	lsl.l #2,d6
	add.l d6,a0
	jsr (a0)
	movem.l (a7)+,d6/a0
	rts
.0001:
	moveq #E_Func,d0
	rts

	align 2
setup_framebuf:
	movem.l d0/a0/a1,-(a7)
	moveq #32,d0
	lea.l framebuf_dcb,a0
.0001:
	clr.l (a0)+
	dbra d0,.0001
	move.l #$44434220,framebuf_dcb+DCB_MAGIC			; 'DCB '
	move.l #$4652414D,framebuf_dcb+DCB_NAME				; 'FRAMEBUF'
	move.l #$42554600,framebuf_dcb+DCB_NAME+4
	move.l #framebuf_cmdproc,framebuf_dcb+DCB_CMDPROC
	move.l #$00000000,d0
	move.l d0,framebuf_dcb+DCB_INBUFPTR
	move.l d0,framebuf_dcb+DCB_OUTBUFPTR
	move.l #$00400000,framebuf_dcb+DCB_INBUFSIZE
	move.l #$00400000,framebuf_dcb+DCB_OUTBUFSIZE
	lea.l framebuf_dcb+DCB_MAGIC,a1
	jsr DisplayString
	jsr CRLF
	bsr framebuf_init
	movem.l (a7)+,d0/a0/a1
	rts

	align 2
framebuf_init:
	move.b #1,FRAMEBUF+0		; turn on frame buffer
	move.l #$00002AAA,FRAMEBUF+FRAMEBUF_COLOR_COMP	; 2-10-10-10 color
	move.b #$11,FRAMEBUF+2	; hres 1:1 vres 1:1
	move.l #$0F000063,FRAMEBUF+4		; burst length, burst interval
	move.l #$3fffffff,framebuf_dcb+DCB_FGCOLOR	; white
	move.l #$000000ff,framebuf_dcb+DCB_BKCOLOR	; medium blue
	clr.l framebuf_dcb+DCB_OUTPOSX
	clr.l framebuf_dcb+DCB_OUTPOSY
	clr.l framebuf_dcb+DCB_INPOSX
	clr.l framebuf_dcb+DCB_INPOSY
	move.b #1,framebuf_dcb+DCB_OPCODE	; raster op = copy
	move.w #800,framebuf_dcb+DCB_OUTDIMX		; set rows and columns
	move.w #600,framebuf_dcb+DCB_OUTDIMY
	move.w #800,framebuf_dcb+DCB_INDIMX			; set rows and columns
	move.w #600,framebuf_dcb+DCB_INDIMY
	move.l #$00000000,framebuf_dcb+DCB_INBUFPTR
	move.l #$00400000,framebuf_dcb+DCB_INBUFPTR2
	move.l #$00000000,framebuf_dcb+DCB_OUTBUFPTR
	move.l #$00200000,framebuf_dcb+DCB_OUTBUFPTR2
	move.l #$00000000,FRAMEBUF+FRAMEBUF_PAGE1_ADDR	; base addr 1
	move.l #$00200000,FRAMEBUF+FRAMEBUF_PAGE2_ADDR	; base addr 2
	rts

	align 2
framebuf_stat:
framebuf_putchar:
framebuf_getchar:
framebuf_set_destbuf:
	rts

	align 2
framebuf_set_inpos:
	move.l d1,framebuf_dcb+DCB_INPOSX
	move.l d2,framebuf_dcb+DCB_INPOSY
	rts
	align 2
framebuf_set_outpos:
	move.l d1,framebuf_dcb+DCB_OUTPOSX
	move.l d2,framebuf_dcb+DCB_OUTPOSY
	rts

	align 2
framebuf_getbuf1:
	move.l framebuf_dcb+DCB_OUTBUFPTR,d1
	rts
	align 2
framebuf_getbuf2:
	move.l framebuf_dcb+DCB_OUTBUFPTR2,d1
	rts
	align 2
framebuf_setbuf1:
	move.l d1,framebuf_dcb+DCB_OUTBUFPTR
	move.l d2,framebuf_dcb+DCB_OUTBUFSIZE
	rts
	align 2
framebuf_setbuf2:
	move.l d1,framebuf_dcb+DCB_OUTBUFPTR2
	move.l d2,framebuf_dcb+DCB_OUTBUFSIZE2
	rts

	align 2
framebuf_swapbuf:
	movem.l d1/d2,-(a7)
	move.b FRAMEBUF+3,d1
	eor.b #1,d1
	move.b d1,FRAMEBUF+3					; page flip
	move.l framebuf_dcb+DCB_OUTBUFPTR,d2
	move.l framebuf_dcb+DCB_OUTBUFPTR2,d0
	move.l d2,framebuf_dcb+DCB_OUTBUFPTR2
	move.l d0,framebuf_dcb+DCB_OUTBUFPTR
	move.l d0,GFXACCEL+16+256
	move.l framebuf_dcb+DCB_INBUFPTR,d2
	move.l framebuf_dcb+DCB_INBUFPTR2,d0
	move.l d2,framebuf_dcb+DCB_INBUFPTR2
	move.l d0,framebuf_dcb+DCB_INBUFPTR
	movem.l (a7)+,d1/d2
	move.l #E_Ok,d0
	rts

	align 2
framebuf_set_dispbuf:
	move.b d1,FRAMEBUF+3					; set display page
	move.l #E_Ok,d0
	rts

	align 2
framebuf_set_unit:
	move.l d1,framebuf_dcb+DCB_UNIT
	move.l #E_Ok,d0
	rts

	align 2
framebuf_getbuf:
framebuf_putbuf:
framebuf_stub:
	moveq #E_NotSupported,d0
	rts

	align 2
framebuf_set_color_depth:
	move.l d1,FRAMEBUF+FRAMEBUF_COLOR_COMP
	move.l #E_Ok,d0
	rts
	
	align 2
framebuf_get_color:
	move.l framebuf_dcb+DCB_FGCOLOR,d1
	move.l framebuf_dcb+DCB_BKCOLOR,d2
	move.l #E_Ok,d0
	rts

	align 2
framebuf_get_dimen:
	cmpi.b #0,d0
	bne.s .0001
	move.l framebuf_dcb+DCB_OUTDIMX,d1
	move.l framebuf_dcb+DCB_OUTDIMY,d2
	move.l framebuf_dcb+DCB_OUTDIMZ,d3
	move.l #E_Ok,d0
	rts
.0001:
	move.l framebuf_dcb+DCB_INDIMX,d1
	move.l framebuf_dcb+DCB_INDIMY,d2
	move.l framebuf_dcb+DCB_INDIMZ,d3
	move.l #E_Ok,d0
	rts

	align 2
framebuf_set_dimen:
	cmpi.b #0,d0
	bne.s .0001
	move.l d1,framebuf_dcb+DCB_OUTDIMX
	move.l d2,framebuf_dcb+DCB_OUTDIMY
	move.l d3,framebuf_dcb+DCB_OUTDIMZ
	move.l d1,FRAMEBUF+FRAMEBUF_BMPSIZE_X
	move.l d2,FRAMEBUF+FRAMEBUF_BMPSIZE_Y
	move.l #E_Ok,d0
	rts
.0001:
	cmpi.b #1,d0
	bne.s .0002
	move.l d1,framebuf_dcb+DCB_INDIMX
	move.l d2,framebuf_dcb+DCB_INDIMY
	move.l d3,framebuf_dcb+DCB_INDIMZ
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

	align 2
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
	move.w framebuf_dcb+DCB_FGCOLOR,44(a0)	; pixel color
	move.b framebuf_dcb+DCB_OPCODE,41(a0)	; set raster operation
	move.b #2,40(a0)							; point plot command
	movem.l (a7)+,d1/d2/a0
	rts

;-------------------------------------------
; In case of lacking hardware plot
;-------------------------------------------
	align 2
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

	align 2
plot_sw:
	movem.l d1/d2/d3/d4/a0/a1,-(a7)
	mulu framebuf_dcb+DCB_OUTDIMX,d2	; multiply y by screen width
;	move.l d1,d3
;	andi.l #30,d3
;	moveq #30,d4
;	sub.l d4,d3
;	andi.l #$FFFFFFE0,d1
;	or.l d3,d1
	ext.l d1											; clear high-order word of x
	add.l d1,d2										; add in x co-ord
	add.l d2,d2										; *2 for 16 BPP
	move.l framebuf_dcb+DCB_OUTBUFPTR2,a0		; where the draw occurs
	move.b framebuf_dcb+DCB_OPCODE,d3				; raster operation
	ext.w d3
	lsl.w #2,d3
	move.l plottbl(pc,d3.w),a1
	jmp (a1)
plot_or:
	move.w (a0,d2.l),d4	
	or.w framebuf_dcb+DCB_FGCOLOR,d4
	move.w d4,(a0,d2.l)
	movem.l (a7)+,d1/d2/d3/d4/a0/a1
	rts
plot_xor:
	move.w (a0,d2.l),d4
	move.w framebuf_dcb+DCB_FGCOLOR,d3	
	eor.w d3,d4
	move.w d4,(a0,d2.l)
	movem.l (a7)+,d1/d2/d3/d4/a0/a1
	rts
plot_and:
	move.w (a0,d2.l),d4	
	and.w framebuf_dcb+DCB_FGCOLOR,d4
	move.w d4,(a0,d2.l)
	movem.l (a7)+,d1/d2/d3/d4/a0/a1
	rts
plot_copy:
	move.w framebuf_dcb+DCB_FGCOLOR,(a0,d2.l)
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


	align 2
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
;	move.l framebuf_dcb+DCB_OUTBUFPTR,a4
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

	align 2
framebuf_clear:
	fmove.x fp0,-(a7)
	fmove.x fp1,-(a7)
	movem.l d1/d2/d4/a0,-(a7)
	move.b FRAMEBUF+3,d1		; get displayed page
	cmpi.b #1,d1
	bne.s .0001
	move.l framebuf_dcb+DCB_OUTBUFPTR,a0		; where the draw occurs
	bra.s .0002
.0001
	move.l framebuf_dcb+DCB_OUTBUFPTR2,a0		; where the draw occurs
.0002
	move.l framebuf_dcb+DCB_OUTDIMX,d1
	move.l framebuf_dcb+DCB_OUTDIMY,d2
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
	move.l framebuf_dcb+DCB_FGCOLOR,d1
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

