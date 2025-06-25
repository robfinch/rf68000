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

; the following constant is used to scramble device handles. The device handle
; (address) is rotated 16 bits then xor'd with this value.

DEV_HMASH	equ $56791123

DEV_INIT equ 0
DEV_STAT equ 1
DEV_PUTCHAR equ 2
DEV_PUTBUF equ 3
DEV_GETCHAR equ 4
DEV_GETBUF equ 5
DEV_SET_INPOS equ 6
DEV_SET_OUTPOS equ 7
DEV_GETCHAR_DIRECT equ 8
DEV_PEEKCHAR equ 9
DEV_PEEKCHAR_DIRECT equ 10
DEV_PUTCHAR_DIRECT equ 11
DEV_CLEAR equ 12
DEV_SWAPBUF equ 13
DEV_SETBUF1 equ 14
DEV_SETBUF2 equ 15
DEV_GETBUF1 equ 16
DEV_GETBUF2 equ 17
DEV_WRITEAT equ 18
DEV_SETUNIT equ 19
DEV_GET_DIMEN equ 20
DEV_GET_COLOR equ 21
DEV_GET_INPOS equ 22
DEV_GET_OUTPOS equ 23
DEV_GET_OUTPTR equ 24
DEV_SET_COLOR equ 25
DEV_SET_COLOR123 equ 26
DEV_PLOT_POINT equ 27
DEV_DRAW_LINE equ 28
DEV_DRAW_TRIANGLE equ 29
DEV_DRAW_RECTANGLE equ 30
DEV_DRAW_CURVE equ 31
DEV_SET_DIMEN equ 32
DEV_SET_COLOR_DEPTH equ 33
DEV_SET_DESTBUF equ 34
DEV_SET_DISPBUF equ 35
DEV_GET_INPTR equ 36

DCB_MAGIC equ	0			; 'DCB'
DCB_NAME	equ 4			; 11 chars+NULL
DCB_CMDPROC	equ 24	; 8 byte pointer to command processor
DCB_OUTPOSX equ 32
DCB_OUTPOSY equ 36
DCB_OUTPOSZ equ 40
DCB_INPOSX equ 44
DCB_INPOSY equ 48
DCB_INPOSZ equ 52
DCB_INBUFPTR equ 56
DCB_OUTBUFPTR equ 60
DCB_INBUFSIZE equ 64
DCB_OUTBUFSIZE equ 68
DCB_INDIMX equ 72
DCB_INDIMY equ 76
DCB_INDIMZ equ 80
DCB_OUTDIMX equ 84
DCB_OUTDIMY equ 88
DCB_OUTDIMZ equ 92
DCB_BKCOLOR equ 96
DCB_FGCOLOR equ 100
DCB_OPCODE equ 104
DCB_LASTERC equ 108
DCB_INBUFPTR2 equ 112
DCB_OUTBUFPTR2 equ 116
DCB_INBUFSIZE2 equ 120
DCB_OUTBUFSIZE2 equ 124
DCB_UNIT equ 128
DCB_SIZE equ 132

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
