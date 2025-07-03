; ============================================================================
;        __
;   \\__/ o\    (C) 2020-2025  Robert Finch, Waterloo
;    \  __ /    All rights reserved.
;     \/_//     robfinch<remove>@finitron.ca
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

	ifnd DEV_HMASH

macRbo macro arg1
	rol.w #8,\1
	swap \1
	rol.w #8,\1
endm

; the following constant is used to scramble device handles. The device handle
; (address) is rotated 16 bits then xor'd with this value.

DEV_HMASH	equ $56791123

DEV_NOP equ 0
DEV_SETUP equ 1
DEV_INIT equ 2
DEV_STAT equ 3
DEV_MEDIA_CHECK equ 4
DEV_OPEN equ 6
DEV_CLOSE equ 7
DEV_GETCHAR equ 8
DEV_PEEKCHAR equ 9
DEV_GETCHAR_DIRECT equ 10
DEV_PEEKCHAR_DIRECT equ 11
DEV_INPUT_STATUS equ 12
DEV_PUTCHAR equ 13
DEV_PUTCHAR_DIRECT equ 14
DEV_SET_POSITION equ 15
DEV_READ_BLOCK equ 16
DEV_WRITE_BLOCK equ 17
DEV_VERIFY_BLOCK equ 18
DEV_OUTPUT_STATUS equ 19
DEV_FLUSH_INPUT equ 20
DEV_FLUST_OUTPUT equ 21
DEV_IRQ equ 22
DEV_IS_REMOVEABLE equ 23
DEV_IOCTRL_READ equ 24
DEV_IOCTRL_WRITE equ 25
DEV_OUTPUT_UNTIL_BUSY equ 26
DEV_SHUTDOWN equ 27
DEV_CLEAR equ 28
DEV_SWAPBUF equ 29
DEV_SETBUF1 equ 30
DEV_SETBUF2 equ 31
DEV_GETBUF1 equ 32
DEV_GETBUF2 equ 33
DEV_GET_DIMEN equ 34
DEV_GET_COLOR equ 35
DEV_GET_POSITION equ 36
DEV_SET_COLOR equ 37
DEV_SET_COLOR123 equ 38
DEV_PLOT_POINT equ 40
DEV_DRAW_LINE equ 41
DEV_DRAW_TRIANGLE equ 42
DEV_DRAW_RECTANGLE equ 43
DEV_DRAW_CURVE equ 44
DEV_SET_DIMEN equ 45
DEV_SET_COLOR_DEPTH equ 46
DEV_SET_DESTBUF equ 47
DEV_SET_DISPBUF equ 48
DEV_GET_INPOS equ 49
DEV_SET_INPOS equ 50
DEV_SET_OUTPOS equ 51
DEV_GET_OUTPOS equ 52
DEV_GET_INPTR	equ 53
DEV_GET_OUTPTR equ 54
DEV_SET_UNIT equ 55
DEV_SET_ECHO equ 56

DCB_MAGIC equ	0			; 'DCB'
DCB_NAME	equ 4			; 11 chars+NULL
DCB_CMDPROC	equ 16	; 8 byte pointer to command processor
DCB_TYPE equ 20
DCB_REENTRY_COUNT equ 21
DCB_SINGLE_USER equ 22
DCB_UNIT_SIZE equ 23
DCB_PAD1 equ 24
DCB_BPB equ 28
DCB_LASTERC equ 32
DCB_START_BLOCK equ 36
DCB_NBLOCKS equ 40
DCB_HMBX_SEND equ 44
DCB_HMBX_RCV equ 46
DCB_HAPP equ 48
DCB_RESV1 equ 50
DCB_PSEMA equ 52
DCB_RESV2 equ 56
DCB_SIZE equ 64

;Standard Devices are:

;#		Device					Standard name

;0		NULL device 			NUL		(OS built-in)
;1		Keyboard (sequential)	KBD		(OS built-in, ReadOnly)
;2		Video (sequential)		VID		(OS built-in, WriteOnly)
;3		Printer (parallel 1)	LPT		(OS built-in)
;4		Printer (parallel 2)	LPT2	(OS built-in)
;5		RS-232 1				COM1	(OS built-in)
;6		RS-232 2				COM2	(OS built-in)
;7		RS-232 3				COM3	(OS built-in)
;8		RS-232 4				COM4	(OS built-in)
;9
;10		Floppy					FD0 	(OS built-in)
;11		Floppy					FD1 	(OS built-in)
;12		Hard disk				HD0 	(OS built-in)
;13		Hard disk				HD1 	(OS built-in)
;14
;15
;16
;17
;18
;19
;20
;21
;22
;23

leds equ $FDFFC000
KEYBD equ	$FDFF8000
FRAMEBUF EQU	$FD208000
FRAMEBUF_CTRL equ 0
MMU	equ	$FDC00000
PLIC equ $FD260000
GFXACCEL equ $FD210000
TEXTREG		equ	$FD080000

	endif
